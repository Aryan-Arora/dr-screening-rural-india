function run_pipeline(inputImagePath, outputDir)
%RUN_PIPELINE Single-image, single-shot entry point (loads models fresh).
%   RUN_PIPELINE(inputImagePath, outputDir) loads models and runs the
%   full pipeline on one image in a single call -- kept for direct/manual
%   invocation and backward compatibility:
%     matlab -batch "addpath('.../scripts'); run_pipeline('input.jpg','outdir')"
%
%   The bridge server no longer calls this per request -- it pays the
%   ~7-25s model-loading cost on every call, which is exactly the
%   latency problem this was split up to avoid. It now runs
%   run_pipeline_server.m once (loadModels.m loads everything a single
%   time) and dispatches each request to runOnImage.m against that
%   already-warm state -- see matlabRunner.js and run_pipeline_server.m.

models = loadModels();
runOnImage(models, inputImagePath, outputDir);

end
