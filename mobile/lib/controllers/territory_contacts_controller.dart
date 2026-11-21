import 'package:get/get.dart';

import '../models/contact.dart';
import '../models/territory.dart';
import '../models/unlisted.dart';
import '../services/app_exception.dart';
import '../services/contact_service.dart';
import '../services/unlisted_service.dart';

/// Every contact inside one zone or subzone, read page by page until the whole list is in.
class TerritoryContactsController extends GetxController {
  TerritoryContactsController(
    this._service,
    this._unlistedService,
    this.territory,
  );

  final ContactService _service;
  final UnlistedService _unlistedService;
  final Territory territory;
  final _contacts = <Contact>[].obs;
  final _unlistedContacts = <UnlistedContact>[].obs;
  final _categories = <ContactCategory>[].obs;
  final _types = <ContactType>[].obs;
  final _isLoading = true.obs;
  final _errorMessage = RxnString();

  List<Contact> get contacts => _contacts;

  /// Doctors and chemists met in this patch that are not on the contact list. Empty for a headquarter.
  List<UnlistedContact> get unlistedContacts => _unlistedContacts;

  /// The categories a contact can be given. Switched-off categories are left out.
  List<ContactCategory> get categories => _categories;

  /// The switched-on types under [categoryId]. Empty when the category has none, and the form then skips the type step.
  List<ContactType> typesFor(int categoryId) => [
    for (final type in _types)
      if (type.categoryId == categoryId && type.isActive) type,
  ];

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
      _types.assignAll(await _service.listTypes());
    } on AppException {
      _categories.clear();
      _types.clear();
    }
  }

  /// Creates a contact in this subzone, or changes the given one. Returns the problem to show, or null when saved.
  Future<String?> saveContact({
    Contact? contact,
    required String name,
    int? categoryId,
    int? typeId,
    bool changeType = false,
  }) async {
    try {
      if (contact == null) {
        if (categoryId == null) return 'Choose a category.';
        await _service.createContact(
          name: name,
          categoryId: categoryId,
          subzoneId: territory.id,
          typeId: typeId,
        );
      } else {
        await _service.updateContact(
          contact.id,
          name: name,
          categoryId: categoryId,
          typeId: typeId,
          changeType: changeType,
        );
      }
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }

  /// Adds an unlisted doctor or chemist to this patch. Throws the app's error when it cannot be saved.
  Future<UnlistedContact> addUnlisted({
    required String name,
    required int categoryId,
  }) async {
    final added = await _unlistedService.add(
      name: name,
      categoryId: categoryId,
      subzoneId: territory.id,
    );
    await _loadUnlistedContacts();
    return added;
  }

  /// Unlisted contacts in this patch under the same name, so the rep can reuse one instead of adding a duplicate.
  Future<List<UnlistedContact>> similarUnlisted(String name) =>
      _unlistedService.findSimilar(subzoneId: territory.id, name: name);

  Future<void> _loadUnlistedContacts() async {
    if (isZone) return;
    try {
      final collected = <UnlistedContact>[];
      var page = 1;
      while (true) {
        final result = await _unlistedService.listUnlisted(
          subzoneId: territory.id,
          page: page,
        );
        collected.addAll(result.items);
        if (result.items.isEmpty || collected.length >= result.total) break;
        page++;
      }
      _unlistedContacts.assignAll(collected);
    } on AppException catch (e) {
      _errorMessage.value = e.message;
    }
  }

  /// Switches a listed contact off or on. A switched-off contact stays in the list but cannot be visited.
  /// Returns the problem to show, or null when it was saved.
  Future<String?> setContactActive(Contact contact, bool isActive) async {
    try {
      await _service.updateContact(contact.id, isActive: isActive);
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
      await _loadUnlistedContacts();
    } on AppException catch (e) {
      _errorMessage.value = e.message;
    } finally {
      _isLoading.value = false;
    }
  }
}
