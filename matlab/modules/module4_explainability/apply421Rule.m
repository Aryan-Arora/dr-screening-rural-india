function result = apply421Rule(hemorrhageCentroids, discCenter, cnnIcdrLevel)
%APPLY421RULE Clinical "4-2-1 rule" cross-check for Severe NPDR (ICDR
%   Level 3), per the PRD's Module 3 requirement.
%   result = APPLY421RULE(hemorrhageCentroids, discCenter, cnnIcdrLevel)
%
%   PARTIAL IMPLEMENTATION -- stated plainly: the real 4-2-1 rule is
%   three independent criteria (any one triggers Severe NPDR):
%     1. >20 hemorrhages in ALL 4 quadrants
%     2. Venous beading in 2+ quadrants
%     3. IRMA (intraretinal microvascular abnormalities) in 1+ quadrant
%   Only criterion 1 is implemented. Criteria 2 and 3 were both attempted
%   and deliberately NOT shipped, on the same "don't fabricate a number"
%   principle used throughout this project's other lesion detectors:
%     - Venous beading: measured vessel-caliber coefficient-of-variation
%       along major vessel segments (skeleton + distance-transform width,
%       tapering tips trimmed to kill discretization noise). The
%       methodology is sound -- false positives from thin/tapering
%       vessels were successfully eliminated -- but it found ZERO
%       candidates in every test image available, and with no confirmed
%       ground-truth case of real beading to check against, there's no
%       way to tell whether that's a correct "no beading present" or a
%       miscalibrated threshold. Shipping a count here would imply
%       confidence the evidence doesn't support.
%     - IRMA: tried thin-vessel tortuosity (arc-length/chord-length
%       ratio). Found a weak signal in the plausible direction (max
%       tortuosity 1.72 on a pathological sample vs 1.23 on a healthy
%       one) but nowhere near a confident detection at any reasonable
%       threshold. IRMA is widely considered one of the hardest DR
%       features to detect even in published literature with far more
%       sophisticated methods -- genuinely hard to distinguish from
%       normal vessel variation or early neovascularization even for
%       trained specialists, let alone a classical-CV heuristic.
%   This function can only ever confirm Severe NPDR via hemorrhage count,
%   never rule it out via the other two pathways -- a real, stated
%   limitation, not a silent gap.
%
%   Quadrants are purely geometric (image divided into 4 by two
%   perpendicular lines through the optic disc center), NOT anatomically
%   labeled (superior-temporal, etc.) -- that labeling needs eye
%   laterality (left/right) metadata this project doesn't track, but the
%   counting/thresholding the rule actually needs doesn't require it.
%
%   Empirically, this rule essentially never fires with this project's
%   current hemorrhage detector: real test images returned 0-3
%   hemorrhage-like candidates total, nowhere near >20 per quadrant. Not
%   necessarily a bug -- could mean the detector under-counts, or that
%   no test image so far was genuinely Severe NPDR, or both. Worth
%   revisiting once Module 2's hemorrhage detection has real validation.
%
%   Returns a struct:
%       quadrantCounts       - 1x4 hemorrhage count per quadrant
%       meetsHemorrhageCriterion - true if all 4 quadrants exceed 20
%       ruleBasedGrade        - 3 if meetsHemorrhageCriterion, else []
%                                (NOT "confirmed non-severe" -- just "the
%                                one criterion checked wasn't met")
%       agreesWithCNN         - [] if ruleBasedGrade is [] (nothing to
%                                compare), else whether it matches
%                                cnnIcdrLevel >= 3

HEMORRHAGE_THRESHOLD_PER_QUADRANT = 20;

if isempty(hemorrhageCentroids)
    quadrantCounts = zeros(1, 4);
else
    dx = hemorrhageCentroids(:, 1) - discCenter(1);
    dy = hemorrhageCentroids(:, 2) - discCenter(2);
    % Quadrant 1: dx>=0,dy<0 ; 2: dx<0,dy<0 ; 3: dx<0,dy>=0 ; 4: dx>=0,dy>=0
    % (purely geometric -- see note above on why no anatomical labels)
    quadrantIdx = 1 + (dx < 0) + 2 * (dy >= 0);
    quadrantCounts = accumarray(quadrantIdx, 1, [4, 1])';
end

meetsHemorrhageCriterion = all(quadrantCounts > HEMORRHAGE_THRESHOLD_PER_QUADRANT);

result.quadrantCounts = quadrantCounts;
result.meetsHemorrhageCriterion = meetsHemorrhageCriterion;

if meetsHemorrhageCriterion
    result.ruleBasedGrade = 3;
else
    result.ruleBasedGrade = [];
end

if nargin >= 3 && ~isempty(cnnIcdrLevel) && ~isempty(result.ruleBasedGrade)
    result.agreesWithCNN = (cnnIcdrLevel >= 3) == meetsHemorrhageCriterion;
else
    result.agreesWithCNN = [];
end

end
