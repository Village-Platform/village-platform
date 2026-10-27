module Admin
  class BroadcastsController < BaseController
    requires_permission "notifications.send"

    def index
      @broadcasts, @meta = paginate(::Broadcast.includes(:actor).order(created_at: :desc, id: :desc))
    end

    # Also the preview: submitting the form with "preview" re-renders it with the recipient count.
    def new
      @broadcast = ::Broadcast.new(broadcast_params.merge(idempotency_key: params.dig(:broadcast, :idempotency_key).presence || SecureRandom.uuid))
      @categories = Category.ordered
      @recipients_count = @broadcast.recipients.count if params[:broadcast].present?
    end

    def create
      @broadcast = Notifications::Broadcast.call(actor: current_admin, **broadcast_params.to_h.symbolize_keys,
                                                 idempotency_key: params.dig(:broadcast, :idempotency_key).to_s)
      redirect_to admin_broadcasts_path, notice: "تم إرسال الإشعار إلى #{@broadcast.recipients_count} مستخدم."
    rescue ActiveRecord::RecordInvalid => e
      @broadcast = e.record
      @categories = Category.ordered
      render :new, status: :unprocessable_content
    end

    private

    def broadcast_params
      return {} unless params[:broadcast]

      params.require(:broadcast).permit(:audience, :title, :body, audience_params: %i[days category_id])
    end
  end
end
