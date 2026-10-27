module Admin
  class GlobalSearch
    MIN_QUERY_LENGTH = 3
    # A global dropdown shows six types at once and must stay shallow; when the whole
    # dropdown is one type there is room to show more.
    PER_TYPE_LIMIT = 4
    SCOPED_LIMIT = 8
    SCOPES = %w[firms users subscriptions articles categories plans].freeze
    Result = Data.define(:type, :title, :subtitle, :record)

    def self.call(query:, scope: "all")
      new(query:, scope:).call
    end

    def initialize(query:, scope:)
      @query = query.to_s.strip
      @scope = scope.to_s
    end

    def call
      return [] if @query.length < MIN_QUERY_LENGTH

      # `send`, not `public_send`: the per-type methods are private. Safe because
      # `search_types` intersects with SCOPES, so `type` is always one of six known strings.
      search_types.filter_map { |type| send("search_#{type}") }.flatten
    end

    private

    def search_types
      @scope == "all" ? SCOPES : SCOPES & [ @scope ]
    end

    def pattern
      @pattern ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
    end

    def matching(scope, table, columns)
      conditions = columns.map { |column| "lower(#{table}.#{column}) LIKE :pattern" }.join(" OR ")
      scope.where(conditions, pattern:).limit(result_limit)
    end

    def result_limit
      @scope == "all" ? PER_TYPE_LIMIT : SCOPED_LIMIT
    end

    def search_firms
      matching(Firm.includes(:category, :owner), "firms", %w[name phone address])
        .map { |firm| Result.new("نشاط", firm.name, [ firm.category.name, firm.phone ].compact_blank.join(" · "), firm) }
    end

    def search_users
      matching(User.all, "users", %w[name phone email])
        .map { |user| Result.new("مستخدم", user.name, [ user.phone, user.email ].compact_blank.join(" · "), user) }
    end

    def search_subscriptions
      scope = Subscription.includes(:user, :subscription_plan)
      matching(scope, "subscriptions", %w[transaction_reference payer_phone])
        .map do |subscription|
          Result.new("اشتراك", "##{subscription.id} · #{subscription.user.name}",
                     [ subscription.transaction_reference, subscription.subscription_plan.name ].join(" · "),
                     subscription)
        end
    end

    def search_articles
      matching(Article.all, "articles", %w[title])
        .map { |article| Result.new("مقال", article.title, enum_label(article.kind), article) }
    end

    def search_categories
      matching(Category.all, "categories", %w[name])
        .map { |category| Result.new("تصنيف", category.name, category.description.to_s.truncate(70), category) }
    end

    def search_plans
      matching(SubscriptionPlan.all, "subscription_plans", %w[name])
        .map { |plan| Result.new("باقة", plan.name, "#{plan.duration_days} يوم · #{plan.price_cents / 100.0} ج.م", plan) }
    end

    def enum_label(kind)
      I18n.t("enums.article.kind.#{kind}", default: kind.to_s.humanize)
    end
  end
end
