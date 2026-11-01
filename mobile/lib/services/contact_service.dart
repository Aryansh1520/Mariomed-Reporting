import '../models/contact.dart';
import 'api_service.dart';

/// One page of contacts and the total across all pages.
class ContactPage {
  const ContactPage({required this.items, required this.total});

  final List<Contact> items;
  final int total;
}

/// Contact endpoints. Screens reach these through their controllers.
class ContactService {
  ContactService(this._api);

  final ApiService _api;

  /// The contacts the caller can see, optionally narrowed to a zone or to one subzone.
  Future<ContactPage> listContacts({
    int? zoneId,
    int? subzoneId,
    required int page,
    int pageSize = 100,
  }) {
    final zone = zoneId == null ? '' : '&zone_id=$zoneId';
    final subzone = subzoneId == null ? '' : '&subzone_id=$subzoneId';
    return _api.getData<ContactPage>(
      '/contacts?page=$page&page_size=$pageSize$zone$subzone',
      (data) {
        final json = ApiService.asJsonMap(data);
        final items = json['items'] as List<Object?>;
        return ContactPage(
          items: [
            for (final item in items)
              Contact.fromJson(ApiService.asJsonMap(item)),
          ],
          total: json['total'] as int,
        );
      },
    );
  }

  Future<List<ContactCategory>> listCategories() =>
      _api.getData<List<ContactCategory>>('/contacts/categories', (data) {
        final items = data as List<Object?>;
        return [
          for (final item in items)
            ContactCategory.fromJson(ApiService.asJsonMap(item)),
        ];
      });

  /// A type is optional. Null [typeId] means no type.
  Future<void> createContact({
    required String name,
    required int categoryId,
    required int subzoneId,
    int? typeId,
  }) => _api.postData<void>(
    '/contacts',
    (_) {},
    body: {
      'name': name,
      'category_id': categoryId,
      'type_id': typeId,
      'subzone_id': subzoneId,
    },
  );

  /// Only the fields given are changed. The type changes only when [changeType] is set, so null can clear it.
  Future<void> updateContact(
    int contactId, {
    String? name,
    int? categoryId,
    int? typeId,
    bool changeType = false,
  }) => _api.patchData<void>(
    '/contacts/$contactId',
    (_) {},
    body: {
      'name': ?name,
      'category_id': ?categoryId,
      if (changeType) 'type_id': typeId,
    },
  );

  /// The types of every category, or of one category when [categoryId] is given. Read in one page of up to 100.
  Future<List<ContactType>> listTypes({int? categoryId}) {
    final category = categoryId == null ? '' : '&category_id=$categoryId';
    return _api.getData<List<ContactType>>(
      '/contacts/types?page_size=100$category',
      (data) {
        final items = ApiService.asJsonMap(data)['items'] as List<Object?>;
        return [
          for (final item in items)
            ContactType.fromJson(ApiService.asJsonMap(item)),
        ];
      },
    );
  }

  Future<ContactType> createType({
    required int categoryId,
    required String name,
  }) => _api.postData<ContactType>(
    '/contacts/types',
    (data) => ContactType.fromJson(ApiService.asJsonMap(data)),
    body: {'category_id': categoryId, 'name': name},
  );

  /// Renames a type or switches it on or off. Only the fields given are changed.
  Future<ContactType> updateType(
    int typeId, {
    String? name,
    bool? isActive,
  }) => _api.patchData<ContactType>(
    '/contacts/types/$typeId',
    (data) => ContactType.fromJson(ApiService.asJsonMap(data)),
    body: {'name': ?name, 'is_active': ?isActive},
  );

  Future<ContactCategory> createCategory(String name) =>
      _api.postData<ContactCategory>(
        '/contacts/categories',
        (data) => ContactCategory.fromJson(ApiService.asJsonMap(data)),
        body: {'name': name},
      );

  /// Renames a category or switches it on or off. Only the fields given are changed.
  Future<ContactCategory> updateCategory(
    int categoryId, {
    String? name,
    bool? isActive,
  }) => _api.patchData<ContactCategory>(
    '/contacts/categories/$categoryId',
    (data) => ContactCategory.fromJson(ApiService.asJsonMap(data)),
    body: {'name': ?name, 'is_active': ?isActive},
  );
}
