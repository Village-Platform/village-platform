# Idempotent seeds: safe to run many times (bin/rails db:seed).

admin = User.find_or_initialize_by(phone: User.normalize_value_for(:phone, ENV.fetch("SUPER_ADMIN_PHONE", "01000000000")))
if admin.new_record?
  admin.assign_attributes(
    name: "مدير النظام",
    password: ENV.fetch("SUPER_ADMIN_PASSWORD") {
      raise "Set SUPER_ADMIN_PASSWORD before seeding production" if Rails.env.production?

      "change-me-please"
    },
    role: :super_admin
  )
  admin.save!
end

# `icon` keys (doctor, pharmacy, restaurant, ...) pick the default image from db/seeds/category_icons/
# and are what older Android versions map to built-in symbols. The image is attached only once,
# so an icon uploaded from the dashboard is never replaced.
[
  { name: "أطباء",        position: 1, icon: "doctor",     description: "عيادات وأطباء القرية" },
  { name: "صيدليات",      position: 2, icon: "pharmacy",   description: "صيدليات ومستلزمات طبية" },
  { name: "مطاعم",        position: 3, icon: "restaurant", description: "مطاعم وكافيهات ومأكولات" },
  { name: "محلات تجارية", position: 4, icon: "shop",       description: "بقالة وسوبر ماركت وملابس وأدوات" },
  { name: "حرفيون",       position: 5, icon: "craft",      description: "سباكة وكهرباء ونجارة وصيانة" },
  { name: "مدارس",        position: 6, icon: "school",     description: "مدارس وحضانات ومراكز دروس" },
  { name: "مخابز",        position: 7, icon: "bakery",     description: "مخابز بلدي وأفرنجي وحلويات" },
  { name: "مواصلات",      position: 8, icon: "transport",  description: "مواقف ومكاتب نقل وتوصيل" },
  { name: "مساجد",        position: 9, icon: "mosque",     description: "مساجد وزوايا القرية" },
  { name: "رياضة وشباب",  position: 10, icon: "sports",    description: "مركز الشباب والجيم والملاعب" },
  { name: "خدمات عامة",   position: 11, icon: "services",  description: "البريد والمصالح الحكومية" }
].each do |attrs|
  category = Category.find_or_initialize_by(name: attrs[:name])
  category.position = attrs[:position] if category.new_record?
  category.icon ||= attrs[:icon]
  category.description ||= attrs[:description]
  category.save!
  category.attach_default_icon!
end

Article.find_or_create_by!(title: "مرحباً بكم في تطبيق أجهور الكبرى") do |a|
  a.author = admin
  a.kind = :announcement
  a.body = "تطبيق القرية لكل خدمات أجهور الكبرى: أطباء، صيدليات، مطاعم، وأخبار القرية."
  a.published_at = Time.current
end

# Example plans — adjust prices from the admin endpoints.
[
  { name: "شهري",   price_cents: 10_000,  duration_days: 30,  max_firms: 1, position: 1 },
  { name: "ربع سنوي", price_cents: 27_000, duration_days: 90,  max_firms: 2, position: 2 },
  { name: "سنوي",   price_cents: 100_000, duration_days: 365, max_firms: 3, position: 3 }
].each do |attrs|
  SubscriptionPlan.find_or_create_by!(name: attrs[:name]) { |p| p.assign_attributes(attrs) }
end

# Feature flags the apps read. Created off; only the description is set here, so a flag switched
# on from the dashboard stays on when the seeds run again.
FeatureFlag.find_or_create_by!(key: "plans") do |flag|
  flag.description = "إظهار الباقات والاشتراك في التطبيق"
end

# Push topics. "all" is every device (membership implicit); "news" is listed in the app for opt-in.
Topic.everyone
Topic.find_or_create_by!(key: "news") do |topic|
  topic.assign_attributes(name: "الأخبار", public: true, description: "أخبار القرية ومقالاتها الجديدة")
end

# Demo data (owners, firms, news) for development and testing only.
# Never runs in production unless SEED_DEMO=1 is set on purpose.
if Rails.env.development? || ENV["SEED_DEMO"] == "1"
  load Rails.root.join("db/seeds/demo.rb")
end

puts "Seeded: #{User.count} users, #{Category.count} categories, #{Article.count} articles, #{SubscriptionPlan.count} plans, #{FeatureFlag.count} feature flags, #{Topic.count} topics, #{Firm.count} firms, #{Subscription.count} subscriptions"
