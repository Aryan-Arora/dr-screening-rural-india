const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const config = require('./config');
const analyzeRoute = require('./routes/analyze');
const matlabRunner = require('./matlabRunner');

for (const dir of [config.UPLOADS_DIR, config.OUTPUTS_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

const app = express();
app.use(cors());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api', analyzeRoute);
app.use('/api/outputs', express.static(config.OUTPUTS_DIR));

// Minimal test frontend (not the real product UI) so the API can be
// exercised from a browser without waiting on the separate frontend work.
app.use(express.static(path.join(__dirname, 'public')));

app.use((err, req, res, next) => {
  res.status(400).json({ error: err.message });
});

// The persistent MATLAB session's one-time ~7-25s startup + model-load
// cost happens here, before the port is even opened -- so it's paid once
// when you start the server, never again per request. If it fails to
// come up, the server still starts (so /health etc. work for debugging)
// but /api/analyze will error until it's fixed and the process restarted.
matlabRunner.startServer().catch((err) => {
  console.error(`matlabRunner: failed to start persistent MATLAB session: ${err.message}`);
});

const server = app.listen(config.PORT, () => {
  console.log(`DR screening bridge server listening on port ${config.PORT}`);
  console.log(`MATLAB binary: ${config.MATLAB_BIN}`);
});

function shutdown() {
  console.log('bridge server: shutting down, stopping MATLAB session...');
  matlabRunner.stopServer();
  server.close(() => process.exit(0));
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
