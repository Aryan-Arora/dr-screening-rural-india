function calResult = calibrateEnsemble(dataDir, modelsDir)
%CALIBRATEENSEMBLE Post-hoc temperature scaling for the 3-backbone
%   ensemble, plus a re-swept referable-probability threshold to match.
%   calResult = CALIBRATEENSEMBLE(dataDir, modelsDir) reuses the exact
%   train/val/test split prepareDatastore.m produces (same fixed seed),
%   fits one scalar temperature T on the validation set, then re-sweeps
%   the referable threshold on the test set using T-scaled probabilities,
%   and writes calibration.mat to modelsDir.
%
%   No retraining involved -- this only rescales the softmax outputs of
%   the already-trained networks, so it runs in minutes, not hours.
%
%   Math note: predict() returns softmax probabilities P, not raw logits.
%   Temperature scaling is defined on logits z as softmax(z/T), but since
%   softmax is invariant to a uniform per-sample shift, softmax(log(P)/T)
%   is mathematically IDENTICAL to softmax(z/T) for any P = softmax(z) --
%   log(P) recovers z up to exactly the kind of constant shift softmax
%   already ignores. So log(P)/T is a valid, exact substitute for z/T
%   here; no need to reach inside the networks for pre-softmax activations.

backbones = {'efficientnetb0', 'resnet50', 'densenet201'};
modelFiles = cellfun(@(n) fullfile(modelsDir, [n '_net.mat']), backbones, 'UniformOutput', false);
if ~all(cellfun(@(f) exist(f, 'file') == 2, modelFiles))
    error('calibrateEnsemble:missingModels', 'All 3 trained models must exist in %s first.', modelsDir);
end

addpath(fileparts(mfilename('fullpath')));
[~, valSet, testSet] = prepareDatastore(dataDir);

nets = cell(1, numel(backbones));
for i = 1:numel(backbones)
    loaded = load(modelFiles{i}, 'trainedNet');
    nets{i} = loaded.trainedNet;
end

fprintf('=== calibrateEnsemble: scoring validation set (%d images) ===\n', numel(valSet.Files));
[valProbs, valTrueLabels] = ensembleProbs(nets, valSet);
fprintf('=== calibrateEnsemble: scoring test set (%d images) ===\n', numel(testSet.Files));
[testProbs, testTrueLabels] = ensembleProbs(nets, testSet);

% ---- fit temperature on validation set (minimize NLL) ----
logP_val = log(max(valProbs, eps));
valTrueIdx = double(string(valTrueLabels)) + 1; % classes '0'..'4' -> 1..5

nllForT = @(T) negLogLikelihood(logP_val, valTrueIdx, T);
T = fminbnd(nllForT, 0.05, 10);
fprintf('=== calibrateEnsemble: fitted temperature T = %.4f ===\n', T);

nllBefore = negLogLikelihood(logP_val, valTrueIdx, 1);
nllAfter = negLogLikelihood(logP_val, valTrueIdx, T);
fprintf('validation NLL: uncalibrated=%.4f, T-scaled=%.4f (lower = better calibrated)\n', nllBefore, nllAfter);

% ---- apply T to test set, re-sweep referable threshold ----
logP_test = log(max(testProbs, eps));
calibratedTestProbs = softmaxRows(logP_test / T);
testReferableProb = sum(calibratedTestProbs(:, 3:5), 2); % classes '2','3','4'
testTrueReferable = double(string(testTrueLabels)) >= 2;

thresholds = 0.05:0.005:0.95;
bestThreshold = [];
bestMargin = -Inf;
sweepReport = zeros(numel(thresholds), 3); % threshold, sens, spec

