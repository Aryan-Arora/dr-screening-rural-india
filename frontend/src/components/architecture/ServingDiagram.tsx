export function ServingDiagram() {
  const nodes = [
    { x: 10, w: 170, title: 'REACT', sub: 'FRONTEND (5176)' },
    { x: 220, w: 200, title: 'NODE / EXPRESS', sub: 'BRIDGE SERVER (4000)' },
    { x: 460, w: 190, title: 'MATLAB -BATCH', sub: 'FRESH PROCESS / REQUEST' },
    { x: 690, w: 170, title: 'JSON RESULT', sub: '+ SAVED result.json' },
  ]
  const y = 20
  const h = 60

  return (
    <svg viewBox="0 0 880 130" className="pipeline-diagram" role="img" aria-label="Serving architecture diagram">
      <defs>
        <marker id="arrow2" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" fill="rgba(177,242,204,.55)" />
        </marker>
      </defs>
      {nodes.map((n) => (
        <g key={n.title}>
          <rect x={n.x} y={y} width={n.w} height={h} rx={12} fill="rgba(255,255,255,.02)" stroke="rgba(177,242,204,.4)" strokeWidth={1.3} />
          <text x={n.x + n.w / 2} y={y + 26} textAnchor="middle" className="pd-title">{n.title}</text>
          <text x={n.x + n.w / 2} y={y + 44} textAnchor="middle" className="pd-sub">{n.sub}</text>
        </g>
      ))}
      {nodes.slice(0, -1).map((n, i) => {
        const next = nodes[i + 1]
        return <line key={i} x1={n.x + n.w} y1={y + h / 2} x2={next.x - 2} y2={y + h / 2} stroke="rgba(177,242,204,.55)" strokeWidth={1.3} markerEnd="url(#arrow2)" />
      })}
      <text x={460} y={y + h + 22} textAnchor="middle" className="pd-caption">~7-25s PER REQUEST — MATLAB STARTUP + MODEL LOAD, PAID EVERY TIME</text>
    </svg>
  )
}
