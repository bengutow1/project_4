// Rule-based outfit recommendation engine.
// Input: { tempF, precipitationProbability, windMph, isDay }
// Output: { summary, items[] }

function suggestOutfit({ tempF, precipitationProbability = 0, windMph = 0, isDay = true }) {
  const items = [];

  if (tempF < 32) {
    items.push('heavy winter coat', 'gloves', 'beanie');
  } else if (tempF < 45) {
    items.push('warm jacket');
  } else if (tempF < 60) {
    items.push('light jacket or hoodie');
  } else if (tempF < 75) {
    items.push('t-shirt', 'light layers');
  } else {
    items.push('t-shirt', 'shorts');
  }

  if (precipitationProbability >= 50) {
    items.push('umbrella');
    if (tempF < 60) items.push('waterproof jacket');
  } else if (precipitationProbability >= 20) {
    items.push('umbrella (just in case)');
  }

  if (windMph >= 20) {
    items.push('windbreaker');
  }

  if (isDay && tempF >= 70 && precipitationProbability < 20) {
    items.push('sunglasses');
  }

  const summary = `${Math.round(tempF)}°F${precipitationProbability >= 50 ? ' and rainy' : ''} → ${items.join(', ')}`;

  return { summary, items };
}

module.exports = { suggestOutfit };
