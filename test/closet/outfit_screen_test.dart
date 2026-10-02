import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/closet/closet_item.dart';
import 'package:project_4/closet/outfit_screen.dart';
import 'package:project_4/weather_service.dart';

import 'in_memory_closet_store.dart';

void main() {
  Forecast forecastWith(List<OutfitItem> items) => Forecast(
    name: 'Baton Rouge',
    tempF: 52,
    windMph: 10,
    outfitSummary: '52°F → rain jacket, umbrella',
    outfitItems: items,
  );

  testWidgets('shows the closet photo when a matching item exists', (tester) async {
    final store = InMemoryClosetStore();
    await store.add(
      sourcePhotoPath: '/fake/jacket.png',
      category: ClothingCategory.outerwear,
      warmth: ClothingWarmth.light,
      waterproof: true,
      name: 'Navy rain jacket',
    );

    final forecast = forecastWith(const [
      OutfitItem(label: 'rain jacket', category: 'outerwear', warmth: 'light', waterproof: true),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: OutfitScreen(forecast: forecast, store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Navy rain jacket'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('falls back to the requirement label when nothing in the closet matches', (tester) async {
    final store = InMemoryClosetStore();
    final forecast = forecastWith(const [
      OutfitItem(label: 'umbrella', category: 'accessory', warmth: 'none', waterproof: true),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: OutfitScreen(forecast: forecast, store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('umbrella'), findsOneWidget);
    expect(find.textContaining('general suggestion'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('falls back to the plain-text summary when there are no structured items', (tester) async {
    final store = InMemoryClosetStore();
    final forecast = forecastWith(const []);

    await tester.pumpWidget(
      MaterialApp(home: OutfitScreen(forecast: forecast, store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('52°F → rain jacket, umbrella'), findsOneWidget);
  });
}
