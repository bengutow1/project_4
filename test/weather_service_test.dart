import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:project_4/weather_service.dart';

void main() {
  final payload = {
    'location': {'name': 'Montréal'},
    'weather': {
      'tempF': 62,
      'windMph': 12,
      'condition': 'Rain',
      'highF': 68,
      'lowF': 54,
    },
    'outfit': {'summary': '62°F → jacket, umbrella'},
  };
  for (final base in [
    'http://localhost:3000',
    'https://weather.example.com/',
    'https://weather.example.com/service/',
  ]) {
    test('fetches and decodes the same response using $base', () async {
      final service = WeatherService(
        baseUrl: base,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            '${base.replaceFirst(RegExp(r"/+$"), "")}/api/forecast?city=Baton+Rouge',
          );
          expect(request.headers['Accept'], 'application/json');
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final forecast = await service.fetch(city: ' Baton Rouge ');
      expect(forecast.name, 'Montréal');
      expect(forecast.tempF, 62);
      expect(forecast.windMph, 12);
      expect(forecast.highF, 68);
      expect(forecast.lowF, 54);
      expect(forecast.condition, 'Rain');
      expect(forecast.outfitSummary, '62°F → jacket, umbrella');
    });
  }
  test('connection failure surfaces a retryable WeatherFailure', () async {
    final service = WeatherService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      service.fetch(city: 'Chicago'),
      throwsA(
        isA<WeatherFailure>().having(
          (e) => e.message,
          'message',
          contains('Check your connection'),
        ),
      ),
    );
  });
  test('timeout surfaces a WeatherFailure', () async {
    final service = WeatherService(
      client: MockClient((_) async => throw TimeoutException('timeout')),
    );
    await expectLater(
      service.fetch(city: 'Chicago'),
      throwsA(
        isA<WeatherFailure>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
  for (final status in [502, 504]) {
    test('handles non-JSON HTTP $status', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('<html>Gateway error</html>', status),
        ),
      );
      await expectLater(
        service.fetch(city: 'Chicago'),
        throwsA(
          isA<WeatherFailure>().having(
            (e) => e.message,
            'message',
            contains(status == 504 ? 'timed out' : 'unavailable'),
          ),
        ),
      );
    });
  }
  test(
    'invalid success response is distinguished from connection failure',
    () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('{"weather":{}}', 200)),
      );
      await expectLater(
        service.fetch(city: 'Chicago'),
        throwsA(
          isA<WeatherFailure>().having(
            (e) => e.message,
            'message',
            contains('invalid response'),
          ),
        ),
      );
    },
  );
  test('invalid base URL does not send a request', () async {
    final service = WeatherService(
      baseUrl: 'localhost:3000',
      client: MockClient((_) async => fail('Unexpected request')),
    );
    await expectLater(
      service.fetch(city: 'Chicago'),
      throwsA(
        isA<WeatherFailure>().having(
          (e) => e.message,
          'message',
          contains('API_BASE_URL'),
        ),
      ),
    );
  });
}
