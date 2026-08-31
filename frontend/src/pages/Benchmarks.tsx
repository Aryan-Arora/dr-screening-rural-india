import { Bar, BarChart, CartesianGrid, Legend, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { Fragment, useEffect, useRef, type RefObject } from 'react'
import { ArrowRight, CheckCircle2, ClipboardList } from 'lucide-react'
import { StatusLegend } from '../components/ui/StatusLegend'

/**
 * Slow, continuous ping-pong auto-scroll through the card track — pauses
 * the instant a pointer/touch enters so it never fights a user actually
 * trying to browse, and does nothing at all under reduced-motion. Ping-pong
 * (reverse direction at each end) rather than snapping back to the start,
 * so there's never a jarring jump mid-animation.
 */
function useAutoScroll(ref: RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const el = ref.current
    if (!el || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    let frame: number
    let paused = false
    let dir = 1
    const step = () => {
      if (!paused) {
        const max = el.scrollWidth - el.clientWidth
        if (max > 0) {
          el.scrollLeft += 0.5 * dir
          if (el.scrollLeft >= max - 1) dir = -1
          else if (el.scrollLeft <= 1) dir = 1
        }
      }
      frame = requestAnimationFrame(step)
    }
    frame = requestAnimationFrame(step)
    const pause = () => { paused = true }
    const resume = () => { paused = false }
    el.addEventListener('pointerenter', pause)
    el.addEventListener('pointerleave', resume)
    el.addEventListener('pointerdown', pause)
    el.addEventListener('touchstart', pause, { passive: true })
    el.addEventListener('touchend', resume)
    return () => {
      cancelAnimationFrame(frame)
      el.removeEventListener('pointerenter', pause)
      el.removeEventListener('pointerleave', resume)
      el.removeEventListener('pointerdown', pause)
      el.removeEventListener('touchstart', pause)
      el.removeEventListener('touchend', resume)
    }
  }, [ref])
}

const kpis = [
  { value: '95.5', label: 'Referable Sensitivity', target: '>90%', delta: '+5.5 pts' },
  { value: '90.8', label: 'Referable Specificity', target: '>85%', delta: '+5.8 pts' },
]

const backboneRuns = [
  { name: 'EfficientNet-B0', sens: 86.6, spec: 91.2 },
  { name: 'ResNet50', sens: 90.5, spec: 92.3 },
  { name: 'DenseNet201', sens: 83.8, spec: 95.8 },
  { name: 'Ensemble (naive argmax)', sens: 86.6, spec: 95.0 },
]
const liveEnsemble = { name: 'Ensemble (calibrated) — LIVE', sens: 95.5, spec: 90.8 }

const chartData = [
  ...backboneRuns.map((r) => ({ name: r.name, 'Sensitivity': r.sens, 'Specificity': r.spec })),
  { name: liveEnsemble.name, 'Sensitivity': liveEnsemble.sens, 'Specificity': liveEnsemble.spec },
]

