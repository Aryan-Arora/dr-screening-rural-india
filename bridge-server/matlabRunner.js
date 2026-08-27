const { execFile } = require('child_process');
const config = require('./config');

/**
 * Runs run_pipeline.m headlessly on one image and resolves with the
 * parsed result.json it writes. Rejects on MATLAB failure, timeout, or
 * malformed output.
 */
function runPipeline(inputImagePath, outputDir) {
  return new Promise((resolve, reject) => {
    const escapedScriptsDir = config.SCRIPTS_DIR.replace(/'/g, "''");
    const escapedInput = inputImagePath.replace(/'/g, "''");
    const escapedOutput = outputDir.replace(/'/g, "''");
    const statement = `addpath('${escapedScriptsDir}'); run_pipeline('${escapedInput}', '${escapedOutput}');`;

    execFile(
      config.MATLAB_BIN,
      ['-batch', statement],
      { timeout: config.PIPELINE_TIMEOUT_MS, maxBuffer: 10 * 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(`MATLAB pipeline failed: ${error.message}\n${stderr}`));
          return;
        }

        const fs = require('fs');
        const resultPath = require('path').join(outputDir, 'result.json');
        if (!fs.existsSync(resultPath)) {
          reject(new Error(`MATLAB pipeline did not produce result.json.\nstdout: ${stdout}\nstderr: ${stderr}`));
          return;
        }

        try {
          const result = JSON.parse(fs.readFileSync(resultPath, 'utf8'));
          resolve({ result, stdout });
        } catch (parseErr) {
          reject(new Error(`result.json was not valid JSON: ${parseErr.message}`));
        }
      }
    );
  });
}

module.exports = { runPipeline };
