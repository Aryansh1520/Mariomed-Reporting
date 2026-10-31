import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/product_form_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_tokens.dart';

class ProductFormView extends GetView<ProductFormController> {
  const ProductFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.sizeOf(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit product' : 'New product'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: ListView(
            padding: EdgeInsets.all(AppLayout.gutter(size)),
            children: [
              TextField(
                controller: controller.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: controller.code,
                decoration: const InputDecoration(labelText: 'Product code'),
              ),
              const SizedBox(height: AppSpace.m),
              TextField(
                controller: controller.description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              if (controller.isEditing) ...[
                const SizedBox(height: AppSpace.s),
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Inactive products stay in history but leave the picker.',
                    ),
                    value: controller.isActive.value,
                    onChanged: (value) => controller.isActive.value = value,
                  ),
                ),
              ],
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
                  onPressed: controller.isSaving.value ? null : controller.save,
                  child: controller.isSaving.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
