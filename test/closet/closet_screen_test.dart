import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_4/closet/closet_item.dart';
import 'package:project_4/closet/closet_photo_picker.dart';
import 'package:project_4/closet/closet_screen.dart';

import 'in_memory_closet_store.dart';

class _FakePhotoPicker extends ClosetPhotoPicker {
  _FakePhotoPicker(this.fakePath);
  final String fakePath;

  @override
  Future<XFile?> pickFromCamera() async => XFile(fakePath);

  @override
  Future<XFile?> pickFromGallery() async => XFile(fakePath);
}

void main() {
  Future<void> useTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<ClosetItem> seedItem(InMemoryClosetStore store, {String? name}) =>
      store.add(
        sourcePhotoPath: '/fake/seed.png',
        category: ClothingCategory.top,
        warmth: ClothingWarmth.light,
        waterproof: false,
        name: name,
      );

  testWidgets('B3 shows an empty state with no items', (tester) async {
    final store = InMemoryClosetStore();
    await tester.pumpWidget(MaterialApp(home: ClosetScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your closet is empty'), findsOneWidget);
  });

  testWidgets('B3 shows saved items with their photo and name', (tester) async {
    final store = InMemoryClosetStore();
    await seedItem(store, name: 'Blue tee');

    await tester.pumpWidget(MaterialApp(home: ClosetScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Blue tee'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('B3 deleting an item removes it from the grid and the store', (tester) async {
    final store = InMemoryClosetStore();
    final item = await seedItem(store, name: 'Blue tee');

    await tester.pumpWidget(MaterialApp(home: ClosetScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue tee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Blue tee'), findsNothing);
    expect(store.items.where((i) => i.id == item.id), isEmpty);
  });

  testWidgets('B3 editing an item updates its tags', (tester) async {
    final store = InMemoryClosetStore();
    await seedItem(store, name: 'Blue tee');

    await tester.pumpWidget(MaterialApp(home: ClosetScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue tee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name or color'), 'Renamed tee');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed tee'), findsOneWidget);
    expect(store.items.single.waterproof, isTrue);
  });

  testWidgets('B3 add button opens the add-item screen and refreshes on return', (tester) async {
    await useTallSurface(tester);
    final store = InMemoryClosetStore();
    final picker = _FakePhotoPicker('/fake/new.png');

    await tester.pumpWidget(
      MaterialApp(home: ClosetScreen(store: store, photoPicker: picker)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('closet-add-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add to Closet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('closet-photo-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<ClothingCategory>, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to closet'));
    await tester.pumpAndSettle();

    expect(find.text('My Closet'), findsOneWidget);
    expect(store.items, hasLength(1));
  });
}
