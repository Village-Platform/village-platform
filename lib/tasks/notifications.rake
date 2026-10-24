namespace :notifications do
  desc "Send subscription expiry reminders (run daily)"
  task subscription_reminders: :environment do
    sent = SubscriptionExpiryRemindersJob.perform_now
    puts "Sent #{sent} reminder(s)"
  end
end
