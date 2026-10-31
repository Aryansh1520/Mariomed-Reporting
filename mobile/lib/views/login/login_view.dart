import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/login_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/mesh_hero.dart';

/// Phones show the brand at the top with the sign-in card centred on the screen. Wide windows put the brand
/// on the left and the card on the right.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Builder(
        builder: (context) {
          final size = AppLayout.sizeOf(context);
          if (size == ScreenSize.expanded) return _splitLayout();
          return _stackedLayout(context, size);
        },
      ),
    );
  }

  /// The hero sits at the top and the card is centred on the whole screen, so the card's centre is the screen's centre.
  Widget _stackedLayout(BuildContext context, ScreenSize size) {
    final gutter = AppLayout.gutter(size);
    // Home's hero is about half the screen and fades into the page at its bottom edge; the login hero matches that.
    final heroHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: heroHeight,
          child: const _Brand(),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.all(gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: _SignInCard(controller: controller),
            ),
          ),
        ),
      ],
    );
  }

  Widget _splitLayout() {
    return Row(
      children: [
        const Expanded(flex: 3, child: _Brand()),
        Expanded(
          flex: 2,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.formMaxWidth,
                ),
                child: _SignInCard(controller: controller),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The hero: the logo and one line of what the app is for, on the same mesh as Home.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return MeshHero(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.l,
              AppSpace.l,
              AppSpace.l,
              AppSpace.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/mariomed-logo.png',
                  height: 96,
                  semanticLabel: AppConstants.appName,
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  'Visits, plans and targets for the field team.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: p.onHero,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sign-in card: a heading, one line of instruction, then the fields and the action.
class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign in',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Use the mobile number or email your admin set up for you.',
            style: text.bodyMedium?.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: AppSpace.xl),
          TextField(
            controller: controller.identifier,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Mobile or email',
              prefixIcon: Icon(Iconsax.user),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          Obx(
            () => TextField(
              controller: controller.password,
              obscureText: controller.isPasswordHidden.value,
              onSubmitted: (_) => controller.signIn(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Iconsax.lock),
                suffixIcon: IconButton(
                  tooltip: controller.isPasswordHidden.value
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: controller.togglePasswordVisibility,
                  icon: Icon(
                    controller.isPasswordHidden.value
                        ? Iconsax.eye
                        : Iconsax.eye_slash,
                  ),
                ),
              ),
            ),
          ),
          Obx(() {
            final message = controller.errorMessage.value;
            if (message == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpace.m),
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(color: p.alert),
              ),
            );
          }),
          const SizedBox(height: AppSpace.xl),
          Obx(
            () => FilledButton(
              onPressed: controller.isLoading.value ? null : controller.signIn,
              child: controller.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          TextButton(
            onPressed: controller.forgotPassword,
            child: const Text('Forgot password?'),
          ),
        ],
      ),
    );
  }
}
