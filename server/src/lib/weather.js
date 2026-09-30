const GEOCODE_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const REQUEST_TIMEOUT_MS = Number(process.env.UPSTREAM_TIMEOUT_MS) || 8000;

// Errors the route turns into HTTP responses. `status` is the HTTP code to send.
// The Flutter app relies on the "No location found" prefix, so keep it.
class LocationNotFoundError extends Error {
  constructor(city, suggestions = []) {
    const hint = suggestions.length ? ` Did you mean ${suggestions.map(placeLabel).join(' or ')}?` : '';
    super(`No location found for "${city}".${hint}`);
    this.name = 'LocationNotFoundError';
    this.status = 404;
  }
}

class AmbiguousLocationError extends Error {
  constructor(city, places) {
    const example = [places[0].name, places[0].admin1 || places[0].country].filter(Boolean).join(', ');
    super(
      `"${city}" matches several places: ${places.map(placeLabel).join('; ')}. `
      + `Add a state or country, e.g. "${example}".`,
    );
    this.name = 'AmbiguousLocationError';
    this.status = 422;
    this.candidates = places.map(toLocation);
  }
}

class UpstreamError extends Error {
  constructor(message, status = 502) {
    super(message);
    this.name = 'UpstreamError';
    this.status = status;
  }
}

// fetch + JSON with a timeout; every failure becomes an UpstreamError.
async function getJson(url, what) {
  let res;
  try {
    res = await fetch(url, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
  } catch (err) {
    if (err.name === 'TimeoutError' || err.name === 'AbortError') {
      throw new UpstreamError(`${what} service timed out. Please try again.`, 504);
    }
    throw new UpstreamError(`${what} service is unreachable. Please try again later.`);
  }
  if (!res.ok) {
    throw new UpstreamError(`${what} service returned an error (${res.status}). Please try again later.`);
  }
  try {
    return await res.json();
  } catch {
    throw new UpstreamError(`${what} service returned an invalid response.`);
  }
}

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

// A place wins outright over the next match if it is this many times more populous
// ("Paris" -> Paris, France, not Paris, Texas). Otherwise the name is ambiguous.
const DOMINANCE_RATIO = 5;
// Results closer than this are treated as the same place (e.g. a city and its district).
const SAME_PLACE_KM = 25;

const US_STATES = {
  AL: 'Alabama', AK: 'Alaska', AZ: 'Arizona', AR: 'Arkansas', CA: 'California',
  CO: 'Colorado', CT: 'Connecticut', DE: 'Delaware', DC: 'District of Columbia',
  FL: 'Florida', GA: 'Georgia', HI: 'Hawaii', ID: 'Idaho', IL: 'Illinois',
  IN: 'Indiana', IA: 'Iowa', KS: 'Kansas', KY: 'Kentucky', LA: 'Louisiana',
  ME: 'Maine', MD: 'Maryland', MA: 'Massachusetts', MI: 'Michigan', MN: 'Minnesota',
  MS: 'Mississippi', MO: 'Missouri', MT: 'Montana', NE: 'Nebraska', NV: 'Nevada',
  NH: 'New Hampshire', NJ: 'New Jersey', NM: 'New Mexico', NY: 'New York',
  NC: 'North Carolina', ND: 'North Dakota', OH: 'Ohio', OK: 'Oklahoma', OR: 'Oregon',
  PA: 'Pennsylvania', RI: 'Rhode Island', SC: 'South Carolina', SD: 'South Dakota',
  TN: 'Tennessee', TX: 'Texas', UT: 'Utah', VT: 'Vermont', VA: 'Virginia',
  WA: 'Washington', WV: 'West Virginia', WI: 'Wisconsin', WY: 'Wyoming',
};
const COUNTRY_ALIASES = { usa: 'US', 'united states of america': 'US', america: 'US', uk: 'GB', britain: 'GB', 'great britain': 'GB' };

// Lowercase, strip accents and periods: "São Paulo" -> "sao paulo", "St. Louis" -> "st louis".
function normalize(text) {
  return String(text ?? '')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/\./g, '').replace(/\s+/g, ' ').trim();
}

function placeLabel(r) {
  const parts = [r.name, r.admin1, r.country].filter(Boolean);
  return parts.filter((p, i) => parts.indexOf(p) === i).join(', ');
}

function toLocation(r) {
  return { name: r.name, region: r.admin1 ?? null, country: r.country ?? null, lat: r.latitude, lon: r.longitude };
}

// Does a result match a qualifier like "TX", "Texas", "France" or "FR"?
function matchesQualifier(r, qualifier) {
  const q = normalize(qualifier);
  const code = qualifier.trim().toUpperCase();
  if ([r.admin1, r.admin2, r.country].some((field) => field && normalize(field) === q)) return true;
  if (r.country_code && (r.country_code === code || r.country_code === COUNTRY_ALIASES[q])) return true;
  return r.country_code === 'US' && US_STATES[code] !== undefined && normalize(US_STATES[code]) === normalize(r.admin1);
}

function distanceKm(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

// Accepts "City", "City, State" or "City, State, Country".
async function geocodeCity(input) {
  const [name, ...qualifiers] = input.split(',').map((part) => part.trim()).filter(Boolean);
  if (!name) throw new LocationNotFoundError(input);

  const url = `${GEOCODE_URL}?name=${encodeURIComponent(name)}&count=10&language=en&format=json`;
  const data = await getJson(url, 'Geocoding');
  const results = Array.isArray(data.results) ? data.results : [];

  // Open-Meteo also returns prefix matches ("Lon" -> London); only accept the exact name.
  const exact = results.filter((r) => normalize(r.name) === normalize(name));
  if (exact.length === 0) throw new LocationNotFoundError(input, results.slice(0, 3));

  const qualified = exact.filter((r) => qualifiers.every((q) => matchesQualifier(r, q)));
  if (qualified.length === 0) throw new LocationNotFoundError(input, exact.slice(0, 3));

  // Prefer populated places (cities, towns) over regions with the same name, largest first.
  const populated = qualified.filter((r) => !r.feature_code || r.feature_code.startsWith('PPL'));
  const pool = (populated.length ? populated : qualified)
    .slice()
    .sort((a, b) => (b.population ?? 0) - (a.population ?? 0));

  const places = [];
  for (const r of pool) {
    if (!places.some((kept) => distanceKm(kept, r) < SAME_PLACE_KM)) places.push(r);
  }

  const [top, second] = places;
  const topPop = top.population ?? 0;
  const secondPop = second ? second.population ?? 0 : 0;
  if (!second || (topPop > 0 && topPop >= DOMINANCE_RATIO * secondPop)) return toLocation(top);

  throw new AmbiguousLocationError(name, places.slice(0, 5));
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
  const data = await getJson(`${FORECAST_URL}?${params.toString()}`, 'Weather');
  const current = data.current;
  if (!current || typeof current.temperature_2m !== 'number') {
    throw new UpstreamError('Weather service returned incomplete data.');
  }
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

module.exports = {
  geocodeCity, fetchWeather, LocationNotFoundError, AmbiguousLocationError, UpstreamError,
};
