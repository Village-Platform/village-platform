class ReportSerializer
  def self.render(report)
    {
      id: report.id,
      subject_type: Report::SUBJECT_TYPES.key(report.subject_type),
      subject_id: report.subject_id,
      reason: report.reason,
      note: report.note,
      status: report.status,
      created_at: report.created_at
    }
  end
end
