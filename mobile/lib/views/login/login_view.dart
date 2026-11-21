import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/login_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/password_field.dart';
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

  /// The blue hero fills the top half, and the card is centred over it with the logo inside the card.
  /// Nothing can cover the logo, because it is part of the card.
  Widget _stackedLayout(BuildContext context, ScreenSize size) {
    final gutter = AppLayout.gutterOf(context);
    final heroHeight = MediaQuery.sizeOf(context).height * 0.5;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: heroHeight,
          child: const MeshHero(child: SizedBox.expand()),
        ),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: _SignInCard(controller: controller, showLogo: true),
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
    return MeshHero(
      child: SafeArea(
        bottom: false,
        child: Align(
          // Above the centre, so the logo clears the top edge of the sign-in card.
          alignment: const Alignment(0, -0.3),
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
  const _SignInCard({required this.controller, this.showLogo = false});

  final LoginController controller;

  /// Phones put the logo at the top of the card. Wide windows already show it in the brand panel.
  final bool showLogo;

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
          if (showLogo) ...[
            Center(
              child: Image.asset(
                'assets/images/mariomed-logo.png',
                height: 72,
                semanticLabel: AppConstants.appName,
              ),
            ),
            const SizedBox(height: AppSpace.l),
          ],
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
          PasswordField(
            controller: controller.password,
            labelText: 'Password',
            prefixIcon: Iconsax.lock,
            onSubmitted: (_) => controller.signIn(),
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
          const SizedBox(height: AppSpace.s),
          Obx(
            () => CheckboxListTile(
              value: controller.rememberMe.value,
              onChanged: controller.isLoading.value
                  ? null
                  : (value) => controller.rememberMe.value = value ?? false,
              title: const Text('Remember me'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
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
          Obx(() {
            if (!controller.biometricReady.value) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                const SizedBox(height: AppSpace.s),
                OutlinedButton.icon(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.signInWithBiometrics,
                  icon: const Icon(Iconsax.finger_scan),
                  label: const Text('Use fingerprint or face'),
                ),
                TextButton(
                  onPressed: controller.turnOffBiometricSignIn,
                  child: const Text('Turn off fingerprint or face sign-in'),
                ),
              ],
            );
          }),
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
