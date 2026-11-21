import '../core/utils/formatters.dart';
import '../models/unlisted.dart';
import 'api_service.dart';

/// One page of unlisted contacts in a patch and the total across all pages.
class UnlistedPage {
  const UnlistedPage({required this.items, required this.total});

  final List<UnlistedContact> items;
  final int total;
}

/// Unlisted doctor and chemist endpoints: adding them while recording, and the admin's view per patch.
class UnlistedService {
  UnlistedService(this._api);

  final ApiService _api;

  /// The patch's unlisted contacts, one page at a time. Converted ones are left out unless asked for.
  Future<UnlistedPage> listUnlisted({
    required int subzoneId,
    required int page,
    int pageSize = 100,
  }) => _api.getData<UnlistedPage>(
    '/visits/unlisted-contacts?subzone_id=$subzoneId&page=$page&page_size=$pageSize',
    (data) {
      final json = ApiService.asJsonMap(data);
      final items = json['items'] as List<Object?>;
      return UnlistedPage(
        items: [
          for (final item in items)
            UnlistedContact.fromJson(ApiService.asJsonMap(item)),
        ],
        total: json['total'] as int,
      );
    },
  );

  /// Unlisted contacts in the patch under the same name, so the rep can reuse one instead of adding a duplicate.
  Future<List<UnlistedContact>> findSimilar({
    required int subzoneId,
    required String name,
  }) => _api.getData<List<UnlistedContact>>(
    '/visits/unlisted-contacts/similar?subzone_id=$subzoneId&name=${Uri.encodeQueryComponent(name)}',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          UnlistedContact.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  Future<UnlistedContact> add({
    required String name,
    required int categoryId,
    required int subzoneId,
  }) => _api.postData<UnlistedContact>(
    '/visits/unlisted-contacts',
    (data) => UnlistedContact.fromJson(ApiService.asJsonMap(data)),
    body: {'name': name, 'category_id': categoryId, 'subzone_id': subzoneId},
  );

  /// Per patch, for the admin: the unlisted contacts and the calls on them between two dates.
  Future<List<UnlistedPatch>> patchStats({
    required DateTime from,
    required DateTime to,
  }) => _api.getData<List<UnlistedPatch>>(
    '/reports/unlisted/patches?date_from=${apiDate(from)}&date_to=${apiDate(to)}',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          UnlistedPatch.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  /// The unlisted contacts of one patch, each with its calls between two dates.
  Future<List<UnlistedContactStat>> patchContacts({
    required int subzoneId,
    required DateTime from,
    required DateTime to,
  }) => _api.getData<List<UnlistedContactStat>>(
    '/reports/unlisted/patches/$subzoneId/contacts?date_from=${apiDate(from)}&date_to=${apiDate(to)}',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          UnlistedContactStat.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  /// One unlisted contact in full: who added it, its conversion, its totals and its calls.
  Future<UnlistedDetail> detail(int unlistedId) => _api.getData<UnlistedDetail>(
    '/visits/unlisted-contacts/$unlistedId',
    (data) => UnlistedDetail.fromJson(ApiService.asJsonMap(data)),
  );

  /// Flags an unlisted contact as converted. Its past calls stay on it; new calls go to the listed contact.
  Future<void> convert(int unlistedId) => _api.postData<void>(
    '/visits/unlisted-contacts/$unlistedId/convert',
    (_) {},
  );
}
