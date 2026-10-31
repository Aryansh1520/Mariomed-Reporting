import 'package:get/get.dart';

import '../core/utils/business_time.dart';
import '../models/product.dart';
import '../models/team_dashboard.dart';
import '../services/app_exception.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/team_dashboard_service.dart';

/// The product list with this month's figures for each product. The figures show only where the caller may see the team dashboard.
class ProductsController extends GetxController {
  ProductsController(this._service, this._dashboard);

  final ProductService _service;
  final TeamDashboardService _dashboard;
  final _products = <Product>[].obs;
  final _isLoading = true.obs;
  final _errorMessage = RxnString();

  /// This month's figures by product id.
  final stats = <int, ProductLine>{}.obs;

  List<Product> get products => _products;

  bool get isLoading => _isLoading.value;

  String? get errorMessage => _errorMessage.value;

  /// Whether this caller may see the figures.
  bool get showsStats => Get.find<AuthService>().can('admin.dashboard');

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      _products.assignAll(await _service.listProducts());
    } on AppException catch (e) {
      _errorMessage.value = e.message;
    } finally {
      _isLoading.value = false;
    }
    await _loadStats();
  }

  Future<void> _loadStats() async {
    stats.clear();
    if (!showsStats) return;
    try {
      final today = indiaToday();
      final dashboard = await _dashboard.fetch(
        from: DateTime(today.year, today.month),
        to: today,
      );
      stats.addAll({
        for (final line in dashboard.products) line.productId: line,
      });
    } on AppException {
      stats.clear();
    }
  }

  /// Switches a product on or off, then reloads the list. Returns the problem to show, or null when it worked.
  Future<String?> setActive(Product product, {required bool isActive}) async {
    try {
      await _service.setActive(product.id, isActive: isActive);
      await loadProducts();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}
