import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/home_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_dialogs.dart';

class ProfileView extends GetView<HomeController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    final user = controller.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: ListView(
            padding: EdgeInsets.all(AppLayout.gutter(size)),
            children: [
              if (user != null)
                _IdentityCard(name: user.fullName, email: user.email),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.s),
              Obx(
                () => _ThemeChoice(
                  selected: controller.themeMode,
                  onChanged: controller.setThemeMode,
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              _SignOutButton(onPressed: () => _confirmSignOut()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await AppDialogs.confirm(
      title: 'Sign out?',
      message: 'You will need your password to sign in again.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (confirmed) await controller.signOut();
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: p.primary,
            child: Icon(Iconsax.user, color: p.onPrimary),
          ),
          const SizedBox(width: AppSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  email,
                  style: text.bodyMedium?.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('System'),
            icon: Icon(Iconsax.mobile),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Light'),
            icon: Icon(Iconsax.sun_1),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Dark'),
            icon: Icon(Iconsax.moon),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (choice) => onChanged(choice.first),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.alert,
        side: BorderSide(color: p.alert.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      icon: const Icon(Iconsax.logout),
      label: const Text('Sign out'),
    );
  }
}
