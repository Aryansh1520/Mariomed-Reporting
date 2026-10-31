/// A person the field team visits, with where it sits. Names come from the server so rows read without a second request.
class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.zoneName,
    required this.zoneId,
    required this.subzoneId,
    required this.subzoneName,
    required this.isActive,
  });

  factory Contact.fromJson(Map<String, Object?> json) => Contact(
    id: json['id'] as int,
    name: json['name'] as String,
    categoryName: json['category_name'] as String,
    zoneName: json['zone_name'] as String,
    zoneId: json['zone_id'] as int,
    subzoneId: json['subzone_id'] as int,
    subzoneName: json['subzone_name'] as String,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String name;
  final String categoryName;
  final String zoneName;
  final int zoneId;
  final int subzoneId;
  final String subzoneName;
  final bool isActive;
}

/// A kind of contact the admin sets up, such as doctors, chemists or stockists.
class ContactCategory {
  const ContactCategory({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory ContactCategory.fromJson(Map<String, Object?> json) =>
      ContactCategory(
        id: json['id'] as int,
        name: json['name'] as String,
        isActive: json['is_active'] as bool,
      );

  final int id;
  final String name;
  final bool isActive;
}
