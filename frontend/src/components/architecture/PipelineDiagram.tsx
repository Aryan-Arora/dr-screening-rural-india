/**
 * The real control flow of run_pipeline.m, drawn to scale with what
 * actually happens — including the two branches that are easy to miss
 * in a plain left-to-right list: a rejected-quality image stops the
 * chain early (never reaches the CNN), and Module 6 runs in parallel off
 * Module 1/2's output rather than after Module 4.
 */
export function PipelineDiagram() {
  const nodeY = 30
  const nodeH = 64
  const nodes: { x: number; w: number; label: string; sub: string; tone: string }[] = [
    { x: 10, w: 130, label: 'FUNDUS', sub: 'IMAGE', tone: 'neutral' },
    { x: 180, w: 150, label: '01', sub: 'QUALITY GATE', tone: 'good' },
    { x: 370, w: 150, label: '02', sub: 'SEGMENTATION', tone: 'warn' },
    { x: 560, w: 160, label: '03', sub: 'SEVERITY GRADING', tone: 'good' },
    { x: 760, w: 150, label: '04', sub: 'EXPLAINABILITY', tone: 'warn' },
  ]
  const toneColor: Record<string, string> = {
    neutral: 'rgba(177,242,204,.35)',
    good: 'rgba(143,240,182,.55)',
    warn: 'rgba(240,204,123,.55)',
    bad: 'rgba(242,168,156,.55)',
  }

  return (
    <svg viewBox="0 0 960 400" className="pipeline-diagram" role="img" aria-label="Pipeline flow diagram">
      <defs>
        <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" fill="rgba(177,242,204,.55)" />
        </marker>
        <marker id="arrow-dashed" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" fill="rgba(242,168,156,.6)" />
        </marker>
      </defs>

      {/* main chain */}
      {nodes.map((n) => (
        <g key={n.label}>
          <rect
            x={n.x} y={nodeY} width={n.w} height={nodeH} rx={12}
            fill="rgba(255,255,255,.02)" stroke={toneColor[n.tone]} strokeWidth={1.3}
          />
          <text x={n.x + n.w / 2} y={nodeY + 26} textAnchor="middle" className="pd-title">{n.label}</text>
          <text x={n.x + n.w / 2} y={nodeY + 44} textAnchor="middle" className="pd-sub">{n.sub}</text>
        </g>
      ))}
      {nodes.slice(0, -1).map((n, i) => {
        const next = nodes[i + 1]
        const y = nodeY + nodeH / 2
        return <line key={i} x1={n.x + n.w} y1={y} x2={next.x - 2} y2={y} stroke="rgba(177,242,204,.55)" strokeWidth={1.3} markerEnd="url(#arrow)" />
      })}

      {/* rejected branch, off module 01 */}
      <line x1={255} y1={nodeY + nodeH} x2={255} y2={190} stroke="rgba(242,168,156,.6)" strokeWidth={1.3} strokeDasharray="5 4" markerEnd="url(#arrow-dashed)" />
      <rect x={180} y={198} width={150} height={54} rx={12} fill="rgba(242,168,156,.05)" stroke="rgba(242,168,156,.5)" strokeWidth={1.2} strokeDasharray="4 3" />
      <text x={255} y={220} textAnchor="middle" className="pd-title pd-title--bad">REJECTED</text>
      <text x={255} y={238} textAnchor="middle" className="pd-sub">PIPELINE STOPS HERE</text>

      {/* module 6 parallel branch, off module 02 */}
      <line x1={445} y1={nodeY + nodeH} x2={445} y2={280} stroke="rgba(177,242,204,.4)" strokeWidth={1.3} />
      <line x1={445} y1={280} x2={685} y2={280} stroke="rgba(177,242,204,.4)" strokeWidth={1.3} />
      <line x1={685} y1={280} x2={685} y2={306} stroke="rgba(177,242,204,.4)" strokeWidth={1.3} markerEnd="url(#arrow)" />
      <rect x={510} y={314} width={350} height={62} rx={12} fill="rgba(159,240,191,.04)" stroke="rgba(159,240,191,.4)" strokeWidth={1.2} />
      <text x={685} y={340} textAnchor="middle" className="pd-title">06 · VASCULAR / CEREBROVASCULAR RISK</text>
      <text x={685} y={358} textAnchor="middle" className="pd-sub">RUNS IN PARALLEL — INDEPENDENT OF 03/04</text>

      <text x={10} y={392} className="pd-caption">SOLID = MAIN DR-GRADING CHAIN</text>
      <text x={280} y={392} className="pd-caption pd-caption--bad">DASHED = EARLY EXIT</text>
      <text x={470} y={392} className="pd-caption pd-caption--good">BRANCH = PARALLEL SIDE-PIPELINE</text>
    </svg>
  )
}
