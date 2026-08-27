function result = classifyHypertensiveRetinopathy(avrResult)
%CLASSIFYHYPERTENSIVERETINOPATHY Simplified generalized-arteriolar-
%   narrowing grade from AVR alone.
%   result = CLASSIFYHYPERTENSIVERETINOPATHY(avrResult) takes computeAVR.m's
%   output struct and returns:
%       grade  - 0 (normal), 1 (mild narrowing), 2 (moderate narrowing), or
%                [] if avrResult.usable is false
%       label  - human-readable string for `grade`
%       gradable - false if avrResult wasn't usable
%
%   **Important scope limitation, stated plainly**: real hypertensive
%   retinopathy grading (Keith-Wagener-Barker or the modified Scheie
%   scale) is a 4-grade system that also requires focal arteriolar
%   narrowing, AV nicking, flame hemorrhages / cotton-wool spots, and
%   (grade 4) papilledema -- none of which this project has a dedicated,
%   validated detector for. Reusing Module 2's DR-oriented hemorrhage/
%   exudate detectors here would misrepresent DR lesion morphology as
%   hypertensive-retinopathy morphology, which are not the same finding
%   clinically, so that was deliberately NOT done. This function only
%   grades the GENERALIZED ARTERIOLAR NARROWING component via AVR, which
%   is real but is one sign among several -- it cannot distinguish grade
%   3/4 (accelerated/malignant hypertensive retinopathy) from grade 2 at
%   all, since that distinction requires exactly the signs above. Treat
%   `grade` as "narrowing severity 0-2", not a full clinical HTN
%   retinopathy stage.
%
%   Thresholds (normal AVR ~0.66-0.75 in most population studies; used
%   here as the standard reference points, not independently recalibrated
%   against local ground truth -- same unvalidated status as the rest of
%   Module 6):
%       AVR >= 0.66         -> grade 0, "no generalized narrowing"
%       0.50 <= AVR < 0.66  -> grade 1, "mild generalized narrowing"
%       AVR < 0.50          -> grade 2, "moderate-to-severe generalized narrowing"

if ~avrResult.usable || isempty(avrResult.AVR)
    result.grade = [];
    result.label = [];
    result.gradable = false;
    return;
end

avr = avrResult.AVR;
if avr >= 0.66
    grade = 0;
    label = 'no generalized arteriolar narrowing';
elseif avr >= 0.50
    grade = 1;
    label = 'mild generalized arteriolar narrowing';
else
    grade = 2;
    label = 'moderate-to-severe generalized arteriolar narrowing';
end

result.grade = grade;
result.label = label;
result.gradable = true;

end
