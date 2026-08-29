import React, { useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { motion, useReducedMotion } from 'framer-motion'
import { ArrowUpRight } from 'lucide-react'
import { RetinalVisual } from '../retinal/RetinalVisual'

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
  const reduceMotion = useReducedMotion()
  // Critically damped by default (Apple's house style for non-momentum UI:
  // damping 1.0 reads as graceful, not distracting) -- this indicator never
  // carries gesture velocity, so it never earns the bounce reserved for
  // flicks/drags.
  const indicatorSpring = { type: 'spring' as const, damping: 1, duration: reduceMotion ? 0 : 0.35 }

  return (
    <div className="app-shell">
      <header className="site-header">
        <div className="site-header-inner">
          <Link to="/" className="brand-mark">RETINAL <span>AI</span></Link>
          <nav className="desktop-nav">
            {navigation.map((item) => {
              const active = location.pathname.startsWith(item.path)
              return (
                <Link key={item.path} to={item.path} className={active ? 'active' : ''}>
                  {item.label}
                  {active && (
                    <motion.span
                      layoutId="nav-indicator"
                      className="nav-indicator"
                      transition={indicatorSpring}
                    />
                  )}
                </Link>
              )
            })}
          </nav>
          <Link className="header-cta" to="/screening">START SCREENING <ArrowUpRight size={13} /></Link>
          <button className="menu-button mobile-menu" onClick={() => setOpen(true)}>MENU <span>+</span></button>

        </div>
      </header>

      {/* A quiet echo of the Landing hero's retina visual, so interior
          "workspace" pages don't feel like an abrupt drop from a richly
          art-directed home page into flat, empty black. Landing supplies
          its own dominant version, so it's excluded here. */}
      {location.pathname !== '/' && (
        <div className="page-accent" aria-hidden="true">
          <RetinalVisual />
        </div>
      )}

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
