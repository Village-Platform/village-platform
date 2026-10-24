# Serves files of the "database" Active Storage service through signed, expiring URLs
# (the same kind of token the Disk service uses). Without a valid token it answers 404.
class StoredFilesController < ActionController::API
  include ActionController::DataStreaming

  def show
    payload = ActiveStorage.verifier.verified(params[:encoded_key], purpose: :blob_key)
    return head :not_found unless payload.is_a?(Hash)

    payload = payload.symbolize_keys
    file = StoredFile.find_by(key: payload[:key])
    return head :not_found unless file

    response.headers["Content-Disposition"] = payload[:disposition] if payload[:disposition]
    response.headers["Cache-Control"] = "private, max-age=300"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data file.data, type: payload[:content_type].presence || "application/octet-stream", disposition: nil
  end
end
