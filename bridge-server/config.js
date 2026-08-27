const path = require('path');

module.exports = {
  PORT: process.env.PORT || 4000,
  MATLAB_BIN: process.env.MATLAB_BIN || '/Applications/MATLAB_R2026a.app/bin/matlab',
  SCRIPTS_DIR: path.join(__dirname, '..', 'matlab', 'scripts'),
  UPLOADS_DIR: path.join(__dirname, 'uploads'),
  OUTPUTS_DIR: path.join(__dirname, 'outputs'),
  // Each request spins up a fresh headless MATLAB process (per the PRD's
  // architecture), which pays CNN-loading startup cost every time -- slow
  // per request, but simple and matches spec. A persistent MATLAB engine
  // session would remove this cost if latency becomes a real problem.
  PIPELINE_TIMEOUT_MS: 5 * 60 * 1000,
};
