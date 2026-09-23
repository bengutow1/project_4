const { suggestOutfit } = require('../src/lib/outfit');

describe('suggestOutfit', () => {
  test('cold and rainy suggests jacket and umbrella', () => {
    const { items, summary } = suggestOutfit({ tempF: 45, precipitationProbability: 80, windMph: 5, isDay: true });
    expect(items.some((i) => i.category === 'accessory' && i.waterproof)).toBe(true);
    expect(items.some((i) => i.category === 'outerwear')).toBe(true);
    expect(summary).toMatch(/rainy/);
  });

  test('freezing weather suggests heavy winter gear', () => {
    const { items } = suggestOutfit({ tempF: 20, precipitationProbability: 0, windMph: 0, isDay: true });
    const labels = items.map((i) => i.label);
    expect(labels).toEqual(expect.arrayContaining(['heavy winter coat', 'gloves', 'beanie']));
    expect(items.every((i) => i.warmth === 'heavy')).toBe(true);
  });

  test('hot sunny day suggests t-shirt and sunglasses, no jacket', () => {
    const { items } = suggestOutfit({ tempF: 85, precipitationProbability: 0, windMph: 5, isDay: true });
    expect(items.some((i) => i.label === 't-shirt')).toBe(true);
    expect(items.some((i) => i.label === 'sunglasses')).toBe(true);
    expect(items.some((i) => i.category === 'outerwear')).toBe(false);
  });

  test('high wind suggests a windbreaker', () => {
    const { items } = suggestOutfit({ tempF: 65, precipitationProbability: 0, windMph: 25, isDay: true });
    expect(items.some((i) => i.label === 'windbreaker' && i.category === 'outerwear')).toBe(true);
  });

  test('every item exposes the closet-matching contract fields', () => {
    const { items } = suggestOutfit({ tempF: 50, precipitationProbability: 60, windMph: 10, isDay: true });
    for (const i of items) {
      expect(i).toHaveProperty('label');
      expect(['outerwear', 'top', 'bottom', 'accessory']).toContain(i.category);
      expect(['none', 'light', 'medium', 'heavy']).toContain(i.warmth);
      expect(typeof i.waterproof).toBe('boolean');
    }
  });
});
