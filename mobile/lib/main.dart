import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'services/app_theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final themes = AppThemeService();
  await themes.restore();
  Get.put<AppThemeService>(themes, permanent: true);
  runApp(const App());
}
