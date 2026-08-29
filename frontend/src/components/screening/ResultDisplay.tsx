import { motion, useReducedMotion } from 'framer-motion'
import { AlertTriangle, CheckCircle2, XCircle } from 'lucide-react'
import type { ScreeningResult } from '../../types/screening'

const ICDR_LABELS = ['No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR']

/**
 * Shared with both the live Screening workspace and the pre-computed
 * Cases gallery -- one rendering path for "what did the pipeline
 * actually return," so the two pages can never drift into showing
 * different things for the same result shape.
 */
export function ResultDisplay({ result }: { result: ScreeningResult }) {
  const { quality_check: qc, severity, lesions, images, vascular_risk: vr } = result
  const reduceMotion = useReducedMotion()

  // Critically damped (damping 1.0): these cards aren't gesture-driven --
  // no drag, no flick -- so per Apple's guidance they get the graceful,
  // non-bouncy default, not the momentum-flavored overshoot reserved for
  // things a user physically threw. Reduced motion drops the lift/scale
  // entirely and keeps only the (already CSS-transitioned) border/color
  // change, per the "gentle equivalent, not zero feedback" rule.
  const hoverMotion = reduceMotion
    ? {}
    : {
        whileHover: { y: -3, transition: { type: 'spring' as const, damping: 1, duration: 0.25 } },
        whileTap: { y: -1, scale: 0.995, transition: { type: 'spring' as const, damping: 1, duration: 0.15 } },
      }

  return (
    <div className="result-grid">
      <motion.section className="result-card" {...hoverMotion}>
        <h3 className="result-card-title">
          {qc.status === 'rejected' ? <XCircle size={16} /> : <CheckCircle2 size={16} />}
          IMAGE QUALITY -- <span className={`status-tag status-tag--${qc.status}`}>{qc.status.toUpperCase()}</span>
        </h3>
        {qc.reason && <p className="body-copy">{qc.reason}</p>}
        <dl className="score-list">
          {Object.entries(qc.scores).map(([key, value]) => (
            value !== undefined && <div key={key}><dt>{key}</dt><dd>{(value * 100).toFixed(0)}%</dd></div>
          ))}
        </dl>
      </motion.section>

      {qc.status === 'rejected' ? (
        <motion.section className="result-card result-card--wide" {...hoverMotion}>
          <p className="body-copy">
            The pipeline stops here for rejected images, same as it would for a real screening --
            severity grading, lesion detection, and vascular-risk assessment all require a
            gradable image to mean anything.
          </p>
        </motion.section>
      ) : (
        <>
          <motion.section className="result-card" {...hoverMotion}>
            <h3 className="result-card-title">SEVERITY GRADING</h3>
            {severity ? (
              <>
                <p className="severity-headline">
                  {ICDR_LABELS[severity.icdr_level]}
                  <span className={`status-tag ${severity.referable ? 'status-tag--referable' : 'status-tag--nonreferable'}`}>
                    {severity.referable ? 'REFERABLE' : 'NON-REFERABLE'}
                  </span>
                </p>
                <p className="body-copy">Confidence: {(severity.confidence * 100).toFixed(1)}% -- {severity.ensemble_agreement ? 'all backbones agree' : 'backbones disagree'}</p>
                {severity.needs_review && (
                  <p className="result-banner result-banner--warning"><AlertTriangle size={14} /> {severity.review_reason}</p>
                )}
              </>
            ) : (
              <p className="body-copy not-available">
                Not available -- the trained grading models aren't ready yet (a retrain is
                currently running). This is a real, honest null, not a placeholder.
              </p>
            )}
          </motion.section>

          <motion.section className="result-card" {...hoverMotion}>
            <h3 className="result-card-title">LESION DETECTION</h3>
            {lesions ? (
              <dl className="score-list">
                <div><dt>Microaneurysms</dt><dd>{lesions.microaneurysms ?? 'n/a'}</dd></div>
                <div><dt>Hemorrhages</dt><dd>{lesions.hemorrhages ?? 'n/a'}</dd></div>
                <div><dt>Exudates</dt><dd>{lesions.exudates ?? 'n/a'}</dd></div>
                <div><dt>Neovascularization</dt><dd>{lesions.neovascularization ?? 'not implemented'}</dd></div>
              </dl>
            ) : <p className="body-copy not-available">Not available.</p>}
            <p className="caveat">Classical CV, first-pass -- unvalidated against pixel-level ground truth.</p>
          </motion.section>

          <motion.section className="result-card" {...hoverMotion}>
            <h3 className="result-card-title">VASCULAR / CEREBROVASCULAR RISK</h3>
            {vr ? (
              <>
                <dl className="score-list">
                  <div><dt>AVR</dt><dd>{vr.avr.usable ? vr.avr.AVR?.toFixed(3) : 'not usable'}</dd></div>
                  <div><dt>Hypertensive narrowing</dt><dd>{vr.hypertensiveRetinopathy.label ?? 'not gradable'}</dd></div>
                  <div><dt>Cerebrovascular risk</dt><dd className={`risk-${vr.cerebrovascularRisk.category ?? 'na'}`}>{vr.cerebrovascularRisk.category?.toUpperCase() ?? 'N/A'}</dd></div>
                </dl>
                <p className="caveat">
                  A screening flag from retinal vessel biomarkers (stroke + vascular-dementia
                  correlates) -- not a diagnosis, and not a test for Alzheimer's or any
                  amyloid/tau-driven condition.
                </p>
              </>
            ) : <p className="body-copy not-available">Not available.</p>}
          </motion.section>

          <motion.section className="result-card result-card--wide" {...hoverMotion}>
            <h3 className="result-card-title">GENERATED IMAGES</h3>
            <div className="image-row">
              <ResultImage label="Enhanced" url={images.enhanced_url} />
              <ResultImage label="Segmentation" url={images.segmentation_overlay_url} />
              <ResultImage label="Grad-CAM" url={images.gradcam_url} />
            </div>
          </motion.section>
        </>
      )}
    </div>
  )
}

function ResultImage({ label, url }: { label: string; url: string | null }) {
  return (
    <div className="result-image">
      <span className="frame-label top">{label.toUpperCase()}</span>
      {url ? <img src={url} alt={label} /> : <div className="result-image-empty">not generated</div>}
    </div>
  )
}
