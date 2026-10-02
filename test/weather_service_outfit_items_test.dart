import 'package:flutter_test/flutter_test.dart';
import 'package:project_4/weather_service.dart';

void main() {
  Map<String, dynamic> response({List<dynamic>? items}) => {
    'location': {'name': 'Baton Rouge'},
    'weather': {'tempF': 52, 'windMph': 12},
    'outfit': {'summary': '52°F → rain jacket, umbrella', 'items': ?items},
  };

  test('parses structured outfit items from the response', () {
    final forecast = Forecast.fromJson(
      response(
        items: [
          {
            'label': 'rain jacket',
            'category': 'outerwear',
            'warmth': 'light',
            'waterproof': true,
          },
          {
            'label': 'umbrella',
            'category': 'accessory',
            'warmth': 'none',
            'waterproof': true,
          },
        ],
      ),
    );

    expect(forecast.outfitItems, hasLength(2));
    expect(forecast.outfitItems.first.label, 'rain jacket');
    expect(forecast.outfitItems.first.category, 'outerwear');
    expect(forecast.outfitItems.first.waterproof, isTrue);
  });

  test('defaults to an empty list when items are missing (older response)', () {
    final forecast = Forecast.fromJson(response());
    expect(forecast.outfitItems, isEmpty);
  });

  test('skips malformed entries instead of failing the whole parse', () {
    final forecast = Forecast.fromJson(
      response(
        items: [
          {'label': 'umbrella', 'category': 'accessory', 'warmth': 'none', 'waterproof': true},
          {'label': 'broken entry missing fields'},
        ],
      ),
    );

    expect(forecast.outfitItems, hasLength(1));
    expect(forecast.outfitItems.single.label, 'umbrella');
  });
}
