# Public web page where a user deletes their account without the app. Google Play requires this
# URL (Data safety form → account deletion) alongside the in-app DELETE /api/v1/me.
class AccountDeletionsController < ActionController::Base
  layout "admin_auth"

  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to account_deletion_path, alert: I18n.t("account_deletions.too_many_attempts") }

  around_action :use_arabic

  def new
  end

  def create
    user = User.not_deleted.find_by(phone: User.normalize_value_for(:phone, params[:phone].to_s))

    if user.nil? || !user.authenticate(params[:password].to_s)
      flash.now[:alert] = I18n.t("account_deletions.invalid")
      render :new, status: :unprocessable_content
    elsif user.super_admin?
      flash.now[:alert] = I18n.t("account_deletions.super_admin")
      render :new, status: :unprocessable_content
    else
      Users::DeleteAccount.call(user:)
      render :done
    end
  end

  private

  def use_arabic(&action)
    I18n.with_locale(:ar, &action)
  end
end
