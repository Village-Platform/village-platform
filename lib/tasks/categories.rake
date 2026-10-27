namespace :categories do
  # Production categories already exist, so seeds never re-run there; this backfills the images.
  # Safe to run again: categories that already have an image are skipped.
  desc "Attach the default icon image (db/seeds/category_icons/<icon>.png) to categories without one"
  task attach_default_icons: :environment do
    attached = Category.find_each.count(&:attach_default_icon!)
    puts "Attached #{attached} category icon(s)."
  end

  # Re-encodes existing icons to the category_icon media profile. Safe to run again: icons
  # already optimized are skipped. The icon URL's `v` changes, so app and CDN caches roll over.
  desc "Shrink category icon images to the category_icon media profile"
  task optimize_icons: :environment do
    optimized = Category.with_attached_icon_image.find_each.count { |category| Categories::OptimizeIcon.call(category) }
    puts "Optimized #{optimized} category icon(s)."
  end
end
