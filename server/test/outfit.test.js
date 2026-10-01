const { suggestOutfit } = require('../src/lib/outfit');

const CATEGORIES = ['outerwear', 'top', 'bottom', 'accessory'];
const WARMTH = ['none', 'light', 'medium', 'heavy'];

function outfit(overrides) {
  return suggestOutfit({ tempF: 65, precipitationProbability: 0, windMph: 5, isDay: true, ...overrides });
}
const labels = (o) => o.items.map((i) => i.label);
const byCategory = (o, category) => o.items.filter((i) => i.category === category);

describe('C3 confirmation', () => {
  test('cold + rainy includes outerwear and a waterproof accessory', () => {
    const o = outfit({ tempF: 40, precipitationProbability: 80 });
    expect(byCategory(o, 'outerwear')).toHaveLength(1);
    expect(o.items.some((i) => i.category === 'accessory' && i.waterproof)).toBe(true);
  });

  test('hot + clear has no outerwear', () => {
    const o = outfit({ tempF: 88, precipitationProbability: 0, uvIndex: 9 });
    expect(byCategory(o, 'outerwear')).toHaveLength(0);
  });
});

describe('temperature bands', () => {
  test.each([
    [10, 'heavy winter coat', 'sweater or thermal top', 'lined or insulated pants'],
    [31.9, 'heavy winter coat', 'sweater or thermal top', 'lined or insulated pants'],
    [32, 'warm jacket', 'sweater', 'long pants'],
    [44.9, 'warm jacket', 'sweater', 'long pants'],
    [45, 'light jacket or hoodie', 'long-sleeve shirt', 'long pants'],
    [59.9, 'light jacket or hoodie', 'long-sleeve shirt', 'long pants'],
    [60, null, 't-shirt', 'jeans or light pants'],
    [74.9, null, 't-shirt', 'jeans or light pants'],
    [75, null, 't-shirt', 'shorts'],
    [100, null, 't-shirt', 'shorts'],
  ])('%s°F → %s / %s / %s', (tempF, jacket, top, bottom) => {
    const o = outfit({ tempF, isDay: false });
    expect(byCategory(o, 'outerwear').map((i) => i.label)).toEqual(jacket ? [jacket] : []);
    expect(byCategory(o, 'top')[0].label).toBe(top);
    expect(byCategory(o, 'bottom').map((i) => i.label)).toEqual([bottom]);
  });

  test('freezing adds heavy gloves and beanie, and everything is heavy', () => {
    const o = outfit({ tempF: 20, isDay: false });
    expect(labels(o)).toEqual(expect.arrayContaining(['gloves', 'beanie']));
    expect(o.items.every((i) => i.warmth === 'heavy')).toBe(true);
  });

  test('mild weather layers a light top over a t-shirt', () => {
    expect(byCategory(outfit({ tempF: 65 }), 'top').map((i) => i.label)).toEqual(['t-shirt', 'light layers']);
  });

  test('warmth never increases as it gets hotter', () => {
    const rank = (o) => Math.max(...o.items.map((i) => WARMTH.indexOf(i.warmth)));
    const ranks = [10, 40, 50, 65, 85].map((tempF) => rank(outfit({ tempF, isDay: false })));
    expect(ranks).toEqual([...ranks].sort((a, b) => b - a));
  });
});

describe('precipitation', () => {
  test.each([
    [0, []],
    [19, []],
    [20, ['umbrella (just in case)']],
    [49, ['umbrella (just in case)']],
    [50, ['umbrella']],
    [100, ['umbrella']],
  ])('%s%% chance → %j', (precipitationProbability, umbrellas) => {
    const o = outfit({ precipitationProbability, isDay: false });
    expect(labels(o).filter((l) => l.startsWith('umbrella'))).toEqual(umbrellas);
    expect(o.items.filter((i) => i.label.startsWith('umbrella')).every((i) => i.waterproof)).toBe(true);
  });

  test.each([
    [20, 'waterproof winter coat', 'heavy'],
    [40, 'waterproof warm jacket', 'medium'],
    [50, 'rain jacket', 'light'],
  ])('likely rain at %s°F swaps in a waterproof jacket of the same warmth', (tempF, label, warmth) => {
    const o = outfit({ tempF, precipitationProbability: 80 });
    expect(byCategory(o, 'outerwear')).toEqual([{ label, category: 'outerwear', warmth, waterproof: true }]);
  });

  test('possible rain keeps the regular jacket', () => {
    const [jacket] = byCategory(outfit({ tempF: 50, precipitationProbability: 30 }), 'outerwear');
    expect(jacket).toMatchObject({ label: 'light jacket or hoodie', waterproof: false });
  });

  test('warm rain adds an umbrella but no jacket', () => {
    const o = outfit({ tempF: 80, precipitationProbability: 90 });
    expect(byCategory(o, 'outerwear')).toHaveLength(0);
    expect(labels(o)).toContain('umbrella');
  });
});

