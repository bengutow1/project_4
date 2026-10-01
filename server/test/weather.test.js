const {
  fetchWeather, geocodeCity, LocationNotFoundError, AmbiguousLocationError,
} = require('../src/lib/weather');

describe('forecast display fields', () => {
  afterEach(() => jest.restoreAllMocks());

  test.each([
    [0, 'Clear sky'], [2, 'Partly cloudy'], [63, 'Moderate rain'],
    [75, 'Heavy snow'], [95, 'Thunderstorm'], [999, 'Condition unavailable'],
  ])('maps weather code %s and daily extremes', async (code, condition) => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({
        current: { temperature_2m: 62, wind_speed_10m: 12, weather_code: code },
        daily: { temperature_2m_max: [68], temperature_2m_min: [54] },
      }),
    });
    const weather = await fetchWeather({ lat: 30, lon: -91 });
    expect(weather).toMatchObject({ tempF: 62, windMph: 12, condition, highF: 68, lowF: 54 });
    const params = new URL(fetchMock.mock.calls[0][0]).searchParams;
    expect(params.get('current')).toContain('weather_code');
    expect(params.get('daily')).toBe('temperature_2m_max,temperature_2m_min');
    expect(params.get('temperature_unit')).toBe('fahrenheit');
    expect(params.get('timezone')).toBe('auto');
  });

  test('requests and returns the UV index for the outfit rules', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true, json: async () => ({ current: { temperature_2m: 80, wind_speed_10m: 3, uv_index: 7.4 } }),
    });
    expect(await fetchWeather({ lat: 30, lon: -91 })).toMatchObject({ uvIndex: 7.4 });
    expect(new URL(fetchMock.mock.calls[0][0]).searchParams.get('current')).toContain('uv_index');
  });

  test('missing UV index is null, so the outfit rules use their fallback', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true, json: async () => ({ current: { temperature_2m: 80, wind_speed_10m: 3 } }),
    });
    expect(await fetchWeather({ lat: 30, lon: -91 })).toMatchObject({ uvIndex: null });
  });

  test('missing daily data stays unavailable', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true, json: async () => ({ current: { temperature_2m: 32, wind_speed_10m: 0 } }),
    });
    expect(await fetchWeather({ lat: 30, lon: -91 })).toMatchObject({
      condition: 'Condition unavailable', highF: null, lowF: null,
    });
  });
});

// ---- C2: common, ambiguous and unknown city names ----
function place(name, admin1, country, country_code, latitude, longitude, population, feature_code = 'PPLA2') {
  return { name, admin1, country, country_code, latitude, longitude, population, feature_code };
}
const PARIS_FR = place('Paris', 'Île-de-France', 'France', 'FR', 48.85341, 2.3488, 2138551, 'PPLC');
const PARIS_TX = place('Paris', 'Texas', 'United States', 'US', 33.66094, -95.55551, 24171, 'PPLA2');
const PARIS_TN = place('Paris', 'Tennessee', 'United States', 'US', 36.302, -88.32671, 10156, 'PPLA2');
const SPRINGFIELD_MO = place('Springfield', 'Missouri', 'United States', 'US', 37.21533, -93.29824, 169176);
const SPRINGFIELD_MA = place('Springfield', 'Massachusetts', 'United States', 'US', 42.10148, -72.58981, 155929);
const SPRINGFIELD_IL = place('Springfield', 'Illinois', 'United States', 'US', 39.80172, -89.64371, 116250, 'PPLA');
const BATON_ROUGE = place('Baton Rouge', 'Louisiana', 'United States', 'US', 30.45075, -91.15455, 227470, 'PPLA');

function geocodeReturns(results) {
  return jest.spyOn(global, 'fetch').mockResolvedValueOnce({
    ok: true, status: 200, json: async () => (results ? { results } : {}),
  });
}

