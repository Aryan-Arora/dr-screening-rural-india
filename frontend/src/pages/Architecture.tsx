import { ScanEye, Layers, Gauge, Lightbulb, GitBranch, HeartPulse } from 'lucide-react'
import { PipelineDiagram } from '../components/architecture/PipelineDiagram'
import { ServingDiagram } from '../components/architecture/ServingDiagram'
import { StatusLegend } from '../components/ui/StatusLegend'

const modules = [
  { n: '01', icon: ScanEye, name: 'Quality Gate', detail: 'Focus, illumination, and field-of-view scoring on a calibrated classical CV pipeline. Calibrated against 45 real images across 2 camera profiles (APTOS + DRIMDB).', status: 'calibrated', tone: 'good' },
  { n: '02', icon: Layers, name: 'Segmentation', detail: 'Disc/fovea localization with physically-grounded confidence flags, vessel segmentation, and first-pass classical lesion detectors (microaneurysms, hemorrhages, exudates).', status: 'unvalidated lesions', tone: 'warn' },
  { n: '03', icon: Gauge, name: 'Severity Grading', detail: '3-backbone CNN ensemble (EfficientNet-B0, ResNet50, DenseNet201), test-time augmentation, post-hoc calibration (95.5% sensitivity / 90.8% specificity). Xception + InceptionResNetV2 were also trained and calibrated as a 5-backbone variant -- identical calibrated result, so the simpler 3-backbone ensemble is what actually ships.', status: 'meets PRD targets', tone: 'good' },
  { n: '04', icon: Lightbulb, name: 'Explainability', detail: 'Grad-CAM attention maps (one designated backbone, DenseNet201) correlated against Module 2\'s independently-detected lesions, plus the clinical 4-2-1 rule\'s hemorrhage criterion.', status: 'partial', tone: 'warn' },
  { n: '05', icon: GitBranch, name: 'Deployment Simulation', detail: 'A Simulink discrete-event model of the real clinic workflow -- found AI processing capacity, not doctor staffing, is the binding bottleneck at scale.', status: 'built + swept', tone: 'good' },
  { n: '06', icon: HeartPulse, name: 'Vascular / Cerebrovascular Risk', detail: 'A parallel side-pipeline (not DR grading) estimating stroke/vascular-dementia risk from AVR, tortuosity, and fractal dimension. Explicitly not a stroke or Alzheimer\'s diagnostic.', status: 'heuristic, unvalidated', tone: 'bad' },
]

export function Architecture() {
  return (
    <div className="architecture-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">SYSTEM ARCHITECTURE</p>
        <h2>SIX MODULES, <em>ONE PIPELINE.</em></h2>
        <p className="body-copy">
          MATLAB/Simulink pipeline, Node/Express bridge server, React frontend. Every stage below
          is real and running -- this isn't a diagram of a plan, it's a description of what
          actually executes on a real image right now.
        </p>
      </header>

      <div className="diagram-frame">
        <PipelineDiagram />
      </div>

      <StatusLegend />

      <div className="arch-modules">
        {modules.map((m) => {
          const Icon = m.icon
          return (
            <div className="arch-module" key={m.n}>
              <div className={`arch-module-icon arch-module-icon--${m.tone}`}><Icon size={20} /></div>
              <div>
                <h3><span className="arch-module-n">{m.n}</span> {m.name} <span className={`status-tag arch-status arch-status--${m.tone}`}>{m.status.toUpperCase()}</span></h3>
                <p className="body-copy">{m.detail}</p>
              </div>
            </div>
          )
        })}
      </div>

      <section className="bench-section">
        <p className="eyebrow">SERVING ARCHITECTURE</p>
        <p className="body-copy">
          The bridge server spawns a fresh headless <code>matlab -batch</code> process per request
          (per the original spec), waits for it to finish, and returns the fixed JSON contract.
          This pays MATLAB's ~7-25s startup + model-loading cost on every request -- simple and
          correct, but a real latency cost. A persistent MATLAB engine session would remove it if
          latency becomes a real problem at higher request volume.
        </p>
        <div className="diagram-frame diagram-frame--compact">
          <ServingDiagram />
        </div>
      </section>

      <section className="bench-section">
        <p className="eyebrow">HONEST GAPS, NOT HIDDEN</p>
        <ul className="bench-notes">
          <li>Neovascularization detection: not attempted -- PRD explicitly scopes this as optional/future work.</li>
          <li>Venous beading and IRMA (part of the 4-2-1 rule): genuinely attempted, not shipped -- no confirmed ground-truth case to calibrate against, so no confident number exists to report.</li>
          <li>Lesion detectors (microaneurysms, hemorrhages, exudates): real, working, classical CV -- but unvalidated against pixel-level ground truth. Treat counts as a rough signal, not a clinical number.</li>
          <li>Auto-generated annotated report (<code>report_url</code>): not implemented, stays null.</li>
        </ul>
      </section>
    </div>
  )
}
