// Rule-based outfit recommendation engine.
// Input: { tempF, precipitationProbability, windMph, isDay, uvIndex }
// Output: { summary, items: [{ label, category, warmth, waterproof }] }
//
// `category`, `warmth`, and `waterproof` are the matching contract the
// closet feature (Track B) uses to pick real photographed items out of a
// user's closet instead of just showing this generic text. Categories are
// one of: 'outerwear' | 'top' | 'bottom' | 'accessory'.
// Warmth is one of: 'none' | 'light' | 'medium' | 'heavy'.
//
// Every outfit has at least one top and exactly one bottom, at most one
// outerwear item, and then accessories. Items are always in that order.
// The full rule table is in server/README.md.

const FREEZING_F = 32;
const COLD_F = 45;
const COOL_F = 60;
const HOT_F = 75;

const RAIN_LIKELY = 50; // % chance: dress for rain
const RAIN_POSSIBLE = 20; // % chance: bring an umbrella just in case
const WINDY_MPH = 20;
const UV_SUNGLASSES = 3; // WHO "moderate" UV
const UV_SUN_HAT = 8; // WHO "very high" UV

function item(label, category, warmth, waterproof = false) {
  return { label, category, warmth, waterproof };
}

// Base layers for each temperature band.
function baseLayers(tempF) {
  if (tempF < FREEZING_F) {
    return {
      outerwear: item('heavy winter coat', 'outerwear', 'heavy'),
      tops: [item('sweater or thermal top', 'top', 'heavy')],
      bottom: item('lined or insulated pants', 'bottom', 'heavy'),
      accessories: [item('gloves', 'accessory', 'heavy'), item('beanie', 'accessory', 'heavy')],
    };
  }
  if (tempF < COLD_F) {
    return {
      outerwear: item('warm jacket', 'outerwear', 'medium'),
      tops: [item('sweater', 'top', 'medium')],
      bottom: item('long pants', 'bottom', 'medium'),
      accessories: [],
    };
  }
  if (tempF < COOL_F) {
    return {
      outerwear: item('light jacket or hoodie', 'outerwear', 'light'),
      tops: [item('long-sleeve shirt', 'top', 'light')],
      bottom: item('long pants', 'bottom', 'light'),
      accessories: [],
    };
  }
  if (tempF < HOT_F) {
    return {
      outerwear: null,
      tops: [item('t-shirt', 'top', 'none'), item('light layers', 'top', 'light')],
      bottom: item('jeans or light pants', 'bottom', 'light'),
      accessories: [],
    };
  }
  return {
    outerwear: null,
    tops: [item('t-shirt', 'top', 'none')],
    bottom: item('shorts', 'bottom', 'none'),
    accessories: [],
  };
}

// Waterproof version of each jacket, keeping its warmth.
const WATERPROOF_OUTERWEAR = {
  heavy: 'waterproof winter coat',
  medium: 'waterproof warm jacket',
  light: 'rain jacket',
};

function needsSunglasses({ tempF, precipitationProbability, isDay, uvIndex }) {
  if (!isDay) return false;
  // UV already accounts for cloud cover; fall back to a warm-and-dry guess without it.
  if (typeof uvIndex === 'number') return uvIndex >= UV_SUNGLASSES;
  return tempF >= 70 && precipitationProbability < RAIN_POSSIBLE;
}

function suggestOutfit({
  tempF, precipitationProbability = 0, windMph = 0, isDay = true, uvIndex = null,
}) {
  const base = baseLayers(tempF);
  const { tops, bottom, accessories } = base;
  let { outerwear } = base;
  const rainLikely = precipitationProbability >= RAIN_LIKELY;

  if (rainLikely) {
    // Swap the jacket for a waterproof one instead of stacking a second jacket.
    if (outerwear) outerwear = item(WATERPROOF_OUTERWEAR[outerwear.warmth], 'outerwear', outerwear.warmth, true);
    accessories.push(item('umbrella', 'accessory', 'none', true));
  } else if (precipitationProbability >= RAIN_POSSIBLE) {
    accessories.push(item('umbrella (just in case)', 'accessory', 'none', true));
  }

  // Colder outfits already have a jacket, and a windbreaker in hot weather is too warm.
  if (windMph >= WINDY_MPH && !outerwear && tempF < HOT_F) {
    outerwear = item('windbreaker', 'outerwear', 'light');
  }

  if (needsSunglasses({ tempF, precipitationProbability, isDay, uvIndex })) {
    accessories.push(item('sunglasses', 'accessory', 'none'));
    if (typeof uvIndex === 'number' && uvIndex >= UV_SUN_HAT) {
      accessories.push(item('sun hat', 'accessory', 'none'));
    }
  }

  const items = [...(outerwear ? [outerwear] : []), ...tops, bottom, ...accessories];
  const wet = rainLikely ? ` and ${tempF < FREEZING_F ? 'snowy' : 'rainy'}` : '';
  const summary = `${Math.round(tempF)}°F${wet} → ${items.map((i) => i.label).join(', ')}`;

  return { summary, items };
}

module.exports = { suggestOutfit };
