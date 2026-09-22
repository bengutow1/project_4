const express = require('express');
const { geocodeCity, fetchWeather } = require('../lib/weather');
const { suggestOutfit } = require('../lib/outfit');

const router = express.Router();

router.get('/forecast', async (req, res) => {
  const { city, lat, lon } = req.query;

  try {
    let location;
    if (lat && lon) {
      location = { lat: Number(lat), lon: Number(lon), name: null };
    } else if (city) {
      location = await geocodeCity(city);
    } else {
      return res.status(400).json({ error: 'Provide either "city" or "lat" and "lon" query params.' });
    }

    const weather = await fetchWeather(location);
    const outfit = suggestOutfit(weather);

    res.json({
      location: { name: location.name, lat: location.lat, lon: location.lon },
      weather,
      outfit,
    });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

module.exports = router;