describe('geocodeCity — C2', () => {
  afterEach(() => jest.restoreAllMocks());

  test('common city returns the expected coordinates', async () => {
    geocodeReturns([BATON_ROUGE]);
    await expect(geocodeCity('Baton Rouge')).resolves.toEqual({
      name: 'Baton Rouge', region: 'Louisiana', country: 'United States', lat: 30.45075, lon: -91.15455,
    });
  });

  test('asks Open-Meteo for several candidates, using only the city part', async () => {
    const spy = geocodeReturns([PARIS_TX]);
    await geocodeCity('Paris, TX');
    const url = new URL(spy.mock.calls[0][0]);
    expect(url.searchParams.get('name')).toBe('Paris');
    expect(url.searchParams.get('count')).toBe('10');
  });

  test('a much bigger city wins over small namesakes', async () => {
    geocodeReturns([PARIS_FR, PARIS_TX, PARIS_TN]);
    await expect(geocodeCity('Paris')).resolves.toMatchObject({ country: 'France', lat: 48.85341 });
  });

  test.each([
    ['state abbreviation', 'Paris, TX'],
    ['state name', 'paris, texas'],
    ['state and country', 'Paris, Texas, USA'],
  ])('qualifier picks the right place (%s)', async (_label, input) => {
    geocodeReturns([PARIS_FR, PARIS_TX, PARIS_TN]);
    await expect(geocodeCity(input)).resolves.toMatchObject({ region: 'Texas', lat: 33.66094 });
  });

  test('country code qualifier works', async () => {
    geocodeReturns([PARIS_FR, PARIS_TX]);
    await expect(geocodeCity('Paris, FR')).resolves.toMatchObject({ country: 'France' });
  });

  test('similar-sized namesakes are ambiguous and list candidates', async () => {
    geocodeReturns([SPRINGFIELD_MO, SPRINGFIELD_MA, SPRINGFIELD_IL]);
    const err = await geocodeCity('Springfield').catch((e) => e);
    expect(err).toBeInstanceOf(AmbiguousLocationError);
    expect(err.status).toBe(422);
    expect(err.message).toMatch(/"Springfield" matches several places/);
    expect(err.message).toMatch(/Springfield, Missouri, United States/);
    expect(err.message).toMatch(/Add a state or country, e\.g\. "Springfield, Missouri"/);
    expect(err.candidates).toHaveLength(3);
    expect(err.candidates[0]).toEqual({
      name: 'Springfield', region: 'Missouri', country: 'United States', lat: 37.21533, lon: -93.29824,
    });
  });

  test('qualifier resolves an ambiguous name', async () => {
    geocodeReturns([SPRINGFIELD_MO, SPRINGFIELD_MA, SPRINGFIELD_IL]);
    await expect(geocodeCity('Springfield, IL')).resolves.toMatchObject({ region: 'Illinois' });
  });

  test('results with no population data are ambiguous rather than guessed', async () => {
    geocodeReturns([
      place('Riverside', 'Utopia', 'Nowhere', 'NW', 10, 10, undefined),
      place('Riverside', 'Elsewhere', 'Nowhere', 'NW', 20, 20, undefined),
    ]);
    await expect(geocodeCity('Riverside')).rejects.toBeInstanceOf(AmbiguousLocationError);
  });

  test('duplicate entries for the same place are not treated as ambiguous', async () => {
    const district = { ...PARIS_FR, feature_code: 'PPLX', latitude: 48.86, longitude: 2.35, population: 2100000 };
    geocodeReturns([PARIS_FR, district]);
    await expect(geocodeCity('Paris')).resolves.toMatchObject({ country: 'France' });
  });

  test('prefers a city over a region with the same name', async () => {
    const region = place('New York', 'New York', 'United States', 'US', 43, -75, 19000000, 'ADM1');
    const city = place('New York', 'New York', 'United States', 'US', 40.71427, -74.00597, 8804190, 'PPL');
    geocodeReturns([region, city]);
    await expect(geocodeCity('New York')).resolves.toMatchObject({ lat: 40.71427 });
  });

  test('matching ignores accents, case and periods', async () => {
    geocodeReturns([place('São Paulo', 'São Paulo', 'Brazil', 'BR', -23.5475, -46.63611, 10021295, 'PPLA')]);
    await expect(geocodeCity('sao paulo')).resolves.toMatchObject({ name: 'São Paulo' });
    geocodeReturns([place('St. Louis', 'Missouri', 'United States', 'US', 38.62727, -90.19789, 301578, 'PPLA2')]);
    await expect(geocodeCity('St Louis')).resolves.toMatchObject({ region: 'Missouri' });
  });

  test('unknown city is a not-found error', async () => {
    geocodeReturns(undefined);
    const err = await geocodeCity('Notarealplace').catch((e) => e);
    expect(err).toBeInstanceOf(LocationNotFoundError);
    expect(err.status).toBe(404);
    expect(err.message).toBe('No location found for "Notarealplace".');
  });

  test('prefix-only matches are not accepted, but are suggested', async () => {
    geocodeReturns([place('London', 'England', 'United Kingdom', 'GB', 51.50853, -0.12574, 8961989, 'PPLC')]);
    const err = await geocodeCity('Londo').catch((e) => e);
    expect(err).toBeInstanceOf(LocationNotFoundError);
    expect(err.message).toBe('No location found for "Londo". Did you mean London, England, United Kingdom?');
  });

  test('qualifier that matches nothing is not-found, with suggestions', async () => {
    geocodeReturns([PARIS_FR, PARIS_TX]);
    const err = await geocodeCity('Paris, Narnia').catch((e) => e);
    expect(err).toBeInstanceOf(LocationNotFoundError);
    expect(err.message).toMatch(/^No location found for "Paris, Narnia"\. Did you mean Paris, Île-de-France, France or Paris, Texas/);
  });

  test('input that is only commas is not-found without calling Open-Meteo', async () => {
    const spy = jest.spyOn(global, 'fetch');
    await expect(geocodeCity(' , ')).rejects.toBeInstanceOf(LocationNotFoundError);
    expect(spy).not.toHaveBeenCalled();
  });
});
