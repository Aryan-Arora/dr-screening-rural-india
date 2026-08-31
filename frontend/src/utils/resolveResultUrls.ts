import { outputUrl } from '../services/api'
import type { ScreeningResult } from '../types/screening'

/**
 * The bridge server (both the live /api/analyze response and the saved
 * result.json a job's output directory) stores image paths as relative
 * `/api/outputs/...` — correct for a same-origin frontend, but this
 * frontend runs on a different port (5176 vs. the bridge server's 4000),
 * so every image path needs the API base URL prefixed before the browser
 * can actually load it. Shared by the live Screening page and the
 * permalink ScreeningResult page so both apply it identically.
 */
export function resolveResultUrls(result: ScreeningResult): ScreeningResult {
  return {
    ...result,
    images: {
      enhanced_url: outputUrl(result.images.enhanced_url),
      segmentation_overlay_url: outputUrl(result.images.segmentation_overlay_url),
      gradcam_url: outputUrl(result.images.gradcam_url),
    },
    report_url: outputUrl(result.report_url),
  }
}
