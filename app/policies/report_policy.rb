class ReportPolicy < ApplicationPolicy
  def create? = user.present?

  def permitted_attributes
    %i[subject_type subject_id reason note]
  end
end
