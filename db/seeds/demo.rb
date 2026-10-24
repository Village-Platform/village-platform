# Demo data for development: firm owners with subscriptions, firms in every category,
# and news of every kind. The owners and their firms are fictional; the "real places"
# section at the end imports public Google Maps listings from aghour_al_kubra_places.json.
# Idempotent: records are found by a unique key and only created once.

admin = User.super_admin.order(:id).first!
plans = SubscriptionPlan.all.index_by(&:name)
categories = Category.all.index_by(&:name)

# Village center (from the Google Maps pins in aghour_al_kubra_places.json);
# fictional firms are spread a few hundred meters around it.
center_lat = 30.3010
center_lng = 31.1450
demo_location = ->(i) { [ (center_lat + ((i % 5) - 2) * 0.0021).round(6), (center_lng + ((i % 7) - 3) * 0.0017).round(6) ] }

# ---- Firm owners and their firms ----
# ends_in: days left on the current subscription (one owner is close to expiry on purpose).
owners = [
  {
    name: "أحمد سالم", phone: "01090000001", plan: "سنوي", ends_in: 300,
    firms: [
      { name: "عيادة د. أحمد سالم للباطنة", category: "أطباء", hours: "يوميًا ٥م - ١٠م عدا الجمعة",
        address: "شارع المستشفى، بجوار مسجد النور", description: "كشف باطنة وسكر وضغط ومتابعة الحالات المزمنة." },
      { name: "مركز الشفاء للتحاليل", category: "أطباء", hours: "يوميًا ٨ص - ٩م", status: :pending,
        address: "الشارع الرئيسي، أمام البنك", description: "تحاليل طبية شاملة وسحب عينات من المنزل." }
    ]
  },
  {
    name: "منى عبد الحميد", phone: "01090000002", plan: "سنوي", ends_in: 210,
    firms: [
      { name: "عيادة د. منى للأطفال", category: "أطباء", hours: "السبت إلى الخميس ٤م - ٩م",
        address: "شارع المدارس، عمارة الصفا الدور الأول", description: "طب أطفال وحديثي الولادة وتطعيمات." },
      { name: "عيادة الابتسامة لطب الأسنان", category: "أطباء", hours: "يوميًا ٢م - ١٠م",
        address: "ميدان القرية", description: "حشو وتنظيف وتركيبات وتقويم أسنان." }
    ]
  },
  {
    name: "محمود الصيدلي", phone: "01090000003", plan: "ربع سنوي", ends_in: 45,
    firms: [
      { name: "صيدلية النور", category: "صيدليات", hours: "يوميًا ٩ص - ١٢م",
        address: "الشارع الرئيسي، بجوار مكتب البريد", description: "أدوية ومستحضرات تجميل وقياس ضغط وسكر مجانًا." },
      { name: "صيدلية الرحمة", category: "صيدليات", hours: "٢٤ ساعة",
        address: "مدخل القرية من ناحية الطريق السريع", description: "خدمة توصيل للمنازل داخل القرية." }
    ]
  },
  {
    name: "سعيد أبو علي", phone: "01090000004", plan: "سنوي", ends_in: 120,
    firms: [
      { name: "فول وطعمية أبو علي", category: "مطاعم", hours: "يوميًا ٦ص - ١٢ظ",
        address: "سوق القرية", description: "فول، طعمية، بطاطس، وسندوتشات الفطار." },
      { name: "مطعم الأصيل للمشويات", category: "مطاعم", hours: "يوميًا ١ظ - ١٢م",
        address: "الشارع الرئيسي، أمام موقف الميكروباص", description: "كباب وكفتة وفراخ مشوية وتوصيل للمنازل." },
      { name: "كافيه النخيل", category: "مطاعم", hours: "يوميًا ٤م - ٢ص", status: :suspended,
        address: "طريق الترعة", description: "مشروبات ساخنة وباردة ومكان للعائلات." }
    ]
  },
  {
    name: "حسن البركة", phone: "01090000005", plan: "شهري", ends_in: 3, # expires soon → shows on the dashboard
    firms: [
      { name: "سوبر ماركت البركة", category: "محلات تجارية", hours: "يوميًا ٨ص - ١١م",
        address: "شارع الجمعية", description: "بقالة وخضار وفاكهة ومنظفات، وتوصيل مجاني للطلبات الكبيرة." }
    ]
  },
  {
    name: "إبراهيم الفرسان", phone: "01090000006", plan: "ربع سنوي", ends_in: 60,
    firms: [
      { name: "معرض الفرسان للملابس", category: "محلات تجارية", hours: "يوميًا ١١ص - ١١م",
        address: "شارع السوق", description: "ملابس رجالي وحريمي وأطفال وأحذية." },
      { name: "الأمانة للأدوات المنزلية", category: "محلات تجارية", hours: "يوميًا ٩ص - ١٠م",
        address: "شارع السوق، بجوار المخبز", description: "أدوات مطبخ وأجهزة كهربائية صغيرة وهدايا." }
    ]
  },
  {
    name: "الأسطى محمود عبده", phone: "01090000007", plan: "سنوي", ends_in: 330,
    firms: [
      { name: "الأسطى محمود للسباكة", category: "حرفيون", hours: "حسب الطلب، طوارئ ٢٤ ساعة",
        address: "عزبة الجسر", description: "تأسيس وصيانة سباكة وتركيب سخانات وفلاتر." },
      { name: "ورشة الأمل للكهرباء", category: "حرفيون", hours: "يوميًا ٩ص - ٨م",
        address: "شارع الورش", description: "تأسيس كهرباء وصيانة أجهزة وتركيب لمبات وطاقة شمسية." },
      { name: "نجارة الحاج سعيد", category: "حرفيون", hours: "السبت إلى الخميس ٨ص - ٥م", status: :pending,
        address: "شارع الورش", description: "أبواب وشبابيك ومطابخ خشب وتصليح أثاث." }
    ]
  },
  {
    name: "هالة مصطفى", phone: "01090000008", plan: "سنوي", ends_in: 250,
    firms: [
      { name: "حضانة البراعم", category: "مدارس", hours: "السبت إلى الخميس ٧ص - ٢ظ",
        address: "شارع المدارس", description: "حضانة لعمر ٢ إلى ٦ سنوات، تأسيس عربي وإنجليزي وحساب." },
      { name: "مركز النجاح للدروس", category: "مدارس", hours: "يوميًا ٣م - ٩م",
        address: "ميدان القرية، الدور الثاني", description: "مجموعات تقوية لجميع المراحل ولغات." }
    ]
  },
  {
    name: "عبد الله الشروق", phone: "01090000009", plan: "سنوي", ends_in: 180,
    firms: [
      { name: "مخبز الأمل البلدي", category: "مخابز", hours: "يوميًا ٥ص - ١ظ",
        address: "شارع الجمعية", description: "عيش بلدي مدعم وطباقي وفينو." },
      { name: "حلواني الشروق", category: "مخابز", hours: "يوميًا ١٠ص - ١٢م",
        address: "الشارع الرئيسي", description: "جاتوه وتورت مناسبات وحلويات شرقية." }
    ]
  },
  {
    name: "ياسر السلام", phone: "01090000010", plan: "ربع سنوي", ends_in: 75,
    firms: [
      { name: "مكتب السلام للتوصيل", category: "مواصلات", hours: "يوميًا ٧ص - ١١م",
        address: "موقف القرية", description: "توصيل طلبات وطرود داخل القرية والقرى المجاورة." },
      { name: "توك توك الأمان", category: "مواصلات", hours: "يوميًا ٦ص - ١٢م",
        address: "موقف القرية", description: "مشاوير داخل القرية بأسعار ثابتة، اتصل واطلب." }
    ]
  }
]

