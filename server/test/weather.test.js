const { fetchWeather } = require('../src/lib/weather');

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

  test('missing daily data stays unavailable', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true, json: async () => ({ current: { temperature_2m: 32, wind_speed_10m: 0 } }),
    });
    expect(await fetchWeather({ lat: 30, lon: -91 })).toMatchObject({
      condition: 'Condition unavailable', highF: null, lowF: null,
    });
  });
});