const history = [
  {
    stage: '01',
    title: 'First pilot',
    detail: '714 images, no class weighting. 57% accuracy, 76-81% sensitivity per backbone — missed the >90% target. Class 2 (the referable boundary) was the universal confusion bottleneck.',
    verdict: 'target missed', tone: 'bad',
  },
  {
    stage: '02',
    title: 'EyePACS blend attempt',
    detail: 'Added EyePACS (2015 Kaggle competition, same label scale) for volume. Made things WORSE: 60% accuracy on APTOS-only vs. 36% on EyePACS-only within the same blended test set — a real domain gap, not a calibration issue.',
    verdict: 'reverted', tone: 'bad',
  },
  {
    stage: '03',
    title: 'APTOS-only, full pool',
    detail: '2,930 images, class-weighted loss, all 3 backbones retrained. Naive-argmax ensemble: 82.5% accuracy, 90.5% sensitivity, 95.8% specificity on a 439-image test set — both PRD targets met with real margin, no threshold trick needed. The best naive-argmax result of the project, though a later retrain on the same data + approach (stage 05) landed a few points lower — a real reminder that training is stochastic and single-run point estimates carry noise.',
    verdict: 'target met', tone: 'good',
  },
  {
    stage: '04',
    title: 'APTOS + IDRiD + DDR blend',
    detail: '5,434 images (real class-3/4 boost: 474/1,211 vs. 108/164), 5 backbones. Per-source breakdown confirmed the SAME domain-gap pattern as EyePACS: aptos 82.2% vs. ddr 68.1%/idrid 68.0%. Every backbone individually got worse. Ensemble fell to 75.6%/89.3%/93.8% — below the old result and below the PRD sensitivity target.',
    verdict: 'regression, reverted', tone: 'bad',
  },
  {
    stage: '05',
    title: 'APTOS-only retrain, 5 backbones',
    detail: 'Reverted to the proven-good data, kept the 2 new backbones (Xception, InceptionResNetV2) from stage 04 to see if they helped on clean data. Naive-argmax ensemble: 78.8% accuracy, 88.3% sensitivity, 93.8% specificity — recovered most of the regression but still missed the sensitivity target on raw argmax.',
    verdict: 'target missed (pre-calibration)', tone: 'warn',
  },
  {
    stage: '06',
    title: 'Post-hoc calibration (both ensemble sizes)',
    detail: 'Temperature scaling + re-swept referable threshold, no retraining — same technique already proven in stage 03. Both the 5-backbone and the simpler 3-backbone ensemble hit 95.5% sensitivity / 90.8% specificity, exactly identical. Since the 2 extra backbones bought zero accuracy once calibrated, the 3-backbone ensemble is what actually ships in run_pipeline.m.',
    verdict: 'target met, deployed', tone: 'good',
  },
]

