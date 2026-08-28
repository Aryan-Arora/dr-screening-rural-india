import React from 'react'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
} from 'react-router-dom'

import { Layout } from './components/layout/Layout'
import { Landing } from './pages/Landing'

const Placeholder = ({ title }: { title: string }) => (
  <div className="mx-auto flex min-h-[80vh] max-w-7xl items-center px-6">
    <div>
      <p className="mb-3 font-mono text-xs uppercase tracking-[0.3em] text-emerald-400">
        RETINA / AI
      </p>

      <h1 className="font-display text-5xl font-bold">
        {title}
      </h1>

      <p className="mt-4 max-w-xl text-slate-400">
        Explainable AI for diabetic retinopathy screening.
      </p>
    </div>
  </div>
)

const App: React.FC = () => {
  return (
    <BrowserRouter>
      <Layout>
        <Routes>
          <Route
            path="/"
            element={<Landing />}
          />

          <Route
            path="/screening"
            element={<Placeholder title="Screening Workspace" />}
          />

          <Route
            path="/screening/result/:id"
            element={<Placeholder title="Screening Result" />}
          />

          <Route
            path="/cases"
            element={<Placeholder title="Clinical Cases" />}
          />

          <Route
            path="/simulation"
            element={<Placeholder title="District Simulation" />}
          />

          <Route
            path="/benchmarks"
            element={<Placeholder title="Validation & Benchmarks" />}
          />

          <Route
            path="/architecture"
            element={<Placeholder title="System Architecture" />}
          />

          <Route
            path="*"
            element={<Navigate to="/" replace />}
          />
        </Routes>
      </Layout>
    </BrowserRouter>
  )
}

export default App
