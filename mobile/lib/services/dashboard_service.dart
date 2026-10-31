import '../models/dashboard.dart';
import 'api_service.dart';

/// The home dashboard. The server decides which sections the caller gets.
class DashboardService {
  DashboardService(this._api);

  final ApiService _api;

  Future<Dashboard> fetchDashboard() => _api.getData<Dashboard>(
    '/dashboard',
    (data) => Dashboard.fromJson(ApiService.asJsonMap(data)),
  );
}
