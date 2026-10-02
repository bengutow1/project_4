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

/// One recommended outfit piece from the server's outfit rules engine.
/// `category`/`warmth`/`waterproof` are the closet-matching contract
/// documented in server/README.md: category is one of
/// 'outerwear' | 'top' | 'bottom' | 'accessory', warmth is one of
/// 'none' | 'light' | 'medium' | 'heavy'.
class OutfitItem {
  const OutfitItem({
    required this.label,
    required this.category,
    required this.warmth,
    required this.waterproof,
  });
  final String label;
  final String category;
  final String warmth;
  final bool waterproof;

  factory OutfitItem.fromJson(Map<String, dynamic> json) => OutfitItem(
    label: json['label'] as String,
    category: json['category'] as String,
    warmth: json['warmth'] as String,
    waterproof: json['waterproof'] as bool,
  );
}

List<OutfitItem> _parseOutfitItems(Map<String, dynamic> json) {
  final items = (json['outfit'] as Map<String, dynamic>?)?['items'];
  if (items is! List) return const [];
  final parsed = <OutfitItem>[];
  for (final item in items) {
    try {
      parsed.add(OutfitItem.fromJson(item as Map<String, dynamic>));
    } catch (_) {
      // Skip malformed entries rather than failing the whole forecast.
    }
  }
  return parsed;
}

class Forecast {
  const Forecast({
    required this.name,
    required this.tempF,
    required this.windMph,
    this.condition = 'Condition unavailable',
    this.highF,
    this.lowF,
    this.outfitSummary,
    this.outfitItems = const [],
  });
  final String name;
  final double tempF;
  final double windMph;
  final String condition;
  final double? highF;
  final double? lowF;
  final String? outfitSummary;
  final List<OutfitItem> outfitItems;

  factory Forecast.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'] as Map<String, dynamic>;
    final location = json['location'] as Map<String, dynamic>;
    final forecast = Forecast(
      name: location['name'] as String? ?? 'Current location',
      tempF: (weather['tempF'] as num).toDouble(),
      windMph: (weather['windMph'] as num).toDouble(),
      condition: weather['condition'] as String? ?? 'Condition unavailable',
      highF: (weather['highF'] as num?)?.toDouble(),
      lowF: (weather['lowF'] as num?)?.toDouble(),
      outfitSummary:
          (json['outfit'] as Map<String, dynamic>?)?['summary'] as String?,
      outfitItems: _parseOutfitItems(json),
    );
    if (!forecast.tempF.isFinite ||
        !forecast.windMph.isFinite ||
        (forecast.highF != null && !forecast.highF!.isFinite) ||
        (forecast.lowF != null && !forecast.lowF!.isFinite)) {
      throw const FormatException('Non-finite weather value');
    }
    return forecast;
  }
}

class WeatherService {
  WeatherService({this.client, String? baseUrl})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://weather-outfit-server.onrender.com',
          );
  final http.Client? client;
  final String _baseUrl;
  Future<Forecast> fetch({String? city, Coordinates? coordinates}) async {
    final client = this.client ?? http.Client();
    try {
      final base = Uri.tryParse(_baseUrl.trim());
      if (base == null ||
          !base.hasAuthority ||
          base.host.isEmpty ||
          !['http', 'https'].contains(base.scheme) ||
          base.hasQuery ||
          base.hasFragment ||
          base.userInfo.isNotEmpty) {
        throw const WeatherFailure(
          'The weather server URL is invalid. Check API_BASE_URL.',
        );
      }
      if (coordinates == null && (city == null || city.trim().isEmpty)) {
        throw const WeatherFailure('Enter a city name to get weather.');
      }
      final uri = base.replace(
        path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/forecast',
        queryParameters: {
          if (coordinates != null) ...{
            'lat': '${coordinates.latitude}',
            'lon': '${coordinates.longitude}',
          } else
            'city': city!.trim(),
        },
      );
      final response = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        // Proxies may return HTML or an empty body on failure.
        Object? error;
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map<String, dynamic>) error = body['error'];
        } catch (_) {}
        if (error is String && error.startsWith('No location found')) {
          throw const WeatherFailure(
            'City not found. Check the spelling and try another city.',
          );
        }
        if (response.statusCode == 422 && error is String) {
          // Ambiguous city: the server explains which state or country to add.
          throw WeatherFailure(error);
        }
        if (response.statusCode == 504) {
          throw const WeatherFailure(
            'Weather request timed out. Please try again.',
          );
        }
        throw const WeatherFailure(
          'Weather is unavailable right now. Please try again.',
        );
      }
      try {
        return Forecast.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
        );
      } catch (_) {
        throw const WeatherFailure(
          'The weather server returned an invalid response. Please try again.',
        );
      }
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
