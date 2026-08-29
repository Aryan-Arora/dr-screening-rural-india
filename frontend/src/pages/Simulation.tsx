import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { module5Sweep } from '../data/module5Sweep'

export function Simulation() {
  return (
    <div className="simulation-page section-shell">
      <header className="section-heading">
        <p className="eyebrow">DISTRICT SIMULATION</p>
        <h2>WHERE DOES THIS <em>ACTUALLY BREAK?</em></h2>
        <p className="body-copy">
          A real Simulink discrete-event model of the clinic workflow -- patient arrival, quality-
          gate capture/recapture, AI processing queue, doctor review queue -- swept across annual
          patient volume from 100k to 1.5M. Not a mockup chart: this is the actual output of
          <code> module5_sweep_results.mat</code>.
        </p>
      </header>

      <section className="bench-section">
        <p className="eyebrow">RESOURCE UTILIZATION AT SCALE</p>
        <div className="sim-chart">
          <ResponsiveContainer width="100%" height={360}>
            <LineChart data={module5Sweep} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(177,242,204,.12)" />
              <XAxis dataKey="volumeLabel" stroke="#a5b7ae" fontSize={11} fontFamily="DM Mono, monospace" />
              <YAxis stroke="#a5b7ae" fontSize={11} fontFamily="DM Mono, monospace" unit="%" />
              <Tooltip
                contentStyle={{ background: '#0a1a14', border: '1px solid rgba(177,242,204,.3)', borderRadius: 8, fontFamily: 'DM Mono, monospace', fontSize: 12 }}
                labelStyle={{ color: '#e8f1ed' }}
              />
              <Line type="monotone" dataKey="aiUtil1Slot" name="AI utilization (1 slot)" stroke="#f2a89c" strokeWidth={2} dot={{ r: 3 }} />
              <Line type="monotone" dataKey="aiUtil2Slot" name="AI utilization (2 slots)" stroke="#8ff0b6" strokeWidth={2} dot={{ r: 3 }} />
              <Line type="monotone" dataKey="doctorUtil1Doc" name="Doctor utilization (1 doctor)" stroke="#f0cc7b" strokeWidth={2} dot={{ r: 3 }} strokeDasharray="4 3" />
            </LineChart>
          </ResponsiveContainer>
        </div>
        <div className="sim-legend">
          <span><i className="sim-dot" style={{ background: '#f2a89c' }} /> AI utilization, 1 processing slot</span>
          <span><i className="sim-dot" style={{ background: '#8ff0b6' }} /> AI utilization, 2 processing slots</span>
          <span><i className="sim-dot" style={{ background: '#f0cc7b' }} /> Doctor utilization, 1 doctor</span>
        </div>
      </section>

      <section className="bench-section">
        <p className="eyebrow">THE FINDING</p>
        <p className="body-copy" style={{ maxWidth: 720, fontSize: 16, lineHeight: 1.8 }}>
          At 1.5M patients/year with a single AI processing slot, AI utilization reaches{' '}
          <b style={{ color: '#f2a89c' }}>86.7%</b> -- approaching the saturation point where
          queueing theory says wait times explode nonlinearly. Doctor utilization, meanwhile,
          never exceeds <b style={{ color: '#f0cc7b' }}>52.2%</b> even with just a single doctor at
          that same volume, because only ~10% of patients are referable and actually need review.
          A second AI slot keeps utilization comfortable (<b style={{ color: '#8ff0b6' }}>43.3%</b>{' '}
          at the highest volume tested.
        </p>
        <p className="caveat" style={{ marginTop: '1.5rem' }}>
          Concrete, counter-intuitive recommendation: for district-scale growth beyond ~600k-1M
          patients/year, prioritize AI compute capacity over ophthalmologist headcount -- the
          opposite of where intuition points first. All simulation parameters (15% field-capture
          reject rate, 10% referable prevalence, 5-second AI processing time for a warm production
          service) are stated literature/estimate-based assumptions, not measurements from this
          project's own data -- see the model's source for exactly which is which.
        </p>
      </section>
    </div>
  )
}
