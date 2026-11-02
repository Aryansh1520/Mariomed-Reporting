/// A person the field team visits, with where it sits. Names come from the server so rows read without a second request.
class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.categoryName,
    this.categoryId,
    this.typeId,
    this.typeName,
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
    categoryId: json['category_id'] as int?,
    typeId: json['type_id'] as int?,
    typeName: json['type_name'] as String?,
    zoneName: json['zone_name'] as String,
    zoneId: json['zone_id'] as int,
    subzoneId: json['subzone_id'] as int,
    subzoneName: json['subzone_name'] as String,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String name;
  final String categoryName;

  /// Null when the contact was built from a visit, which does not carry the category's id.
  final int? categoryId;
  final int? typeId;
  final String? typeName;
  final String zoneName;
  final int zoneId;
  final int subzoneId;
  final String subzoneName;
  final bool isActive;
}

/// How a contact is labelled on screen: its category, then its type when it has one.
String contactKind(String categoryName, String? typeName) =>
    typeName == null ? categoryName : '$categoryName  ·  $typeName';

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

/// A sub-kind of one category, such as ortho or physician under doctors. A contact may have one, but it is optional.
class ContactType {
  const ContactType({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.isActive,
  });

  factory ContactType.fromJson(Map<String, Object?> json) => ContactType(
    id: json['id'] as int,
    categoryId: json['category_id'] as int,
    name: json['name'] as String,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final int categoryId;
  final String name;
  final bool isActive;
}
