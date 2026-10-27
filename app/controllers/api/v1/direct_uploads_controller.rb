module Api
  module V1
    # Step 1 of a direct upload: checks the declared size and type against the profile, then
    # returns a short-lived presigned URL. The phone PUTs the bytes straight to object storage, so
    # a 40MB video never passes through (or sits in the memory of) the web pod. The feature
    # endpoint re-validates the stored bytes when the signed id comes back.
    #
    # POST /api/v1/direct_uploads
    #   { "profile": "firm_video",
    #     "blob": { "filename", "byte_size", "checksum" (base64 MD5), "content_type" } }
    class DirectUploadsController < BaseController
      include ActiveStorage::SetCurrent # Disk service URLs in development and test

      SIGNED_ID_TTL = 1.hour

      before_action :authenticate_user!

      def create
        profile = MediaProfile::ALL.fetch(params.require(:profile).to_s) { raise ActionController::ParameterMissing, :profile }
        authorize :media_upload, :"#{profile.name}?"

        attrs = params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type)
        check_declared!(profile, attrs)
        service_name = Media.service_name_for(profile)
        raise Media::InvalidFile.new("direct_upload_unsupported") if Media.database_service?(service_name)

        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: attrs.require(:filename), byte_size: attrs[:byte_size].to_i, checksum: attrs.require(:checksum),
          content_type: attrs[:content_type], service_name:,
          metadata: { "profile" => profile.name, "uploader_id" => current_user.id }
        )

        render json: {
          data: {
            signed_id: blob.signed_id(expires_in: SIGNED_ID_TTL),
            direct_upload: { url: blob.service_url_for_direct_upload, headers: blob.service_headers_for_direct_upload }
          }
        }, status: :created
      end

      private

      def check_declared!(profile, attrs)
        size = attrs.require(:byte_size).to_i
        raise Media::InvalidFile.new("bad_request", param: "byte_size") unless size.positive?
        if size > profile.max_bytes
          raise Media::InvalidFile.new("file_too_large", size: ActiveSupport::NumberHelper.number_to_human_size(profile.max_bytes, locale: :en))
        end
        return if profile.content_types.include?(attrs[:content_type])

        raise Media::InvalidFile.new("invalid_media_type", types: profile.content_types.join(", "))
      end
    end
  end
end
