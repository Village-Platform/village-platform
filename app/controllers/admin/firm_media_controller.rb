module Admin
  # Moderation of a firm's gallery: remove anything; add images (video comes from the app).
  class FirmMediaController < BaseController
    requires_permission "firms.moderate"

    before_action :set_firm

    def create
      FirmMedia::Add.call(firm: @firm, uploader: current_admin, kind: :image,
                          caption: params[:caption], file: params[:file])
      redirect_to admin_firm_path(@firm), notice: "تم إضافة الصورة."
    rescue Media::InvalidFile => e
      redirect_to admin_firm_path(@firm), alert: I18n.t("errors.api.#{e.code}", **e.details)
    end

    def destroy
      medium = @firm.media.find(params[:id])
      audited("firm_medium.destroy") { medium.destroy! }
      redirect_to admin_firm_path(@firm), notice: "تم حذف الملف."
    end

    private

    def set_firm
      @firm = Firm.find(params[:firm_id])
    end
  end
end
