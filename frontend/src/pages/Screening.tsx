import { useCallback, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { motion, useReducedMotion } from 'framer-motion'
import { UploadCloud, AlertTriangle, Loader2 } from 'lucide-react'
import { analyzeImage, ApiError } from '../services/api'
import { ResultDisplay } from '../components/screening/ResultDisplay'
import { AnalyzingStatus } from '../components/screening/AnalyzingStatus'
import { resolveResultUrls } from '../utils/resolveResultUrls'
import type { ScreeningResult } from '../types/screening'

type Status = 'idle' | 'analyzing' | 'done' | 'error'

export function Screening() {
  const navigate = useNavigate()
  const [file, setFile] = useState<File | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [status, setStatus] = useState<Status>('idle')
  const [result, setResult] = useState<ScreeningResult | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [dragOver, setDragOver] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const reduceMotion = useReducedMotion()

  const pickFile = useCallback((picked: File | null) => {
    if (!picked) return
    setFile(picked)
    setPreviewUrl(URL.createObjectURL(picked))
    setStatus('idle')
    setResult(null)
    setErrorMessage(null)
  }, [])

  const runAnalysis = useCallback(async () => {
    if (!file) return
    setStatus('analyzing')
    setErrorMessage(null)
    try {
      const data = await analyzeImage(file)
      // Redirect to the permalink page rather than showing the result
      // inline -- the URL itself becomes a real, shareable/revisitable
      // link (backed by the bridge server's saved result.json), not just
      // a page in component state that vanishes on refresh.
      if (data.jobId) {
        navigate(`/screening/result/${data.jobId}`)
        return
      }
      setResult(resolveResultUrls(data))
      setStatus('done')
    } catch (err) {
      setErrorMessage(err instanceof ApiError ? err.message : 'Unexpected error analyzing image.')
      setStatus('error')
    }
  }, [file, navigate])

  const reset = () => {
    setFile(null)
    setPreviewUrl(null)
    setStatus('idle')
    setResult(null)
    setErrorMessage(null)
  }

  return (
    <div className="screening-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">SCREENING WORKSPACE</p>
        <h2>UPLOAD A <em>RETINAL IMAGE.</em></h2>
        <p className="body-copy">
          Runs the real pipeline (Module 1-4, plus Module 6's vascular-risk side-pipeline) end to
          end via the bridge server. Every field below is exactly what the pipeline actually
          returned -- no field is filled in or estimated by the interface.
        </p>
      </header>

      {!result && (
        <motion.div
          className={`dropzone ${dragOver ? 'dropzone--active' : ''}`}
          onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
          onDragLeave={() => setDragOver(false)}
          onDrop={(e) => {
            e.preventDefault()
            setDragOver(false)
            pickFile(e.dataTransfer.files[0] ?? null)
          }}
          onClick={() => inputRef.current?.click()}
          // Rubber-band-flavored feedback: the dropzone leans toward the
          // gesture on drag-over (anticipating the drop) and settles back
          // critically damped, no overshoot -- this is hover/drop state,
          // not a flick, so it doesn't earn momentum bounce.
          animate={reduceMotion ? {} : { scale: dragOver ? 1.012 : 1 }}
          transition={{ type: 'spring', damping: 1, duration: 0.3 }}
          whileTap={reduceMotion ? {} : { scale: 0.995 }}
        >
          <input
            ref={inputRef}
            type="file"
            accept="image/jpeg,image/png"
            hidden
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
          />
          {previewUrl ? (
            <img src={previewUrl} alt="Selected fundus photo" className="dropzone-preview" />
          ) : (
            <>
              <UploadCloud size={36} />
              <p>DRAG A FUNDUS PHOTO HERE, OR CLICK TO BROWSE</p>
              <span className="dropzone-hint">JPEG or PNG, up to 25MB</span>
            </>
          )}
        </motion.div>
      )}

      {file && status !== 'done' && (
        <div className="screening-actions">
          <button
            className="screening-button"
            disabled={status === 'analyzing'}
            onClick={runAnalysis}
          >
            {status === 'analyzing' ? (
              <><Loader2 className="spin" size={15} /> ANALYZING (~10-25s)...</>
            ) : (
              <>RUN ANALYSIS</>
            )}
          </button>
          {status !== 'analyzing' && (
            <button className="line-link" onClick={reset}>CHOOSE A DIFFERENT IMAGE</button>
          )}
        </div>
      )}

      {status === 'analyzing' && <AnalyzingStatus />}

      {status === 'error' && errorMessage && (
        <div className="result-banner result-banner--error">
          <AlertTriangle size={16} /> {errorMessage}
        </div>
      )}

      {result && (
        <>
          <ResultDisplay result={result} />
          <button className="line-link" onClick={reset}>ANALYZE ANOTHER IMAGE</button>
        </>
      )}
    </div>
  )
}
