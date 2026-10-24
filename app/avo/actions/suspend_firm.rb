class Avo::Actions::SuspendFirm < Avo::BaseAction
  self.name = "إيقاف المنشأة"

  def handle(query:, **)
    query.each { |firm| firm.update!(status: :suspended) }
    succeed I18n.t("admin.actions.done", count: query.count)
  end
end
