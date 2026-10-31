import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_tokens.dart';

/// What a dialog is about. The tone picks the icon and the colour; the colours come from the palette.
enum AppDialogTone { info, success, warning, danger }

/// Every modal the app uses. Screens and controllers call these; none builds its own dialog.
abstract class AppDialogs {
  static Future<void> info(String title, String message) =>
      _alert(AppDialogTone.info, title, message);

  static Future<void> success(String title, String message) =>
      _alert(AppDialogTone.success, title, message);

  static Future<void> warning(String title, String message) =>
      _alert(AppDialogTone.warning, title, message);

  static Future<void> error(String title, String message) =>
      _alert(AppDialogTone.danger, title, message);

  /// Resolves to true only when the user confirms. Barrier taps and back presses count as cancel.
  /// Pass [destructive] for deletes and other actions that cannot be undone.
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final tone = destructive ? AppDialogTone.danger : AppDialogTone.warning;
    final result = await Get.dialog<bool>(
      _DialogCard(
        tone: tone,
        title: title,
        message: message,
        actions: [
          _SecondaryAction(
            label: cancelLabel,
            onTap: () => Get.back<bool>(result: false),
          ),
          _PrimaryAction(
            tone: tone,
            label: confirmLabel,
            onTap: () => Get.back<bool>(result: true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Asks for one line of text. Resolves to the trimmed text, or null when cancelled or left empty.
  static Future<String?> prompt({
    required String title,
    required String label,
    String initial = '',
    String confirmLabel = 'Save',
  }) async {
    final result = await Get.dialog<String>(
      _PromptDialog(
        title: title,
        label: label,
        initial: initial,
        confirmLabel: confirmLabel,
      ),
    );
    final trimmed = result?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Blocks the screen while work runs. Close it with [closeLoading].
  static void loading(String message) {
    Get.dialog<void>(
      _LoadingDialog(message: message),
      barrierDismissible: false,
    );
  }

  static void closeLoading() {
    if (Get.isDialogOpen == true) Get.back<void>();
  }

  /// Picks one option from a list, shown as a bottom sheet. Resolves to null when dismissed.
  static Future<T?> choose<T>({
    required String title,
    required List<AppChoice<T>> choices,
  }) {
    return Get.bottomSheet<T>(_ChoiceSheet<T>(title: title, choices: choices));
  }

  static Future<void> _alert(AppDialogTone tone, String title, String message) {
    return Get.dialog<void>(
      _DialogCard(
        tone: tone,
        title: title,
        message: message,
        actions: [
          _PrimaryAction(
            tone: tone,
            label: 'OK',
            onTap: () => Get.back<void>(),
          ),
        ],
      ),
    );
  }
}

/// One row in [AppDialogs.choose].
class AppChoice<T> {
  const AppChoice({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? description;
}

Color _toneColor(AppPalette p, AppDialogTone tone) => switch (tone) {
  AppDialogTone.info => p.info,
  AppDialogTone.success => p.go,
  AppDialogTone.warning => p.warning,
  AppDialogTone.danger => p.alert,
};

IconData _toneIcon(AppDialogTone tone) => switch (tone) {
  AppDialogTone.info => Iconsax.info_circle,
  AppDialogTone.success => Iconsax.tick_circle,
  AppDialogTone.warning => Iconsax.warning_2,
  AppDialogTone.danger => Iconsax.danger,
};

class _DialogCard extends StatelessWidget {
  const _DialogCard({
    required this.tone,
    required this.title,
    required this.message,
    required this.actions,
  });

  final AppDialogTone tone;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = _toneColor(p, tone);

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(AppSpace.l),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_toneIcon(tone), color: color, size: 24),
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                message,
                style: text.bodyMedium?.copyWith(color: p.inkMuted),
              ),
              const SizedBox(height: AppSpace.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpace.s,
                runSpacing: AppSpace.s,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.tone,
    required this.label,
    required this.onTap,
  });

  final AppDialogTone tone;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context.palette, tone);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: context.palette.inkMuted),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String initial;
  final String confirmLabel;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(AppSpace.l),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.l),
              TextField(
                controller: _text,
                autofocus: true,
                decoration: InputDecoration(labelText: widget.label),
                onSubmitted: (_) => Get.back<String>(result: _text.text),
              ),
              const SizedBox(height: AppSpace.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpace.s,
                runSpacing: AppSpace.s,
                children: [
                  _SecondaryAction(
                    label: 'Cancel',
                    onTap: () => Get.back<String>(),
                  ),
                  FilledButton(
                    onPressed: () => Get.back<String>(result: _text.text),
                    child: Text(widget.confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: p.primary),
            const SizedBox(height: AppSpace.l),
            Text(message, style: text.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.choices});

  final String title;
  final List<AppChoice<T>> choices;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpace.l),
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(color: p.surface, borderRadius: AppRadius.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpace.m),
            for (final choice in choices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(choice.icon, color: p.primary),
                title: Text(choice.label),
                subtitle: switch (choice.description) {
                  final description? => Text(description),
                  null => null,
                },
                onTap: () => Get.back<T>(result: choice.value),
              ),
          ],
        ),
      ),
    );
  }
}
