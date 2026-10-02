import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/closet/closet_item.dart';
import 'package:project_4/closet/outfit_matcher.dart';
import 'package:project_4/weather_service.dart';

ClosetItem _item(
  String id,
  ClothingCategory category,
  ClothingWarmth warmth, {
  bool waterproof = false,
}) => ClosetItem(
  id: id,
  imagePath: '/fake/$id.png',
  category: category,
  warmth: warmth,
  waterproof: waterproof,
);

void main() {
  test('matches a closet item with the exact same category, warmth and waterproof', () {
    final heavyCoat = _item('1', ClothingCategory.outerwear, ClothingWarmth.heavy, waterproof: true);
    final matches = matchOutfit(
      requirements: const [
        OutfitItem(label: 'waterproof winter coat', category: 'outerwear', warmth: 'heavy', waterproof: true),
      ],
      closet: [heavyCoat],
    );

    expect(matches.single.closetItem, heavyCoat);
  });

  test('falls back to null when no closet item matches the category', () {
    final matches = matchOutfit(
      requirements: const [
        OutfitItem(label: 'umbrella', category: 'accessory', warmth: 'none', waterproof: true),
      ],
      closet: [_item('1', ClothingCategory.top, ClothingWarmth.none)],
    );

    expect(matches.single.closetItem, isNull);
  });

  test('prefers the waterproof item when rain is required, even if warmth matches better elsewhere', () {
    final waterproofJacket = _item('1', ClothingCategory.outerwear, ClothingWarmth.light, waterproof: true);
    final exactWarmthButDry = _item('2', ClothingCategory.outerwear, ClothingWarmth.medium, waterproof: false);

    final matches = matchOutfit(
      requirements: const [
        OutfitItem(label: 'rain jacket', category: 'outerwear', warmth: 'medium', waterproof: true),
      ],
      closet: [exactWarmthButDry, waterproofJacket],
    );

    expect(matches.single.closetItem, waterproofJacket);
  });

  test('prefers the closest warmth among otherwise-equal candidates', () {
    final tooLight = _item('1', ClothingCategory.outerwear, ClothingWarmth.light);
    final exact = _item('2', ClothingCategory.outerwear, ClothingWarmth.medium);
    final tooHeavy = _item('3', ClothingCategory.outerwear, ClothingWarmth.heavy);

    final matches = matchOutfit(
      requirements: const [
        OutfitItem(label: 'warm jacket', category: 'outerwear', warmth: 'medium', waterproof: false),
      ],
      closet: [tooLight, tooHeavy, exact],
    );

    expect(matches.single.closetItem, exact);
  });

  test('matches each requirement independently across multiple items', () {
    final tee = _item('1', ClothingCategory.top, ClothingWarmth.none);
    final shorts = _item('2', ClothingCategory.bottom, ClothingWarmth.none);

    final matches = matchOutfit(
      requirements: const [
        OutfitItem(label: 't-shirt', category: 'top', warmth: 'none', waterproof: false),
        OutfitItem(label: 'shorts', category: 'bottom', warmth: 'none', waterproof: false),
      ],
      closet: [tee, shorts],
    );

    expect(matches[0].closetItem, tee);
    expect(matches[1].closetItem, shorts);
  });
}
