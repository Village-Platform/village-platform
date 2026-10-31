# Stands in for Fcm::Client in every example: records what would have been sent to Google, each
# delivery a full message (the payload plus its token:, topic: or condition:).
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

  def send_to_token(token, payload) = deliver(token:, **payload)

  # Same contract as the client: per-token outcome, only AuthError raises.
  def send_to_tokens(tokens, payload)
    tokens.uniq.each_with_object(Fcm::TokensResult.empty) do |token, result|
      next result.unregistered << token if @rejected_tokens.include?(token)

      result.sent[token] = send_to_token(token, payload)
    rescue Fcm::AuthError
      raise
    rescue Fcm::Unregistered
      result.unregistered << token
    rescue Fcm::Error => e
      result.failed[token] = e
    end
  end

  def send_to_topic(topic, payload) = deliver(topic:, **payload)

  def send_to_topics(topics, payload, operator: :or)
    topics = topics.uniq
    raise ArgumentError, "1 to 5 topics" unless topics.size.between?(1, Fcm::Client::MAX_CONDITION_TOPICS)
    return send_to_topic(topics.first, payload) if topics.one?

    send_to_condition(Fcm::Message.condition_for(topics, operator:), payload)
  end

  def send_to_condition(condition, payload) = deliver(condition:, **payload)

  def subscribe(topic_key, tokens) = topic_call(@subscribed, topic_key, tokens)

  def unsubscribe(topic_key, tokens) = topic_call(@unsubscribed, topic_key, tokens)

  private

  def deliver(message)
    raise @failures.shift if @failures.any?

    @deliveries << message
    "projects/test/messages/#{@deliveries.size}"
  end

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
