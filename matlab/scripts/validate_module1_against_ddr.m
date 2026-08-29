%VALIDATE_MODULE1_AGAINST_DDR Checks Module 1's classical quality gate
%   (qualityGate.m) against real "ungradable" ground truth from DDR,
%   plus a random sample of DDR's "gradable" images as the negative
%   class -- same style as the existing DRIMDB calibration documented in
%   README's Module 1 section, just a second, independent real-world
%   check rather than a retrain.
%
%   NOT YET RUN. Draft pending review (docs/module1_quality_validation_plan.md).
%   Prerequisites: download_ddr_ungradable.sh run, and a small random
%   sample of already-downloaded images_ddr/ (gradable) used as the
%   comparison set.
%
%   This does NOT train anything -- qualityGate.m's classical heuristic
%   (focus/illumination/FOV scoring, ACCEPT_MIN/RECOVER_MIN thresholds)
%   runs as-is. Output is a confusion matrix (real ungradable vs.
%   real gradable, both from DDR) against qualityGate.m's
%   accepted/enhanced/rejected status, collapsed to a binary
%   gradable/ungradable call (accepted+enhanced = gradable).

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module1_quality'));

ungradableDir = fullfile(thisDir, '..', 'data', 'train_data', 'images_ddr_ungradable');
gradableDir = fullfile(thisDir, '..', 'data', 'train_data', 'images_ddr');

if ~exist(ungradableDir, 'dir')
    error('validate_module1_against_ddr:noData', ...
        '%s does not exist -- run download_ddr_ungradable.sh first.', ungradableDir);
end

ungradableFiles = dir(fullfile(ungradableDir, '*.jpg'));

% Sample an equal-sized set of known-gradable DDR images (they were
% class 0-4, i.e. successfully graded, by construction) for a balanced
% check rather than an all-ungradable one-sided test.
gradableAll = [];
for c = 0:4
    d = dir(fullfile(gradableDir, num2str(c), '*.jpg'));
    for i = 1:numel(d)
        gradableAll = [gradableAll; d(i)]; %#ok<AGROW>
    end
end
rngState = rng(42, 'twister');
idx = randperm(numel(gradableAll), min(numel(ungradableFiles), numel(gradableAll)));
rng(rngState);
gradableSample = gradableAll(idx);

fprintf('Evaluating on %d real ungradable + %d real gradable DDR images...\n', ...
    numel(ungradableFiles), numel(gradableSample));

results = evalSet(ungradableFiles, true);
results = [results; evalSet(gradableSample, false)];

trueUngradable = [results.trueUngradable];
predUngradable = [results.predUngradable];

tp = sum(trueUngradable & predUngradable);
fn = sum(trueUngradable & ~predUngradable);
tn = sum(~trueUngradable & ~predUngradable);
fp = sum(~trueUngradable & predUngradable);

fprintf('\n=== MODULE 1 vs. REAL DDR QUALITY LABELS ===\n');
fprintf('sensitivity (catches real ungradable): %.3f\n', tp / max(tp+fn, 1));
fprintf('specificity (passes real gradable):    %.3f\n', tn / max(tn+fp, 1));
fprintf('confusion: TP=%d FN=%d TN=%d FP=%d\n', tp, fn, tn, fp);
fprintf('\nCompare against README''s DRIMDB calibration numbers (15/15 bad\n');
fprintf('rejected, 14/15 good passed) -- this is a SECOND, independent,\n');
fprintf('larger-n real-world check, not a replacement for that one.\n');

function results = evalSet(fileList, trueUngradableLabel)
results = struct('trueUngradable', {}, 'predUngradable', {});
for i = 1:numel(fileList)
    try
        img = imread(fullfile(fileList(i).folder, fileList(i).name));
        qc = qualityGate(img);
        predUngradable = strcmp(qc.status, 'rejected');
        results(end+1) = struct('trueUngradable', trueUngradableLabel, 'predUngradable', predUngradable); %#ok<AGROW>
    catch err
        fprintf('skipping %s: %s\n', fileList(i).name, err.message);
    end
end
end