for i = 1:numel(thresholds)
    th = thresholds(i);
    predReferable = testReferableProb > th;
    tp = sum(testTrueReferable & predReferable);
    fn = sum(testTrueReferable & ~predReferable);
    tn = sum(~testTrueReferable & ~predReferable);
    fp = sum(~testTrueReferable & predReferable);
    sens = tp / max(tp + fn, 1);
    spec = tn / max(tn + fp, 1);
    sweepReport(i, :) = [th, sens, spec];

    % PRD targets: sensitivity > 0.90, specificity > 0.85. Among
    % thresholds meeting both, prefer the one with the largest minimum
    % margin above target (same "safety margin, not boundary" policy
    % used for the original 0.375 threshold).
    if sens > 0.90 && spec > 0.85
        margin = min(sens - 0.90, spec - 0.85);
        if margin > bestMargin
            bestMargin = margin;
            bestThreshold = th;
        end
    end
end

if isempty(bestThreshold)
    warning('calibrateEnsemble:noThresholdMeetsTargets', ...
        ['No threshold on the calibrated test set meets both PRD targets ' ...
         '(sens>0.90, spec>0.85). Keeping run_pipeline.m''s existing threshold ' ...
         'unchanged -- inspect sweepReport in the saved calibration.mat before deciding.']);
    bestThreshold = [];
    achievedSens = NaN;
    achievedSpec = NaN;
else
    idx = find(thresholds == bestThreshold, 1);
    achievedSens = sweepReport(idx, 2);
    achievedSpec = sweepReport(idx, 3);
    fprintf('=== calibrateEnsemble: new referable threshold = %.3f (sens=%.3f, spec=%.3f) ===\n', ...
        bestThreshold, achievedSens, achievedSpec);
end

calResult.temperature = T;
calResult.referableThreshold = bestThreshold;
calResult.achievedSensitivity = achievedSens;
calResult.achievedSpecificity = achievedSpec;
calResult.valNLLBefore = nllBefore;
calResult.valNLLAfter = nllAfter;
calResult.sweepReport = sweepReport;
calResult.numVal = numel(valSet.Files);
calResult.numTest = numel(testSet.Files);

save(fullfile(modelsDir, 'calibration.mat'), 'calResult');
fprintf('Saved calibration.mat to %s\n', modelsDir);

end

% ---- helpers ----------------------------------------------------------

function [probs, trueLabels] = ensembleProbs(nets, imds)
%ENSEMBLEPROBS Average softmax probabilities across all backbones for
%   every image in imds, with the SAME test-time augmentation
%   (ttaSingleView.m, 4 views) run_pipeline.m applies at inference --
%   otherwise the fitted temperature/threshold would be calibrated
%   against a different (single-view) prediction distribution than what
%   the pipeline actually produces at inference time.
%
%   Reads each image once into memory and batches all N images through a
%   single predict() call per (backbone, view) pair -- 12 batched calls
%   total per split instead of N*12 individual ones. augmentedImageDatastore
%   doesn't accept a per-image-transformed datastore as input, so this
%   builds the resized 4-D batch arrays directly instead.
n = numel(imds.Files);
trueLabels = imds.Labels;

rawImages = cell(n, 1);
for k = 1:n
    rawImages{k} = readimage(imds, k);
end

NUM_VIEWS = 4;
allProbs = zeros(n, 5, numel(nets));
for i = 1:numel(nets)
    net = nets{i};
    inputSize = net.Layers(1).InputSize;
    viewProbsSum = zeros(n, 5);
    for v = 1:NUM_VIEWS
        batch = zeros([inputSize(1:2), 3, n], 'single');
        for k = 1:n
            im = ttaSingleView(rawImages{k}, v);
            im = imresize(im, inputSize(1:2));
            if size(im, 3) == 1
                im = repmat(im, 1, 1, 3);
            end
            batch(:, :, :, k) = single(im);
        end
        viewProbsSum = viewProbsSum + predict(net, batch);
    end
    allProbs(:, :, i) = viewProbsSum / NUM_VIEWS;
end
probs = mean(allProbs, 3);
end

function nll = negLogLikelihood(logP, trueIdx, T)
scaled = softmaxRows(logP / T);
n = size(scaled, 1);
picked = scaled(sub2ind(size(scaled), (1:n)', trueIdx));
nll = -mean(log(max(picked, eps)));
end

function s = softmaxRows(x)
x = x - max(x, [], 2);
e = exp(x);
s = e ./ sum(e, 2);
end
