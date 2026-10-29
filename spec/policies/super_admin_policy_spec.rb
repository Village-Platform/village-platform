require "rails_helper"

# Super admins may do everything. This walks every policy file, so a new policy or action that
# forgets `super_admin? ||` fails here instead of in production.
RSpec.describe "Super admin policies" do
  let(:super_admin) { create(:user, :super_admin) }
  let(:someone) { create(:user) }

  # A record the super admin neither owns nor could see through a public scope.
  let(:records) do
    {
      Article => create(:article, :draft),
      Category => create(:category, active: false),
      Firm => create(:firm, :pending, owner: create(:user, :firm_admin)),
      SubscriptionPlan => create(:subscription_plan, active: false),
      Subscription => create(:subscription, user: someone),
      User => someone
    }
  end

  policies = Rails.root.glob("app/policies/*_policy.rb").map { |f| f.basename(".rb").to_s.camelize.constantize }
  policies -= [ ApplicationPolicy ]

  policies.each do |policy_class|
    model = policy_class.name.delete_suffix("Policy").constantize

    describe policy_class do
      let(:record) { records.fetch(model) { raise "add a #{model} record to `records` in this spec" } }

      (policy_class.public_instance_methods - Object.public_instance_methods).grep(/\?\z/).each do |action|
        it "allows #{action}" do
          expect(policy_class.new(super_admin, record).public_send(action)).to be(true)
        end
      end

      if policy_class.const_defined?(:Scope, false)
        it "scopes to every record" do
          expect(policy_class::Scope.new(super_admin, model).resolve).to include(record)
        end
      end
    end
  end
end
