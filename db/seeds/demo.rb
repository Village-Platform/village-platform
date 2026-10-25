# Import only the places in aghour_al_kubra_places.json.
# Put the JSON file at db/seeds/aghour_al_kubra_places.json.
# Requires the existing super admin and application categories to be seeded first.
# Creates no users, subscriptions, articles, or fictional places.
# Re-running updates matching places; it does not delete existing database records.

require "json"

places = JSON.parse(File.read(Rails.root.join("db/seeds/aghour_al_kubra_places.json")))
raise ArgumentError, "Expected a JSON array of places" unless places.is_a?(Array)

admin = User.super_admin.order(:id).first!
categories = Category.all.index_by(&:name)

# Map the source's detailed Arabic types to the application's categories.
place_categories = {
  "صيدليات" => [ "صيدلية" ],
  "أطباء" => [ "أشعة وتحاليل طبية", "عيادة أسنان", "عيادة بيطرية", "عيادة طبية",
               "مستشفى / خدمة طبية", "مركز حضانات أطفال (مصنف خدمة طبية على الخريطة)" ],
  "مدارس" => [ "مدرسة إعدادية", "مدرسة ابتدائية", "مدرسة تعليم عام",
               "مدرسة ثانوية بنات", "مدرسة ثانوية بنين" ],
  "مطاعم" => [ "مطعم", "مطعم بيتزا", "مطعم كريب", "مطعم مشويات", "كافتيريا", "مقهى" ],
  "محلات تجارية" => [ "أجهزة وأدوات كهربائية", "بقالة وسوبر ماركت", "توريد فحم",
                       "سوبر ماركت", "قطع غيار دراجات نارية", "متجر", "متجر أغذية",
                       "متجر سلع عامة", "مجوهرات", "محل تجاري", "مكتبة", "ملابس",
                       "ملابس شبابي", "هواتف محمولة وإكسسوارات" ],
  "حرفيون" => [ "صيانة هواتف محمولة" ],
  "مخابز" => [ "مخبز" ],
  "مساجد" => [ "مسجد" ],
  "رياضة وشباب" => [ "مركز شباب", "نادي رياضي" ],
  "خدمات عامة" => [ "مقابر", "مكتب بريد", "مكتبة عامة", "نقطة إطفاء", "وحدة محلية" ]
}.flat_map { |category, types| types.map { |type| [ type, category ] } }.to_h

# Resolve every category before writing, so no source place is silently skipped.
places.each do |place|
  source_type = place.fetch("details").fetch("category")
  categories.fetch(place_categories.fetch(source_type))
end

created = 0
updated = 0

Firm.transaction do
  places.each do |place|
    details = place.fetch("details")
    source_type = details.fetch("category")

    # Keep full source precision and nil coordinates. Same-name places at
    # different coordinates remain separate listings.
    firm = Firm.find_or_initialize_by(
      name: place.fetch("name"),
      latitude: place.fetch("latitude"),
      longitude: place.fetch("longitude")
    )
    new_record = firm.new_record?
    firm.owner = admin if new_record
    firm.status = :active if new_record
    firm.category = categories.fetch(place_categories.fetch(source_type))
    firm.phone = place.fetch("phone")
    firm.address = details.fetch("address")
    firm.whatsapp = nil
    firm.working_hours = nil

    # Preserve the original detailed category alongside any source notes.
    description = [ source_type, details["description"] ].compact
    facebook = place.fetch("facebook")
    if firm.respond_to?(:facebook_url=)
      firm.facebook_url = facebook
    elsif firm.respond_to?(:facebook=)
      firm.facebook = facebook
    elsif facebook
      # The supplied demo does not establish a Facebook column on Firm.
      description << "فيسبوك: #{facebook}"
    end
    firm.description = description.join("\n")
    firm.save!

    new_record ? created += 1 : updated += 1
  end
end

puts "Places from JSON: #{created} created, #{updated} updated (#{places.size} source records)"
