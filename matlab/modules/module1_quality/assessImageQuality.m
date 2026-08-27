function scores = assessImageQuality(img)
%ASSESSIMAGEQUALITY Score a fundus image on focus, illumination, and field of view.
%   scores = ASSESSIMAGEQUALITY(img) returns a struct with fields
%   focus, illumination, fov, each a value in [0, 1] where 1 is best.
%
%   img must be an RGB or grayscale fundus image (uint8 or double).

% Normalize to a fixed working resolution: variance-of-Laplacian (used by
% focusScore) is resolution-dependent — the same optical sharpness scores
% an order of magnitude differently between e.g. a 1050x1050 and a
% 2136x3216 capture. Fundus cameras vary widely in native resolution, so
% score at a canonical size instead of raw pixel dimensions.
REF_SIZE = 600;
img = imresize(img, [REF_SIZE, REF_SIZE]);

if size(img, 3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end
gray = im2double(gray);

fovMask = retinalFieldMask(gray);

scores.focus = focusScore(gray, fovMask);
scores.illumination = illuminationScore(img, fovMask);
scores.fov = fovScore(fovMask);

end

% ---- helpers ----------------------------------------------------------

function mask = retinalFieldMask(gray)
%RETINALFIELDMASK Rough segmentation of the illuminated retinal disc
%   region within the fundus frame (excludes the black surround typical
%   of fundus camera captures).
%
%   Found via real-data testing: on images with strong vessel contrast
%   (notably after enhanceImage's CLAHE step), a plain intensity threshold
%   fragments the retinal field into many disconnected islands separated
%   by dark vessels, and bwareafilt(mask, 1) then keeps one small island
%   instead of the whole field -- collapsing measured coverage from ~0.7
%   to ~0.04 on an otherwise perfectly good capture. A morphological
%   closing bridges the vessel-width gaps before region selection.
level = max(graythresh(gray), 0.03);
mask = imbinarize(gray, level);
mask = imclose(mask, strel('disk', 8));
mask = imfill(mask, 'holes');
mask = bwareafilt(mask, 1); % keep the single largest connected region
if ~any(mask(:))
    mask = true(size(gray)); % fallback: no discernible dark surround
end
end

function s = focusScore(gray, fovMask)
%FOCUSSCORE Variance-of-Laplacian sharpness metric restricted to the
%   retinal field, mapped to [0, 1] via a soft threshold.
lap = fspecial('laplacian', 0.2);
edgeResponse = imfilter(gray, lap, 'replicate');
v = var(edgeResponse(fovMask));
% Empirical scale (calibrated at REF_SIZE=600 against 15 real APTOS 2019
% fundus images plus a synthetic Gaussian-blur sweep on the sharpest one):
% real gradable images range ~0.0002-0.0009; a mild blur (sigma=0.5) roughly
% halves that, a clearly problematic blur (sigma=1.0) drops it another
% order of magnitude to ~0.00007, well below any real sample observed.
s = min(1, v / 0.0006);
end

function s = illuminationScore(img, fovMask)
%ILLUMINATIONSCORE Penalizes under-/over-exposure and poor tonal spread
%   within the retinal field.
if size(img, 3) == 3
    hsv = rgb2hsv(im2double(img));
    v = hsv(:, :, 3);
else
    v = im2double(img);
end
region = v(fovMask);
meanV = mean(region);
stdV = std(region);

% Ideal mean brightness band ~[0.35, 0.65]; penalize distance from it.
targetMid = 0.5;
brightnessPenalty = abs(meanV - targetMid) / targetMid;
brightnessScore = max(0, 1 - brightnessPenalty);

% Reward reasonable contrast (std), penalize flat/washed-out images.
contrastScore = min(1, stdV / 0.18);

s = 0.6 * brightnessScore + 0.4 * contrastScore;
s = max(0, min(1, s));
end

function s = fovScore(fovMask)
%FOVSCORE Rewards adequate, centered retinal field coverage. Only
%   penalizes coverage that is too LOW (small/narrow field) or a field
%   centroid that sits off the frame center -- coverage is never
%   penalized for being high.
%
%   The original version penalized any deviation from ~70% coverage in
%   either direction, calibrated against raw fundus-camera captures
%   (e.g. APTOS) which have a black surround around the illuminated
%   disc. Internet-sourced / stock fundus images are almost always
%   pre-cropped tight to the retinal field with no border at all --
%   retinalFieldMask's "no discernible dark surround" fallback then sets
%   coverage to exactly 1.0, which the old symmetric formula scored
%   ~0.57 (below the 0.6 accept floor) even though a full-frame, centered
%   capture is not a real defect. Confirmed on two real rejected uploads
%   (both origin coverage=1.0000, fov=0.5714) that had focus/illumination
%   scores near-perfect.
[h, w] = size(fovMask);
coverage = sum(fovMask(:)) / numel(fovMask);

MIN_GOOD_COVERAGE = 0.45;
coverageScore = min(1, coverage / MIN_GOOD_COVERAGE);

props = regionprops(fovMask, 'Centroid');
if isempty(props)
    centerScore = 1;
else
    c = props(1).Centroid; % [x y]
    dx = (c(1) - w/2) / (w/2);
    dy = (c(2) - h/2) / (h/2);
    offset = sqrt(dx^2 + dy^2);
    centerScore = max(0, 1 - offset);
end

s = 0.6 * coverageScore + 0.4 * centerScore;
s = max(0, min(1, s));
end