firm_index = 0
owners.each_with_index do |data, owner_index|
  owner = User.find_or_initialize_by(phone: data[:phone])
  if owner.new_record?
    owner.assign_attributes(name: data[:name], password: "password123", role: :firm_admin)
    owner.save!
  end

  # One approved, current subscription per owner (created once).
  unless owner.subscriptions.exists?
    plan = plans.fetch(data[:plan])
    ends_at = data[:ends_in].days.from_now
    owner.subscriptions.create!(
      subscription_plan: plan,
      payment_method: owner_index.even? ? :instapay : :vodafone_cash,
      transaction_reference: "DEMO-#{data[:phone]}",
      payer_phone: data[:phone],
      status: :active,
      starts_at: ends_at - plan.duration_days.days,
      ends_at: ends_at,
      reviewed_by: admin,
      reviewed_at: ends_at - plan.duration_days.days
    )
  end

  data[:firms].each do |f|
    firm_index += 1
    lat, lng = demo_location.call(firm_index)
    Firm.find_or_create_by!(name: f[:name]) do |firm|
      firm.owner = owner
      firm.category = categories.fetch(f[:category])
      firm.status = f.fetch(:status, :active)
      firm.phone = format("0155%07d", 1_000 + firm_index)
      firm.whatsapp = firm_index % 3 == 0 ? nil : firm.phone # some firms have no WhatsApp
      firm.address = f[:address]
      firm.working_hours = f[:hours]
      firm.description = f[:description]
      firm.latitude = lat
      firm.longitude = lng
    end
  end
