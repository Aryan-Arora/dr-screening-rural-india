const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const config = require('./config');

// A single persistent `matlab -batch run_pipeline_server(...)` process,
// started once by startServer() and reused for every request via a
// file-based job queue -- see run_pipeline_server.m for the MATLAB side.
// This is what actually removes the ~7-25s per-request MATLAB startup +
// model-load cost the old spawn-per-request approach paid every time.
let matlabProcess = null;
let readyPromise = null;

/**
 * Starts the persistent MATLAB session and resolves once it has finished
 * loading every model (signaled by it writing READY_FLAG_PATH). Safe to
 * call once at bridge-server startup; awaiting the returned promise means
 * the one-time ~7-25s cost happens when you start the server, not when
 * the first user clicks "Run Analysis".
 */
function startServer() {
  if (readyPromise) return readyPromise;

  fs.mkdirSync(config.QUEUE_DIR, { recursive: true });
  if (fs.existsSync(config.READY_FLAG_PATH)) fs.unlinkSync(config.READY_FLAG_PATH);
  if (fs.existsSync(config.SHUTDOWN_FLAG_PATH)) fs.unlinkSync(config.SHUTDOWN_FLAG_PATH);

  const escapedScriptsDir = config.SCRIPTS_DIR.replace(/'/g, "''");
  const escapedQueueDir = config.QUEUE_DIR.replace(/'/g, "''");
  const escapedReadyFlag = config.READY_FLAG_PATH.replace(/'/g, "''");
  const statement = `addpath('${escapedScriptsDir}'); run_pipeline_server('${escapedQueueDir}', '${escapedReadyFlag}');`;

  console.log('matlabRunner: starting persistent MATLAB session (one-time ~7-25s startup + model load)...');
  matlabProcess = spawn(config.MATLAB_BIN, ['-batch', statement], { stdio: ['ignore', 'pipe', 'pipe'] });

  matlabProcess.stdout.on('data', (chunk) => process.stdout.write(`[matlab] ${chunk}`));
  matlabProcess.stderr.on('data', (chunk) => process.stderr.write(`[matlab:err] ${chunk}`));

  matlabProcess.on('exit', (code) => {
    console.error(`matlabRunner: persistent MATLAB session exited (code ${code}) -- image analysis is unavailable until the server restarts.`);
    matlabProcess = null;
    readyPromise = null;
  });

  readyPromise = new Promise((resolve, reject) => {
    const startedAt = Date.now();
    const check = setInterval(() => {
      if (fs.existsSync(config.READY_FLAG_PATH)) {
        clearInterval(check);
        console.log('matlabRunner: MATLAB session ready, models loaded.');
        resolve();
      } else if (!matlabProcess) {
        clearInterval(check);
        reject(new Error('MATLAB persistent session exited before becoming ready'));
      } else if (Date.now() - startedAt > config.MATLAB_STARTUP_TIMEOUT_MS) {
        clearInterval(check);
        reject(new Error('MATLAB persistent session did not become ready in time'));
      }
    }, 250);
  });

  return readyPromise;
}

/**
 * Asks the persistent MATLAB session to exit cleanly via the shutdown
 * flag (so its `-batch` invocation returns and the process quits on its
 * own); force-kills it if it hasn't exited shortly after.
 */
function stopServer() {
  if (!matlabProcess) return;
  try {
    fs.writeFileSync(config.SHUTDOWN_FLAG_PATH, '');
  } catch {
    // fall through to the force-kill below
  }
  const proc = matlabProcess;
  setTimeout(() => {
    if (proc.exitCode === null && proc.signalCode === null) proc.kill();
  }, 3000).unref();
}

/**
 * Runs one image through the already-warm persistent MATLAB session:
 * drops a job file for run_pipeline_server.m to pick up, then polls for
 * the result.json it writes -- same contract routes/analyze.js already
 * expects, so it doesn't need to know this changed under it.
 */
function runPipeline(inputImagePath, outputDir) {
  return new Promise((resolve, reject) => {
    if (!matlabProcess || !readyPromise) {
      reject(new Error('MATLAB persistent session is not running'));
      return;
    }

    readyPromise
      .then(() => {
        const jobId = path.basename(outputDir);
        const jobPath = path.join(config.QUEUE_DIR, `${jobId}.job.json`);
        const resultPath = path.join(outputDir, 'result.json');

        fs.mkdirSync(outputDir, { recursive: true });
        fs.writeFileSync(jobPath, JSON.stringify({ jobId, imagePath: inputImagePath, outputDir }));

        const startedAt = Date.now();
        const poll = setInterval(() => {
          if (fs.existsSync(resultPath)) {
            clearInterval(poll);
            let parsed;
            try {
              parsed = JSON.parse(fs.readFileSync(resultPath, 'utf8'));
            } catch (parseErr) {
              reject(new Error(`result.json was not valid JSON: ${parseErr.message}`));
              return;
            }
            if (parsed && parsed.error) {
              reject(new Error(`MATLAB pipeline failed: ${parsed.error}`));
            } else {
              resolve({ result: parsed, stdout: '' });
            }
          } else if (!matlabProcess) {
            clearInterval(poll);
            reject(new Error('MATLAB persistent session crashed while processing this request'));
          } else if (Date.now() - startedAt > config.PIPELINE_TIMEOUT_MS) {
            clearInterval(poll);
            reject(new Error('MATLAB pipeline timed out'));
          }
        }, config.PIPELINE_POLL_INTERVAL_MS);
      })
      .catch(reject);
  });
}

module.exports = { startServer, stopServer, runPipeline };
