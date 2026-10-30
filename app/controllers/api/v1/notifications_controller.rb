module Api
  module V1
    # Notifications are always scoped to current_user, so no Pundit policy is needed.
    class NotificationsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/notifications?unread=true
      def index
        scope = current_user.notifications.latest_first
        scope = scope.unread if params[:unread].present?

        records, meta = paginate(filter(scope))
        meta[:unread_count] = current_user.notifications.unread.count
        render_collection(records, meta, NotificationSerializer)
      end

      # PATCH /api/v1/notifications/:id/read
      def read
        notification = current_user.notifications.find(params[:id])
        notification.mark_as_read!
        render_record(notification, NotificationSerializer)
      end

      # PATCH /api/v1/notifications/read_all
      def read_all
        now = Time.current
        current_user.notifications.unread.update_all(read_at: now, updated_at: now)
        head :no_content
      end
    end
  end
end
