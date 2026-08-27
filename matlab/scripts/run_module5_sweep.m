%RUN_MODULE5_SWEEP Parameter sweep over staffing (NumDoctors) and AI
%   bandwidth (AICapacity) to find the throughput bottleneck and a
%   concrete resource-allocation recommendation for 100,000+
%   patients/year, per the PRD's Module 5 requirement.
%
%   Simulates 20 operating days back-to-back (160 hours at 8hr/day) rather
%   than literally modeling day/night gaps -- a stated simplification for
%   statistical stability, not a claim about real clinic hours.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules', 'module5_simulink'));

% First pass at fixed 100k/year showed <6% utilization everywhere from
% 1 doctor/1 AI slot upward -- not a useful "find the bottleneck" result.
% Sweeping annual patient volume (i.e. district population size) instead
% is what actually reveals where staffing starts to matter.
doctorLevels = [1, 2, 4];
aiLevels = [1, 2];
annualVolumes = [100000, 300000, 600000, 1000000, 1500000];
SIM_HOURS = 8 * 20; % 20 operating days back-to-back
OPERATING_HOURS_PER_YEAR = 8 * 300;

results = struct('annualVolume', {}, 'numDoctors', {}, 'aiCapacity', {}, 'summary', {});
idx = 1;
for vol = annualVolumes
    arrivalRate = vol / OPERATING_HOURS_PER_YEAR;
    for nd = doctorLevels
        for na = aiLevels
            s = DRScreeningQueueSim('ArrivalRatePerHour', arrivalRate, 'NumDoctors', nd, ...
                'AICapacity', na, 'SimHours', SIM_HOURS, 'RandSeed', 42);
            summary = DRScreeningQueueSim.asSummaryStruct(step(s));
            results(idx).annualVolume = vol;
            results(idx).numDoctors = nd;
            results(idx).aiCapacity = na;
            results(idx).summary = summary;
            idx = idx + 1;
        end
    end
end

fprintf('%-12s %-8s %-8s %-12s %-14s %-12s %-14s\n', ...
    'AnnualVol', 'Doctors', 'AISlots', 'AI_wait(s)', 'AI_util(%)', 'Doc_wait(s)', 'Doc_util(%)');
for i = 1:numel(results)
    r = results(i);
    fprintf('%-12d %-8d %-8d %-12.1f %-14.1f %-12.1f %-14.1f\n', ...
        r.annualVolume, r.numDoctors, r.aiCapacity, r.summary.meanAIWaitSec, r.summary.aiUtilization*100, ...
        r.summary.meanDoctorWaitSec, r.summary.doctorUtilization*100);
end

save(fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'module5_sweep_results.mat'), 'results');
