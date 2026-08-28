import { useEffect, useRef } from 'react'

type RetinalVisualProps = { className?: string; compact?: boolean; story?: boolean }
type Kind = 'tissue' | 'vessel' | 'disc' | 'macula' | 'field'
type Particle = { seed: number; base: [number, number, number]; field: [number, number, number]; kickX: number; kickY: number; vx: number; vy: number; size: number; kind: Kind; tone: number }

const clamp = (n: number, min = 0, max = 1) => Math.max(min, Math.min(max, n))
const smooth = (n: number) => { n = clamp(n); return n * n * (3 - 2 * n) }
const mix = (a: number, b: number, t: number) => a + (b - a) * t
const random = (n: number) => { const x = Math.sin(n * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x) }
const colors = {
  tissue: ['#7d260b', '#b84c0d', '#e48616', '#f2ae28', '#ffd76b'],
  vessel: ['#4a110c', '#76170d', '#9e2812', '#c34419'],
  disc: ['#f1a425', '#ffd45c', '#fff0ad', '#c96513'],
  macula: ['#51200f', '#7b3012', '#b4561a'],
  field: ['#126bb2', '#1caee2', '#8bdcff', '#f5fbff', '#d88813', '#f0ad25'],
}

/** One canvas, one reversible particle population: a fundus map rather than a texture. */
export function RetinalVisual({ className = '', compact = false, story = false }: RetinalVisualProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const hostRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current, host = hostRef.current
    if (!canvas || !host) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    // The hero deliberately carries a denser structural population than its small
    // editorial instances.  It keeps the fundus legible before the viewer notices
    // that it is composed of individual data points.
    const retinaCount = compact ? 1250 : story ? 14500 : 3600
    const backgroundCount = compact ? 240 : story ? 5200 : 1050
    // The optic disc sits off-centre, as it does in a real fundus capture.
    const discX = .31, discY = .045

    const particles: Particle[] = Array.from({ length: retinaCount + backgroundCount }, (_, i) => {
      const seed = random(i + 1), q = random(i + 91), r = Math.sqrt(random(i + 211)), a = random(i + 337) * Math.PI * 2
      if (i >= retinaCount) {
        return { seed, base: [0, 0, 0], field: [(random(i + 5) - .5) * 3.05, (random(i + 9) - .5) * 2.05, random(i + 17) * 1.7 - .55], kickX: 0, kickY: 0, vx: 0, vy: 0, size: .3 + q * 1.12, kind: 'field', tone: Math.floor(seed * 6) }
      }
      const order = i / retinaCount
      const kind: Kind = order < .265 ? 'vessel' : order < .325 ? 'disc' : order < .40 ? 'macula' : 'tissue'
      let x: number, y: number, z: number
      if (kind === 'vessel') {
        // Curved vascular trees grow outward from the optic disc; fine offsets create capillary width.
        const branch = i % 30
        const root = branch / 30 * Math.PI * 2 + (seed - .5) * .075
        const t = Math.pow(q, .62)
        // Major vessels arc around the macula; minor branches are nested along
        // them so the map reads as retinal vasculature rather than radial rays.
        const bend = Math.sin(t * Math.PI) * (.34 + (branch % 5) * .028) * (Math.sin(root) > 0 ? 1 : -1)
        const angle = root + bend + Math.sin(t * 12 + branch) * .018
        const reach = .085 + t * (.82 + seed * .11)
        const width = (seed - .5) * (.009 + (1 - t) * .037)
        x = discX + Math.cos(angle) * reach + Math.cos(angle + Math.PI / 2) * width
        y = discY + Math.sin(angle) * reach * .90 + Math.sin(angle + Math.PI / 2) * width
        z = -.20 + (1 - t) * .16 + (seed - .5) * .075
      } else if (kind === 'disc') {
        const rr = Math.sqrt(q) * .145; x = discX + Math.cos(a) * rr * 1.05; y = discY + Math.sin(a) * rr * .89; z = -.18 + q * .12
      } else if (kind === 'macula') {
        const rr = Math.sqrt(q) * .19; x = -.23 + Math.cos(a) * rr * 1.16; y = -.025 + Math.sin(a) * rr; z = -.23 + q * .07
      } else {
        x = Math.cos(a) * r; y = Math.sin(a) * r * .92; z = -.31 + r * r * .52 + Math.sin(a * 7 + seed * 21) * .028
      }
      const edge = Math.sqrt(x * x + (y / .92) ** 2)
      if (edge > 1.02) { x /= edge / 1.02; y /= edge / 1.02 }
      const tones = kind === 'vessel' || kind === 'disc' ? 4 : kind === 'macula' ? 3 : 5
      return { seed, base: [x, y, z], field: [Math.sin(i * 4.13) * (1.45 + seed), Math.cos(i * 7.81) * (1.18 + q), Math.sin(i * 2.91) * 1.45], kickX: 0, kickY: 0, vx: 0, vy: 0, size: kind === 'vessel' ? .72 + q * 1.12 : kind === 'disc' ? .75 + q * 1.35 : .42 + q * 1.2, kind, tone: Math.floor(seed * tones) }
    })

    let width = 1, height = 1, ratio = 1, frame = 0
    let pointer = { x: -9999, y: -9999, active: false }
    const resize = () => { const rect = host.getBoundingClientRect(); width = rect.width; height = rect.height; ratio = Math.min(devicePixelRatio, 2); canvas.width = Math.ceil(width * ratio); canvas.height = Math.ceil(height * ratio); canvas.style.width = `${width}px`; canvas.style.height = `${height}px`; ctx.setTransform(ratio, 0, 0, ratio, 0, 0) }
    const pointerMove = (event: PointerEvent) => { const rect = host.getBoundingClientRect(); pointer = { x: event.clientX - rect.left, y: event.clientY - rect.top, active: document.body.classList.contains('retinal-lens-enabled') && event.clientX >= rect.left && event.clientX <= rect.right && event.clientY >= rect.top && event.clientY <= rect.bottom } }
    const progress = () => { if (!story) return Number.parseFloat(getComputedStyle(host).getPropertyValue('--retina-phase')) || 0; const landing = host.closest('.landing') as HTMLElement | null; return landing ? clamp((-landing.getBoundingClientRect().top) / Math.max(1, landing.offsetHeight - innerHeight)) : 0 }
    const target = (p: Particle, stage: number) => {
      if (p.kind === 'field') return p.field
      const dissolve = smooth((stage - .12) / .30), reform = smooth((stage - .60) / .28)
      const base = [mix(p.base[0], p.field[0], dissolve), mix(p.base[1], p.field[1], dissolve), mix(p.base[2], p.field[2], dissolve)]
      const analysisX = p.base[0] * .93 + (p.kind === 'vessel' ? Math.sin(p.seed * 43) * .075 : 0)
      return [mix(base[0], analysisX, reform), mix(base[1], p.base[1] * .93, reform), mix(base[2], p.base[2] + (p.kind === 'vessel' ? .24 : p.kind === 'disc' ? .12 : -.03), reform)]
    }
    const draw = (time: number) => {
      const phase = progress(); ctx.clearRect(0, 0, width, height)
      const cx = width * .68, cy = height * .49, scale = Math.min(width, height) * (compact ? .54 : story ? .76 : .61), drift = reduced ? 0 : time * .000075
      // Dense low-contrast data / biological matter throughout the viewport.
      for (let i = 0; i < (compact ? 240 : story ? 3600 : 850); i++) {
        const x = (random(i + 700) * width + Math.sin(drift * 8 + i) * 5) % width, y = random(i + 1300) * height, alpha = .045 + random(i + 800) * .18
        const gold = i % 11 === 0, white = i % 31 === 0
        ctx.fillStyle = white ? `rgba(232,247,255,${alpha})` : gold ? `rgba(233,161,39,${alpha})` : `rgba(${i % 3 ? '34,151,220' : '56,205,240'},${alpha})`
        const s = i % 79 === 0 ? 2.4 : i % 17 === 0 ? 1.55 : .42 + random(i) * .78; ctx.fillRect(x, y, s, s)
      }
      const aura = ctx.createRadialGradient(cx, cy, 0, cx, cy, scale * 1.55); aura.addColorStop(0, 'rgba(239,120,9,.26)'); aura.addColorStop(.44, 'rgba(123,50,5,.14)'); aura.addColorStop(1, 'rgba(0,0,0,0)'); ctx.fillStyle = aura; ctx.fillRect(0, 0, width, height)
      for (const p of particles) {
        const t = target(p, phase), z = t[2] + 2.75, px = cx + t[0] / z * scale * 2 + Math.sin(drift + p.seed * 30) * (reduced ? 0 : .7), py = cy + t[1] / z * scale * 2
        const dx = px - pointer.x, dy = py - pointer.y, d = Math.hypot(dx, dy), force = pointer.active ? Math.pow(clamp(1 - d / 105), 2) : 0, inv = d > .01 ? 1 / d : 0
        p.vx = (p.vx + dx * inv * force * 2 - p.kickX * .13) * .82; p.vy = (p.vy + dy * inv * force * 2 - p.kickY * .13) * .82; p.kickX += p.vx; p.kickY += p.vy
        const magnify = 1 + force * .22, x = pointer.active ? pointer.x + (px + p.kickX - pointer.x) * magnify : px + p.kickX, y = pointer.active ? pointer.y + (py + p.kickY - pointer.y) * magnify : py + p.kickY
        const color = colors[p.kind][p.tone], dissolved = smooth((phase - .12) / .30)
        ctx.globalAlpha = (p.kind === 'field' ? .14 + p.size * .14 : .38 + p.size * .25) * clamp(1.36 - z / 4) * (p.kind === 'vessel' ? 1.55 : p.kind === 'disc' ? 1.38 : 1) * (1 - dissolved * .18) + force * .22
        ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, p.size * (1 + force * .65) * (1.65 / z), 0, Math.PI * 2); ctx.fill()
      }
      ctx.globalAlpha = 1; frame = requestAnimationFrame(draw)
    }
    resize(); addEventListener('resize', resize); addEventListener('pointermove', pointerMove, { passive: true }); frame = requestAnimationFrame(draw)
    return () => { cancelAnimationFrame(frame); removeEventListener('resize', resize); removeEventListener('pointermove', pointerMove) }
  }, [compact, story])
  return <div ref={hostRef} className={`retinal-visual ${className}`}><canvas ref={canvasRef} /></div>
}
