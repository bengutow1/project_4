import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_4/main.dart';
import 'package:project_4/weather_service.dart';

class FakeLocation extends LocationService {
  bool denied = false;
  int calls = 0;
  @override
  Future<Coordinates> current() async {
    calls++;
    if (denied) {
      throw const WeatherFailure(
        'Location permission was denied. Enter a city instead.',
      );
    }
    return (latitude: 30.45, longitude: -91.18);
  }
}

void main() {
  late FakeLocation location;
  late List<Uri> requests;
  late WeatherService weather;
  setUp(() {
    location = FakeLocation();
    requests = [];
    weather = WeatherService(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.queryParameters['city'] == 'InvalidCity') {
          return http.Response(
            jsonEncode({'error': 'No location found for "InvalidCity"'}),
            502,
          );
        }
        return http.Response(
          jsonEncode({
            'location': {'name': request.url.queryParameters['city']},
            'weather': {'tempF': 72, 'windMph': 8},
          }),
          200,
        );
      }),
    );
  });

  testWidgets('launch has no automatic GPS or forecast request', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(weatherService: weather, locationService: location),
    );
    expect(location.calls, 0);
    expect(requests, isEmpty);
    expect(find.text('e.g. Baton Rouge'), findsOneWidget);
    await tester.tap(find.text('Get Weather'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a city name to get weather.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('denied GPS still allows city forecast', (tester) async {
    location.denied = true;
    await tester.pumpWidget(
      MyApp(weatherService: weather, locationService: location),
    );
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('permission was denied'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Baton Rouge  ');
    await tester.tap(find.text('Get Weather'));
    await tester.pumpAndSettle();
    expect(requests.single.queryParameters, {'city': 'Baton Rouge'});
    expect(find.text('72°F'), findsOneWidget);
    expect(find.textContaining('permission was denied'), findsNothing);
  });

  testWidgets('GPS fetches weather without city input', (tester) async {
    await tester.pumpWidget(
      MyApp(weatherService: weather, locationService: location),
    );
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(requests.single.queryParameters, {'lat': '30.45', 'lon': '-91.18'});
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('72°F'), findsOneWidget);
  });

  testWidgets('unknown city shows error and permits recovery', (tester) async {
    await tester.pumpWidget(
      MyApp(weatherService: weather, locationService: location),
    );
    await tester.enterText(find.byType(TextField), 'InvalidCity');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.text('City not found. Check the spelling and try another city.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Chicago');
    await tester.tap(find.text('Get Weather'));
    await tester.pumpAndSettle();
    expect(find.text('72°F'), findsOneWidget);
  });

  test('malformed response is a handled failure', () async {
    final service = WeatherService(
      client: MockClient((_) async => http.Response('<html>Error</html>', 502)),
    );
    await expectLater(
      service.fetch(city: 'Chicago'),
      throwsA(isA<WeatherFailure>()),
    );
  });
}
