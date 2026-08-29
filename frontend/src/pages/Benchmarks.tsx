import { StatusLegend } from '../components/ui/StatusLegend'

const backboneRuns = [
  { name: 'EfficientNet-B0', acc: '72.9%', sens: '86.6%', spec: '91.2%' },
  { name: 'ResNet50', acc: '77.4%', sens: '90.5%', spec: '92.3%' },
  { name: 'DenseNet201', acc: '76.3%', sens: '83.8%', spec: '95.8%' },
]

const history = [
  {
    stage: '01',
    title: 'First pilot',
    detail: '714 images, no class weighting. 57% accuracy, 76-81% sensitivity per backbone -- missed the >90% target. Class 2 (the referable boundary) was the universal confusion bottleneck.',
    verdict: 'target missed', tone: 'bad',
  },
  {
    stage: '02',
    title: 'EyePACS blend attempt',
    detail: 'Added EyePACS (2015 Kaggle competition, same label scale) for volume. Made things WORSE: 60% accuracy on APTOS-only vs. 36% on EyePACS-only within the same blended test set -- a real domain gap, not a calibration issue.',
    verdict: 'reverted', tone: 'bad',
  },
  {
    stage: '03',
    title: 'APTOS-only, full pool',
    detail: '2,930 images, class-weighted loss, all 3 backbones retrained. Naive-argmax ensemble: 82.5% accuracy, 90.5% sensitivity, 95.8% specificity on a 439-image test set -- both PRD targets met with real margin, no threshold trick needed. The best naive-argmax result of the project, though a later retrain on the same data + approach (stage 05) landed a few points lower -- a real reminder that training is stochastic and single-run point estimates carry noise.',
    verdict: 'target met', tone: 'good',
  },
  {
    stage: '04',
    title: 'APTOS + IDRiD + DDR blend',
    detail: '5,434 images (real class-3/4 boost: 474/1,211 vs. 108/164), 5 backbones. Per-source breakdown confirmed the SAME domain-gap pattern as EyePACS: aptos 82.2% vs. ddr 68.1%/idrid 68.0%. Every backbone individually got worse. Ensemble fell to 75.6%/89.3%/93.8% -- below the old result and below the PRD sensitivity target.',
    verdict: 'regression, reverted', tone: 'bad',
  },
  {
    stage: '05',
    title: 'APTOS-only retrain, 5 backbones',
    detail: 'Reverted to the proven-good data, kept the 2 new backbones (Xception, InceptionResNetV2) from stage 04 to see if they helped on clean data. Naive-argmax ensemble: 78.8% accuracy, 88.3% sensitivity, 93.8% specificity -- recovered most of the regression but still missed the sensitivity target on raw argmax.',
    verdict: 'target missed (pre-calibration)', tone: 'warn',
  },
  {
    stage: '06',
    title: 'Post-hoc calibration (both ensemble sizes)',
    detail: 'Temperature scaling + re-swept referable threshold, no retraining -- same technique already proven in stage 03. Both the 5-backbone and the simpler 3-backbone ensemble hit 95.5% sensitivity / 90.8% specificity, exactly identical. Since the 2 extra backbones bought zero accuracy once calibrated, the 3-backbone ensemble is what actually ships in run_pipeline.m.',
    verdict: 'target met, deployed', tone: 'good',
  },
]

export function Benchmarks() {
  return (
    <div className="benchmarks-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">VALIDATION &amp; BENCHMARKS</p>
        <h2>REAL NUMBERS, <em>REAL HISTORY.</em></h2>
        <p className="body-copy">
          Every number on this page is from an actual training run and test-set evaluation --
          including the ones that didn't work. A negative result with real evidence behind it is
          more credible than a project with no failed experiments at all.
        </p>
      </header>

      <section className="bench-section">
        <p className="eyebrow">PRD TARGETS</p>
        <div className="bench-targets">
          <div><b>&gt;90%</b><span>Referable Sensitivity</span></div>
          <div><b>&gt;85%</b><span>Referable Specificity</span></div>
        </div>
        <p className="caveat">
          "Referable" = ICDR grade &ge;2 (Moderate NPDR or worse), the clinical threshold for
          specialist referral -- the PRD's actual success metric, not raw 5-class accuracy.
        </p>
      </section>

      <section className="bench-section">
        <p className="eyebrow">CURRENTLY DEPLOYED (APTOS-ONLY, 3 BACKBONES)</p>
        <div className="bench-table">
          <div className="bench-row bench-row--head"><span>Backbone</span><span>5-class acc.</span><span>Sensitivity</span><span>Specificity</span></div>
          {backboneRuns.map((r) => (
            <div className="bench-row" key={r.name}><span>{r.name}</span><span>{r.acc}</span><span>{r.sens}</span><span>{r.spec}</span></div>
          ))}
          <div className="bench-row"><span>Ensemble (naive argmax)</span><span>79.0%</span><span>86.6%</span><span>95.0%</span></div>
          <div className="bench-row bench-row--ensemble"><span>Ensemble (calibrated) — LIVE</span><span>—</span><span>95.5%</span><span>90.8%</span></div>
        </div>
        <p className="caveat">
          439-image held-out test set, fixed seed, class-weighted cross-entropy. The naive-argmax
          ensemble alone falls short of the sensitivity target -- post-hoc temperature scaling +
          a re-swept referable threshold (no retraining, see Methodology below) is what actually
          closes the gap, and is what <code>run_pipeline.m</code> uses in production. A 5-backbone
          version (adding Xception + InceptionResNetV2) was also trained and calibrated
          separately -- it landed at the exact same 95.5%/90.8% after calibration, so the extra
          2 backbones' inference cost bought nothing, and the simpler 3-backbone ensemble is what
          actually ships.
        </p>
      </section>

      <section className="bench-section">
        <p className="eyebrow">TRAINING HISTORY</p>
        <StatusLegend />
        <div className="bench-history">
          {history.map((h) => (
            <div className="bench-history-item" key={h.stage}>
              <span className="bench-history-stage">{h.stage}</span>
              <div>
                <p className="bench-history-title">{h.title} <span className={`status-tag bench-verdict--${h.tone}`}>{h.verdict.toUpperCase()}</span></p>
                <p className="body-copy">{h.detail}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="bench-section">
        <p className="eyebrow">METHODOLOGY NOTES</p>
        <ul className="bench-notes">
          <li>Fixed-seed 70/15/15 train/val/test split, shared identically across every backbone so ensembling and per-backbone comparison are valid.</li>
          <li>Test-time augmentation (4 views per backbone: identity, horizontal flip, ±10° rotation) before ensembling -- a genuine variance-reduction technique, not cosmetic.</li>
          <li>Post-hoc temperature scaling + re-swept referable threshold (no retraining) -- needs re-running after every architecture/data change, since it's specific to whichever ensemble is currently trained.</li>
          <li>CPU-only training throughout -- no GPU or Parallel Computing Toolbox in this environment.</li>
        </ul>
      </section>
    </div>
  )
}
