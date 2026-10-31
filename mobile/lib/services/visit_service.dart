import '../models/joint_partner.dart';
import '../models/visit.dart';
import 'api_service.dart';

/// Visit endpoints. Screens reach these through their controllers.
class VisitService {
  VisitService(this._api);

  final ApiService _api;

  /// The reps who can join a call on this contact.
  Future<List<JointPartner>> listJointPartners(int contactId) =>
      _api.getData<List<JointPartner>>(
        '/visits/joint-partners?contact_id=$contactId',
        (data) {
          final items = data as List<Object?>;
          return [
            for (final item in items)
              JointPartner.fromJson(ApiService.asJsonMap(item)),
          ];
        },
      );

  /// Calls between two dates, inclusive. [mineOnly] keeps it to the caller's own calls even when they can see everyone's.
  Future<List<VisitRecord>> listVisits({
    required DateTime from,
    required DateTime to,
    bool mineOnly = false,
  }) => _api.getData<List<VisitRecord>>(
    '/visits?date_from=${_date(from)}&date_to=${_date(to)}&mine=$mineOnly',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items)
          VisitRecord.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  /// Day reports between two dates. A date with no report is not in the list. [mineOnly] as for [listVisits].
  Future<List<VisitDay>> listDays({
    required DateTime from,
    required DateTime to,
    bool mineOnly = false,
  }) => _api.getData<List<VisitDay>>(
    '/visits/days?date_from=${_date(from)}&date_to=${_date(to)}&mine=$mineOnly',
    (data) {
      final items = data as List<Object?>;
      return [
        for (final item in items) VisitDay.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  /// Joint calls other reps recorded with the caller.
  Future<List<JointRequest>> listJointRequests() =>
      _api.getData<List<JointRequest>>('/visits/joint-requests', (data) {
        final items = data as List<Object?>;
        return [
          for (final item in items)
            JointRequest.fromJson(ApiService.asJsonMap(item)),
        ];
      });

  /// Records one call. The server checks the date against the grace period and the caller's territories.
  Future<void> recordVisit({
    required int contactId,
    required DateTime visitDate,
    required String visitTime,
    required String remarks,
    required List<int> productIds,
    int? partnerUserId,
  }) => _api.postData<void>(
    '/visits',
    (_) {},
    body: {
      'contact_id': contactId,
      'visit_date': _date(visitDate),
      'visit_time': visitTime,
      'remarks': remarks,
      'product_ids': productIds,
      'partner_user_id': partnerUserId,
    },
  );

  /// Changes a call while its day is open. The partner is sent as null to remove one.
  Future<void> updateVisit({
    required int visitId,
    required String visitTime,
    required String remarks,
    required List<int> productIds,
    int? partnerUserId,
  }) => _api.patchData<void>(
    '/visits/$visitId',
    (_) {},
    body: {
      'visit_time': visitTime,
      'remarks': remarks,
      'product_ids': productIds,
      'partner_user_id': partnerUserId,
    },
  );

  Future<void> deleteVisit(int visitId) =>
      _api.deleteData<void>('/visits/$visitId', (_) {});

  /// Closes the caller's day. Its calls become completed and joint partners are asked to answer.
  Future<void> endDay(DateTime visitDate) =>
      _api.postData<void>('/visits/days/${_date(visitDate)}/end', (_) {});

  Future<void> acceptJoint(int visitId) =>
      _api.postData<void>('/visits/$visitId/joint/accept', (_) {});

  Future<void> disputeJoint(int visitId) =>
      _api.postData<void>('/visits/$visitId/joint/dispute', (_) {});

  /// Settles a disputed joint call: 'both', 'them' (the recorder only) or 'none'.
  Future<void> resolveDispute(int visitId, String decision) =>
      _api.postData<void>(
        '/visits/$visitId/dispute/resolve',
        (_) {},
        body: {'decision': decision},
      );

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
