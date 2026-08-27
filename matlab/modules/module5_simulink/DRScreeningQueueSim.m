classdef DRScreeningQueueSim < matlab.System
    %DRSCREENINGQUEUESIM Discrete-event simulation of the district
    %   screening workflow: patient arrival -> quality-gate capture/
    %   recapture loop -> AI processing queue -> ophthalmologist review
    %   queue for AI-flagged referable cases.
    %
    %   PRD Module 5 asks for "Simulink (SimEvents if available)". SimEvents
    %   is NOT installed in this environment (license flag says yes,
    %   product files say no -- verified by trying to load its library).
    %   Hand-authoring a Stateflow chart via text/API without interactive
    %   GUI access is unreliable to get right blind, so the actual
    %   discrete-event logic lives here, in a MATLAB System object -- a
    %   standard, text-file-authorable way to embed custom algorithms in
    %   a Simulink model. buildSimulinkModel.m wraps this in an actual
    %   .slx model, so the PRD's "in Simulink" requirement is still met;
    %   the event-driven simulation itself uses a classic next-event
    %   time-advance algorithm (sort pending events by time, advance the
    %   clock, process, repeat) rather than a fixed Simulink time step,
    %   since patient arrivals are a continuous-time Poisson process, not
    %   naturally aligned to any fixed step size.
    %
    %   ASSUMPTIONS (no real district data available; these are stated
    %   estimates, not measured facts -- treat outputs as directional,
    %   not a commitment, until validated against real operational data):
    %     - QualityRejectRate = 0.15: portable/field-camera ungradable
    %       rate. Module 1's own calibration used DRIMDB's artificially
    %       50/50 Good/Bad split for testing, NOT a real-world prevalence
    %       estimate -- 0.15 is a separate, literature-typical guess for
    %       field-quality capture rates, not derived from that data.
    %     - ReferableRate = 0.10: population prevalence of referable DR
    %       among screened diabetics. Explicitly NOT the ~45% referable
    %       rate in Module 3's training data -- that set was deliberately
    %       class-balanced for training, not representative of true
    %       population prevalence, which published screening literature
    %       puts far lower.
    %     - AIProcessingTimeSec = 5: total quality-gate + segmentation +
    %       ensemble-inference time for a WARM, already-loaded production
    %       service. Explicitly NOT the ~25 sec measured in the bridge
    %       server end-to-end test -- that number includes spawning a
    %       fresh MATLAB process and loading 3 pretrained CNNs from disk
    %       per request, a hackathon-simple architectural choice, not
    %       what a real persistent deployment would do. 5 sec is a rough
    %       estimate from the per-image forward-pass benchmarks taken
    %       during Module 3 development (~0.5-1 sec/image/network).
    %     - DoctorReviewTimeSec = 30: directly from the PRD's own success
    %       metric ("Ophthalmologist validation time per case < 30 sec"),
    %       not a separate guess.
    %     - RecaptureDelaySec = 180, MaxRecaptureAttempts = 3.

    properties (Nontunable)
        ArrivalRatePerHour = 42       % ~100,000/year over ~300 operating days, 8hr/day
        NumDoctors = 2
        AICapacity = 1                % parallel AI processing "slots" (bandwidth cap)
        SimHours = 24
        RandSeed = 42

        QualityRejectRate = 0.15
        ReferableRate = 0.10
        AIProcessingTimeSec = 5
        DoctorReviewTimeSec = 30
        RecaptureDelaySec = 180
        MaxRecaptureAttempts = 3
    end

    methods
        function obj = DRScreeningQueueSim(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Static)
        function names = outputFieldNames()
            %OUTPUTFIELDNAMES Fixed order of stepImpl's output vector.
            %   A MATLAB System block's output can't be a struct without
            %   defining a Simulink.Bus type for it -- returning a plain
            %   numeric vector avoids that, at the cost of losing
            %   self-documenting field names on the raw signal. This is
            %   the single source of truth for what each vector element
            %   means, used by asSummaryStruct below and by any script
            %   that calls step() directly.
            names = {'numPatients', 'numFailedCapture', 'numRecaptures', ...
                'numReferable', 'meanAIWaitSec', 'maxAIWaitSec', 'aiUtilization', ...
                'meanDoctorWaitSec', 'maxDoctorWaitSec', 'doctorUtilization', ...
                'throughputPerHour', 'projectedAnnualThroughput'};
        end

        function s = asSummaryStruct(vec)
            %ASSUMMARYSTRUCT Convert stepImpl's output vector back to a
            %   labeled struct for display/analysis outside Simulink.
            names = DRScreeningQueueSim.outputFieldNames();
            s = cell2struct(num2cell(vec(:)), names(:));
        end
    end

    methods (Access = protected)
        function [summaryVec] = stepImpl(obj)
            rng(obj.RandSeed);
            simEndSec = obj.SimHours * 3600;
            arrivalRateSec = obj.ArrivalRatePerHour / 3600;

            % ---- Generate arrivals (Poisson process) ----
            t = 0;
            arrivals = [];
            while true
                t = t + exprnd(1 / arrivalRateSec);
                if t > simEndSec
                    break;
                end
                arrivals(end+1) = t; %#ok<AGROW>
            end
            numPatients = numel(arrivals);

            % ---- Capture/recapture loop: determine when each patient's
            % image becomes AI-ready, and whether they ever succeed ----
            aiReadyTime = zeros(1, numPatients);
            failedCapture = false(1, numPatients);
            numRecaptures = 0;
            for i = 1:numPatients
                readyTime = arrivals(i);
                attempts = 0;
                while rand() < obj.QualityRejectRate && attempts < obj.MaxRecaptureAttempts
                    readyTime = readyTime + obj.RecaptureDelaySec;
                    attempts = attempts + 1;
                    numRecaptures = numRecaptures + 1;
                end
                if attempts >= obj.MaxRecaptureAttempts && rand() < obj.QualityRejectRate
                    failedCapture(i) = true;
                end
                aiReadyTime(i) = readyTime;
            end

            validIdx = find(~failedCapture);
            [aiReadyTimeSorted, sortOrder] = sort(aiReadyTime(validIdx));
            validIdx = validIdx(sortOrder);
            numValid = numel(validIdx);

            % ---- AI processing queue: c parallel servers (next-event
            % time-advance -- track when each of the c servers frees up,
            % assign each arrival to the server that frees soonest) ----
            aiServerFreeAt = zeros(1, obj.AICapacity);
            aiStartTime = zeros(1, numValid);
            aiWait = zeros(1, numValid);
            for i = 1:numValid
                [serverFreeTime, serverIdx] = min(aiServerFreeAt);
                startTime = max(aiReadyTimeSorted(i), serverFreeTime);
                aiStartTime(i) = startTime;
                aiWait(i) = startTime - aiReadyTimeSorted(i);
                aiServerFreeAt(serverIdx) = startTime + obj.AIProcessingTimeSec;
            end
            aiDoneTime = aiStartTime + obj.AIProcessingTimeSec;

            % ---- Referable cases enter the doctor review queue; only
            % referable cases per the PRD's own workflow (ophthalmologist
            % reviews AI-FLAGGED cases, not every capture) ----
            isReferable = rand(1, numValid) < obj.ReferableRate;
            referableIdx = find(isReferable);
            numReferable = numel(referableIdx);

            [docReadyTimeSorted, docSortOrder] = sort(aiDoneTime(referableIdx));
            docServerFreeAt = zeros(1, obj.NumDoctors);
            docWait = zeros(1, numReferable);
            docStartTime = zeros(1, numReferable);
            for i = 1:numReferable
                [serverFreeTime, serverIdx] = min(docServerFreeAt);
                startTime = max(docReadyTimeSorted(i), serverFreeTime);
                docStartTime(i) = startTime;
                docWait(i) = startTime - docReadyTimeSorted(i);
                docServerFreeAt(serverIdx) = startTime + obj.DoctorReviewTimeSec;
            end
            docDoneTime = docStartTime + obj.DoctorReviewTimeSec; %#ok<NASGU>

            % ---- Summary ----
            % Plain numeric vector, not a struct -- a MATLAB System
            % block's struct/bus output needs an explicit Simulink.Bus
            % type definition to run inside Simulink, which a plain
            % vector avoids. Field order is outputFieldNames() above;
            % asSummaryStruct() converts back for display outside Simulink.
            throughputPerHour = numPatients / obj.SimHours;
            summaryVec = [ ...
                numPatients, ...
                sum(failedCapture), ...
                numRecaptures, ...
                numReferable, ...
                mean(aiWait), ...
                max([aiWait, 0]), ...
                (numValid * obj.AIProcessingTimeSec) / (obj.SimHours * 3600 * obj.AICapacity), ...
                mean(docWait), ...
                max([docWait, 0]), ...
                (numReferable * obj.DoctorReviewTimeSec) / (obj.SimHours * 3600 * obj.NumDoctors), ...
                throughputPerHour, ...
                throughputPerHour * 8 * 300]; % 8hr/day, 300 operating days/year
        end

        function resetImpl(~)
        end
    end
end
