const express = require('express');
const { geocodeCity, fetchWeather } = require('../lib/weather');
const { suggestOutfit } = require('../lib/outfit');

const router = express.Router();

const MAX_CITY_LENGTH = 100;

function badRequest(res, message) {
  return res.status(400).json({ error: message });
}

// Parses a coordinate query param; returns a number, or null if invalid.
function parseCoordinate(value, min, max) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < min || n > max) return null;
  return n;
}

router.get('/forecast', async (req, res) => {
  const { city, lat, lon } = req.query;
  const hasLat = lat !== undefined;
  const hasLon = lon !== undefined;

  let location;
  if (hasLat || hasLon) {
    if (!hasLat || !hasLon) {
      return badRequest(res, 'Provide both "lat" and "lon", or use "city" instead.');
    }
    const latNum = parseCoordinate(lat, -90, 90);
    const lonNum = parseCoordinate(lon, -180, 180);
    if (latNum === null) return badRequest(res, '"lat" must be a number between -90 and 90.');
    if (lonNum === null) return badRequest(res, '"lon" must be a number between -180 and 180.');
    location = { lat: latNum, lon: lonNum, name: null };
  } else if (city !== undefined) {
    if (typeof city !== 'string' || city.trim() === '') {
      return badRequest(res, '"city" must be a non-empty string.');
    }
    if (city.trim().length > MAX_CITY_LENGTH) {
      return badRequest(res, `"city" must be ${MAX_CITY_LENGTH} characters or fewer.`);
    }
  } else {
    return badRequest(res, 'Provide either "city" or "lat" and "lon" query params.');
  }

  try {
    if (!location) location = await geocodeCity(city.trim());
    const weather = await fetchWeather(location);
    const outfit = suggestOutfit(weather);

    return res.json({
      location: { name: location.name, lat: location.lat, lon: location.lon },
      weather,
      outfit,
    });
  } catch (err) {
    if (err.status) {
      return res.status(err.status).json({ error: err.message });
    }
    console.error('Unexpected error in /api/forecast:', err);
    return res.status(500).json({ error: 'Something went wrong on the server. Please try again.' });
  }
});

module.exports = router;
