import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/business_time.dart';
import '../models/contact.dart';
import '../models/joint_partner.dart';
import '../models/product.dart';
import '../models/visit.dart';
import '../services/app_exception.dart';
import '../services/product_service.dart';
import '../services/visit_service.dart';

/// What the record screen opens on: a contact for a new call, or an existing call to change.
class VisitRecordArgs {
  const VisitRecordArgs({required this.contact, this.visit});

  final Contact contact;
  final VisitRecord? visit;

  bool get isEditing => visit != null;
}

/// Records a call on a contact, or changes one whose day is still open.
class VisitRecordController extends GetxController {
  VisitRecordController(this._visits, this._products, this.args);

  final VisitService _visits;
  final ProductService _products;
  final VisitRecordArgs args;

  Contact get contact => args.contact;

  bool get isEditing => args.isEditing;

  final remarks = TextEditingController();
  final visitDate = Rx<DateTime>(_today());
  final visitTime = Rx<TimeOfDay>(TimeOfDay.fromDateTime(indiaNow()));
  final products = <Product>[].obs;
  final selectedProductIds = <int>{}.obs;
  final partners = <JointPartner>[].obs;
  final partner = Rxn<JointPartner>();
  final isLoading = true.obs;
  final isSaving = false.obs;
  final loadError = RxnString();

  /// The earliest day a visit may be recorded for. Today is the latest. An existing call keeps its date.
  DateTime get earliestDate =>
      _today().subtract(const Duration(days: AppConstants.visitGraceDays));

  DateTime get latestDate => _today();

  @override
  void onInit() {
    super.onInit();
    final visit = args.visit;
    if (visit != null) {
      remarks.text = visit.remarks;
      visitDate.value = visit.visitDate;
      visitTime.value = visit.time;
      selectedProductIds.addAll(visit.products.map((product) => product.id));
    }
    load();
  }

  @override
  void onClose() {
    remarks.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      final catalogue = await _products.listProducts();
      products.assignAll(
        catalogue.where(
          (product) =>
              product.isActive || selectedProductIds.contains(product.id),
        ),
      );
      partners.assignAll(await _visits.listJointPartners(contact.id));
      _restorePartner();
    } on AppException catch (e) {
      loadError.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// An existing call keeps its joint partner, even if that rep is no longer assigned to the area.
  void _restorePartner() {
    final existing = args.visit?.partnerUserId;
    if (existing == null) return;
    partner.value =
        partners.where((item) => item.userId == existing).firstOrNull ??
        JointPartner(userId: existing, fullName: 'Joint partner');
    if (!partners.any((item) => item.userId == existing))
      partners.add(partner.value!);
  }

  void toggleProduct(int productId) {
    if (!selectedProductIds.remove(productId))
      selectedProductIds.add(productId);
  }

  void setDate(DateTime value) => visitDate.value = DateUtils.dateOnly(value);

  void setTime(TimeOfDay value) => visitTime.value = value;

  void setPartner(JointPartner? value) => partner.value = value;

  /// Saves the call. Returns an error message to show, or null when it was saved.
  Future<String?> save() async {
    final text = remarks.text.trim();
    if (text.isEmpty) return 'Add remarks for this call.';
    if (selectedProductIds.isEmpty)
      return 'Choose at least one product you promoted.';
    if (isSunday(visitDate.value))
      return 'Sunday is a leave day for everyone. No calls can be recorded on it.';
    isSaving.value = true;
    try {
      final visit = args.visit;
      if (visit == null) {
        await _visits.recordVisit(
          contactId: contact.id,
          visitDate: visitDate.value,
          visitTime: _timeText(visitTime.value),
          remarks: text,
          productIds: selectedProductIds.toList(),
          partnerUserId: partner.value?.userId,
        );
      } else {
        await _visits.updateVisit(
          visitId: visit.id,
          visitTime: _timeText(visitTime.value),
          remarks: text,
          productIds: selectedProductIds.toList(),
          partnerUserId: partner.value?.userId,
        );
      }
      return null;
    } on AppException catch (e) {
      return e.message;
    } finally {
      isSaving.value = false;
    }
  }

  static DateTime _today() => indiaToday();

  static String _timeText(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
