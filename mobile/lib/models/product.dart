/// A product from the catalogue.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, Object?> json) => Product(
    id: json['id'] as int,
    name: json['name'] as String,
    code: json['code'] as String,
    description: json['description'] as String?,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String name;
  final String code;
  final String? description;
  final bool isActive;
}
