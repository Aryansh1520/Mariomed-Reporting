/// One person's performance for the chosen period.
class MemberRow {
  const MemberRow({
    required this.userId,
    required this.fullName,
    required this.roleName,
    required this.isActive,
    required this.calls,
    required this.contactsVisited,
    required this.coverageTotal,
    required this.daysReported,
    required this.daysLeave,
    required this.daysNeverReported,
    required this.plansDue,
    required this.plansAchieved,
  });

  factory MemberRow.fromJson(Map<String, Object?> json) => MemberRow(
    userId: json['user_id'] as int,
    fullName: json['full_name'] as String,
    roleName: json['role_name'] as String,
    isActive: json['is_active'] as bool,
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
    coverageTotal: json['coverage_total'] as int,
    daysReported: json['days_reported'] as int,
    daysLeave: json['days_leave'] as int,
    daysNeverReported: json['days_never_reported'] as int,
    plansDue: json['plans_due'] as int,
    plansAchieved: json['plans_achieved'] as int,
  );

  final int userId;
  final String fullName;
  final String roleName;
  final bool isActive;
  final int calls;
  final int contactsVisited;
  final int coverageTotal;
  final int daysReported;
  final int daysLeave;
  final int daysNeverReported;
  final int plansDue;
  final int plansAchieved;

  /// Share of the person's contacts visited, from 0 to 1. Zero when they have no contacts.
  double get coverage => coverageTotal == 0
      ? 0
      : (contactsVisited > coverageTotal ? coverageTotal : contactsVisited) /
            coverageTotal;
}

class DayLine {
  const DayLine({required this.day, required this.status, required this.calls});

  factory DayLine.fromJson(Map<String, Object?> json) => DayLine(
    day: DateTime.parse(json['day'] as String),
    status: json['status'] as String?,
    calls: json['calls'] as int,
  );

  final DateTime day;
  final String? status;
  final int calls;
}

class CallLine {
  const CallLine({
    required this.visitId,
    required this.visitDate,
    required this.visitTime,
    required this.contactName,
    required this.categoryName,
    required this.products,
    required this.remarks,
    required this.status,
  });

  factory CallLine.fromJson(Map<String, Object?> json) => CallLine(
    visitId: json['visit_id'] as int,
    visitDate: DateTime.parse(json['visit_date'] as String),
    visitTime: json['visit_time'] as String,
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    products: [
      for (final product in json['products'] as List<Object?>)
        product as String,
    ],
    remarks: json['remarks'] as String,
    status: json['status'] as String,
  );

  final int visitId;
  final DateTime visitDate;
  final String visitTime;
  final String contactName;
  final String categoryName;
  final List<String> products;
  final String remarks;
  final String status;
}

class MemberDetail {
  const MemberDetail({
    required this.member,
    required this.days,
    required this.calls,
  });

  factory MemberDetail.fromJson(Map<String, Object?> json) => MemberDetail(
    member: MemberRow.fromJson((json['member'] as Map).cast()),
    days: [
      for (final day in json['days'] as List<Object?>)
        DayLine.fromJson((day as Map).cast()),
    ],
    calls: [
      for (final call in json['calls'] as List<Object?>)
        CallLine.fromJson((call as Map).cast()),
    ],
  );

  final MemberRow member;
  final List<DayLine> days;
  final List<CallLine> calls;
}
