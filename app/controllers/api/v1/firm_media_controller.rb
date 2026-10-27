module Api
  module V1
    # A firm's image and video gallery.
    #
    # PATCH /api/v1/firms/:firm_id/media/:id  { "medium": { "caption", "position" } }
    # POST /api/v1/firms/:firm_id/media
    #   multipart: { kind: "image", file: <file>, caption }       (images)
    #   JSON:      { kind: "video", signed_blob_id: "...", caption } (after POST /direct_uploads)
    class FirmMediaController < BaseController
      before_action :authenticate_user!, except: :index
      before_action :set_firm
      before_action :set_medium, only: %i[update destroy]

      def index
        media = @firm.media.includes(file_attachment: :blob)
        render json: { data: media.map { FirmMediumSerializer.render(_1) } }
      end

      def create
        authorize FirmMedium.new(firm: @firm)
        medium = FirmMedia::Add.call(firm: @firm, uploader: current_user, kind: params.require(:kind),
                                     caption: params[:caption], file: params[:file],
                                     signed_blob_id: params[:signed_blob_id])
        render_record(medium, FirmMediumSerializer, status: :created)
      end

      def update
        authorize @medium
        attrs = params.require(:medium).permit(policy(@medium).permitted_attributes)
        audited("firm_medium.update", @medium) { @medium.update!(attrs) }
        render_record(@medium, FirmMediumSerializer)
      end

      def destroy
        authorize @medium
        audited("firm_medium.destroy", @medium, changes: Audit.snapshot(@medium)) { @medium.destroy! }
        head :no_content
      end

      private

      def set_firm
        @firm = policy_scope(Firm).find(params[:firm_id])
      end

      def set_medium
        @medium = @firm.media.find(params[:id])
      end
    end
  end
end
