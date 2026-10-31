import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_system_ui.dart';
import '../core/theme/app_theme.dart';
import '../services/app_theme_service.dart';
import '../services/auth_service.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  /// Routes check the session, so the stored token must be read before the first route is built.
  late final Future<void> _sessionReady;
  Timer? _permissionTimer;

  @override
  void initState() {
    super.initState();
    InitialBinding().dependencies();
    _sessionReady = _restoreSession();
    AppSystemUi.enableEdgeToEdge();
    WidgetsBinding.instance.addObserver(this);
    _permissionTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _refreshPermissions(),
    );
  }

  /// Reloads the signed-in user's permissions, so a change made on another device takes effect without a sign-in.
  void _refreshPermissions() {
    final auth = Get.find<AuthService>();
    if (auth.isSignedIn) auth.refreshCurrentUser().catchError((_) {});
  }

  @override
  void dispose() {
    _permissionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Permissions can change on the server while the app is in the background, so they reload on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final auth = Get.find<AuthService>();
    if (auth.isSignedIn) auth.refreshCurrentUser().catchError((_) {});
  }

  /// Restores a saved session. Nobody is signed in automatically: without a saved session the login screen shows.
  Future<void> _restoreSession() async {
    await Get.find<AuthService>().restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _sessionReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return _buildApp();
      },
    );
  }

  /// Rebuilds when the user picks a theme, so the whole app switches at once.
  Widget _buildApp() {
    final themes = Get.find<AppThemeService>();
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themes.observedMode.value,
        getPages: AppPages.pages,
        initialRoute: AppRoutes.login,
        builder: (context, child) {
          final p = context.palette;
          AppSystemUi.apply(p);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.backgroundTop, p.backgroundBottom],
              ),
            ),
            child: BackspaceBack(
              child: ShadTheme(
                data: AppTheme.shad(p),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Linux desktop has no back button, so Backspace goes back to the previous screen.
/// A text field keeps Backspace for itself, because it handles the key before this does.
class BackspaceBack extends StatelessWidget {
  const BackspaceBack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }
        if (Get.key.currentState?.canPop() != true)
          return KeyEventResult.ignored;
        Get.back<void>();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
