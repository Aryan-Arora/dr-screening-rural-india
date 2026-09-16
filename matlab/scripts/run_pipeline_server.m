function run_pipeline_server(queueDir, readyFlagPath)
%RUN_PIPELINE_SERVER Long-lived MATLAB worker for the bridge server.
%   RUN_PIPELINE_SERVER(queueDir, readyFlagPath) loads all models ONCE
%   (loadModels.m), writes readyFlagPath to signal the bridge server it
%   can start accepting requests, then polls queueDir for job files
%   written by Node and runs each one against the already-loaded models
%   (runOnImage.m). This is what actually removes the ~7-25s per-request
%   MATLAB startup + model-load cost that run_pipeline.m used to pay on
%   every single image -- see matlabRunner.js for the Node side.
%
%   One bad image's error is caught and written into that job's own
%   result.json rather than crashing this loop, since it has to keep
%   serving every other request for the life of the bridge server
%   process.
%
%   Job file contract (written by Node, one per request):
%     <jobId>.job.json = {"jobId": "...", "imagePath": "...", "outputDir": "..."}
%   Claimed by renaming to <jobId>.job.json.processing before running, so
%   a job already picked up is never picked up again.
%
%   Shuts down cleanly (so -batch exits) when a shutdown.flag file
%   appears next to queueDir -- matlabRunner.js's stopServer() writes it.

fprintf('run_pipeline_server: loading models...\n');
models = loadModels();
if ~models.haveAllModels
    fprintf('run_pipeline_server: WARNING -- trained Module 3 models not found, severity grading will be skipped for every request.\n');
end

if ~exist(queueDir, 'dir')
    mkdir(queueDir);
end
shutdownFlagPath = fullfile(queueDir, '..', 'shutdown.flag');
if exist(shutdownFlagPath, 'file')
    delete(shutdownFlagPath); % stale from a previous run -- don't exit immediately
end

fid = fopen(readyFlagPath, 'w');
fprintf(fid, '%s', string(datetime('now')));
fclose(fid);
fprintf('run_pipeline_server: ready, watching %s\n', queueDir);

while true
    if exist(shutdownFlagPath, 'file')
        delete(shutdownFlagPath);
        fprintf('run_pipeline_server: shutdown flag detected, exiting.\n');
        break;
    end

    jobFiles = dir(fullfile(queueDir, '*.job.json'));
    if isempty(jobFiles)
        pause(0.15);
        continue;
    end

    % Oldest first, so requests are served in the order they arrived.
    [~, order] = sort([jobFiles.datenum]);
    jobFiles = jobFiles(order);
    jobPath = fullfile(jobFiles(1).folder, jobFiles(1).name);
    claimedPath = [jobPath, '.processing'];

    try
        movefile(jobPath, claimedPath);
    catch
        % Lost a race (shouldn't happen with a single worker, but
        % harmless if it ever does) -- next pass picks up what's left.
        continue;
    end

    job = jsondecode(fileread(claimedPath));
    fprintf('run_pipeline_server: processing job %s (%s)\n', job.jobId, job.imagePath);

    try
        runOnImage(models, job.imagePath, job.outputDir);
    catch err
        fprintf('run_pipeline_server: job %s failed: %s\n', job.jobId, err.message);
        if ~exist(job.outputDir, 'dir')
            mkdir(job.outputDir);
        end
        errFid = fopen(fullfile(job.outputDir, 'result.json'), 'w');
        fwrite(errFid, jsonencode(struct('error', err.message)));
        fclose(errFid);
    end

    delete(claimedPath);
end

end
