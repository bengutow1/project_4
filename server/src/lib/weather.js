const GEOCODE_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';

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
    current: 'temperature_2m,precipitation_probability,wind_speed_10m,is_day',
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
    precipitationProbability: current.precipitation_probability ?? 0,
    windMph: current.wind_speed_10m,
    isDay: current.is_day === 1,
    time: current.time,
  };
}

module.exports = { geocodeCity, fetchWeather };
