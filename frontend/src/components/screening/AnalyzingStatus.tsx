import { useEffect, useState } from 'react'

const STAGES = [
  'Checking image quality...',
  'Segmenting vessels, disc, and fovea...',
  'Grading severity across 3 backbones...',
  'Generating Grad-CAM explanation...',
  'Assessing vascular risk...',
]

/**
 * Cycles through the pipeline's real stage names while waiting on the
 * single blocking /api/analyze call. Deliberately NOT wired to real
 * backend progress -- there's no server-sent progress channel, just one
 * request/response -- so this never claims a specific stage is "now
 * running," only rotates through what the pipeline is doing broadly
 * during the wait. An indeterminate bar, not a fake percentage.
 */
export function AnalyzingStatus() {
  const [stageIndex, setStageIndex] = useState(0)

  useEffect(() => {
    const id = setInterval(() => setStageIndex((i) => (i + 1) % STAGES.length), 3200)
    return () => clearInterval(id)
  }, [])

  return (
    <div className="analyzing-status">
      <div className="analyzing-bar"><span /></div>
      <p className="analyzing-text">{STAGES[stageIndex]}</p>
    </div>
  )
}
