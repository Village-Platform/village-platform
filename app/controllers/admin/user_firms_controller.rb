module Admin
  # Manages which firms a user owns, from that user's own page.
  #
  # firms.owner_id is NOT NULL, so there is no "detach": every removal is a move to another
  # owner, and the caller has to say who. Creating a firm for a user is the ordinary firms
  # form with the owner prefilled; this controller only moves existing ones.
  class UserFirmsController < BaseController
    before_action :set_user

    def create
      reassign(Firm.find(params[:firm_id]), @user)
    end

    def destroy
      reassign(@user.firms.find(params[:id]), User.find_by(id: params[:new_owner_id]))
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def reassign(firm, new_owner)
      if new_owner.nil?
        return refuse("اختر المالك الجديد أولاً — لا يمكن ترك نشاط بلا مالك.")
      end

      unless new_owner.can_manage_firms?
        return refuse("#{new_owner.name} ليس صاحب نشاط أو مديرًا، ولا يمكنه إدارة الأنشطة.")
      end

      firm.update!(owner: new_owner)
      redirect_back_or_to admin_user_path(@user), notice: moved_notice(firm, new_owner)
    end

    def refuse(message)
      redirect_back_or_to admin_user_path(@user), alert: message
    end

    # Firm.visible keys off the owner's subscription, so a move can hide an approved firm from
    # the app the instant it is saved. Say so rather than letting it vanish quietly.
    def moved_notice(firm, new_owner)
      notice = "تم نقل \"#{firm.name}\" إلى #{new_owner.name}."
      return notice unless firm.active? && !Firm.visible.exists?(firm.id)

      "#{notice} لن يظهر في التطبيق: اشتراك المالك الجديد غير ساري."
    end
  end
end
