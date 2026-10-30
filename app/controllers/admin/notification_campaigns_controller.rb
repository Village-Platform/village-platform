module Admin
  # Messages to one or more topics, now or at a set time. Delivery is DeliverCampaignJob's; this
  # controller only schedules (Campaigns::Schedule) and cancels.
  class NotificationCampaignsController < BaseController
    before_action :set_campaign, only: %i[show cancel]

    def index
      scope = NotificationCampaign.includes(:topics).latest_first
      scope = scope.where(status: params[:status]) if NotificationCampaign.statuses.key?(params[:status])
      @campaigns, @meta = paginate(scope)
    end

    def show; end

    def new
      @campaign = NotificationCampaign.new(screen: "none", topic_ids: [ Topic.everyone.id ])
      load_form
    end

    def create
      @campaign = NotificationCampaign.new(campaign_params.merge(created_by: current_admin))
      Campaigns::Schedule.call(campaign: @campaign)
      redirect_to admin_notification_campaign_path(@campaign),
                  notice: @campaign.scheduled_at > 1.minute.from_now ? "تمت جدولة الحملة." : "جارٍ إرسال الحملة."
    rescue ActiveRecord::RecordInvalid
      load_form
      render :new, status: :unprocessable_content
    end

    def cancel
      @campaign.cancel!("ألغاها #{current_admin.name}")
      redirect_to admin_notification_campaign_path(@campaign), notice: "تم إلغاء الحملة."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_notification_campaign_path(@campaign), alert: "لا يمكن إلغاء حملة ليست مجدولة."
    end

    private

    def set_campaign
      @campaign = NotificationCampaign.find(params[:id])
    end

    def load_form
      Topic.everyone
      @topics = Topic.order(system: :desc, name: :asc)
    end

    # datetime-local sends no zone: read it as Cairo time (the app's zone).
    def campaign_params
      permitted = params.require(:notification_campaign).permit(:title, :body, :screen, :target_id, :scheduled_at, topic_ids: [])
      permitted[:topic_ids] = Array(permitted[:topic_ids]).compact_blank
      permitted[:scheduled_at] = Time.zone.parse(permitted[:scheduled_at]) if permitted[:scheduled_at].present?
      permitted
    end
  end
end
