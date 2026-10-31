import 'package:get/get.dart';

import '../models/contact.dart';
import '../models/territory.dart';
import '../services/app_exception.dart';
import '../services/contact_service.dart';

/// Every contact inside one zone or subzone, read page by page until the whole list is in.
class TerritoryContactsController extends GetxController {
  TerritoryContactsController(this._service, this.territory);

  final ContactService _service;
  final Territory territory;
  final _contacts = <Contact>[].obs;
  final _categories = <ContactCategory>[].obs;
  final _isLoading = true.obs;
  final _errorMessage = RxnString();

  List<Contact> get contacts => _contacts;

  /// The categories a contact can be given. Switched-off categories are left out.
  List<ContactCategory> get categories => _categories;

  bool get isLoading => _isLoading.value;

  String? get errorMessage => _errorMessage.value;

  bool get isZone => territory.kind == TerritoryKind.zone;

  @override
  void onInit() {
    super.onInit();
    load();
    _loadCategories();
  }

  /// A failure here leaves the list empty; the add and edit dialogs then say there are no categories.
  Future<void> _loadCategories() async {
    try {
      final all = await _service.listCategories();
      _categories.assignAll(all.where((category) => category.isActive));
    } on AppException {
      _categories.clear();
    }
  }

  /// Creates a contact in this subzone, or changes the given one. Returns the problem to show, or null when saved.
  Future<String?> saveContact({
    Contact? contact,
    required String name,
    int? categoryId,
  }) async {
    try {
      if (contact == null) {
        if (categoryId == null) return 'Choose a category.';
        await _service.createContact(
          name: name,
          categoryId: categoryId,
          subzoneId: territory.id,
        );
      } else {
        await _service.updateContact(
          contact.id,
          name: name,
          categoryId: categoryId,
        );
      }
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  Future<void> load() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      final collected = <Contact>[];
      var page = 1;
      while (true) {
        final result = await _service.listContacts(
          zoneId: isZone ? territory.id : null,
          subzoneId: isZone ? null : territory.id,
          page: page,
        );
        collected.addAll(result.items);
        if (result.items.isEmpty || collected.length >= result.total) break;
        page++;
      }
      _contacts.assignAll(collected);
    } on AppException catch (e) {
      _errorMessage.value = e.message;
    } finally {
      _isLoading.value = false;
    }
  }
}
