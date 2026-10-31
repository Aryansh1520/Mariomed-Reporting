/// A call the rep planned for a day. Only the rep sees these.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.planDate,
    required this.contactId,
    required this.contactName,
    required this.categoryName,
    required this.zoneName,
    required this.subzoneName,
    required this.status,
  });

  factory PlanItem.fromJson(Map<String, Object?> json) => PlanItem(
    id: json['id'] as int,
    planDate: DateTime.parse(json['plan_date'] as String),
    contactId: json['contact_id'] as int,
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    zoneName: json['zone_name'] as String,
    subzoneName: json['subzone_name'] as String,
    status: json['status'] as String,
  );

  final int id;
  final DateTime planDate;
  final int contactId;
  final String contactName;
  final String categoryName;
  final String zoneName;
  final String subzoneName;

  /// planned for a future day; open while the day can still be reported; achieved once the contact was visited;
  /// missed when the report window has passed without a visit.
  final String status;
}

/// One day the rep planned or marked as leave. Days with neither are not in the list.
class PlanDay {
  const PlanDay({
    required this.planDate,
    required this.isLeave,
    required this.items,
  });

  factory PlanDay.fromJson(Map<String, Object?> json) => PlanDay(
    planDate: DateTime.parse(json['plan_date'] as String),
    isLeave: json['is_leave'] as bool,
    items: [
      for (final item in json['items'] as List<Object?>)
        PlanItem.fromJson((item as Map).cast()),
    ],
  );

  final DateTime planDate;
  final bool isLeave;
  final List<PlanItem> items;
}
