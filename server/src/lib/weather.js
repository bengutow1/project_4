const GEOCODE_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';

// WMO weather codes from https://open-meteo.com/en/docs.
function conditionForCode(code) {
  const conditions = {
    0: 'Clear sky', 1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
    45: 'Fog', 48: 'Depositing rime fog',
    51: 'Light drizzle', 53: 'Moderate drizzle', 55: 'Dense drizzle',
    56: 'Light freezing drizzle', 57: 'Dense freezing drizzle',
    61: 'Slight rain', 63: 'Moderate rain', 65: 'Heavy rain',
    66: 'Light freezing rain', 67: 'Heavy freezing rain',
    71: 'Slight snow', 73: 'Moderate snow', 75: 'Heavy snow', 77: 'Snow grains',
    80: 'Slight rain showers', 81: 'Moderate rain showers', 82: 'Violent rain showers',
    85: 'Slight snow showers', 86: 'Heavy snow showers',
    95: 'Thunderstorm', 96: 'Thunderstorm with slight hail', 99: 'Thunderstorm with heavy hail',
  };
  return conditions[code] ?? 'Condition unavailable';
}

async function geocodeCity(city) {
  const url = `${GEOCODE_URL}?name=${encodeURIComponent(city)}&count=1&language=en&format=json`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Geocoding request failed: ${res.status}`);
  const data = await res.json();
  const result = data.results && data.results[0];
  if (!result) throw new Error(`No location found for "${city}"`);
  return { lat: result.latitude, lon: result.longitude, name: result.name, country: result.country };
}

async function fetchWeather({ lat, lon }) {
  const params = new URLSearchParams({
    latitude: lat,
    longitude: lon,
    current: 'temperature_2m,precipitation_probability,wind_speed_10m,is_day,weather_code',
    daily: 'temperature_2m_max,temperature_2m_min',
    forecast_days: 1,
    temperature_unit: 'fahrenheit',
    wind_speed_unit: 'mph',
    timezone: 'auto',
  });
  const res = await fetch(`${FORECAST_URL}?${params.toString()}`);
  if (!res.ok) throw new Error(`Forecast request failed: ${res.status}`);
  const data = await res.json();
  const current = data.current;
  return {
    tempF: current.temperature_2m,
    condition: conditionForCode(current.weather_code),
    highF: data.daily?.temperature_2m_max?.[0] ?? null,
    lowF: data.daily?.temperature_2m_min?.[0] ?? null,
    precipitationProbability: current.precipitation_probability ?? 0,
    windMph: current.wind_speed_10m,
    isDay: current.is_day === 1,
    time: current.time,
  };
}

module.exports = { geocodeCity, fetchWeather };
