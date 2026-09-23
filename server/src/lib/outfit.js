// Rule-based outfit recommendation engine.
// Input: { tempF, precipitationProbability, windMph, isDay }
// Output: { summary, items: [{ label, category, warmth, waterproof }] }
//
// `category`, `warmth`, and `waterproof` are the matching contract the
// closet feature (Track B) uses to pick real photographed items out of a
// user's closet instead of just showing this generic text. Categories are
// one of: 'outerwear' | 'top' | 'bottom' | 'accessory'.
// Warmth is one of: 'none' | 'light' | 'medium' | 'heavy'.

function item(label, category, warmth, waterproof = false) {
  return { label, category, warmth, waterproof };
}

function suggestOutfit({ tempF, precipitationProbability = 0, windMph = 0, isDay = true }) {
  const items = [];

  if (tempF < 32) {
    items.push(
      item('heavy winter coat', 'outerwear', 'heavy'),
      item('gloves', 'accessory', 'heavy'),
      item('beanie', 'accessory', 'heavy'),
    );
  } else if (tempF < 45) {
    items.push(item('warm jacket', 'outerwear', 'medium'));
  } else if (tempF < 60) {
    items.push(item('light jacket or hoodie', 'outerwear', 'light'));
  } else if (tempF < 75) {
    items.push(item('t-shirt', 'top', 'none'), item('light layers', 'top', 'light'));
  } else {
    items.push(item('t-shirt', 'top', 'none'), item('shorts', 'bottom', 'none'));
  }

  if (precipitationProbability >= 50) {
    items.push(item('umbrella', 'accessory', 'none', true));
    if (tempF < 60) items.push(item('waterproof jacket', 'outerwear', 'medium', true));
  } else if (precipitationProbability >= 20) {
    items.push(item('umbrella (just in case)', 'accessory', 'none', true));
  }

  if (windMph >= 20) {
    items.push(item('windbreaker', 'outerwear', 'light'));
  }

  if (isDay && tempF >= 70 && precipitationProbability < 20) {
    items.push(item('sunglasses', 'accessory', 'none'));
  }

  const summary = `${Math.round(tempF)}°F${precipitationProbability >= 50 ? ' and rainy' : ''} → ${items.map((i) => i.label).join(', ')}`;

  return { summary, items };
}

module.exports = { suggestOutfit };
