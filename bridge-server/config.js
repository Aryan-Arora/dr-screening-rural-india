const path = require('path');

module.exports = {
  PORT: process.env.PORT || 4000,
  MATLAB_BIN: process.env.MATLAB_BIN || '/Applications/MATLAB_R2026a.app/bin/matlab',
  SCRIPTS_DIR: path.join(__dirname, '..', 'matlab', 'scripts'),
  UPLOADS_DIR: path.join(__dirname, 'uploads'),
  OUTPUTS_DIR: path.join(__dirname, 'outputs'),
  // One persistent `matlab -batch run_pipeline_server(...)` process is
  // started when the bridge server itself starts (see matlabRunner.js),
  // loading every CNN backbone once and keeping them warm for the life of
  // the process. Requests are handed to it as job files in QUEUE_DIR
  // instead of each spawning its own fresh MATLAB process -- that fresh-
  // spawn-per-request approach paid MATLAB's ~7-25s startup + model-load
  // cost on every single image, which this removes entirely after the
  // one-time startup cost.
  QUEUE_DIR: path.join(__dirname, 'queue'),
  READY_FLAG_PATH: path.join(__dirname, 'queue', 'ready.flag'),
  SHUTDOWN_FLAG_PATH: path.join(__dirname, 'shutdown.flag'),
  MATLAB_STARTUP_TIMEOUT_MS: 3 * 60 * 1000,
  PIPELINE_POLL_INTERVAL_MS: 150,
  PIPELINE_TIMEOUT_MS: 5 * 60 * 1000,
};
