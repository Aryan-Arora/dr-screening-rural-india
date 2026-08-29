import { useLayoutEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { ArrowDownRight, ArrowUpRight } from 'lucide-react'
import { RetinalVisual } from '../components/retinal/RetinalVisual'

gsap.registerPlugin(ScrollTrigger)

const stages = [
  ['01', 'IMAGE QUALITY', 'A calibrated intake checks whether the photograph is suitable for meaningful review.'],
  ['02', 'RETINAL STRUCTURE', 'The retinal field, optic disc and vascular pathways are brought into focus.'],
  ['03', 'LESION DETECTION', 'Potential features are mapped as visual signals for clinician review.'],
  ['04', 'SEVERITY GRADING', 'A five-class framework gives the result a clear clinical context.'],
  ['05', 'EXPLANATION', 'Attention regions make the visual basis of the mock result inspectable.'],
]

export function Landing() {
  const page = useRef<HTMLDivElement>(null)
  useLayoutEffect(() => {
    const context = gsap.context(() => {
      gsap.to('.hero-copy', { yPercent: -24, opacity: .2, ease: 'none', scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true } })
      gsap.from('.image-copy', { y: 70, opacity: 0, scrollTrigger: { trigger: '.image-story', start: 'top 72%', end: 'top 36%', scrub: true } })
      gsap.utils.toArray<HTMLElement>('.chapter').forEach((chapter) => gsap.fromTo(chapter.querySelector('.chapter-content'), { y: 70, opacity: .16 }, { y: 0, opacity: 1, scrollTrigger: { trigger: chapter, start: 'top 72%', end: 'top 28%', scrub: true } }))
      gsap.to('.severity-dot', { left: '52%', ease: 'none', scrollTrigger: { trigger: '.severity', start: 'top 78%', end: 'center center', scrub: true } })
    }, page)
    return () => context.revert()
  }, [])
  return <div ref={page} className="landing">
    <RetinalVisual className="retinal-universe" story />
    <section className="hero"><div className="hero-copy"><p className="eyebrow hero-kicker"><i /> AI-POWERED DIABETIC RETINOPATHY SCREENING</p><h1><span className="outline">SEE</span><br />BEYOND<br /><span className="outline">THE SURFACE</span></h1><p className="hero-description">Advanced AI system for early detection<br />and analysis of diabetic retinopathy.</p><Link className="screening-button" to="/screening">START SCREENING <ArrowUpRight size={15} /></Link><div className="impact"><p className="eyebrow"><i /> OUR IMPACT</p><div className="impact-grid"><div><b>95.5%</b><span>Referable Sensitivity</span></div><div><b>2,930</b><span>Training Images</span></div><div><b>3</b><span>CNN Backbones</span></div><div><b>5</b><span>AI Modules</span></div></div></div></div><p className="scroll-cue">SCROLL <ArrowDownRight size={15} /></p><p className="explore-cue">MOVE CURSOR TO EXPLORE <span /></p></section>
    <section className="image-story section-shell"><div className="image-copy"><p className="eyebrow">01 / THE SOURCE</p><h2>EVERY IMAGE<br />TELLS A <em>STORY.</em></h2><p className="body-copy">A retinal photograph contains patterns that may be difficult to recognize without careful analysis.</p></div><div className="retina-frame"><RetinalVisual compact /><span className="scanline" /><span className="frame-label top">FIELD OF VIEW / VALID</span><span className="frame-label bottom">45° RETINAL CAPTURE</span></div></section>
    <section className="pipeline section-shell"><header className="section-heading"><p className="eyebrow">SCREENING SEQUENCE</p><h2>ENTERING<br />THE <em>ANALYSIS.</em></h2></header>{stages.map(([number, title, detail]) => <article className={`chapter chapter-${number}`} key={number}><div className="chapter-content"><span className="chapter-number">{number}</span><div><p className="eyebrow">{title}</p><h3>{title}</h3><p className="body-copy">{detail}</p></div>{number === '01' && <QualityVisual />}{number === '03' && <LesionVisual />}{number === '04' && <SeverityVisual />}{number === '05' && <ExplainVisual />}</div></article>)}</section>
    <section className="trust section-shell"><div><p className="eyebrow">EXPLAINABILITY / GRAD-CAM INSPIRED</p><h2>DON’T JUST<br />TRUST THE SCORE.<br /><em>UNDERSTAND WHY.</em></h2></div><div className="trust-flow"><span>ORIGINAL RETINAL IMAGE</span><i>↓</i><span>AI ATTENTION</span><i>↓</i><span>HIGHLIGHTED REGIONS</span><i>↓</i><span>EXPLAINABLE RESULT</span></div></section>
    <section className="access section-shell"><p className="eyebrow">FOR EVERYWHERE CARE HAPPENS</p><h2>BRING SCREENING<br />CLOSER TO <em>THE PATIENT.</em></h2><div className="access-line"><span>RETINAL IMAGE</span><i /> <span>ASSISTED REVIEW</span><i /> <span>CLINICIAN SUPPORT</span></div><p className="body-copy">Designed to support accessible, interpretable preliminary assessment in a range of care settings.</p></section>
    <section className="final-cta"><RetinalVisual className="final-retina" compact /><div><p className="eyebrow">RETINA / AI</p><h2>READY<br />TO SEE<br /><em>CLEARER?</em></h2><Link className="line-link light" to="/screening">ENTER THE SCREENING WORKSPACE <ArrowUpRight size={17} /></Link></div></section>
  </div>
}

function QualityVisual() { return <div className="quality-visual"><span className="quality-score">94.8<small>%</small></span><div><b>IMAGE QUALITY</b><p>FOCUS <i /> GOOD</p><p>ILLUMINATION <i /> GOOD</p><p>FIELD <i /> VALID</p></div></div> }
function LesionVisual() { return <div className="lesion-visual"><RetinalVisual compact /><span className="lesion one">MICROANEURYSM</span><span className="lesion two">HEMORRHAGE</span><span className="lesion three">EXUDATE</span></div> }
function SeverityVisual() { return <div className="severity"><div className="severity-line"><span className="severity-dot" /></div><div className="severity-labels"><span>NO DR</span><span>MILD</span><span className="active">MODERATE</span><span>SEVERE</span><span>PDR</span></div><small>DEMONSTRATION SCALE / NOT A CLINICAL RESULT</small></div> }
function ExplainVisual() { return <div className="explain-visual"><RetinalVisual compact /><span className="heatmap h1" /><span className="heatmap h2" /><span className="heatmap h3" /><p>AI ATTENTION MAP / DEMONSTRATION</p></div> }
