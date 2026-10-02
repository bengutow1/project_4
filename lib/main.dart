import 'package:flutter/material.dart';

import 'closet/closet_repository.dart';
import 'closet/closet_screen.dart';
import 'closet/closet_store.dart';
import 'closet/outfit_screen.dart';
import 'weather_service.dart';
import 'forecast_card.dart';
import 'outfit_summary_card.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.weatherService,
    this.locationService,
    this.closetStore,
  });
  final WeatherService? weatherService;
  final LocationService? locationService;
  final ClosetStore? closetStore;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Weather + Outfit',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
    ),
    themeMode: ThemeMode.system,
    home: WeatherHome(
      weather: weatherService ?? WeatherService(),
      location: locationService ?? LocationService(),
      closet: closetStore ?? ClosetRepository(),
    ),
  );
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({
    super.key,
    required this.weather,
    required this.location,
    required this.closet,
  });
  final WeatherService weather;
  final LocationService location;
  final ClosetStore closet;
  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final _city = TextEditingController();
  bool _loading = false;
  String? _error;
  Forecast? _forecast;
  bool _lastUseGps = false;
  String? _lastCity;
  Future<void> _refresh() async {
    if (_lastCity == null && !_lastUseGps) return;
    await _fetch(useGps: _lastUseGps, retryCity: _lastCity);
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool useGps = false, String? retryCity}) async {
    if (_loading) return;
    final city = retryCity ?? _city.text.trim();
    if (!useGps && city.isEmpty) {
      setState(() {
        _error = 'Enter a city name to get weather.';
        _forecast = null;
        _lastCity = null;
        _lastUseGps = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _forecast = null;
      _lastCity = city;
      _lastUseGps = useGps;
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
    appBar: AppBar(
      title: const Text('Weather + Outfit'),
      actions: [
        IconButton(
          key: const Key('open-closet-button'),
          tooltip: 'My Closet',
          icon: const Icon(Icons.checkroom_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClosetScreen(store: widget.closet),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                if (!_loading && _error == null && _forecast == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.wb_sunny_outlined, size: 40),
                          SizedBox(height: 12),
                          Text('No forecast yet'),
                          SizedBox(height: 8),
                          Text(
                            'Search for a city or use your location to see weather and what to wear.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                if (_error != null && (_lastCity != null || _lastUseGps))
                  TextButton.icon(
                    onPressed: () =>
                        _fetch(useGps: _lastUseGps, retryCity: _lastCity),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                if (!_loading && _error == null && _forecast != null) ...[
                  ForecastCard(forecast: _forecast!),
                  const SizedBox(height: 12),
                  OutfitSummaryCard(summary: _forecast!.outfitSummary),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    key: const Key('open-outfit-button'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OutfitScreen(
                          forecast: _forecast!,
                          store: widget.closet,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.checkroom_outlined),
                    label: const Text('What should I wear?'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pull down to refresh.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
