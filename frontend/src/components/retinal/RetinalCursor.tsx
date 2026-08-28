import { useEffect, useRef } from 'react'

/** A single, pointer-events-free lens shared by the landing experience. */
export function RetinalCursor() {
  const lensRef = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)')
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)')
    const lens = lensRef.current
    if (!lens) return undefined
    let frame = 0, visible = false, targetX = -100, targetY = -100, x = -100, y = -100, scale = 1, targetScale = 1, previous = performance.now()
    let interactive: Element | null = null
    const enabled = () => finePointer.matches && !reducedMotion.matches
    const render = (now: number) => {
      // Frame-time based easing keeps the lens equally smooth at 60Hz and on
      // slower displays, while avoiding the visible snap caused by a fixed step.
      const dt = Math.min(48, Math.max(1, now - previous)); previous = now
      const ease = 1 - Math.exp(-dt / 105)
      const scaleEase = 1 - Math.exp(-dt / 135)
      x += (targetX - x) * ease; y += (targetY - y) * ease; scale += (targetScale - scale) * scaleEase
      lens.style.transform = `translate3d(${x}px, ${y}px, 0) translate(-50%, -50%) scale(${scale})`; frame = requestAnimationFrame(render)
    }
    const setEnabled = () => document.body.classList.toggle('retinal-lens-enabled', enabled())
    const move = (event: PointerEvent) => {
      if (!enabled()) return
      const candidate = (event.target as Element | null)?.closest('a, button, [data-lens-interactive]') ?? null
      if (candidate !== interactive) { interactive = candidate; lens.classList.toggle('retinal-cursor--interactive', Boolean(interactive)) }
      targetScale = interactive ? 1.16 : 1
      if (interactive) { const rect = (interactive as HTMLElement).getBoundingClientRect(); targetX = event.clientX + (rect.left + rect.width / 2 - event.clientX) * .12; targetY = event.clientY + (rect.top + rect.height / 2 - event.clientY) * .12 } else { targetX = event.clientX; targetY = event.clientY }
      if (!visible) { visible = true; lens.classList.add('retinal-cursor--visible') }
    }
    const leave = () => { visible = false; lens.classList.remove('retinal-cursor--visible') }
    setEnabled(); window.addEventListener('pointermove', move, { passive: true }); document.addEventListener('mouseleave', leave); finePointer.addEventListener('change', setEnabled); reducedMotion.addEventListener('change', setEnabled); frame = requestAnimationFrame(render)
    return () => { cancelAnimationFrame(frame); document.body.classList.remove('retinal-lens-enabled'); window.removeEventListener('pointermove', move); document.removeEventListener('mouseleave', leave); finePointer.removeEventListener('change', setEnabled); reducedMotion.removeEventListener('change', setEnabled) }
  }, [])
  return <div ref={lensRef} className="retinal-cursor" aria-hidden="true"><i /></div>
}
