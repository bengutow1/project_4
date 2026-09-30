import 'package:flutter/material.dart';

/// General weather advice, distinct from recommendations using closet photos.
class OutfitSummaryCard extends StatelessWidget {
  const OutfitSummaryCard({super.key, required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSummary = summary != null && summary!.trim().isNotEmpty;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checkroom_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Weather-based suggestion',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'General advice based on the forecast.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              hasSummary ? summary! : 'Outfit suggestion unavailable.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
