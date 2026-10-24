# Sends the client to a short-lived URL for a payment screenshot,
# only after the caller has been authorized for the subscription.
module ScreenshotRedirect
  extend ActiveSupport::Concern

  included do
    include ActiveStorage::SetCurrent # needed for Disk service URLs
  end

  private

  def redirect_to_payment_screenshot(subscription)
    return render_error(:not_found, "not_found") unless subscription.payment_screenshot.attached?

    redirect_to subscription.payment_screenshot.url(expires_in: 5.minutes), allow_other_host: true
  end
end
