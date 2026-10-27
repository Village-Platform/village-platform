class User < ApplicationRecord
  has_secure_password

  # user        -> normal village resident
  # firm_admin  -> firm owner, can add/manage own firms while subscribed
  # super_admin -> developers / platform admins
  # staff       -> dashboard helper holding only the StaffPermissions granted to them
  enum :role, { user: 0, firm_admin: 1, super_admin: 2, staff: 3 }, default: :user, validate: true

  # Roles that can sign in to the dashboard.
  ADMIN_ROLES = %w[super_admin staff].freeze

  has_many :firms, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error
  has_many :articles, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :restrict_with_error
  has_many :notifications, dependent: :delete_all
  has_many :staff_permissions, dependent: :delete_all

  normalizes :phone, with: ->(phone) { phone.to_s.gsub(/[^\d+]/, "") }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, uniqueness: true, format: { with: /\A\+?\d{8,15}\z/ }
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true

  def admin? = ADMIN_ROLES.include?(role)

  # Dashboard permission check: super admins hold all; staff hold what was granted.
  def can?(permission)
    return true if super_admin?
    return false unless staff?

    @permissions ||= staff_permissions.pluck(:permission).to_set
    @permissions.include?(permission)
  end

  def can_manage_firms?
    firm_admin? || super_admin?
  end

  def current_subscription
    subscriptions.current.includes(:subscription_plan).order(:ends_at).first
  end

  # Limits from the plan of the current subscription (one query; not memoized, so never stale).
  def entitlements
    Entitlements.for(self)
  end

  # Super admins are unlimited; firm admins need a current subscription with free slots.
  def can_add_firm?
    entitlements.within?(:max_firms, firms.count)
  end

  def articles_this_month
    articles.where(created_at: Time.current.all_month).count
  end
end
