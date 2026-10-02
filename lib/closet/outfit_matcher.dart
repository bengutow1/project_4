import '../weather_service.dart';
import 'closet_item.dart';

/// One slot of today's recommended outfit: the server's requirement, and
/// the best-matching closet item for it (null if nothing in the closet
/// matches, in which case the UI falls back to the plain-text label).
class OutfitMatch {
  const OutfitMatch({required this.requirement, this.closetItem});
  final OutfitItem requirement;
  final ClosetItem? closetItem;
}

const _warmthOrder = ['none', 'light', 'medium', 'heavy'];

int _warmthDistance(String a, String b) =>
    (_warmthOrder.indexOf(a) - _warmthOrder.indexOf(b)).abs();

/// Matches each of the server's outfit requirements to the closest item in
/// the closet of the same category, preferring an exact warmth match and a
/// matching waterproof flag when the requirement calls for one.
List<OutfitMatch> matchOutfit({
  required List<OutfitItem> requirements,
  required List<ClosetItem> closet,
}) {
  return requirements.map((requirement) {
    final candidates = closet
        .where((item) => item.category.name == requirement.category)
        .toList();

    if (candidates.isEmpty) return OutfitMatch(requirement: requirement);

    candidates.sort((a, b) {
      if (requirement.waterproof != a.waterproof ||
          requirement.waterproof != b.waterproof) {
        // Items matching the required waterproof flag sort first.
        final aMatches = a.waterproof == requirement.waterproof;
        final bMatches = b.waterproof == requirement.waterproof;
        if (aMatches != bMatches) return aMatches ? -1 : 1;
      }
      final aDistance = _warmthDistance(a.warmth.name, requirement.warmth);
      final bDistance = _warmthDistance(b.warmth.name, requirement.warmth);
      return aDistance.compareTo(bDistance);
    });

    return OutfitMatch(requirement: requirement, closetItem: candidates.first);
  }).toList();
}
