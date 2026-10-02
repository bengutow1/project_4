import 'dart:io';

import 'package:flutter/material.dart';

import 'add_closet_item_screen.dart';
import 'closet_item.dart';
import 'closet_photo_picker.dart';
import 'closet_store.dart';

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key, required this.store, this.photoPicker});

  final ClosetStore store;
  final ClosetPhotoPicker? photoPicker;

  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  List<ClosetItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.store.loadAll();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _addItem() async {
    await Navigator.push<ClosetItem>(
      context,
      MaterialPageRoute(
        builder: (context) => AddClosetItemScreen(
          store: widget.store,
          photoPicker: widget.photoPicker,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openItem(ClosetItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      await widget.store.delete(item.id);
      await _load();
    } else if (action == 'edit') {
      await _editItem(item);
    }
  }

  Future<void> _editItem(ClosetItem item) async {
    var category = item.category;
    var warmth = item.warmth;
    var waterproof = item.waterproof;
    final nameController = TextEditingController(text: item.name ?? '');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit item',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name or color',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ClothingCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: ClothingCategory.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? category),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ClothingWarmth>(
                    initialValue: warmth,
                    decoration: const InputDecoration(labelText: 'Warmth'),
                    items: ClothingWarmth.values
                        .map(
                          (w) =>
                              DropdownMenuItem(value: w, child: Text(w.label)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => warmth = value ?? warmth),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Waterproof'),
                      Switch(
                        value: waterproof,
                        onChanged: (value) =>
                            setDialogState(() => waterproof = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldSave == true) {
      await widget.store.update(
        item.copyWith(
          category: category,
          warmth: warmth,
          waterproof: waterproof,
          name: nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Closet'),
      actions: [
        IconButton(
          key: const Key('closet-add-button'),
          onPressed: _addItem,
          icon: const Icon(Icons.add_a_photo_outlined),
          tooltip: 'Add to closet',
        ),
      ],
    ),
    body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Your closet is empty. Tap the camera icon to add your first item.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return GestureDetector(
                onTap: () => _openItem(item),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.file(
                          File(item.imagePath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          item.name ?? item.category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
