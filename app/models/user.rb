class User < ApplicationRecord
  has_secure_password

  # user        -> normal village resident
  # firm_admin  -> firm owner, can add/manage own firms (subscription-gated later)
  # super_admin -> developers / platform admins
  enum :role, { user: 0, firm_admin: 1, super_admin: 2 }, default: :user, validate: true

  has_many :firms, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error
  has_many :articles, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_error

  normalizes :phone, with: ->(phone) { phone.to_s.gsub(/[^\d+]/, "") }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, uniqueness: true, format: { with: /\A\+?\d{8,15}\z/ }
  validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true

  def can_manage_firms?
    firm_admin? || super_admin?
  end
end
