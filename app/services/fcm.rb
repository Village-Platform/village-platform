# Firebase Cloud Messaging. Everything that talks to Google goes through Fcm.client, so specs can
# swap it for FakeFcm (spec/support/fake_fcm.rb) and nothing in the suite reaches the network.
module Fcm
  class Error < StandardError; end

  # The token no longer belongs to an installed app: delete the device.
  class Unregistered < Error; end

  # Usually our payload, not a dead device: log it, keep the token.
  class InvalidArgument < Error; end

  # Wrong, expired or mismatched service-account key. Retrying cannot help.
  class AuthError < Error; end

  # 429 / 5xx: try again later, no sooner than retry_after seconds when FCM says so.
  class Retryable < Error
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end

  # Outcome of Client#send_to_tokens, per token: sent ({ token => message name }), unregistered
  # (delete those devices) and failed ({ token => Fcm::Error }; Retryable ones can be tried again).
  TokensResult = Data.define(:sent, :unregistered, :failed) do
    def self.empty = new(sent: {}, unregistered: [], failed: {})
  end

  class << self
    attr_writer :client

    def client
      @client ||= Client.new
    end

    def reset!
      @client = nil
    end
  end
end
