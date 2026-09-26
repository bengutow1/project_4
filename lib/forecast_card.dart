import 'package:flutter/material.dart';

import 'weather_service.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.forecast});

  final Forecast forecast;

  String _temperature(double? value) =>
      value == null ? 'Unavailable' : '${value.round()}°F';

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(forecast.name, style: Theme.of(context).textTheme.titleLarge),
          Text(
            _temperature(forecast.tempF),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          Text(forecast.condition),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('High: ${_temperature(forecast.highF)}'),
              Text('Low: ${_temperature(forecast.lowF)}'),
            ],
          ),
          const SizedBox(height: 8),
          Text('Wind: ${forecast.windMph.round()} mph'),
        ],
      ),
    ),
  );
}
