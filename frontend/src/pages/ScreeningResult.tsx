import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { AlertTriangle, Loader2 } from 'lucide-react'
import { fetchResultById, ApiError } from '../services/api'
import { ResultDisplay } from '../components/screening/ResultDisplay'
import { resolveResultUrls } from '../utils/resolveResultUrls'
import type { ScreeningResult as ScreeningResultType } from '../types/screening'

type LoadState = 'loading' | 'done' | 'error'

/**
 * A real, shareable permalink for one past pipeline run
 * (/screening/result/:id) -- fetches the bridge server's saved
 * result.json for that job ID rather than relying on in-memory state
 * from the Screening page, so the link keeps working after a refresh
 * or if shared with someone else on the same network.
 */
export function ScreeningResultPage() {
  const { id } = useParams<{ id: string }>()
  // Keyed by id so navigating between two different result permalinks
  // (same route, different param) gets a clean remount instead of
  // reusing state from the previous id -- avoids resetting state
  // synchronously inside an effect just to handle that transition.
  return id ? <ResultLoader key={id} id={id} /> : null
}

function ResultLoader({ id }: { id: string }) {
  const [state, setState] = useState<LoadState>('loading')
  const [result, setResult] = useState<ScreeningResultType | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    fetchResultById(id)
      .then((data) => { setResult(resolveResultUrls(data)); setState('done') })
      .catch((err) => {
        setErrorMessage(err instanceof ApiError ? err.message : 'Failed to load this result.')
        setState('error')
      })
  }, [id])

  return (
    <div className="screening-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">SCREENING RESULT / {id}</p>
        <h2>PIPELINE <em>RESULT.</em></h2>
        <p className="body-copy">
          A permalink to one real pipeline run -- reloadable and shareable, backed by the bridge
          server's saved result for this job, not local browser state.
        </p>
      </header>

      {state === 'loading' && (
        <p className="body-copy" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Loader2 className="spin" size={16} /> Loading result...
        </p>
      )}

      {state === 'error' && (
        <div className="result-banner result-banner--error">
          <AlertTriangle size={16} /> {errorMessage}
        </div>
      )}

      {state === 'done' && result && <ResultDisplay result={result} />}

      <p style={{ marginTop: '2rem' }}>
        <Link className="line-link" to="/screening">ANALYZE ANOTHER IMAGE</Link>
      </p>
    </div>
  )
}