export function Benchmarks() {
  const scrollRef = useRef<HTMLDivElement>(null)
  useAutoScroll(scrollRef)
  return (
    <div className="benchmarks-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">VALIDATION &amp; BENCHMARKS</p>
        <h2>REAL NUMBERS, <em>REAL HISTORY.</em></h2>
        <p className="body-copy">
          Every number on this page is from an actual training run and test-set evaluation —
          including the ones that didn't work. A negative result with real evidence behind it is
          more credible than a project with no failed experiments at all.
        </p>
      </header>

      <section className="bench-section">
        <p className="eyebrow">PRD TARGETS — CLEARED</p>
        <div className="kpi-grid">
          {kpis.map((k) => (
            <div className="kpi-card" key={k.label}>
              <div className="kpi-card-head"><CheckCircle2 size={14} /> TARGET MET</div>
              <b className="kpi-value">{k.value}<small>%</small></b>
              <span className="kpi-label">{k.label}</span>
              <div className="kpi-compare"><span>Target {k.target}</span><span className="kpi-delta">{k.delta}</span></div>
            </div>
          ))}
        </div>
        <p className="caveat">
          "Referable" = ICDR grade &ge;2 (Moderate NPDR or worse), the clinical threshold for
          specialist referral — the PRD's actual success metric, not raw 5-class accuracy. Both
          numbers above are the calibrated 3-backbone ensemble's real held-out test-set result
          (see "Currently Deployed" below), cleared with margin to spare, not the raw naive-argmax
          number.
        </p>
      </section>

      <section className="bench-section">
        <p className="eyebrow">CURRENTLY DEPLOYED (APTOS-ONLY, 3 BACKBONES)</p>
        <div className="bench-chart">
          <ResponsiveContainer width="100%" height={380}>
            <BarChart data={chartData} margin={{ top: 4, right: 12, left: -20, bottom: 70 }} barGap={3} barCategoryGap="28%">
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(177,242,204,.1)" vertical={false} />
              <XAxis dataKey="name" stroke="#8ba396" fontSize={11} fontFamily="'Space Grotesk', sans-serif" tickLine={false} interval={0} angle={-30} textAnchor="end" height={80} />
              <YAxis type="number" domain={[0, 100]} unit="%" stroke="#8ba396" fontSize={11} fontFamily="'Space Mono', monospace" />
              <Tooltip
                contentStyle={{ background: '#0a1a14', border: '1px solid rgba(177,242,204,.3)', borderRadius: 8, fontFamily: "'Space Mono', monospace", fontSize: 12 }}
                labelStyle={{ color: '#e8f1ed', marginBottom: 4 }}
                formatter={(value: number) => `${value.toFixed(1)}%`}
              />
              <Legend wrapperStyle={{ fontFamily: "'Space Mono', monospace", fontSize: 11, paddingTop: 12 }} />
              <ReferenceLine y={90} stroke="#41d4ff" strokeDasharray="4 3" strokeOpacity={.6} label={{ value: 'Sens. target 90%', position: 'insideTopRight', fill: '#41d4ff', fontSize: 10, fontFamily: "'Space Mono', monospace" }} />
              <ReferenceLine y={85} stroke="#ff9f5a" strokeDasharray="4 3" strokeOpacity={.6} label={{ value: 'Spec. target 85%', position: 'insideBottomRight', fill: '#ff9f5a', fontSize: 10, fontFamily: "'Space Mono', monospace" }} />
              <Bar dataKey="Sensitivity" fill="#41d4ff" radius={[4, 4, 0, 0]} />
              <Bar dataKey="Specificity" fill="#ff9f5a" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="info-note">
          <p>
            439-image held-out test set, fixed seed, class-weighted cross-entropy. The naive-argmax
            ensemble alone falls short of the sensitivity target — post-hoc temperature scaling and
            a re-swept referable threshold (no retraining, see Methodology below) is what actually
            closes the gap, and is what <code>run_pipeline.m</code> runs in production.
          </p>
          <p>
            A 5-backbone version (adding Xception and InceptionResNetV2) was trained and calibrated
            separately too — it landed at the exact same 95.5% / 90.8% after calibration, so the
            extra two backbones' inference cost bought nothing. The simpler 3-backbone ensemble
            shown above is what actually ships.
          </p>
        </div>
      </section>

      <section className="bench-section">
        <p className="eyebrow">TRAINING HISTORY</p>
        <StatusLegend />
        <div className="bench-flow-scroll" ref={scrollRef}>
          <div className="bench-flow-track">
            {history.map((h, i) => (
              <Fragment key={h.stage}>
                <div className={`bench-flow-card bench-flow-card--${h.tone}`}>
                  <div className="bench-flow-card-head">
                    <span className="bench-flow-dot" />
                    <span className="bench-flow-stage">{h.stage}</span>
                  </div>
                  <h4>{h.title}</h4>
                  <span className={`status-tag bench-verdict--${h.tone}`}>{h.verdict.toUpperCase()}</span>
                  <p className="body-copy">{h.detail}</p>
                </div>
                {i < history.length - 1 && <div className="bench-flow-arrow"><ArrowRight size={18} /></div>}
              </Fragment>
            ))}
          </div>
        </div>
        <p className="scroll-hint">AUTO-SCROLLING — HOVER OR DRAG TO PAUSE</p>
      </section>

      <section className="bench-section">
        <div className="notes-card">
          <div className="notes-head">
            <ClipboardList size={17} />
            <p className="eyebrow">METHODOLOGY NOTES</p>
          </div>
          <ul className="bench-notes">
            <li>Fixed-seed 70/15/15 train/val/test split, shared identically across every backbone so ensembling and per-backbone comparison are valid.</li>
            <li>Test-time augmentation (4 views per backbone: identity, horizontal flip, ±10° rotation) before ensembling — a genuine variance-reduction technique, not cosmetic.</li>
            <li>Post-hoc temperature scaling + re-swept referable threshold (no retraining) — needs re-running after every architecture/data change, since it's specific to whichever ensemble is currently trained.</li>
            <li>CPU-only training throughout — no GPU or Parallel Computing Toolbox in this environment.</li>
          </ul>
        </div>
      </section>
    </div>
  )
}
