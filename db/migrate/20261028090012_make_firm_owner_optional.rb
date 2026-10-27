# A firm may have no owner: the super admin manages it (the imported village places, a firm whose
# owner left). Existing rows keep their owner; only the constraint is relaxed.
class MakeFirmOwnerOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :firms, :owner_id, true
  end
end
