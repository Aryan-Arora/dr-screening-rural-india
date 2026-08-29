import type { ScreeningResult } from '../types/screening'

// The bridge server runs separately (bridge-server/, `npm start`, port 4000)
// -- this is a real HTTP call, not a mock. Overridable via VITE_API_BASE_URL
// for anyone running the bridge server on a different host/port.
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:4000'

export class ApiError extends Error {
  status?: number

  constructor(message: string, status?: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

export async function analyzeImage(file: File): Promise<ScreeningResult> {
  const formData = new FormData()
  formData.append('image', file)

  let response: Response
  try {
    response = await fetch(`${API_BASE_URL}/api/analyze`, {
      method: 'POST',
      body: formData,
    })
  } catch {
    throw new ApiError(
      `Could not reach the bridge server at ${API_BASE_URL}. Is it running? (cd bridge-server && npm start)`,
    )
  }

  if (!response.ok) {
    const body = await response.json().catch(() => ({ error: `HTTP ${response.status}` }))
    throw new ApiError(body.error ?? `Request failed with status ${response.status}`, response.status)
  }

  return response.json() as Promise<ScreeningResult>
}

export function outputUrl(path: string | null): string | null {
  if (!path) return null
  return path.startsWith('http') ? path : `${API_BASE_URL}${path}`
}

/** Fetches a previously-analyzed result by job ID -- the bridge server
 *  writes each job's normalized result.json into its output directory
 *  (see analyze.js), served statically, so this is a real lookup of a
 *  real past pipeline run, not a mock or a client-side cache. */
export async function fetchResultById(jobId: string): Promise<ScreeningResult> {
  const response = await fetch(`${API_BASE_URL}/api/outputs/${jobId}/result.json`)
  if (!response.ok) {
    throw new ApiError(
      response.status === 404
        ? `No result found for "${jobId}" -- the job may not exist, or the bridge server's outputs were cleared.`
        : `Failed to load result (HTTP ${response.status}).`,
      response.status,
    )
  }
  return response.json() as Promise<ScreeningResult>
}
