import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_4/closet/closet_item.dart';
import 'package:project_4/closet/closet_repository.dart';

void main() {
  late Directory tempDir;
  late String sourcePhotoPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('closet_repo_test_');
    sourcePhotoPath = p.join(tempDir.path, 'source.png');
    await File(sourcePhotoPath).writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('add() copies the photo into closet storage and persists metadata', () async {
    final repo = ClosetRepository(directory: Directory(p.join(tempDir.path, 'store')));

    final item = await repo.add(
      sourcePhotoPath: sourcePhotoPath,
      category: ClothingCategory.outerwear,
      warmth: ClothingWarmth.medium,
      waterproof: true,
      name: 'Navy jacket',
    );

    expect(await File(item.imagePath).exists(), isTrue);
    expect(item.imagePath, isNot(sourcePhotoPath));

    final loaded = await repo.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Navy jacket');
    expect(loaded.single.category, ClothingCategory.outerwear);
  });

  test('items persist across repository instances (simulating app restart)', () async {
    final storeDir = Directory(p.join(tempDir.path, 'store'));
    final first = ClosetRepository(directory: storeDir);
    await first.add(
      sourcePhotoPath: sourcePhotoPath,
      category: ClothingCategory.top,
      warmth: ClothingWarmth.light,
      waterproof: false,
    );

    final second = ClosetRepository(directory: storeDir);
    final loaded = await second.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.category, ClothingCategory.top);
  });

  test('update() replaces the matching item', () async {
    final repo = ClosetRepository(directory: Directory(p.join(tempDir.path, 'store')));
    final item = await repo.add(
      sourcePhotoPath: sourcePhotoPath,
      category: ClothingCategory.bottom,
      warmth: ClothingWarmth.none,
      waterproof: false,
    );

    await repo.update(item.copyWith(name: 'Renamed', waterproof: true));

    final loaded = await repo.loadAll();
    expect(loaded.single.name, 'Renamed');
    expect(loaded.single.waterproof, isTrue);
  });

  test('delete() removes the item and its photo file', () async {
    final repo = ClosetRepository(directory: Directory(p.join(tempDir.path, 'store')));
    final item = await repo.add(
      sourcePhotoPath: sourcePhotoPath,
      category: ClothingCategory.accessory,
      warmth: ClothingWarmth.none,
      waterproof: false,
    );

    await repo.delete(item.id);

    expect(await repo.loadAll(), isEmpty);
    expect(await File(item.imagePath).exists(), isFalse);
  });
}
