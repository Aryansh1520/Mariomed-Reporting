import '../models/product.dart';
import 'api_service.dart';

/// Product endpoints. Screens reach these through their controllers.
class ProductService {
  ProductService(this._api);

  final ApiService _api;

  /// The whole catalogue. The list is short, so one page covers it for now.
  Future<List<Product>> listProducts() => _api.getData<List<Product>>(
    '/products?page_size=100',
    (data) {
      final page = ApiService.asJsonMap(data);
      final items = page['items'] as List<Object?>;
      return [
        for (final item in items) Product.fromJson(ApiService.asJsonMap(item)),
      ];
    },
  );

  Future<Product> createProduct({
    required String name,
    required String code,
    String? description,
  }) => _api.postData<Product>(
    '/products',
    (data) => Product.fromJson(ApiService.asJsonMap(data)),
    body: {'name': name, 'code': code, 'description': description},
  );

  Future<Product> updateProduct(
    int productId, {
    required String name,
    required String code,
    required String? description,
    required bool isActive,
  }) => _api.patchData<Product>(
    '/products/$productId',
    (data) => Product.fromJson(ApiService.asJsonMap(data)),
    body: {
      'name': name,
      'code': code,
      'description': description,
      'is_active': isActive,
    },
  );

  /// Switches a product on or off. A product that is off stays in past calls but cannot be used for new ones.
  Future<Product> setActive(int productId, {required bool isActive}) =>
      _api.patchData<Product>(
        '/products/$productId',
        (data) => Product.fromJson(ApiService.asJsonMap(data)),
        body: {'is_active': isActive},
      );
}
