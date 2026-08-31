/**
 * Real output from module5_sweep_results.mat (Module 5's Simulink
 * discrete-event clinic simulation), extracted directly from the .mat
 * file — not estimated or hand-typed. Full sweep has 30 rows (5 annual
 * volumes x 2 AI capacities x 3 doctor counts); this is the specific
 * slice (numDoctors=1, aiCapacity 1 vs. 2) that produces the headline
 * finding documented in the project README: AI processing capacity, not
 * doctor staffing, is the binding bottleneck at scale.
 */
export interface SweepPoint {
  volume: number
  volumeLabel: string
  aiUtil1Slot: number
  aiUtil2Slot: number
  doctorUtil1Doc: number
}

export const module5Sweep: SweepPoint[] = [
  { volume: 100000, volumeLabel: '100k', aiUtil1Slot: 5.7, aiUtil2Slot: 2.9, doctorUtil1Doc: 3.4 },
  { volume: 300000, volumeLabel: '300k', aiUtil1Slot: 17.3, aiUtil2Slot: 8.7, doctorUtil1Doc: 10.4 },
  { volume: 600000, volumeLabel: '600k', aiUtil1Slot: 34.7, aiUtil2Slot: 17.3, doctorUtil1Doc: 21.3 },
  { volume: 1000000, volumeLabel: '1.0M', aiUtil1Slot: 57.8, aiUtil2Slot: 28.9, doctorUtil1Doc: 34.9 },
  { volume: 1500000, volumeLabel: '1.5M', aiUtil1Slot: 86.7, aiUtil2Slot: 43.3, doctorUtil1Doc: 52.2 },
]
