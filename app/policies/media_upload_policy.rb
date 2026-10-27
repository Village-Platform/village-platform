# Who may request a direct upload for each media profile (headless: `authorize :media_upload`).
# The feature endpoint that later attaches the blob still runs its own policy and limits.
class MediaUploadPolicy < ApplicationPolicy
  def category_icon?      = super_admin?
  def firm_image?         = super_admin? || entitled?(:max_images_per_firm)
  def firm_video?         = super_admin? || entitled?(:max_videos_per_firm)
  def article_image?      = super_admin? || entitled?(:max_articles_per_month)
  def payment_screenshot? = user.present?

  private

  def entitled?(limit)
    user.present? && user.entitlements.public_send(limit).to_i.positive?
  end
end
