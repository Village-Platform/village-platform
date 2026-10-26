#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates the backlog in scripts/backlog/backlog.json on GitHub: labels, milestones, issues
# (backend in village-platform, Android in aghour-android), epic -> sub-issue links and one
# GitHub Project board for both repositories.
#
# Safe to run again: everything is matched by name or title and only missing things are created.
#
#   gh auth refresh -s project            # once, the project commands need this scope
#   ruby scripts/backlog/sync.rb --dry-run
#   ruby scripts/backlog/sync.rb
#
# Only the Ruby standard library and the `gh` CLI are used.

require "json"
require "open3"
require "optparse"

options = { owner: "village-platform", project: "Aghour village platform", dry_run: false, skip_project: false }
OptionParser.new do |o|
  o.on("--owner NAME", "GitHub user or organization (default: village-platform)") { |v| options[:owner] = v }
  o.on("--project TITLE", "Project board title") { |v| options[:project] = v }
  o.on("--dry-run", "Print what would be created, change nothing") { options[:dry_run] = true }
  o.on("--skip-project", "Only labels, milestones and issues") { options[:skip_project] = true }
end.parse!

OWNER = options[:owner]
DRY_RUN = options[:dry_run]
ITEMS = JSON.parse(File.read(File.join(__dir__, "backlog.json")))
REPOS = ITEMS.map { |i| i["repo"] }.uniq

LABEL_COLORS = {
  "epic" => "5319e7", "type" => "1d76db", "priority" => "b60205", "size" => "c5def5",
  "horizon" => "fbca04", "area" => "0e8a16", "phase" => "c28d40", "status" => "d4c5f9"
}.freeze
PLACEHOLDER = "_Being created by scripts/backlog/sync.rb._"

def gh(*args, input: nil, write: false, allow_fail: false)
  if write && DRY_RUN
    puts "  [dry-run] gh #{args.join(' ')}"
    return nil
  end

  out, err, status = Open3.capture3("gh", *args, stdin_data: input)
  unless status.success?
    return warn("  skipped: #{err.strip}") if allow_fail

    abort "gh #{args.join(' ')} failed:\n#{err}"
  end
  out.strip.empty? ? nil : JSON.parse(out)
rescue JSON::ParserError
  out
end

def api(path, method: "GET", body: nil)
  args = [ "api", "-X", method, path ]
  args += [ "--input", "-" ] if body
  args += [ "--paginate", "--slurp" ] if method == "GET"
  result = gh(*args, input: body&.to_json, write: method != "GET")
  method == "GET" ? result.flatten : result
end

def labels_for(item)
  return [ "epic", "phase:#{phase_key(item)}" ] if item["epic"]

  list = [ "type:#{item['type']}", "priority:#{item['priority']}", "size:#{item['size']}",
           "horizon:#{item['horizon']}", "phase:#{phase_key(item)}" ]
  list += item["areas"].map { |a| "area:#{a}" }
  list << "status:partial" if item["status"] == "partial"
  list
end

def phase_key(item) = item["phase"]

# 1. Labels and milestones ------------------------------------------------------------------
milestones = {}
REPOS.each do |repo|
  puts "== #{OWNER}/#{repo}"
  repo_items = ITEMS.select { |i| i["repo"] == repo }

  existing_labels = api("repos/#{OWNER}/#{repo}/labels").to_h { |l| [ l["name"], l["color"] ] }
  repo_items.flat_map { |i| labels_for(i) }.uniq.each do |name|
    color = LABEL_COLORS.fetch(name.split(":").first)
    next if existing_labels[name] == color

    puts "  label #{name}"
    gh("label", "create", name, "--repo", "#{OWNER}/#{repo}", "--color", color, "--force", write: true)
  end

  existing = api("repos/#{OWNER}/#{repo}/milestones?state=all").to_h { |m| [ m["title"], m["number"] ] }
  repo_items.map { |i| i["milestone"] }.uniq.each do |title|
    unless existing[title]
      puts "  milestone #{title}"
      created = api("repos/#{OWNER}/#{repo}/milestones", method: "POST", body: { title: title })
      existing[title] = created&.fetch("number")
    end
    milestones[[ repo, title ]] = existing[title]
  end
end

# 2. Issues: create the missing ones with a placeholder body, so every number is known ---------
issues = {} # backlog id => { "number", "id", "html_url" }
REPOS.each do |repo|
  by_title = api("repos/#{OWNER}/#{repo}/issues?state=all&per_page=100")
    .reject { |i| i.key?("pull_request") }
    .to_h { |i| [ i["title"], i ] }

  ITEMS.select { |i| i["repo"] == repo }.each do |item|
    if (found = by_title[item["title"]])
      issues[item["id"]] = found
      next
    end

    puts "  create #{repo}: #{item['title']}"
    created = api("repos/#{OWNER}/#{repo}/issues", method: "POST",
                  body: { title: item["title"], body: PLACEHOLDER, labels: labels_for(item),
                          milestone: milestones[[ repo, item["milestone"] ]] })
    issues[item["id"]] = created || { "number" => 0, "id" => 0, "html_url" => "" }
    sleep 1 unless DRY_RUN # stay under GitHub's content-creation rate limit
  end
