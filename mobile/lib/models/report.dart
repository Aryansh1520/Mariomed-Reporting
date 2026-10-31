/// Which report a home card opens. Each one has a full page with its own figures and lists.
enum ReportKind { today, month, coverage, missed, calls, nextUp, joint, team }

/// How a row reads at a glance: good is done, alert needs attention, warning waits on the rep.
enum RowTone { normal, good, warning, alert, muted }

class ReportFigure {
  const ReportFigure({
    required this.label,
    required this.value,
    this.tone = RowTone.normal,
  });

  final String label;
  final String value;
  final RowTone tone;
}

class ReportRow {
  const ReportRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone = RowTone.normal,
    this.contactId,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final RowTone tone;

  /// The contact a row is about, when a report can act on it.
  final int? contactId;
}

class ReportSection {
  const ReportSection({
    required this.title,
    required this.rows,
    required this.emptyText,
  });

  final String title;
  final List<ReportRow> rows;
  final String emptyText;
}

class ReportData {
  const ReportData({
    required this.figures,
    required this.sections,
    this.footnote,
  });

  final List<ReportFigure> figures;
  final List<ReportSection> sections;
  final String? footnote;
}
