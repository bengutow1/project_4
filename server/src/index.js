const express = require('express');
const cors = require('cors');
const forecastRouter = require('./routes/forecast');

const app = express();
app.use(cors());

app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api', forecastRouter);

if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Weather + Outfit server listening on port ${PORT}`));
}

module.exports = app;
