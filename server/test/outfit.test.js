const { suggestOutfit } = require('../src/lib/outfit');

describe('suggestOutfit', () => {
  test('cold and rainy suggests jacket and umbrella', () => {
    const { items, summary } = suggestOutfit({ tempF: 45, precipitationProbability: 80, windMph: 5, isDay: true });
    expect(items).toContain('umbrella');
    expect(items.some((i) => i.includes('jacket'))).toBe(true);
    expect(summary).toMatch(/rainy/);
  });

  test('freezing weather suggests heavy winter gear', () => {
    const { items } = suggestOutfit({ tempF: 20, precipitationProbability: 0, windMph: 0, isDay: true });
    expect(items).toEqual(expect.arrayContaining(['heavy winter coat', 'gloves', 'beanie']));
  });

  test('hot sunny day suggests t-shirt and sunglasses, no jacket', () => {
    const { items } = suggestOutfit({ tempF: 85, precipitationProbability: 0, windMph: 5, isDay: true });
    expect(items).toContain('t-shirt');
    expect(items).toContain('sunglasses');
    expect(items.some((i) => i.includes('jacket'))).toBe(false);
  });

  test('high wind suggests windbreaker', () => {
    const { items } = suggestOutfit({ tempF: 65, precipitationProbability: 0, windMph: 25, isDay: true });
    expect(items).toContain('windbreaker');
  });
});