end

# A firm by the super admin: always visible, no subscription needed.
Firm.find_or_create_by!(name: "مكتب خدمات أهالي القرية") do |firm|
  firm.owner = admin
  firm.category = categories.fetch("محلات تجارية")
  firm.status = :active
  firm.phone = "01550009999"
  firm.address = "مبنى الجمعية الزراعية"
  firm.working_hours = "السبت إلى الخميس ٩ص - ٣م"
  firm.description = "مساعدة الأهالي في استخراج الأوراق والخدمات الحكومية الإلكترونية."
end

# ---- Users for testing the review queue ----
applicant = User.find_or_create_by!(phone: "01090000020") do |u|
  u.name = "محمد فتحي"
  u.password = "password123"
end
unless applicant.subscriptions.exists?
  applicant.subscriptions.create!(
    subscription_plan: plans.fetch("شهري"),
    payment_method: :vodafone_cash,
    transaction_reference: "DEMO-VC-1001",
    payer_phone: "01090000020",
    notes: "حولت المبلغ من رقم أخي"
  )
end

rejected = User.find_or_create_by!(phone: "01090000021") do |u|
  u.name = "علي حسن"
  u.password = "password123"
end
unless rejected.subscriptions.exists?
  rejected.subscriptions.create!(
    subscription_plan: plans.fetch("سنوي"),
    payment_method: :instapay,
    transaction_reference: "DEMO-IP-2001",
    status: :rejected,
    rejection_reason: "لم يصل التحويل، برجاء التأكد من رقم العملية.",
    reviewed_by: admin,
    reviewed_at: 2.days.ago
  )
end

User.find_or_create_by!(phone: "01090000022") do |u|
  u.name = "سارة إبراهيم"
  u.password = "password123"
end

