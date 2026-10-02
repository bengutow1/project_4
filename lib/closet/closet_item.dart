/// A single piece of clothing in the user's closet, matching the server's
/// outfit contract (see server/README.md "Closet-matching contract").
enum ClothingCategory { outerwear, top, bottom, accessory }

enum ClothingWarmth { none, light, medium, heavy }

extension ClothingCategoryName on ClothingCategory {
  String get label => switch (this) {
    ClothingCategory.outerwear => 'Outerwear',
    ClothingCategory.top => 'Top',
    ClothingCategory.bottom => 'Bottom',
    ClothingCategory.accessory => 'Accessory',
  };
}

extension ClothingWarmthName on ClothingWarmth {
  String get label => switch (this) {
    ClothingWarmth.none => 'None',
    ClothingWarmth.light => 'Light',
    ClothingWarmth.medium => 'Medium',
    ClothingWarmth.heavy => 'Heavy',
  };
}

class ClosetItem {
  const ClosetItem({
    required this.id,
    required this.imagePath,
    required this.category,
    required this.warmth,
    required this.waterproof,
    this.name,
  });

  final String id;
  final String imagePath;
  final ClothingCategory category;
  final ClothingWarmth warmth;
  final bool waterproof;
  final String? name;

  ClosetItem copyWith({
    String? imagePath,
    ClothingCategory? category,
    ClothingWarmth? warmth,
    bool? waterproof,
    String? name,
  }) => ClosetItem(
    id: id,
    imagePath: imagePath ?? this.imagePath,
    category: category ?? this.category,
    warmth: warmth ?? this.warmth,
    waterproof: waterproof ?? this.waterproof,
    name: name ?? this.name,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'category': category.name,
    'warmth': warmth.name,
    'waterproof': waterproof,
    'name': name,
  };

  factory ClosetItem.fromJson(Map<String, dynamic> json) => ClosetItem(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String,
    category: ClothingCategory.values.byName(json['category'] as String),
    warmth: ClothingWarmth.values.byName(json['warmth'] as String),
    waterproof: json['waterproof'] as bool,
    name: json['name'] as String?,
  );
}
