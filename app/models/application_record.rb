class ApplicationRecord < ActiveRecord::Base
  include RansackTiers
  primary_abstract_class
end
