import 'package:image_picker/image_picker.dart';

/// Thin wrapper around [ImagePicker] so the add-item screen can be tested
/// without touching the real camera/gallery.
class ClosetPhotoPicker {
  ClosetPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<XFile?> pickFromCamera() =>
      _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);

  Future<XFile?> pickFromGallery() =>
      _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
}
