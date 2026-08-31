/**
 * The green/amber/coral status-tag color coding is used consistently
 * across ResultDisplay, Benchmarks, and Architecture — but nowhere
 * explains itself. This makes the convention explicit wherever tags
 * first appear on a page, rather than leaving a first-time viewer
 * (a judge) to infer it from context.
 */
export function StatusLegend() {
  return (
    <div className="status-legend">
      <span><i className="sim-dot" style={{ background: '#8ff0b6' }} /> Meets target / validated</span>
      <span><i className="sim-dot" style={{ background: '#f0cc7b' }} /> Partial / in progress</span>
      <span><i className="sim-dot" style={{ background: '#f2a89c' }} /> Unvalidated / regression</span>
    </div>
  )
}
