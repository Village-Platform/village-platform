class AddTrigramIndexesForAdminSearch < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    {
      users: %i[name phone email],
      firms: %i[name phone address],
      subscriptions: %i[transaction_reference payer_phone],
      articles: %i[title],
      categories: %i[name],
      subscription_plans: %i[name]
    }.each do |table, columns|
      columns.each do |column|
        # The operator class has to live inside the expression. Rails' `opclass:` option only
        # applies to plain column names, so on an expression index it is silently dropped and
        # Postgres rejects the GIN index with "text has no default operator class".
        add_index table, "lower(#{column}) gin_trgm_ops", using: :gin,
                  name: "index_#{table}_on_#{column}_trigram"
      end
    end
  end
end
