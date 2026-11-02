/// Team-wide figures for a period. Averages are per working day: Sundays, holidays and each person's leave are left out.
class TeamDashboard {
  const TeamDashboard({
    required this.summary,
    required this.daily,
    required this.employees,
    required this.zones,
    required this.products,
    required this.categories,
  });

  factory TeamDashboard.fromJson(Map<String, Object?> json) => TeamDashboard(
    summary: TeamSummary.fromJson(_map(json['summary'])),
    daily: [
      for (final item in _list(json['daily'])) DayPoint.fromJson(_map(item)),
    ],
    employees: [
      for (final item in _list(json['employees']))
        EmployeeLine.fromJson(_map(item)),
    ],
    zones: [
      for (final item in _list(json['zones'])) ZoneLine.fromJson(_map(item)),
    ],
    products: [
      for (final item in _list(json['products']))
        ProductLine.fromJson(_map(item)),
    ],
    categories: [
      for (final item in _list(json['categories']))
        CategoryLine.fromJson(_map(item)),
    ],
  );

  final TeamSummary summary;
  final List<DayPoint> daily;
  final List<EmployeeLine> employees;
  final List<ZoneLine> zones;
  final List<ProductLine> products;
  final List<CategoryLine> categories;

  static Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value as Map);

  static List<Object?> _list(Object? value) => value as List<Object?>;
}

class TeamSummary {
  const TeamSummary({
    required this.calls,
    required this.contactsVisited,
    required this.coverageTotal,
    required this.coveragePercent,
    required this.reportingReps,
    required this.daysReported,
    required this.workingDays,
    required this.avgCallsPerDay,
    required this.plannedDue,
    required this.plannedAchieved,
    required this.missedCalls,
  });

  factory TeamSummary.fromJson(Map<String, Object?> json) => TeamSummary(
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
    coverageTotal: json['coverage_total'] as int,
    coveragePercent: (json['coverage_percent'] as num).toDouble(),
    reportingReps: json['reporting_reps'] as int,
    daysReported: json['days_reported'] as int,
    workingDays: json['working_days'] as int,
    avgCallsPerDay: (json['avg_calls_per_day'] as num).toDouble(),
    plannedDue: json['planned_due'] as int,
    plannedAchieved: json['planned_achieved'] as int,
    missedCalls: json['missed_calls'] as int,
  );

  final int calls;
  final int contactsVisited;
  final int coverageTotal;
  final double coveragePercent;
  final int reportingReps;
  final int daysReported;
  final int workingDays;
  final double avgCallsPerDay;
  final int plannedDue;
  final int plannedAchieved;
  final int missedCalls;
}

class EmployeeLine {
  const EmployeeLine({
    required this.userId,
    required this.fullName,
    required this.calls,
    required this.contactsVisited,
    required this.daysReported,
    required this.workingDays,
    required this.avgCallsPerDay,
    required this.plannedDue,
    required this.missedCalls,
  });

  factory EmployeeLine.fromJson(Map<String, Object?> json) => EmployeeLine(
    userId: json['user_id'] as int,
    fullName: json['full_name'] as String,
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
    daysReported: json['days_reported'] as int,
    workingDays: json['working_days'] as int,
    avgCallsPerDay: (json['avg_calls_per_day'] as num).toDouble(),
    plannedDue: json['planned_due'] as int,
    missedCalls: json['missed_calls'] as int,
  );

  final int userId;
  final String fullName;
  final int calls;
  final int contactsVisited;
  final int daysReported;
  final int workingDays;
  final double avgCallsPerDay;
  final int plannedDue;
  final int missedCalls;
}

class ZoneLine {
  const ZoneLine({
    required this.zoneId,
    required this.zoneName,
    required this.calls,
    required this.contactsVisited,
    required this.coverageTotal,
    required this.coveragePercent,
    required this.missedCalls,
  });

  factory ZoneLine.fromJson(Map<String, Object?> json) => ZoneLine(
    zoneId: json['zone_id'] as int,
    zoneName: json['zone_name'] as String,
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
    coverageTotal: json['coverage_total'] as int,
    coveragePercent: (json['coverage_percent'] as num).toDouble(),
    missedCalls: json['missed_calls'] as int,
  );

  final int zoneId;
  final String zoneName;
  final int calls;
  final int contactsVisited;
  final int coverageTotal;
  final double coveragePercent;
  final int missedCalls;
}

class ProductLine {
  const ProductLine({
    required this.productId,
    required this.name,
    required this.calls,
    required this.contactsVisited,
    required this.reps,
  });

  factory ProductLine.fromJson(Map<String, Object?> json) => ProductLine(
    productId: json['product_id'] as int,
    name: json['name'] as String,
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
    reps: json['reps'] as int,
  );

  final int productId;
  final String name;
  final int calls;
  final int contactsVisited;
  final int reps;
}

class DayPoint {
  const DayPoint({
    required this.day,
    required this.calls,
    required this.missedCalls,
  });

  factory DayPoint.fromJson(Map<String, Object?> json) => DayPoint(
    day: DateTime.parse(json['day'] as String),
    calls: json['calls'] as int,
    missedCalls: json['missed_calls'] as int,
  );

  final DateTime day;
  final int calls;
  final int missedCalls;
}

class CategoryLine {
  const CategoryLine({
    required this.categoryName,
    required this.calls,
    required this.contactsVisited,
  });

  factory CategoryLine.fromJson(Map<String, Object?> json) => CategoryLine(
    categoryName: json['category_name'] as String,
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
  );

  final String categoryName;
  final int calls;
  final int contactsVisited;
}

/// One call in a zone, product or category, as the team dashboard lists it.
class TeamCallLine {
  const TeamCallLine({
    required this.visitDate,
    required this.visitTime,
    required this.repName,
    required this.contactName,
    required this.categoryName,
    this.typeName,
    required this.zoneName,
    required this.products,
    required this.status,
  });

  factory TeamCallLine.fromJson(Map<String, Object?> json) => TeamCallLine(
    visitDate: DateTime.parse(json['visit_date'] as String),
    visitTime: json['visit_time'] as String,
    repName: json['rep_name'] as String,
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    typeName: json['type_name'] as String?,
    zoneName: json['zone_name'] as String,
    products: [
      for (final name in json['products'] as List<Object?>) name as String,
    ],
    status: json['status'] as String,
  );

  final DateTime visitDate;
  final String visitTime;
  final String repName;
  final String contactName;
  final String categoryName;
  final String? typeName;
  final String zoneName;
  final List<String> products;
  final String status;
}

/// A contact in scope that the team had not visited yet this month, as the day summary lists it.
class MissedContact {
  const MissedContact({
    required this.contactName,
    required this.categoryName,
    this.typeName,
    required this.zoneName,
  });

  factory MissedContact.fromJson(Map<String, Object?> json) => MissedContact(
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    typeName: json['type_name'] as String?,
    zoneName: json['zone_name'] as String,
  );

  final String contactName;
  final String categoryName;
  final String? typeName;
  final String zoneName;
}
