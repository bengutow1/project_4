import 'closet_item.dart';

/// Storage contract for closet items. [ClosetRepository] is the real,
/// file-backed implementation; widget tests use an in-memory fake instead,
/// since real file I/O deadlocks under flutter_test's fake-async clock.
abstract class ClosetStore {
  Future<List<ClosetItem>> loadAll();

  Future<ClosetItem> add({
    required String sourcePhotoPath,
    required ClothingCategory category,
    required ClothingWarmth warmth,
    required bool waterproof,
    String? name,
  });

  Future<void> update(ClosetItem updated);

  Future<void> delete(String id);
}
