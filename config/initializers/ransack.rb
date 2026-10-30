# frozen_string_literal: true

Ransack.configure do |c|
  # Strip whitespace from search inputs
  c.strip_whitespace = true

  # Filters arrive under `f[...]`. `q` is already the plain-text search the shipped Android app
  # sends to /api/v1/firms and that every admin search box uses; ransack's default key is also
  # `q` but expects a hash, so sharing it would break search on every installed app.
  c.search_key = :f

  # A condition outside the caller's allowlist is dropped rather than raised, so an old app
  # version that sends a filter a newer server no longer accepts still gets a result.
  c.ignore_unknown_conditions = true
end
