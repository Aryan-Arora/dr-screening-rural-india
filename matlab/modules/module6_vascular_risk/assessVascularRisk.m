function result = assessVascularRisk(img, vesselMask, discCenter, discRadius)
%ASSESSVASCULARRISK Module 6 entry point: runs the full vascular-risk
%   side-pipeline on one already-segmented image and packages the result.
%   result = ASSESSVASCULARRISK(img, vesselMask, discCenter, discRadius)
%   takes the ORIGINAL (non-enhanced) image plus Module 2's vessel mask
%   and disc localization, and returns:
%       avr                    - computeAVR.m output
%       tortuosity             - computeTortuosity.m output
%       fractalDimension       - computeFractalDimension.m output
%       hypertensiveRetinopathy- classifyHypertensiveRetinopathy.m output
%       cerebrovascularRisk    - computeCerebrovascularRiskScore.m output
%       numSegments            - total classified vessel segments found
%
%   This is the "second, parallel pipeline" that runs alongside Modules
%   2-4's DR grading, both starting from the same Module 1 quality-gated
%   image: Module 2 supplies vessel/disc geometry once, and this module
%   reads it independently to assess a DIFFERENT condition family
%   (vascular/cerebrovascular risk) rather than DR severity. See each
%   sub-function's own header comment for validation status and honest
%   caveats -- summarized: every number in this module is a first-pass,
%   UNVALIDATED classical-CV/heuristic signal, not a clinically
%   calibrated diagnostic. This module explicitly does NOT detect
%   Alzheimer's disease or any amyloid/tau-driven condition -- see
%   computeCerebrovascularRiskScore.m for why.

segments = classifyVesselSegments(img, vesselMask, discCenter, discRadius);

avr = computeAVR(segments, discRadius);
tortuosity = computeTortuosity(segments);
fractalDimension = computeFractalDimension(vesselMask, discCenter, discRadius);
hypertensiveRetinopathy = classifyHypertensiveRetinopathy(avr);
cerebrovascularRisk = computeCerebrovascularRiskScore(avr, tortuosity, fractalDimension);

result.avr = avr;
result.tortuosity = tortuosity;
result.fractalDimension = fractalDimension;
result.hypertensiveRetinopathy = hypertensiveRetinopathy;
result.cerebrovascularRisk = cerebrovascularRisk;
result.numSegments = numel(segments);

end
