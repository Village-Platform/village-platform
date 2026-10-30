class User < ApplicationRecord
  # No public endpoint lists users, and no public association reaches one: nothing is public.
  ransack_tiers admin: %w[ id name phone email role created_at updated_at deleted_at ],
                admin_associations: %w[ firms articles subscriptions ]

  has_secure_password
  acts_as_paranoid

  # user        -> normal village resident
  # firm_admin  -> firm owner, can add/manage own firms while subscribed
  # super_admin -> developers / platform admins
  enum :role, { user: 0, firm_admin: 1, super_admin: 2 }, default: :user, validate: true

  has_many :firms, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error
  has_many :articles, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :restrict_with_error
  has_many :notifications, dependent: :delete_all

  normalizes :phone, with: ->(phone) { phone.to_s.gsub(/[^\d+]/, "") }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, uniqueness: true, format: { with: /\A\+?\d{8,15}\z/ }
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true

  scope :not_deleted, -> { where(deleted_at: nil) }

  def deleted?
    deleted_at.present?
  end

  def can_manage_firms?
    firm_admin? || super_admin?
  end

  def current_subscription
    subscriptions.current.includes(:subscription_plan).order(:ends_at).first
  end

  # Super admins are unlimited; firm admins need a current subscription with free slots.
  def can_add_firm?
    return true if super_admin?

    subscription = current_subscription
    subscription.present? && firms.count < subscription.subscription_plan.max_firms
  end

  def self.ransackable_scopes(auth_object = nil)
    %w[ not_deleted ]
  end
end
