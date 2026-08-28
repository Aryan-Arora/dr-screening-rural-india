import React, { useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { ArrowUpRight } from 'lucide-react'

interface LayoutProps {
  children: React.ReactNode
}

const navigation = [
  { label: 'Screening', path: '/screening' },
  { label: 'Cases', path: '/cases' },
  { label: 'Simulation', path: '/simulation' },
  { label: 'Benchmarks', path: '/benchmarks' },
  { label: 'Architecture', path: '/architecture' },
]

export const Layout: React.FC<LayoutProps> = ({ children }) => {
  const location = useLocation()
  const [open, setOpen] = useState(false)

  return (
    <div className="app-shell">
      <header className="site-header">
        <div className="site-header-inner">
          <Link to="/" className="brand-mark">RETINAL <span>AI</span></Link>
          <nav className="desktop-nav">
            {navigation.map((item) => <Link key={item.path} to={item.path}>{item.label}</Link>)}
          </nav>
          <Link className="header-cta" to="/screening">START SCREENING <ArrowUpRight size={13} /></Link>
          <button className="menu-button mobile-menu" onClick={() => setOpen(true)}>MENU <span>+</span></button>

        </div>
      </header>

      <main>
        {children}
      </main>
      <div className={`nav-overlay ${open ? 'is-open' : ''}`} aria-hidden={!open}>
        <button className="menu-button overlay-close" onClick={() => setOpen(false)}>× CLOSE</button>
        <p className="eyebrow">NAVIGATION / RETINA AI</p>
        <nav>{navigation.map((item, index) => <Link key={item.path} to={item.path} onClick={() => setOpen(false)} className={location.pathname === item.path ? 'active' : ''}><span>0{index + 1}</span>{item.label}</Link>)}</nav>
      </div>
    </div>
  )
}
