import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../models/product.dart';
import '../services/app_exception.dart';
import '../services/product_service.dart';

/// Creates a product, or edits the one passed in with the route. Saving returns to the list with true.
class ProductFormController extends GetxController {
  ProductFormController(this._service);

  final ProductService _service;
  final name = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();
  final isActive = true.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  Product? _editing;

  bool get isEditing => _editing != null;

  @override
  void onInit() {
    super.onInit();
    final product = Get.arguments;
    if (product is Product) _fill(product);
  }

  void _fill(Product product) {
    _editing = product;
    name.text = product.name;
    code.text = product.code;
    description.text = product.description ?? '';
    isActive.value = product.isActive;
  }

  Future<void> save() async {
    final nameText = name.text.trim();
    final codeText = code.text.trim();
    if (nameText.isEmpty || codeText.isEmpty) {
      errorMessage.value = 'Enter a name and a code.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _write(nameText, codeText);
      Get.back(result: true);
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _write(String nameText, String codeText) {
    final descriptionText = description.text.trim();
    final product = _editing;
    if (product == null) {
      return _service.createProduct(
        name: nameText,
        code: codeText,
        description: descriptionText.isEmpty ? null : descriptionText,
      );
    }
    return _service.updateProduct(
      product.id,
      name: nameText,
      code: codeText,
      description: descriptionText,
      isActive: isActive.value,
    );
  }

  @override
  void onClose() {
    name.dispose();
    code.dispose();
    description.dispose();
    super.onClose();
  }
}
