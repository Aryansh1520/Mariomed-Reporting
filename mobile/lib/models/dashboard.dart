/// The home dashboard. A section is null when the caller's permissions do not allow it, so the screen shows only what is there.
class Dashboard {
  const Dashboard({
    required this.today,
    required this.month,
    required this.coverage,
    required this.missed,
    required this.nextUp,
    required this.dailyCalls,
    required this.jointWaiting,
    required this.team,
  });

  factory Dashboard.fromJson(Map<String, Object?> json) => Dashboard(
    today: _map(json['today'], TodayStats.fromJson),
    month: _map(json['month'], MonthStats.fromJson),
    coverage: _map(json['coverage'], CoverageStats.fromJson),
    missed: _map(json['missed'], MissedStats.fromJson),
    nextUp: _list(json['next_up'], NextUpItem.fromJson),
    dailyCalls: _list(json['daily_calls'], DayCount.fromJson),
    jointWaiting: json['joint_waiting'] as int?,
    team: _map(json['team'], TeamStats.fromJson),
  );

  final TodayStats? today;
  final MonthStats? month;
  final CoverageStats? coverage;
  final MissedStats? missed;
  final List<NextUpItem>? nextUp;
  final List<DayCount>? dailyCalls;
  final int? jointWaiting;
  final TeamStats? team;

  static T? _map<T>(Object? value, T Function(Map<String, Object?>) build) =>
      value == null ? null : build((value as Map).cast());

  static List<T>? _list<T>(
    Object? value,
    T Function(Map<String, Object?>) build,
  ) => value == null
      ? null
      : [
          for (final item in value as List<Object?>)
            build((item as Map).cast()),
        ];
}

class TodayStats {
  const TodayStats({
    required this.date,
    required this.calls,
    required this.dayStatus,
    required this.planned,
    required this.isLeave,
  });

  factory TodayStats.fromJson(Map<String, Object?> json) => TodayStats(
    date: DateTime.parse(json['date'] as String),
    calls: json['calls'] as int,
    dayStatus: json['day_status'] as String?,
    planned: json['planned'] as int?,
    isLeave: json['is_leave'] as bool?,
  );

  final DateTime date;
  final int calls;

  /// open, ended, or null when no report exists for today yet.
  final String? dayStatus;
  final int? planned;
  final bool? isLeave;
}

class MonthStats {
  const MonthStats({
    required this.calls,
    required this.contactsVisited,
    required this.daysReported,
  });

  factory MonthStats.fromJson(Map<String, Object?> json) => MonthStats(
    calls: json['calls'] as int,
    contactsVisited: json['contacts_visited'] as int,
    daysReported: json['days_reported'] as int,
  );

  final int calls;
  final int contactsVisited;
  final int daysReported;
}

class CoverageStats {
  const CoverageStats({
    required this.visited,
    required this.total,
    required this.percent,
  });

  factory CoverageStats.fromJson(Map<String, Object?> json) => CoverageStats(
    visited: json['visited'] as int,
    total: json['total'] as int,
    percent: (json['percent'] as num).toDouble(),
  );

  final int visited;
  final int total;

  /// From 0 to 1: how much of the caller's contact list was visited this month.
  final double percent;
}

class MissedStats {
  const MissedStats({required this.missedContacts});

  factory MissedStats.fromJson(Map<String, Object?> json) =>
      MissedStats(missedContacts: json['missed_contacts'] as int);

  /// Contacts that were not visited this month.
  final int missedContacts;
}

class NextUpItem {
  const NextUpItem({
    required this.planDate,
    required this.contactName,
    required this.categoryName,
    required this.subzoneName,
  });

  factory NextUpItem.fromJson(Map<String, Object?> json) => NextUpItem(
    planDate: DateTime.parse(json['plan_date'] as String),
    contactName: json['contact_name'] as String,
    categoryName: json['category_name'] as String,
    subzoneName: json['subzone_name'] as String,
  );

  final DateTime planDate;
  final String contactName;
  final String categoryName;
  final String subzoneName;
}

class DayCount {
  const DayCount({required this.date, required this.count});

  factory DayCount.fromJson(Map<String, Object?> json) => DayCount(
    date: DateTime.parse(json['date'] as String),
    count: json['count'] as int,
  );

  final DateTime date;
  final int count;
}

class TeamStats {
  const TeamStats({required this.activeUsers});

  factory TeamStats.fromJson(Map<String, Object?> json) =>
      TeamStats(activeUsers: json['active_users'] as int);

  final int activeUsers;
}
