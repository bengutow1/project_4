import 'dart:io';

import 'package:flutter/material.dart';

import '../outfit_summary_card.dart';
import '../weather_service.dart';
import 'closet_store.dart';
import 'outfit_matcher.dart';

/// Shows today's outfit built from the user's own closet photos, matched
/// against the server's weather-based requirements. Falls back to the
/// plain-text [OutfitSummaryCard] when the closet has no matching item for
/// a slot, or when the server didn't return structured items at all.
class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key, required this.forecast, required this.store});

  final Forecast forecast;
  final ClosetStore store;

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  List<OutfitMatch>? _matches;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final closet = await widget.store.loadAll();
    final matches = matchOutfit(
      requirements: widget.forecast.outfitItems,
      closet: closet,
    );
    if (mounted) setState(() => _matches = matches);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return Scaffold(
      appBar: AppBar(title: const Text('What to Wear')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (matches == null)
                  const Center(child: CircularProgressIndicator())
                else if (matches.isEmpty)
                  OutfitSummaryCard(summary: widget.forecast.outfitSummary)
                else
                  ...[
                    for (final match in matches) _OutfitSlotCard(match: match),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutfitSlotCard extends StatelessWidget {
  const _OutfitSlotCard({required this.match});

  final OutfitMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closetItem = match.closetItem;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: closetItem == null
          ? ListTile(
              leading: const Icon(Icons.checkroom_outlined),
              title: Text(match.requirement.label),
              subtitle: const Text(
                "Not in your closet yet — here's the general suggestion.",
              ),
            )
          : Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Image.file(
                    File(closetItem.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          closetItem.name ?? match.requirement.label,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For: ${match.requirement.label}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