# ---- News: every kind, plus a draft and a scheduled post ----
articles = [
  { kind: :news, days_ago: 0, title: "بدء أعمال رصف الشارع الرئيسي",
    body: "بدأت اليوم أعمال رصف الشارع الرئيسي من مدخل القرية حتى الميدان، ومن المتوقع انتهاء الأعمال خلال أسبوعين. نرجو من الأهالي استخدام الطرق البديلة خلال هذه الفترة." },
  { kind: :news, days_ago: 2, title: "قافلة طبية مجانية يوم الجمعة",
    body: "تنظم الجمعية الخيرية قافلة طبية مجانية يوم الجمعة القادم من ٩ صباحًا حتى ٣ عصرًا في مبنى الجمعية، وتشمل تخصصات الباطنة والأطفال والعيون والأسنان." },
  { kind: :news, days_ago: 4, title: "افتتاح وحدة لإصدار الشهادات بالجمعية",
    body: "تم افتتاح وحدة جديدة لاستخراج شهادات الميلاد وبطاقات التموين بمبنى الجمعية الزراعية، وتعمل من السبت إلى الخميس." },
  { kind: :news, days_ago: 7, title: "فوز فريق شباب القرية ببطولة الدوري المحلي",
    body: "حقق فريق شباب القرية بطولة الدوري المحلي بعد الفوز في المباراة النهائية بثلاثة أهداف مقابل هدف. مبروك لكل أهالي القرية." },
  { kind: :news, days_ago: 10, title: "تطوير مدخل القرية وزراعة الأشجار",
    body: "انتهت أعمال تطوير مدخل القرية وزراعة الأشجار على جانبي الطريق بمشاركة شباب القرية المتطوعين." },
  { kind: :announcement, days_ago: 1, title: "انقطاع المياه يوم الثلاثاء للصيانة",
    body: "تنبيه: ستنقطع المياه يوم الثلاثاء من ١٠ صباحًا حتى ٤ عصرًا لأعمال صيانة الخط الرئيسي. برجاء تخزين احتياجاتكم." },
  { kind: :announcement, days_ago: 3, title: "مواعيد صرف الخبز المدعم الجديدة",
    body: "تبدأ المخابز في صرف الخبز المدعم من ٦ صباحًا حتى ١ ظهرًا طوال أيام الأسبوع عدا الجمعة." },
  { kind: :announcement, days_ago: 6, title: "سجّل منشأتك في التطبيق",
    body: "أصحاب المحلات والعيادات والورش: يمكنكم الآن إضافة منشآتكم في التطبيق بعد الاشتراك في إحدى الباقات عبر إنستاباي أو فودافون كاش." },
  { kind: :article, days_ago: 5, title: "نصائح للحفاظ على صحة الأطفال في الشتاء",
    body: "مع دخول فصل الشتاء تزيد نزلات البرد بين الأطفال. احرص على التهوية الجيدة، والملابس المناسبة، وغسل اليدين باستمرار، واستشر طبيب الأطفال عند ارتفاع الحرارة أكثر من يومين." },
  { kind: :article, days_ago: 9, title: "تاريخ القرية: حكايات من زمان",
    body: "يحكي كبار القرية عن أيام السوق الأسبوعي والساقية والترعة التي كانت قلب الحياة في القرية. في هذا المقال نجمع بعض هذه الحكايات لنحفظها للأجيال القادمة." },
  { kind: :article, days_ago: 14, title: "كيف تختار الصنايعي المناسب لبيتك؟",
    body: "قبل أي إصلاح في البيت: اسأل عن أعمال سابقة، واتفق على السعر قبل البدء، واطلب ضمانًا على الشغل. ويمكنك الآن الوصول للحرفيين المعتمدين من قسم حرفيون في التطبيق." },
  { kind: :news, draft: true, title: "مسودة: ترتيبات احتفال العيد",
    body: "مسودة لم تُنشر بعد: تفاصيل احتفال العيد في ساحة القرية وبرنامج المسابقات للأطفال." },
  { kind: :announcement, scheduled_in: 2, title: "اجتماع أهالي القرية الأسبوع القادم",
    body: "يُعقد اجتماع لأهالي القرية لمناقشة مشروعات النظافة والإنارة. الحضور مفتوح للجميع." }
]

articles.each_with_index do |a, i|
  Article.find_or_create_by!(title: a[:title]) do |article|
    article.author = admin
    article.kind = a[:kind]
    article.body = a[:body]
    article.published_at =
      if a[:draft] then nil
      elsif a[:scheduled_in] then a[:scheduled_in].days.from_now.change(hour: 10)
      else a[:days_ago].days.ago.change(hour: 9 + (i % 8))
      end
  end
end

# ---- Real places: public Google Maps listings (collected 2026-10-25) ----
# Owned by the super admin, so they are visible without a subscription. When the real
# owner subscribes, move the firm to their account from the dashboard.
# The source says the data is partial and unverified, so:
#   - places outside the village or with an uncertain locality are created as "pending"
#     (review them in the dashboard),
#   - temporarily closed places are created as "suspended" (hidden),
#   - opening hours are kept only when Google says "Open 24 hours" (other values are snapshots).
places = JSON.parse(File.read(Rails.root.join("db/seeds/aghour_al_kubra_places.json")))["places"]

