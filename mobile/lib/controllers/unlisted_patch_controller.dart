import 'package:get/get.dart';

import '../models/unlisted.dart';
import '../services/app_exception.dart';
import '../services/unlisted_service.dart';

/// The patch a contacts page opens on, with the period the admin chose on the list.
class UnlistedPatchArgs {
  const UnlistedPatchArgs({
    required this.patch,
    required this.from,
    required this.to,
  });

  final UnlistedPatch patch;
  final DateTime from;
  final DateTime to;
}

/// One patch's unlisted doctors and chemists, with the calls on each, and the action to flag one as converted.
class UnlistedPatchController extends GetxController {
  UnlistedPatchController(this._service, this.args);

  final UnlistedService _service;
  final UnlistedPatchArgs args;
  final _contacts = <UnlistedContactStat>[].obs;
  final _isLoading = true.obs;
  final _errorMessage = RxnString();

  List<UnlistedContactStat> get contacts => _contacts;

  bool get isLoading => _isLoading.value;

  String? get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    _isLoading.value = true;
    _errorMessage.value = null;
    try {
      _contacts.assignAll(
        await _service.patchContacts(
          subzoneId: args.patch.subzoneId,
          from: args.from,
          to: args.to,
        ),
      );
    } on AppException catch (e) {
      _errorMessage.value = e.message;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Flags the contact as converted. Returns the problem to show, or null when it was flagged.
  Future<String?> convert(UnlistedContactStat contact) async {
    try {
      await _service.convert(contact.unlistedId);
      await load();
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  }
}
