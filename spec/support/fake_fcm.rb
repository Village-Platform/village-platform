# Stands in for Fcm::Client in every example: records what would have been sent to Google.
#
#   Fcm.client.deliveries.last[:data]          # => { "screen" => "article", ... }
#   Fcm.client.subscribed["news"]              # => [ "token" ]
#   Fcm.client.fail_next_with(Fcm::Unregistered.new)
class FakeFcm
  attr_reader :deliveries, :subscribed, :unsubscribed

  def initialize
    @deliveries = []
    @subscribed = Hash.new { |hash, key| hash[key] = [] }
    @unsubscribed = Hash.new { |hash, key| hash[key] = [] }
    @failures = []
    @rejected_tokens = []
  end

  def enabled? = true

  def fail_next_with(error)
    @failures << error
  end

  # Tokens the topic API will report as unregistered.
  def reject_tokens(*tokens)
    @rejected_tokens.concat(tokens)
  end

  def deliver(message)
    raise @failures.shift if @failures.any?

    @deliveries << message
    "projects/test/messages/#{@deliveries.size}"
  end

  def subscribe(topic_key, tokens) = topic_call(@subscribed, topic_key, tokens)

  def unsubscribe(topic_key, tokens) = topic_call(@unsubscribed, topic_key, tokens)

  private

  def topic_call(log, topic_key, tokens)
    raise @failures.shift if @failures.any?

    log[topic_key].concat(tokens)
    tokens & @rejected_tokens
  end
end

RSpec.configure do |config|
  config.around do |example|
    Fcm.client = FakeFcm.new
    example.run
  ensure
    Fcm.reset!
  end
end
