import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/complete_day_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/plan_day_controller.dart';
import '../../controllers/visit_record_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/business_time.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/contact.dart';

/// Stored as the choice for "no joint partner". Real user ids are always positive.
const _noPartner = 0;

class VisitRecordView extends GetView<VisitRecordController> {
  const VisitRecordView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit visit' : 'Record visit'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth(size),
          ),
          child: Obx(() => _body(context, AppLayout.gutter(size))),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double gutter) {
    if (controller.isLoading.value) return const LoadingList(count: 3);
    final error = controller.loadError.value;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Could not open this visit',
        message: error,
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(gutter),
            children: [
              _ContactHeader(controller: controller),
              const SizedBox(height: AppSpace.xl),
              _WhenRow(controller: controller),
              const SizedBox(height: AppSpace.xl),
              _ProductsSection(controller: controller),
              const SizedBox(height: AppSpace.xl),
              _RemarksField(controller: controller),
              const SizedBox(height: AppSpace.xl),
              _PartnerRow(controller: controller),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
          child: _SaveButton(controller: controller),
        ),
      ],
    );
  }
}

class _ContactHeader extends StatelessWidget {
  const _ContactHeader({required this.controller});

  final VisitRecordController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final contact = controller.contact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contact.name,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          contactKind(contact.categoryName, contact.typeName),
          style: text.bodyMedium?.copyWith(
            color: p.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          '${contact.zoneName}  ›  ${contact.subzoneName}',
          style: text.bodySmall?.copyWith(color: p.inkMuted),
        ),
      ],
    );
  }
}

/// The date and time of the call. The date is limited to the grace period.
class _WhenRow extends StatelessWidget {
  const _WhenRow({required this.controller});

  final VisitRecordController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FieldTile(
            label: 'Date',
            value: formatDay(controller.visitDate.value),
            icon: Iconsax.calendar_1,
            onTap: controller.isEditing
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: controller.visitDate.value,
                      firstDate: controller.earliestDate,
                      lastDate: controller.latestDate,
                      selectableDayPredicate: (day) => !isSunday(day),
                    );
                    if (picked != null) controller.setDate(picked);
                  },
          ),
        ),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: _FieldTile(
            label: 'Time',
            value: controller.visitTime.value.format(context),
            icon: Iconsax.clock,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: controller.visitTime.value,
              );
              if (picked != null) controller.setTime(picked);
            },
          ),
        ),
      ],
    );
  }
}

/// A labelled field that opens a picker when tapped.
class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Null when the field cannot be changed, such as the date of an existing call.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: AppRadius.md,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: p.primary),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(color: p.inkMuted),
                  ),
                  Text(
                    value,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.controller});

  final VisitRecordController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Products promoted',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Choose every product you talked about.',
          style: text.bodySmall?.copyWith(color: p.inkMuted),
        ),
        const SizedBox(height: AppSpace.m),
        if (controller.products.isEmpty)
          Text(
            'No products are set up yet.',
            style: text.bodyMedium?.copyWith(color: p.inkMuted),
          )
        else
          Obx(
            () => Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                for (final product in controller.products)
                  FilterChip(
                    label: Text(product.name),
                    selected: controller.selectedProductIds.contains(
                      product.id,
                    ),
                    onSelected: (_) => controller.toggleProduct(product.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RemarksField extends StatelessWidget {
  const _RemarksField({required this.controller});

  final VisitRecordController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.remarks,
      minLines: 3,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Remarks',
        hintText: 'What was discussed, and what they said',
        alignLabelWithHint: true,
      ),
    );
  }
}

/// The optional joint partner: another rep from the same area who was on the call.
class _PartnerRow extends StatelessWidget {
  const _PartnerRow({required this.controller});

  final VisitRecordController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Joint call',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          controller.partners.isEmpty
              ? 'No other rep is assigned to this area, so this call is recorded alone.'
              : 'Only if another rep from this area was on the call.',
          style: text.bodySmall?.copyWith(color: p.inkMuted),
        ),
        if (controller.partners.isNotEmpty) ...[
          const SizedBox(height: AppSpace.m),
          Obx(
            () => _FieldTile(
              label: 'Joint with',
              value: controller.partner.value?.fullName ?? 'Nobody',
              icon: Iconsax.profile_2user,
              onTap: () => _choosePartner(context),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _choosePartner(BuildContext context) async {
    final choice = await AppDialogs.choose<int>(
      title: 'Joint call with',
      choices: [
        const AppChoice<int>(
          value: _noPartner,
          label: 'Nobody',
          icon: Iconsax.close_circle,
        ),
        for (final partner in controller.partners)
          AppChoice<int>(
            value: partner.userId,
            label: partner.fullName,
            icon: Iconsax.profile_2user,
          ),
      ],
    );
    if (choice == null) return;
    final selected = controller.partners
        .where((partner) => partner.userId == choice)
        .firstOrNull;
    controller.setPartner(selected);
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.controller});

  final VisitRecordController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => FilledButton(
        onPressed: controller.isSaving.value ? null : () => _save(context),
        child: controller.isSaving.value
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(controller.isEditing ? 'Save changes' : 'Record visit'),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final problem = await controller.save();
    if (problem != null) {
      await AppDialogs.error('Could not record visit', problem);
      return;
    }
    await AppDialogs.success(
      controller.isEditing ? 'Visit updated' : 'Visit recorded',
      '${controller.contact.name} is saved to the day’s report.',
    );
    _refreshVisitViews();
    Get.back<bool>(result: true);
  }

  /// A saved call changes the day, the plans it may achieve, and the home figures. Each screen that is open
  /// reloads now, so it does not wait for an app restart.
  void _refreshVisitViews() {
    if (Get.isRegistered<CompleteDayController>())
      Get.find<CompleteDayController>().load();
    if (Get.isRegistered<PlanDayController>())
      Get.find<PlanDayController>().load();
    if (Get.isRegistered<HomeController>())
      Get.find<HomeController>().loadDashboard();
  }
}
