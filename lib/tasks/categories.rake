namespace :categories do
  # Production categories already exist, so seeds never re-run there; this backfills the images.
  # Safe to run again: categories that already have an image are skipped.
  desc "Attach the default icon image (db/seeds/category_icons/<icon>.png) to categories without one"
  task attach_default_icons: :environment do
    attached = Category.find_each.count(&:attach_default_icon!)
    puts "Attached #{attached} category icon(s)."
  end
end