end

# 3. Bodies with real cross-links, and close what is already done ------------------------------
def render(body, repo, issues, items)
  body.gsub(/\{\{([A-Z0-9-]+)\}\}/) do
    id = Regexp.last_match(1)
    target = items.find { |i| i["id"] == id }
    issue = issues[id]
    next "`#{id}`" unless target && issue

    ref = target["repo"] == repo ? "##{issue['number']}" : "#{OWNER}/#{target['repo']}##{issue['number']}"
    "#{ref} (#{id})"
  end
end

ITEMS.each do |item|
  issue = issues[item["id"]]
  body = render(item["body"], item["repo"], issues, ITEMS)
  update = {}
  update[:body] = body if issue["body"] != body
  milestone = milestones[[ item["repo"], item["milestone"] ]]
  update[:milestone] = milestone if milestone && issue.dig("milestone", "number") != milestone
  update.merge!(state: "closed", state_reason: "completed") if item["status"] == "done" && issue["state"] != "closed"
  next if update.empty?

  puts "  update #{item['repo']}##{issue['number']} #{item['id']} (#{update.keys.join(', ')})"
  api("repos/#{OWNER}/#{item['repo']}/issues/#{issue['number']}", method: "PATCH", body: update)
end

# 4. Epic -> sub-issue links -----------------------------------------------------------------
ITEMS.select { |i| i["parent"] }.group_by { |i| i["parent"] }.each do |parent_id, children|
  parent = issues[parent_id]
  repo = ITEMS.find { |i| i["id"] == parent_id }["repo"]
  linked = DRY_RUN && parent["number"].zero? ? [] : api("repos/#{OWNER}/#{repo}/issues/#{parent['number']}/sub_issues").map { |s| s["id"] }

  children.each do |child|
    sub = issues[child["id"]]
    next if linked.include?(sub["id"])

    puts "  link #{child['id']} -> #{parent_id}"
    api("repos/#{OWNER}/#{repo}/issues/#{parent['number']}/sub_issues", method: "POST", body: { sub_issue_id: sub["id"] })
  end
end

exit if options[:skip_project]

# 5. Project board -------------------------------------------------------------------------
puts "== project #{options[:project]}"
project = gh("project", "list", "--owner", OWNER, "--format", "json", "--limit", "100")["projects"]
  .find { |p| p["title"] == options[:project] }
project ||= gh("project", "create", "--owner", OWNER, "--title", options[:project], "--format", "json", write: true)
if project.nil?
  puts "  [dry-run] would add #{ITEMS.size} issues to the project and set Priority, Size and Phase"
  exit
end
number = project["number"].to_s

REPOS.each { |repo| gh("project", "link", number, "--owner", OWNER, "--repo", "#{OWNER}/#{repo}", write: true, allow_fail: true) }

FIELDS = {
  "Priority" => %w[P0 P1 P2 P3],
  "Size" => %w[XS S M L],
  "Phase" => ITEMS.map { |i| phase_key(i) }.uniq
}.freeze
fields = gh("project", "field-list", number, "--owner", OWNER, "--format", "json", "--limit", "100")["fields"]
FIELDS.each do |name, values|
  next if fields.any? { |f| f["name"] == name }

  puts "  field #{name}"
  gh("project", "field-create", number, "--owner", OWNER, "--name", name,
     "--data-type", "SINGLE_SELECT", "--single-select-options", values.join(","), write: true)
end
fields = gh("project", "field-list", number, "--owner", OWNER, "--format", "json", "--limit", "100")["fields"]

ITEMS.each do |item|
  added = gh("project", "item-add", number, "--owner", OWNER, "--url", issues[item["id"]]["html_url"],
             "--format", "json", write: true)
  next unless added

  values = { "Priority" => item["priority"]&.upcase, "Size" => item["size"], "Phase" => phase_key(item) }
  values.each do |name, value|
    field = fields.find { |f| f["name"] == name }
    option = field && field["options"]&.find { |o| o["name"] == value }
    next unless option

    gh("project", "item-edit", "--id", added["id"], "--project-id", project["id"],
       "--field-id", field["id"], "--single-select-option-id", option["id"], write: true)
  end
  puts "  added #{item['id']}"
end

puts "Done: #{project['url']}"
