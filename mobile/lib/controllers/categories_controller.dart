import 'package:get/get.dart';

import '../core/utils/business_time.dart';
import '../models/contact.dart';
import '../models/team_dashboard.dart';
import '../services/app_exception.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';
import '../services/team_dashboard_service.dart';

/// The contact categories, with this month's figures for each. The figures show only where the caller may see the team dashboard.
class CategoriesController extends GetxController {
  CategoriesController(this._service, this._dashboard);

  final ContactService _service;
  final TeamDashboardService _dashboard;
  final categories = <ContactCategory>[].obs;
  final types = <ContactType>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();

  /// This month's figures by category name.
  final stats = <String, CategoryLine>{}.obs;

  /// Whether this caller may see the figures.
  bool get showsStats => Get.find<AuthService>().can('admin.dashboard');

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      categories.assignAll(await _service.listCategories());
      types.assignAll(await _service.listTypes());
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
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
        for (final line in dashboard.categories) line.categoryName: line,
      });
    } on AppException {
      stats.clear();
    }
  }

  /// Creates a category, or renames [category] when it is given. Returns the problem to show, or null when saved.
  Future<String?> save(String name, {ContactCategory? category}) async {
    try {
      if (category == null) {
        await _service.createCategory(name);
      } else {
        await _service.updateCategory(category.id, name: name);
      }
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  /// The types under one category, switched-off ones included.
  List<ContactType> typesOf(int categoryId) =>
      types.where((type) => type.categoryId == categoryId).toList();

  /// Adds a type under [categoryId], or renames [contactType] when it is given. Returns the problem to show, or null when saved.
  Future<String?> saveType(
    int categoryId,
    String name, {
    ContactType? contactType,
  }) async {
    try {
      if (contactType == null) {
        await _service.createType(categoryId: categoryId, name: name);
      } else {
        await _service.updateType(contactType.id, name: name);
      }
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> setTypeActive(
    ContactType contactType, {
    required bool isActive,
  }) async {
    try {
      await _service.updateType(contactType.id, isActive: isActive);
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<String?> setActive(
    ContactCategory category, {
    required bool isActive,
  }) async {
    try {
      await _service.updateCategory(category.id, isActive: isActive);
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}
