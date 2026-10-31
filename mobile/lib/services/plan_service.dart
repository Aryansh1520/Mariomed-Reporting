import '../models/plan.dart';
import 'api_service.dart';

/// Plan endpoints: the rep's own planned calls and leave days. Screens reach these through their controllers.
class PlanService {
  PlanService(this._api);

  final ApiService _api;

  Future<List<PlanDay>> listPlans({
    required DateTime from,
    required DateTime to,
  }) => _api.getData<List<PlanDay>>(
    '/plans/days?date_from=${_date(from)}&date_to=${_date(to)}',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items) PlanDay.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  Future<void> addItem(DateTime planDate, int contactId) => _api.postData<void>(
    '/plans/days/${_date(planDate)}/items',
    (_) {},
    body: {'contact_id': contactId},
  );

  Future<void> removeItem(int itemId) =>
      _api.deleteData<void>('/plans/items/$itemId', (_) {});

  Future<void> setLeave(DateTime planDate) =>
      _api.putData<void>('/plans/days/${_date(planDate)}/leave', (_) {});

  Future<void> clearLeave(DateTime planDate) =>
      _api.deleteData<void>('/plans/days/${_date(planDate)}/leave', (_) {});

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
