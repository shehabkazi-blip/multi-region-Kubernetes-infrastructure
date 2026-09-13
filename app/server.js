const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 8080;
const REGION = process.env.REGION || 'unknown-region';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

app.use(express.json());

// Root route - returns basic identifying info (useful for multi-region testing)
app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Hello from the sample multi-region app!',
    region: REGION,
    hostname: os.hostname(),
    version: APP_VERSION,
    timestamp: new Date().toISOString(),
  });
});

// Liveness probe endpoint
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Readiness probe endpoint
app.get('/readyz', (req, res) => {
  res.status(200).json({ status: 'ready' });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT} in region ${REGION}`);
});
