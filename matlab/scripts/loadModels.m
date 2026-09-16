function models = loadModels()
%LOADMODELS Load every module's heavy, reusable state exactly once.
%   MODELS = LOADMODELS() adds the module folders to the path and loads
%   the 3 CNN backbones + calibration for Module 3, returning them in one
%   struct that RUNONIMAGE takes on every subsequent call.
%
%   This is the piece that used to run inside run_pipeline.m on EVERY
%   request (~7-25s of MATLAB startup + backbone loading, paid again per
%   image). Split out so RUN_PIPELINE_SERVER can call it once at process
%   startup and keep the result warm in memory for the life of the
%   persistent MATLAB session -- see run_pipeline_server.m.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module1_quality'));
addpath(fullfile(thisDir, '..', 'modules', 'module2_segmentation'));
addpath(fullfile(thisDir, '..', 'modules', 'module3_grading'));
addpath(fullfile(thisDir, '..', 'modules', 'module4_explainability'));
addpath(fullfile(thisDir, '..', 'modules', 'module6_vascular_risk'));

models = struct();
models.modelsDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');
models.backbones = {'efficientnetb0', 'resnet50', 'densenet201'};
modelFiles = cellfun(@(n) fullfile(models.modelsDir, [n '_net.mat']), models.backbones, 'UniformOutput', false);
models.haveAllModels = all(cellfun(@(f) exist(f, 'file') == 2, modelFiles));

models.nets = {};
models.explainNet = [];
% Kept as a no-op-safe default (temperature 1, the PRD's original
% threshold) so runOnImage behaves identically to before if calibration
% hasn't been generated yet -- same fallback run_pipeline.m always had.
models.temperature = 1;
models.referableProbThreshold = 0.375;

if models.haveAllModels
    for i = 1:numel(models.backbones)
        loaded = load(modelFiles{i}, 'trainedNet');
        models.nets{i} = loaded.trainedNet;
        % Densenet201 is the designated "explainability backbone" (see
        % generateGradCAM.m) -- resolved once here so runOnImage doesn't
        % need to re-derive it from backbone order every call.
        if strcmp(models.backbones{i}, 'densenet201')
            models.explainNet = loaded.trainedNet;
        end
    end

    calFile = fullfile(models.modelsDir, 'calibration.mat');
    if exist(calFile, 'file') == 2
        calLoaded = load(calFile, 'calResult');
        models.temperature = calLoaded.calResult.temperature;
        if ~isempty(calLoaded.calResult.referableThreshold)
            models.referableProbThreshold = calLoaded.calResult.referableThreshold;
        end
    end
end

end
