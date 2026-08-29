import React from 'react'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
} from 'react-router-dom'

import { Layout } from './components/layout/Layout'
import { Landing } from './pages/Landing'
import { Screening } from './pages/Screening'
import { Cases } from './pages/Cases'
import { ScreeningResultPage } from './pages/ScreeningResult'
import { Benchmarks } from './pages/Benchmarks'
import { Architecture } from './pages/Architecture'
import { Simulation } from './pages/Simulation'

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
            element={<Screening />}
          />

          <Route
            path="/screening/result/:id"
            element={<ScreeningResultPage />}
          />

          <Route
            path="/cases"
            element={<Cases />}
          />

          <Route
            path="/simulation"
            element={<Simulation />}
          />

          <Route
            path="/benchmarks"
            element={<Benchmarks />}
          />

          <Route
            path="/architecture"
            element={<Architecture />}
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
