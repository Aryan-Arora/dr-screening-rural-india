const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const config = require('./config');
const analyzeRoute = require('./routes/analyze');

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

app.listen(config.PORT, () => {
  console.log(`DR screening bridge server listening on port ${config.PORT}`);
  console.log(`MATLAB binary: ${config.MATLAB_BIN}`);
});
