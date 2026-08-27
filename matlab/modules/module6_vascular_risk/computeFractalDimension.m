function result = computeFractalDimension(vesselMask, discCenter, discRadius)
%COMPUTEFRACTALDIMENSION Box-counting fractal dimension of the retinal
%   vascular network within a disc-centered region of interest.
%   result = COMPUTEFRACTALDIMENSION(vesselMask, discCenter, discRadius)
%   returns:
%       Dbox   - estimated box-counting fractal dimension (typically
%                ~1.4-1.7 for a healthy human retinal vessel tree; higher
%                = denser/more space-filling branching, lower = sparser)
%       usable - false if the ROI contains too few vessel pixels to fit a
%                meaningful line (Dbox is then [])
%
%   Method: classic box-counting. Crop a square ROI centered on the disc
%   (radius 6x discRadius, clipped to the image -- wide enough to capture
%   real branching structure without needing the whole frame, matching
%   the region size used in most published retinal-fractal-dimension
%   studies, e.g. Cheung et al.'s work linking retinal fractal dimension
%   to stroke risk). Overlay square grids of side length 2,4,8,...,64 px,
%   count boxes containing >=1 vessel pixel at each scale, then Dbox is
%   the negative slope of log(count) vs log(boxSize) via least-squares --
%   the standard box-counting estimator.
%
%   UNVALIDATED like the rest of Module 6: no ground truth to check this
%   against in this project. The literature link (reduced retinal
%   vascular fractal dimension associated with increased stroke risk,
%   independent of traditional risk factors, in population studies like
%   the ARIC and Rotterdam cohorts) is real and cited here for context,
%   but this is a single-image research-grade implementation, not a
%   clinically calibrated measurement -- see
%   computeCerebrovascularRiskScore.m for how it's (heuristically)
%   combined with AVR and tortuosity.
%
%   **Caveat found via real-sample testing**: the ~1.4-1.7 "healthy"
%   range commonly cited is typically measured over the WHOLE fundus
%   image; this disc-centered 6x-radius ROI is a smaller, sparser region
%   by construction and reads systematically lower on both real test
%   images tried here (~1.36-1.40) -- a legitimate protocol-size effect,
%   not necessarily reduced vascular density. computeCerebrovascularRiskScore.m's
%   1.7-reference-point normalization was left as the literature default
%   rather than re-guessed off two samples; treat its fractal component
%   as directionally noisy until recalibrated against a real local
%   dataset with this exact ROI size.

MIN_VESSEL_PIXELS = 50;
ROI_RADIUS_IN_DISCS = 6;
BOX_SIZES = [2, 4, 8, 16, 32, 64];

[h, w] = size(vesselMask);
roiRadius = ROI_RADIUS_IN_DISCS * discRadius;

xMin = max(1, round(discCenter(1) - roiRadius));
xMax = min(w, round(discCenter(1) + roiRadius));
yMin = max(1, round(discCenter(2) - roiRadius));
yMax = min(h, round(discCenter(2) + roiRadius));

roi = vesselMask(yMin:yMax, xMin:xMax);

if nnz(roi) < MIN_VESSEL_PIXELS
    result.Dbox = [];
    result.usable = false;
    return;
end

[roiH, roiW] = size(roi);
counts = zeros(size(BOX_SIZES));
validSizes = true(size(BOX_SIZES));

for i = 1:numel(BOX_SIZES)
    b = BOX_SIZES(i);
    if b >= min(roiH, roiW)
        % ROI too small for this box scale to say anything -- drop it
        % rather than count a single degenerate box.
        validSizes(i) = false;
        continue;
    end
    nRows = ceil(roiH / b);
    nCols = ceil(roiW / b);
    padded = false(nRows * b, nCols * b);
    padded(1:roiH, 1:roiW) = roi;
    occupied = 0;
    for r = 1:nRows
        for c = 1:nCols
            block = padded((r-1)*b+1:r*b, (c-1)*b+1:c*b);
            if any(block(:))
                occupied = occupied + 1;
            end
        end
    end
    counts(i) = occupied;
end

BOX_SIZES = BOX_SIZES(validSizes);
counts = counts(validSizes);

if numel(BOX_SIZES) < 3
    % Need at least 3 points on the log-log plot for the slope fit to
    % mean anything.
    result.Dbox = [];
    result.usable = false;
    return;
end

logInvSize = log(1 ./ BOX_SIZES);
logCount = log(max(counts, 1));
p = polyfit(logInvSize, logCount, 1);

result.Dbox = p(1); % slope of log(N) vs log(1/boxSize) = fractal dimension
result.usable = true;

end
