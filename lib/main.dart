import 'package:flutter/material.dart';

import 'weather_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.weatherService, this.locationService});
  final WeatherService? weatherService;
  final LocationService? locationService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Weather + Outfit',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: WeatherHome(
      weather: weatherService ?? WeatherService(),
      location: locationService ?? LocationService(),
    ),
  );
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key, required this.weather, required this.location});
  final WeatherService weather;
  final LocationService location;
  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final _city = TextEditingController();
  bool _loading = false;
  String? _error;
  Forecast? _forecast;
  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool useGps = false}) async {
    if (_loading) return;
    final city = _city.text.trim();
    if (!useGps && city.isEmpty) {
      setState(() => _error = 'Enter a city name to get weather.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _forecast = null;
    });
    try {
      final coordinates = useGps ? await widget.location.current() : null;
      final forecast = await widget.weather.fetch(
        city: useGps ? null : city,
        coordinates: coordinates,
      );
      if (mounted) setState(() => _forecast = forecast);
    } on WeatherFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to get weather. Please try again or enter a city.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weather + Outfit')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Weather where you are',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Search for a city or use your device location.'),
              const SizedBox(height: 24),
              TextField(
                controller: _city,
                enabled: !_loading,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _fetch(),
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. Baton Rouge',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : () => _fetch(),
                child: const Text('Get Weather'),
              ),
              TextButton.icon(
                onPressed: _loading ? null : () => _fetch(useGps: true),
                icon: const Icon(Icons.my_location),
                label: const Text('Use my location'),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Getting weather',
                  ),
                ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_forecast case final forecast?)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          forecast.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${forecast.tempF.round()}°F',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        Text('Wind: ${forecast.windMph.round()} mph'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
