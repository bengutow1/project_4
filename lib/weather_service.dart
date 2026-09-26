import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherFailure implements Exception {
  const WeatherFailure(this.message);
  final String message;
}

typedef Coordinates = ({double latitude, double longitude});

class Forecast {
  const Forecast({
    required this.name,
    required this.tempF,
    required this.windMph,
    this.condition = 'Condition unavailable',
    this.highF,
    this.lowF,
  });
  final String name;
  final double tempF;
  final double windMph;
  final String condition;
  final double? highF;
  final double? lowF;
}

class WeatherService {
  WeatherService({this.client, String? baseUrl})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          );
  final http.Client? client;
  final String _baseUrl;
  Future<Forecast> fetch({String? city, Coordinates? coordinates}) async {
    final client = this.client ?? http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/forecast').replace(
        queryParameters: {
          if (coordinates != null) ...{
            'lat': '${coordinates.latitude}',
            'lon': '${coordinates.longitude}',
          } else
            'city': city!,
        },
      );
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final error = body['error'];
        if (error is String && error.startsWith('No location found')) {
          throw const WeatherFailure(
            'City not found. Check the spelling and try another city.',
          );
        }
        throw const WeatherFailure(
          'Weather is unavailable right now. Please try again.',
        );
      }
      final weather = body['weather'] as Map<String, dynamic>;
      final location = body['location'] as Map<String, dynamic>;
      return Forecast(
        name: location['name'] as String? ?? 'Current location',
        tempF: (weather['tempF'] as num).toDouble(),
        windMph: (weather['windMph'] as num).toDouble(),
        condition: weather['condition'] as String? ?? 'Condition unavailable',
        highF: (weather['highF'] as num?)?.toDouble(),
        lowF: (weather['lowF'] as num?)?.toDouble(),
      );
    } on WeatherFailure {
      rethrow;
    } on TimeoutException {
      throw const WeatherFailure(
        'Weather request timed out. Please try again.',
      );
    } catch (_) {
      throw const WeatherFailure(
        'Unable to load weather. Check your connection and try again.',
      );
    } finally {
      if (this.client == null) client.close();
    }
  }
}

class LocationService {
  Future<Coordinates> current() async {
    try {
      if (!kIsWeb) {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const WeatherFailure(
            'Location services are off. Turn them on or enter a city instead.',
          );
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          throw const WeatherFailure(
            'Location permission is blocked. Enable it in device settings or enter a city instead.',
          );
        }
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          throw const WeatherFailure(
            'Location permission was denied. Enter a city instead.',
          );
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on WeatherFailure {
      rethrow;
    } on PermissionDeniedException {
      throw const WeatherFailure(
        'Location permission was denied. Enter a city instead.',
      );
    } catch (_) {
      throw const WeatherFailure(
        'Unable to get your location. Enter a city or try again.',
      );
    }
  }
}
