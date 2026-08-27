function report = qualityGate(img)
%QUALITYGATE Module 1 entry point: score, optionally enhance, and decide
%   whether a captured fundus image is usable for downstream grading.
%
%   report = QUALITYGATE(img) returns a struct matching the
%   "quality_check" section of the pipeline's JSON contract:
%       status: 'accepted' | 'enhanced' | 'rejected'
%       reason: char or [] (empty -> serializes to null)
%       scores: struct with focus, illumination, fov
%       image:  the accepted/enhanced image (only present when not rejected)
%
%   Thresholds:
%       ACCEPT_MIN   - per-metric floor to accept outright
%       RECOVER_MIN  - per-metric floor below which enhancement is even
%                      attempted; below this the defect is unrecoverable
%                      (e.g. no field of view captured at all)

ACCEPT_MIN = 0.6;
RECOVER_MIN = 0.3;

scores = assessImageQuality(img);
report.scores = scores;

metricNames = {'focus', 'illumination', 'fov'};
vals = [scores.focus, scores.illumination, scores.fov];

if all(vals >= ACCEPT_MIN)
    report.status = 'accepted';
    report.reason = [];
    report.image = img;
    return;
end

if any(vals < RECOVER_MIN)
    report.status = 'rejected';
    report.reason = rejectReason(scores, metricNames, RECOVER_MIN);
    return;
end

% Borderline: attempt enhancement, then re-score to confirm it helped.
enhanced = enhanceImage(img);
newScores = assessImageQuality(enhanced);
newVals = [newScores.focus, newScores.illumination, newScores.fov];

if all(newVals >= ACCEPT_MIN)
    report.status = 'enhanced';
    report.reason = [];
    report.scores = newScores;
    report.image = enhanced;
else
    report.status = 'rejected';
    report.reason = rejectReason(newScores, metricNames, ACCEPT_MIN);
    report.scores = newScores;
end

end

% ---- helpers ----------------------------------------------------------

function reason = rejectReason(scores, metricNames, threshold)
%REJECTREASON Build a specific, actionable recapture message naming the
%   worst-scoring metric(s), per PRD Module 1 requirement.
vals = struct2array_local(scores, metricNames);
[~, idx] = min(vals);
worst = metricNames{idx};

messages = struct( ...
    'focus', 'Image too blurry — hold the camera steady and refocus before recapturing.', ...
    'illumination', 'Poor illumination — image is too dark, too bright, or low-contrast; adjust camera lighting and recapture.', ...
    'fov', 'Field of view is off-center or too narrow — recenter on the retina and recapture.');

reason = messages.(worst);
if sum(vals < threshold) > 1
    reason = [reason, ' Multiple quality issues detected: ', strjoin(metricNames(vals < threshold), ', '), '.'];
end
end

function vals = struct2array_local(s, fields)
vals = zeros(1, numel(fields));
for i = 1:numel(fields)
    vals(i) = s.(fields{i});
end
end
