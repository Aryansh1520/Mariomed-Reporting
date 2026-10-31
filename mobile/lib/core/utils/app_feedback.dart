import 'package:get/get.dart';

/// The one place that shows a short message to the user. Controllers call this instead of building a snackbar.
void showAppMessage(String title, String message) =>
    Get.snackbar(title, message);
