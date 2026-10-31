import '../models/team_dashboard.dart';
import 'api_service.dart';

/// The admin dashboard's team-wide figures. The server decides who is included and what each figure covers.
class TeamDashboardService {
  TeamDashboardService(this._api);

  final ApiService _api;

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<TeamDashboard> fetch({required DateTime from, required DateTime to}) =>
      _api.getData<TeamDashboard>(
        '/reports/team?date_from=${_date(from)}&date_to=${_date(to)}',
        (data) => TeamDashboard.fromJson(ApiService.asJsonMap(data)),
      );

  /// The team's calls in one zone, product or category. Pass exactly one of the three.
  Future<List<TeamCallLine>> fetchCalls({
    required DateTime from,
    required DateTime to,
    int? zoneId,
    int? productId,
    String? categoryName,
  }) {
    final query = [
      'date_from=${_date(from)}',
      'date_to=${_date(to)}',
      if (zoneId != null) 'zone_id=$zoneId',
      if (productId != null) 'product_id=$productId',
      if (categoryName != null)
        'category_name=${Uri.encodeQueryComponent(categoryName)}',
    ].join('&');
    return _api.getData<List<TeamCallLine>>('/reports/team/calls?$query', (
      data,
    ) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          TeamCallLine.fromJson(ApiService.asJsonMap(item)),
      ];
    });
  }

  /// The contacts the team had not visited from the 1st of the month up to and including [day].
  /// The contacts the team had not visited from the 1st of the month up to and including [day].
  /// A zone or a category narrows the list.
  Future<List<MissedContact>> fetchMissed(
    DateTime day, {
    int? zoneId,
    String? categoryName,
  }) {
    final query = [
      'day=${_date(day)}',
      if (zoneId != null) 'zone_id=$zoneId',
      if (categoryName != null)
        'category_name=${Uri.encodeQueryComponent(categoryName)}',
    ].join('&');
    return _api.getData<List<MissedContact>>('/reports/team/missed?$query', (
      data,
    ) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          MissedContact.fromJson(ApiService.asJsonMap(item)),
      ];
    });
  }
}
