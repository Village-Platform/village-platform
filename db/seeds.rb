# Idempotent seeds: safe to run many times (bin/rails db:seed).

admin = User.find_or_initialize_by(phone: User.normalize_value_for(:phone, ENV.fetch("SUPER_ADMIN_PHONE", "01000000000")))
if admin.new_record?
  admin.assign_attributes(
    name: "مدير النظام",
    password: ENV.fetch("SUPER_ADMIN_PASSWORD", "change-me-please"),
    role: :super_admin
  )
  admin.save!
end

[
  { name: "أطباء",        position: 1 },
  { name: "صيدليات",      position: 2 },
  { name: "مطاعم",        position: 3 },
  { name: "محلات تجارية", position: 4 },
  { name: "حرفيون",       position: 5 },
  { name: "مدارس",        position: 6 }
].each do |attrs|
  Category.find_or_create_by!(name: attrs[:name]) { |c| c.position = attrs[:position] }
end

Article.find_or_create_by!(title: "مرحباً بكم في تطبيق أجهور الكبرى") do |a|
  a.author = admin
  a.kind = :announcement
  a.body = "تطبيق القرية لكل خدمات أجهور الكبرى: أطباء، صيدليات، مطاعم، وأخبار القرية."
  a.published_at = Time.current
end

puts "Seeded: #{User.count} users, #{Category.count} categories, #{Article.count} articles"
