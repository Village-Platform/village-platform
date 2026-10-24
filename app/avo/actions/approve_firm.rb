class Avo::Actions::ApproveFirm < Avo::BaseAction
  self.name = "اعتماد المنشأة"

  def handle(query:, **)
    query.each { |firm| firm.update!(status: :active) }
    succeed I18n.t("admin.actions.done", count: query.count)
  end
end
