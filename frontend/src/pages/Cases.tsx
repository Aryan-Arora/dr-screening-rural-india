import { Link } from 'react-router-dom'
import { cases } from '../data/cases'
import { ResultDisplay } from '../components/screening/ResultDisplay'

export function Cases() {
  return (
    <div className="cases-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">CLINICAL CASES</p>
        <h2>THREE REAL <em>CASES.</em></h2>
        <p className="body-copy">
          Real fundus photos, run through the actual pipeline once and captured here — not a
          live demo dependent on the bridge server being up. Chosen specifically to cover all
          three response shapes the pipeline can return: a referable case, a healthy case, and
          a case the quality gate correctly rejects.
        </p>
      </header>

      <div className="cases-list">
        {cases.map((c, i) => {
          const { quality_check: qc, severity } = c.result
          const verdict = qc.status === 'rejected'
            ? { label: 'REJECTED', tone: 'rejected' }
            : severity?.referable
              ? { label: 'REFERABLE', tone: 'referable' }
              : { label: 'NON-REFERABLE', tone: 'nonreferable' }
          return (
            <article key={c.slug} className="case-block">
              <div className="case-block-header">
                <span className="case-number">{String(i + 1).padStart(2, '0')}</span>
                <div className="case-block-heading">
                  <div className="case-title-row">
                    <h3>{c.title}</h3>
                    <span className={`status-tag status-tag--${verdict.tone}`}>{verdict.label}</span>
                  </div>
                  <p className="body-copy">{c.caption}</p>
                </div>
              </div>
              <ResultDisplay result={c.result} />
            </article>
          )
        })}
      </div>

      <Link className="line-link" to="/screening">TRY YOUR OWN IMAGE IN THE SCREENING WORKSPACE →</Link>
    </div>
  )
}
