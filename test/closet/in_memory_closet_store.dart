import 'package:project_4/closet/closet_item.dart';
import 'package:project_4/closet/closet_store.dart';

/// Pure-Dart, no-I/O fake of [ClosetStore] for widget tests. Avoids the
/// real-file-I/O deadlock that happens when a widget test exercises
/// flutter_test's fake-async clock against genuine dart:io calls.
class InMemoryClosetStore implements ClosetStore {
  final List<ClosetItem> items = [];
  int _nextId = 0;

  @override
  Future<List<ClosetItem>> loadAll() async => List.unmodifiable(items);

  @override
  Future<ClosetItem> add({
    required String sourcePhotoPath,
    required ClothingCategory category,
    required ClothingWarmth warmth,
    required bool waterproof,
    String? name,
  }) async {
    final item = ClosetItem(
      id: '${_nextId++}',
      imagePath: sourcePhotoPath,
      category: category,
      warmth: warmth,
      waterproof: waterproof,
      name: name,
    );
    items.add(item);
    return item;
  }

  @override
  Future<void> update(ClosetItem updated) async {
    final index = items.indexWhere((e) => e.id == updated.id);
    if (index != -1) items[index] = updated;
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((e) => e.id == id);
  }
}
