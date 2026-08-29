/**
 * Mirrors the bridge server's real response shape exactly
 * (bridge-server/routes/analyze.js + matlab/scripts/run_pipeline.m).
 * Every field the pipeline hasn't implemented yet is genuinely `null` at
 * runtime (MATLAB's [] gets normalized to null server-side) -- never
 * fabricate a fallback value for these in the UI, render an honest
 * "not available" state instead. This is a house rule for this project,
 * not a stylistic preference.
 */

export type QualityStatus = 'accepted' | 'enhanced' | 'rejected'

export interface QualityCheck {
  status: QualityStatus
  reason: string | null
  scores: {
    focus?: number
    illumination?: number
    fov?: number
    [key: string]: number | undefined
  }
}

export interface Severity {
  icdr_level: number
  referable: boolean
  confidence: number
  ensemble_agreement: boolean
  rule_based_grade: string | null
  needs_review: boolean
  review_reason: string | null
}

export interface Lesions {
  microaneurysms: number | null
  hemorrhages: number | null
  exudates: number | null
  neovascularization: number | null
}

export interface AvrResult {
  CRAE: number | null
  CRVE: number | null
  AVR: number | null
  numArteries: number
  numVeins: number
  usable: boolean
}

export interface TortuosityResult {
  arteryTortuosity: number | null
  veinTortuosity: number | null
  overallTortuosity: number | null
  usable: boolean
}

export interface FractalDimensionResult {
  Dbox: number | null
  usable: boolean
}

export interface HypertensiveRetinopathy {
  grade: number | null
  label: string | null
  gradable: boolean
}

export interface CerebrovascularRisk {
  score: number | null
  category: 'low' | 'moderate' | 'high' | null
  components: { avr: number | null; tortuosity: number | null; fractal: number | null }
  skipped: string[] | null
  usable: boolean
}

export interface VascularRisk {
  avr: AvrResult
  tortuosity: TortuosityResult
  fractalDimension: FractalDimensionResult
  hypertensiveRetinopathy: HypertensiveRetinopathy
  cerebrovascularRisk: CerebrovascularRisk
  numSegments: number
}

export interface ScreeningImages {
  enhanced_url: string | null
  segmentation_overlay_url: string | null
  gradcam_url: string | null
}

export interface ScreeningResult {
  quality_check: QualityCheck
  severity: Severity | null
  lesions: Lesions | null
  images: ScreeningImages
  report_url: string | null
  vascular_risk: VascularRisk | null
  /** Only present once a result has actually gone through the live
   *  /api/analyze endpoint -- pre-computed Cases-page results don't have
   *  a real job on the bridge server, so this stays undefined for them. */
  jobId?: string
}

export interface ScreeningError {
  error: string
}
