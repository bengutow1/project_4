import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'closet_item.dart';
import 'closet_store.dart';

/// Persists closet items (metadata as JSON, photos as files) to disk.
///
/// Pass [directory] explicitly to point at a custom location; for widget
/// tests, use an in-memory [ClosetStore] fake instead of this class, since
/// real file I/O deadlocks under flutter_test's fake-async clock.
class ClosetRepository implements ClosetStore {
  ClosetRepository({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;
  Directory? _resolvedDirectory;

  Future<Directory> _closetDir() async {
    if (_resolvedDirectory != null) return _resolvedDirectory!;
    final base =
        _directoryOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/closet');
    await dir.create(recursive: true);
    await Directory('${dir.path}/images').create(recursive: true);
    _resolvedDirectory = dir;
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _closetDir();
    return File('${dir.path}/items.json');
  }

  @override
  Future<List<ClosetItem>> loadAll() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ClosetItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<ClosetItem> items) async {
    final file = await _indexFile();
    await file.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Copies [sourcePhotoPath] into closet storage and saves a new item.
  @override
  Future<ClosetItem> add({
    required String sourcePhotoPath,
    required ClothingCategory category,
    required ClothingWarmth warmth,
    required bool waterproof,
    String? name,
  }) async {
    final dir = await _closetDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final extension = sourcePhotoPath.contains('.')
        ? sourcePhotoPath.split('.').last
        : 'jpg';
    final destPath = '${dir.path}/images/$id.$extension';
    await File(sourcePhotoPath).copy(destPath);

    final item = ClosetItem(
      id: id,
      imagePath: destPath,
      category: category,
      warmth: warmth,
      waterproof: waterproof,
      name: name,
    );
    final items = await loadAll();
    items.add(item);
    await _writeAll(items);
    return item;
  }

  @override
  Future<void> update(ClosetItem updated) async {
    final items = await loadAll();
    final index = items.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;
    items[index] = updated;
    await _writeAll(items);
  }

  @override
  Future<void> delete(String id) async {
    final items = await loadAll();
    final removed = items.where((e) => e.id == id).toList();
    items.removeWhere((e) => e.id == id);
    await _writeAll(items);
    for (final item in removed) {
      final file = File(item.imagePath);
      if (await file.exists()) await file.delete();
    }
  }
}
