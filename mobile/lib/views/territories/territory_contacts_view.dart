import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/territory_contacts_controller.dart';
import '../../controllers/visit_record_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_effects.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../app/routes/app_routes.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/category_icon.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_list.dart';
import '../../models/contact.dart';
import '../../services/auth_service.dart';

class TerritoryContactsView extends GetView<TerritoryContactsController> {
  const TerritoryContactsView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    final text = Theme.of(context).textTheme;
    final canManage = Get.find<AuthService>().can('contacts.manage');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          controller.territory.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (canManage && !controller.isZone)
            IconButton(
              tooltip: 'Add contact',
              onPressed: () => _save(),
              icon: const Icon(Iconsax.user_add),
            ),
        ],
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

  /// Adds a contact to this subzone, or changes [contact]. Each step is a dialog; dismissing the category keeps the current one.
  Future<void> _save({Contact? contact}) async {
    if (controller.categories.isEmpty) {
      await AppDialogs.info(
        'No categories',
        'Ask an admin to set up contact categories first.',
      );
      return;
    }
    final name = await AppDialogs.prompt(
      title: contact == null ? 'New contact' : 'Edit contact',
      label: 'Name',
      initial: contact?.name ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    final categoryId = await AppDialogs.choose<int>(
      title: 'Category',
      choices: [
        for (final category in controller.categories)
          AppChoice<int>(
            value: category.id,
            label: category.name,
            icon: Iconsax.user,
          ),
      ],
    );
    if (categoryId == null && contact == null) return;
    final typeChoice = await _chooseType(categoryId ?? contact?.categoryId);
    final problem = await controller.saveContact(
      contact: contact,
      name: name.trim(),
      categoryId: categoryId,
      typeId: typeChoice?.typeId,
      changeType: typeChoice != null,
    );
    if (problem != null) await AppDialogs.error('Could not save', problem);
  }

  /// Asks for the optional type under [categoryId]. Null when the category has no types or the sheet is dismissed.
  Future<_TypeChoice?> _chooseType(int? categoryId) async {
    if (categoryId == null) return null;
    final types = controller.typesFor(categoryId);
    if (types.isEmpty) return null;
    final picked = await AppDialogs.choose<int>(
      title: 'Type',
      choices: [
        const AppChoice<int>(
          value: _noType,
          label: 'No type',
          icon: Iconsax.close_circle,
        ),
        for (final type in types)
          AppChoice<int>(value: type.id, label: type.name, icon: Iconsax.category),
      ],
    );
    if (picked == null) return null;
    return _TypeChoice(picked == _noType ? null : picked);
  }

  Widget _body(BuildContext context, double gutter) {
    if (controller.isLoading) return const LoadingList(count: 4);
    final error = controller.errorMessage;
    if (error != null) {
      return EmptyState(
        icon: Iconsax.warning_2,
        title: 'Could not load contacts',
        message: error,
      );
    }
    if (controller.contacts.isEmpty) {
      return EmptyState(
        icon: Iconsax.user,
        title: 'No contacts here yet',
        message: controller.isZone
            ? 'Nobody is recorded in this zone yet.'
            : 'Nobody is recorded in this subzone yet.',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.all(gutter),
        children: [
          _ContactPanel(
            contacts: controller.contacts,
            onEdit: Get.find<AuthService>().can('contacts.manage')
                ? (contact) => _save(contact: contact)
                : null,
          ),
        ],
      ),
    );
  }
}

/// All contacts in one surface, separated by hairlines. A list this long reads better as one panel than as stacked cards.
class _ContactPanel extends StatelessWidget {
  const _ContactPanel({required this.contacts, this.onEdit});

  final List<Contact> contacts;
  final void Function(Contact contact)? onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final edit = onEdit;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppEffects.card(p),
        border: AppEffects.hairline(p),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lg,
        child: Column(
          children: [
            for (var i = 0; i < contacts.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.border),
              _ContactRow(
                contact: contacts[i],
                onEdit: edit == null ? null : () => edit(contacts[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, this.onEdit});

  final Contact contact;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _record(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: AppSpace.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryIcon(categoryName: contact.categoryName),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: contact.isActive ? p.ink : p.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    contact.isActive
                        ? contactKind(contact.categoryName, contact.typeName)
                        : '${contactKind(contact.categoryName, contact.typeName)}  ·  Switched off',
                    style: text.bodySmall?.copyWith(
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
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit contact',
                onPressed: onEdit,
                icon: const Icon(Iconsax.edit_2),
              ),
          ],
        ),
      ),
    );
  }

  /// Opens the record screen for this contact. The list needs no refresh after a visit is saved.
  Future<void> _record() async {
    await Get.toNamed(
      AppRoutes.visitRecord,
      arguments: VisitRecordArgs(contact: contact),
    );
  }
}

/// Ids start at 1, so 0 stands for "No type" in the type sheet.
const _noType = 0;

/// The type picked in the form. [typeId] is null for "No type".
class _TypeChoice {
  const _TypeChoice(this.typeId);

  final int? typeId;
}
