import 'dart:io';

import 'package:flutter/material.dart';

import 'closet_item.dart';
import 'closet_photo_picker.dart';
import 'closet_store.dart';

class AddClosetItemScreen extends StatefulWidget {
  const AddClosetItemScreen({
    super.key,
    required this.store,
    this.photoPicker,
  });

  final ClosetStore store;
  final ClosetPhotoPicker? photoPicker;

  @override
  State<AddClosetItemScreen> createState() => _AddClosetItemScreenState();
}

class _AddClosetItemScreenState extends State<AddClosetItemScreen> {
  late final ClosetPhotoPicker _picker = widget.photoPicker ?? ClosetPhotoPicker();
  final _name = TextEditingController();
  String? _photoPath;
  ClothingCategory? _category;
  ClothingWarmth _warmth = ClothingWarmth.none;
  bool _waterproof = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = source == 'camera'
        ? await _picker.pickFromCamera()
        : await _picker.pickFromGallery();
    if (file != null && mounted) setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    final category = _category;
    if (_photoPath == null || category == null || _saving) return;
    setState(() => _saving = true);
    try {
      final item = await widget.store.add(
        sourcePhotoPath: _photoPath!,
        category: category,
        warmth: _warmth,
        waterproof: _waterproof,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) Navigator.pop(context, item);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add to Closet')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GestureDetector(
            key: const Key('closet-photo-picker'),
            onTap: _choosePhoto,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _photoPath == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 40),
                            SizedBox(height: 8),
                            Text('Tap to add a photo'),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_photoPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name or color (optional)',
              hintText: 'e.g. Navy rain jacket',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ClothingCategory>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'Required',
              border: OutlineInputBorder(),
            ),
            items: ClothingCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ClothingWarmth>(
            initialValue: _warmth,
            decoration: const InputDecoration(
              labelText: 'Warmth',
              border: OutlineInputBorder(),
            ),
            items: ClothingWarmth.values
                .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))
                .toList(),
            onChanged: (value) => setState(() => _warmth = value ?? _warmth),
          ),
          SwitchListTile(
            value: _waterproof,
            onChanged: (value) => setState(() => _waterproof = value),
            title: const Text('Waterproof'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _photoPath == null || _category == null || _saving
                ? null
                : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save to closet'),
          ),
        ],
      ),
    ),
  );
}
