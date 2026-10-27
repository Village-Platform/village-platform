require "csv"

# CSV download of an admin index, using the page's own filtered scope.
#
#   return export_csv(scope, "firms", FIRM_COLUMNS) if request.format.csv?
#
# Exports carry personal data (phones), so they need the export.run permission and are audited
# with the filters used. Cells that a spreadsheet would run as a formula are neutralized.
module AdminCsvExport
  extend ActiveSupport::Concern

  MAX_ROWS = 10_000
  FORMULA_START = /\A[=+\-@\t\r]/
  BOM = "﻿" # lets Excel open Arabic text as UTF-8

  private

  def export_csv(scope, name, columns)
    return redirect_to(admin_root_path, alert: "ليس لديك صلاحية التصدير.") unless current_admin.can?("export.run")

    filters = filter_params.except(:page, :per_page).compact_blank
    Audit.record(actor: current_admin, action: "#{name}.export", subject: current_admin,
                 changes: { "export" => [ nil, name ], "filters" => [ nil, filters.to_h ] })

    csv = CSV.generate(BOM.dup) do |rows|
      rows << columns.keys
      scope.limit(MAX_ROWS).each { |record| rows << columns.values.map { |value| safe_cell(value.call(record)) } }
    end
    send_data csv, type: "text/csv; charset=utf-8",
                   filename: "#{name}-#{Time.current.strftime('%Y%m%d-%H%M')}.csv"
  end

  # CSV injection: a firm named "=HYPERLINK(...)" must stay text when an admin opens the file.
  def safe_cell(value)
    text = value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) ? value.strftime("%Y-%m-%d %H:%M") : value.to_s
    text.match?(FORMULA_START) ? "'#{text}" : text
  end
end
