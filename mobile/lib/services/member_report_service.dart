import '../models/member_report.dart';
import 'api_service.dart';

/// Team performance and one person's detail. The server decides who is in the report and what each figure covers.
class MemberReportService {
  MemberReportService(this._api);

  final ApiService _api;

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<List<MemberRow>> fetchMembers({
    required DateTime from,
    required DateTime to,
  }) => _api.getData<List<MemberRow>>(
    '/reports/members?date_from=${_date(from)}&date_to=${_date(to)}',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          MemberRow.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  Future<MemberDetail> fetchMember(
    int userId, {
    required DateTime from,
    required DateTime to,
  }) => _api.getData<MemberDetail>(
    '/reports/members/$userId?date_from=${_date(from)}&date_to=${_date(to)}',
    (data) => MemberDetail.fromJson(ApiService.asJsonMap(data)),
  );
}