place_categories = {
  "صيدليات" => [ "Pharmacy" ],
  "أطباء" => [ "Hospital", "Doctor" ],
  "مدارس" => [ "General education school", "Primary school", "Preparatory school", "Girls' high school", "Boys' high school" ],
  "مطاعم" => [ "Restaurant", "Pizza restaurant", "Barbecue restaurant", "Creperie", "Coffee shop", "Cafe" ],
  "محلات تجارية" => [ "Supermarket", "Grocery store", "Store", "General store", "Electronics store",
                      "Organic food store", "Motorcycle parts store", "Jewelry store" ],
  "مساجد" => [ "Mosque" ],
  "رياضة وشباب" => [ "Gym", "Sports club" ],
  "خدمات عامة" => [ "Post office" ]
}.flat_map { |category, types| types.map { |type| [ type, category ] } }.to_h

place_types_ar = {
  "Pharmacy" => "صيدلية", "Hospital" => "مستشفى", "Doctor" => "مركز طبي",
  "General education school" => "مدرسة", "Primary school" => "مدرسة ابتدائية",
  "Preparatory school" => "مدرسة إعدادية", "Girls' high school" => "مدرسة ثانوية بنات",
  "Boys' high school" => "مدرسة ثانوية بنين", "Restaurant" => "مطعم", "Pizza restaurant" => "مطعم بيتزا",
  "Barbecue restaurant" => "مشويات", "Creperie" => "كريب", "Coffee shop" => "كافيه", "Cafe" => "كافيتريا",
  "Supermarket" => "سوبر ماركت", "Grocery store" => "بقالة", "Store" => "محل", "General store" => "محل",
  "Electronics store" => "أدوات كهربائية", "Organic food store" => "منتجات غذائية",
  "Motorcycle parts store" => "قطع غيار موتوسيكلات", "Jewelry store" => "مجوهرات", "Mosque" => "مسجد",
  "Gym" => "مركز شباب", "Sports club" => "جيم", "Post office" => "مكتب بريد"
}

# "+201008501029" -> "01008501029", "+20132432550" -> "0132432550"
local_phone = ->(phone) { phone.presence&.sub(/\A\+20/, "0") }

# Keeps the Arabic street part of the Google address ("أول شارع الشكارة"); drops plus codes,
# English-only parts, the village/district/governorate/postal code and the country.
village_address = "أجهور الكبرى، طوخ، القليوبية"
short_address = lambda do |address|
  parts = address.to_s.split(/[,،]/).map(&:strip).reject(&:empty?)
  street = parts.take_while { |part| part !~ /Aghour|Toukh|Qalyubia|Egypt|طوخ|القليوبية|أجهور|اجهور/i }
                .map { |part| part.sub(/\A[0-9A-Z]{4}\+[0-9A-Z]{2,3}\s*/, "") }
                .reject { |part| part.empty? || part.match?(/\A[A-Za-z .]+\z/) } # "Unnamed Road", "Dandana"
  street.any? ? "#{street.join('، ')}، #{village_address}" : village_address
end

imported = 0
places.each do |place|
  category_name = place_categories[place["category"]]
  next unless category_name # unknown type: skip rather than guess

  lat = place["latitude"]&.round(6)
  lng = place["longitude"]&.round(6)
  status =
    if place["business_status"] == "temporarily_closed" then :suspended
    elsif place["scope_status"] != "address_mentions_aghour_al_kubra" then :pending
    else :active
    end

  description = [ place_types_ar.fetch(place["category"], place["category"]) ]
  if place["rating"]
    description << "تقييم خرائط جوجل: #{place['rating']} من 5 (#{place['review_count']} مراجعة)"
  end
  description << "المصدر: خرائط جوجل، بيانات غير مؤكدة"

  Firm.find_or_create_by!(name: place["name"].strip, latitude: lat, longitude: lng) do |firm|
    firm.owner = admin
    firm.category = categories.fetch(category_name)
    firm.status = status
    firm.phone = local_phone.call(place["phone"])
    firm.address = short_address.call(place["address"])
    firm.working_hours = "٢٤ ساعة" if place["opening_hours_summary"] == "Open 24 hours"
    firm.description = description.join(". ") + "."
    imported += 1
  end
end

puts "Real places: #{imported} imported from Google Maps (#{places.size} in the file)"

puts "Demo data: #{owners.size} firm owners (password: password123), " \
     "#{Firm.count} firms, #{Article.count} articles, #{Subscription.count} subscriptions"