describe('wind', () => {
  test.each([
    ['mild + windy adds a windbreaker', { tempF: 65, windMph: 20 }, ['windbreaker']],
    ['mild + breezy has no jacket', { tempF: 65, windMph: 19 }, []],
    ['hot + windy skips the windbreaker', { tempF: 85, windMph: 30 }, []],
    ['cold + windy keeps just the warm jacket', { tempF: 40, windMph: 30 }, ['warm jacket']],
    ['cool, wet and windy has just the rain jacket', { tempF: 50, windMph: 30, precipitationProbability: 80 }, ['rain jacket']],
  ])('%s', (_name, weather, jackets) => {
    expect(byCategory(outfit(weather), 'outerwear').map((i) => i.label)).toEqual(jackets);
  });
});

describe('sun', () => {
  test.each([
    ['UV 3 in daytime', { uvIndex: 3 }, ['sunglasses']],
    ['UV 2.9 in daytime', { uvIndex: 2.9 }, []],
    ['UV 8 in daytime', { uvIndex: 8 }, ['sunglasses', 'sun hat']],
    ['UV 7.9 in daytime', { uvIndex: 7.9 }, ['sunglasses']],
    ['high UV even when cool', { tempF: 50, uvIndex: 6 }, ['sunglasses']],
    ['high UV at night', { uvIndex: 9, isDay: false }, []],
    ['no UV data: warm and dry daytime', { tempF: 70 }, ['sunglasses']],
    ['no UV data: 69°F', { tempF: 69 }, []],
    ['no UV data: possible rain', { tempF: 80, precipitationProbability: 20 }, []],
    ['no UV data: night', { tempF: 80, isDay: false }, []],
  ])('%s', (_name, weather, expected) => {
    const o = outfit(weather);
    expect(labels(o).filter((l) => l === 'sunglasses' || l === 'sun hat')).toEqual(expected);
  });
});

describe('summary', () => {
  test('lists the temperature and every item in order', () => {
    expect(outfit({ tempF: 62.4, isDay: false }).summary).toBe('62°F → t-shirt, light layers, jeans or light pants');
  });

  test.each([
    [40, 80, '40°F and rainy'],
    [20, 80, '20°F and snowy'],
    [40, 49, '40°F →'],
  ])('%s°F with %s%% chance starts "%s"', (tempF, precipitationProbability, start) => {
    expect(outfit({ tempF, precipitationProbability }).summary.startsWith(start)).toBe(true);
  });

  test('defaults: missing precipitation, wind, daylight and UV are treated as calm, dry daytime', () => {
    expect(suggestOutfit({ tempF: 80 }).items.map((i) => i.label)).toEqual(['t-shirt', 'shorts', 'sunglasses']);
  });
});

describe('closet-matching contract (every combination)', () => {
  const temps = [-10, 20, 31.9, 32, 40, 45, 55, 60, 70, 75, 95];
  const rain = [0, 20, 50, 100];
  const wind = [0, 20, 40];
  const uv = [null, 0, 5, 10];
  const cases = [];
  for (const tempF of temps) for (const p of rain) for (const w of wind) for (const u of uv) {
    for (const isDay of [true, false]) cases.push({ tempF, precipitationProbability: p, windMph: w, uvIndex: u, isDay });
  }

  test.each(cases.map((c) => [JSON.stringify(c), c]))('%s', (_name, weather) => {
    const o = suggestOutfit(weather);
    for (const i of o.items) {
      expect(typeof i.label).toBe('string');
      expect(CATEGORIES).toContain(i.category);
      expect(WARMTH).toContain(i.warmth);
      expect(typeof i.waterproof).toBe('boolean');
    }
    expect(byCategory(o, 'top').length).toBeGreaterThanOrEqual(1);
    expect(byCategory(o, 'bottom')).toHaveLength(1);
    expect(byCategory(o, 'outerwear').length).toBeLessThanOrEqual(1);
    if (weather.tempF >= 75) expect(byCategory(o, 'outerwear')).toHaveLength(0);
    if (weather.tempF < 60) expect(byCategory(o, 'outerwear')).toHaveLength(1);
    if (weather.precipitationProbability >= 50) {
      expect(o.items.some((i) => i.category === 'accessory' && i.waterproof)).toBe(true);
    }
    // Items come out grouped: outerwear, tops, bottom, accessories.
    const order = o.items.map((i) => CATEGORIES.indexOf(i.category));
    expect(order).toEqual([...order].sort((a, b) => a - b));
    expect(new Set(labels(o)).size).toBe(o.items.length);
  });
});
