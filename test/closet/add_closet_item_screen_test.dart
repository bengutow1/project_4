import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_4/closet/add_closet_item_screen.dart';
import 'package:project_4/closet/closet_photo_picker.dart';

import 'in_memory_closet_store.dart';

class _FakePhotoPicker extends ClosetPhotoPicker {
  _FakePhotoPicker(this.fakePath);
  final String? fakePath;
  bool cameraCalled = false;
  bool galleryCalled = false;

  @override
  Future<XFile?> pickFromCamera() async {
    cameraCalled = true;
    return fakePath == null ? null : XFile(fakePath!);
  }

  @override
  Future<XFile?> pickFromGallery() async {
    galleryCalled = true;
    return fakePath == null ? null : XFile(fakePath!);
  }
}

void main() {
  const fakePhotoPath = '/fake/source.png';

  Future<void> useTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('B1 camera flow shows a preview before saving', (tester) async {
    await useTallSurface(tester);
    final picker = _FakePhotoPicker(fakePhotoPath);
    final store = InMemoryClosetStore();

    await tester.pumpWidget(
      MaterialApp(home: AddClosetItemScreen(store: store, photoPicker: picker)),
    );

    expect(find.text('Tap to add a photo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('closet-photo-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalled, isTrue);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Tap to add a photo'), findsNothing);

    await tester.tap(find.text('Save to closet'));
    await tester.pumpAndSettle();

    expect(store.items, hasLength(1));
    expect(store.items.single.imagePath, fakePhotoPath);
  });

  testWidgets('B1 gallery flow lets the user pick instead of using the camera', (tester) async {
    await useTallSurface(tester);
    final picker = _FakePhotoPicker(fakePhotoPath);
    final store = InMemoryClosetStore();

    await tester.pumpWidget(
      MaterialApp(home: AddClosetItemScreen(store: store, photoPicker: picker)),
    );

    await tester.tap(find.byKey(const Key('closet-photo-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(picker.galleryCalled, isTrue);
    expect(picker.cameraCalled, isFalse);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Save is disabled until a photo is chosen', (tester) async {
    await useTallSurface(tester);
    final picker = _FakePhotoPicker(null);
    final store = InMemoryClosetStore();

    await tester.pumpWidget(
      MaterialApp(home: AddClosetItemScreen(store: store, photoPicker: picker)),
    );

    final saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save to closet'));
    expect(saveButton.onPressed, isNull);
  });
}
