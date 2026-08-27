function segments = classifyVesselSegments(img, vesselMask, discCenter, discRadius)
%CLASSIFYVESSELSEGMENTS Break the vessel mask into individual segments and
%   heuristically label each as artery-like or vein-like.
%   segments = CLASSIFYVESSELSEGMENTS(img, vesselMask, discCenter, discRadius)
%   returns a struct array, one entry per segment, with fields:
%       pixelIdx    - linear indices of this segment's skeleton pixels
%       endpoints   - [x1 y1; x2 y2] segment endpoints
%       chordLength - straight-line distance between endpoints
%       arcLength   - path length along the skeleton
%       meanWidth   - mean vessel width along this segment (pixels)
%       colorScore  - mean(R)-mean(G) over the segment's dilated footprint
%                     in the ORIGINAL color image (not the green-channel-
%                     enhanced one segmentVessels.m works from)
%       distFromDisc- distance from discCenter to the segment's midpoint
%       label       - 'artery' | 'vein' (see below for how this is decided)
%
%   UNVALIDATED, same status as this project's other first-pass classical-
%   CV detectors: no ground-truth artery/vein annotation was available in
%   this project at the time of writing to check the classification
%   against (the public INSPIRE-AVR / AVRDB datasets exist for exactly
%   this purpose and are the natural next step to validate against,
%   per README).
%
%   Method: skeletonize the vessel mask, split at branch points to get
%   individual segments (a full vessel TREE separation -- distinguishing
%   the artery tree from the vein tree as connected structures -- is a
%   much harder unsolved problem here; this only classifies independent
%   short segments, which is sufficient for the zone-B width sampling
%   computeAVR.m needs, but should NOT be read as "this pixel's vessel
%   identity is known with tree-level confidence").
%
%   Artery/vein color heuristic: retinal arterioles carry more oxygenated
%   blood and appear lighter, more orange-red; venules appear darker, more
%   blue-red/purple. This is classic, pre-deep-learning AVR literature
%   (the same visual cue ophthalmologists use). Implemented as a per-image
%   RELATIVE split (2-cluster k-means on colorScore, not a fixed global
%   threshold) rather than an absolute threshold, since raw color balance
%   varies a lot across camera models and lighting -- a relative split
%   within one image is far more robust to that than any single hardcoded
%   cutoff would be.

skel = bwskel(vesselMask, 'MinBranchLength', 8);
branchPts = bwmorph(skel, 'branchpoints');
segMask = skel & ~imdilate(branchPts, strel('disk', 1));

cc = bwconncomp(segMask, 8);
MIN_SEGMENT_LENGTH = 10; % pixels; shorter fragments are mostly noise from the branch-point removal itself

segments = struct('pixelIdx', {}, 'endpoints', {}, 'chordLength', {}, ...
    'arcLength', {}, 'meanWidth', {}, 'colorScore', {}, 'distFromDisc', {}, 'label', {});

distTransform = bwdist(~vesselMask);
red = double(img(:, :, 1));
green = double(img(:, :, 2));

for i = 1:cc.NumObjects
    idx = cc.PixelIdxList{i};
    if numel(idx) < MIN_SEGMENT_LENGTH
        continue;
    end
    [ys, xs] = ind2sub(size(segMask), idx);

    % Order points along the segment by nearest-neighbor chaining from one
    % extreme point, so arc length is a real path length, not just "sum of
    % pixel count" (which ignores diagonal steps).
    pts = [xs, ys];
    [~, startIdx] = max(pts(:, 1) + pts(:, 2)); % arbitrary consistent start: max x+y corner
    ordered = orderPointsByProximity(pts, startIdx);

    endpoints = [ordered(1, :); ordered(end, :)];
    chordLength = norm(endpoints(1, :) - endpoints(2, :));
    arcLength = sum(sqrt(sum(diff(ordered, 1, 1).^2, 2)));

    meanWidth = mean(distTransform(idx)) * 2; % distance transform gives radius to nearest background

    footprint = false(size(vesselMask));
    footprint(idx) = true;
    footprint = imdilate(footprint, strel('disk', max(1, round(meanWidth))));
    colorScore = mean(red(footprint)) - mean(green(footprint));

    midpoint = mean(ordered, 1);
    distFromDisc = norm(midpoint - discCenter);

    segments(end+1) = struct( ... %#ok<AGROW>
        'pixelIdx', idx, 'endpoints', endpoints, 'chordLength', chordLength, ...
        'arcLength', arcLength, 'meanWidth', meanWidth, 'colorScore', colorScore, ...
        'distFromDisc', distFromDisc, 'label', ''); %#ok<AGROW>
end

if numel(segments) < 4
    % Too few segments to do a meaningful 2-cluster split -- leave
    % unlabeled rather than force a split on noise.
    return;
end

scores = [segments.colorScore]';
warning('off', 'stats:kmeans:FailedToConvergeRep');
try
    clusterIdx = kmeans(scores, 2, 'Replicates', 3);
    warning('on', 'stats:kmeans:FailedToConvergeRep');
    meanByCluster = [mean(scores(clusterIdx == 1)), mean(scores(clusterIdx == 2))];
    [~, arteryCluster] = max(meanByCluster); % higher R-G score = artery-like
    for i = 1:numel(segments)
        if clusterIdx(i) == arteryCluster
            segments(i).label = 'artery';
        else
            segments(i).label = 'vein';
        end
    end
catch
    warning('on', 'stats:kmeans:FailedToConvergeRep');
    % Statistics and Machine Learning Toolbox's kmeans failed (e.g. all
    % scores identical) -- leave labels empty rather than guess.
end

end

% ---- helpers ----------------------------------------------------------

function ordered = orderPointsByProximity(pts, startIdx)
%ORDERPOINTSBYPROXIMITY Greedy nearest-neighbor chain through a small set
%   of pixel coordinates, approximating the point order along a thin
%   1-pixel-wide skeleton segment (which isn't naturally in path order
%   once extracted via bwconncomp's linear indexing).
n = size(pts, 1);
visited = false(n, 1);
ordered = zeros(n, 2);
current = startIdx;
for k = 1:n
    ordered(k, :) = pts(current, :);
    visited(current) = true;
    remaining = find(~visited);
    if isempty(remaining)
        break;
    end
    d = sum((pts(remaining, :) - pts(current, :)).^2, 2);
    [~, nearest] = min(d);
    current = remaining(nearest);
end
end
