import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_4/main.dart';
import 'package:project_4/forecast_card.dart';
import 'package:project_4/outfit_summary_card.dart';
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
  testWidgets('A3 summary follows the forecast and changes with location', (
    tester,
  ) async {
    final pending = <Completer<http.Response>>[];
    final cities = <String?>[];
    final service = WeatherService(
      client: MockClient((request) {
        cities.add(request.url.queryParameters['city']);
        final response = Completer<http.Response>();
        pending.add(response);
        return response.future;
      }),
    );
    http.Response forecast(String city, String summary) => http.Response(
      jsonEncode({
        'location': {'name': city},
        'weather': {'tempF': 62, 'windMph': 8},
        'outfit': {'summary': summary, 'items': []},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    const first = '62°F and rainy → jacket, umbrella';
    const second = '80°F → t-shirt, shorts';
    await tester.pumpWidget(
      MyApp(weatherService: service, locationService: FakeLocation()),
    );
    expect(find.byType(OutfitSummaryCard), findsNothing);
    await tester.enterText(find.byType(TextField), 'Chicago');
    await tester.tap(find.text('Get Weather'));
    await tester.pump();
    pending[0].complete(forecast('Chicago', first));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(first),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(first), findsOneWidget);
    expect(find.text('Weather-based suggestion'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(OutfitSummaryCard)).dy,
      greaterThan(tester.getBottomLeft(find.byType(ForecastCard)).dy),
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Miami');
    await tester.tap(find.text('Get Weather'));
    await tester.pump();
    expect(find.byType(OutfitSummaryCard), findsNothing);
    pending[1].complete(forecast('Miami', second));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(second),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(cities, ['Chicago', 'Miami']);
    expect(find.text(second), findsOneWidget);
    expect(find.text(first), findsNothing);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'InvalidCity');
    await tester.tap(find.text('Get Weather'));
    await tester.pump();
    pending[2].complete(http.Response('{"error":"Unavailable"}', 502));
    await tester.pumpAndSettle();
    expect(find.byType(OutfitSummaryCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
            'weather': {
              'tempF': 72,
              'windMph': 8,
              'condition': 'Partly cloudy',
              'highF': 78,
              'lowF': 61,
            },
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

  testWidgets('forecast renders all A2 fields from response', (tester) async {
    await tester.pumpWidget(
      MyApp(weatherService: weather, locationService: location),
    );
    await tester.enterText(find.byType(TextField), 'Chicago');
    await tester.tap(find.text('Get Weather'));
    await tester.pumpAndSettle();
    for (final label in [
      '72°F',
      'Partly cloudy',
      'High: 78°F',
      'Low: 61°F',
      'Wind: 8 mph',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('loading clears stale forecast; failure retries original city', (
    tester,
  ) async {
    final pending = <Completer<http.Response>>[];
    final urls = <Uri>[];
    final service = WeatherService(
      client: MockClient((request) {
        urls.add(request.url);
        final response = Completer<http.Response>();
        pending.add(response);
        return response.future;
      }),
    );
    http.Response success(int temp) => http.Response(
      jsonEncode({
        'location': {'name': 'Chicago'},
        'weather': {
          'tempF': temp,
          'windMph': 10,
          'condition': 'Clear sky',
          'highF': 80,
          'lowF': 60,
        },
      }),
      200,
    );
    await tester.pumpWidget(
      MyApp(weatherService: service, locationService: location),
    );
    await tester.enterText(find.byType(TextField), 'Chicago');
    await tester.tap(find.text('Get Weather'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending[0].complete(success(72));
    await tester.pumpAndSettle();
    expect(find.text('72°F'), findsOneWidget);
    await tester.tap(find.text('Get Weather'));
    await tester.pump();
    expect(find.text('72°F'), findsNothing);
    expect(find.text('Clear sky'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending[1].complete(http.Response('{"error":"Unavailable"}', 502));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Boston');
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(urls.last.queryParameters, {'city': 'Chicago'});
    expect(find.text('Retry'), findsNothing);
    pending[2].complete(success(75));
    await tester.pumpAndSettle();
    expect(find.text('75°F'), findsOneWidget);
    expect(find.textContaining('unavailable right now'), findsNothing);
  });

  testWidgets('Retry repeats a failed GPS request', (tester) async {
    location.denied = true;
    await tester.pumpWidget(
      MyApp(weatherService: weather, locationService: location),
    );
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    location.denied = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(location.calls, 2);
    expect(requests.single.queryParameters, {'lat': '30.45', 'lon': '-91.18'});
    expect(find.text('72°F'), findsOneWidget);
  });

  testWidgets('older response shows unavailable optional fields', (
    tester,
  ) async {
    final service = WeatherService(
      client: MockClient(
        (_) async => http.Response(
          '{"location":{},"weather":{"tempF":32,"windMph":0}}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MyApp(weatherService: service, locationService: location),
    );
    await tester.enterText(find.byType(TextField), 'Chicago');
    await tester.tap(find.text('Get Weather'));
    await tester.pumpAndSettle();
    expect(find.text('Condition unavailable'), findsOneWidget);
    expect(find.text('High: Unavailable'), findsOneWidget);
    expect(find.text('Low: Unavailable'), findsOneWidget);
    expect(find.text('Wind: 0 mph'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(OutfitSummaryCard),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Outfit suggestion unavailable.'), findsOneWidget);
  });
}
