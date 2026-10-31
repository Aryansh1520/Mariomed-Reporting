import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/reset_password_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';

/// Enter the code from the reset email and a new password. Reached from the sign-in screen.
class ResetPasswordView extends GetView<ResetPasswordController> {
  const ResetPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final gutter = AppLayout.gutter(AppLayout.sizeOf(context));

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.formMaxWidth,
            ),
            child: Container(
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
                    'Choose a new password',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'If an account exists for the address you entered, a reset code has been emailed to it. '
                    'The code works once and expires after 30 minutes.',
                    style: text.bodyMedium?.copyWith(color: p.inkMuted),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  TextField(
                    controller: controller.code,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Reset code',
                      prefixIcon: Icon(Iconsax.key),
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: controller.password,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText: 'At least 8 characters',
                      prefixIcon: Icon(Iconsax.lock),
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: controller.confirmPassword,
                    obscureText: true,
                    onSubmitted: (_) => controller.submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Iconsax.lock_1),
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
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.submit,
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Change password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
