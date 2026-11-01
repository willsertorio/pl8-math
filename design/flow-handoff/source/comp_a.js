// ===================== the prototype: opening → box → setup → PRs → workout → kit → sets → session over → home =====================
// The 3D gym is the Onboarding board's (box, furnishing, kit drop, bar loading) laid out and art-directed by the Layout Lab;
// the screens are the Input screens · custom ones; the opening and the session over are the UI Animation Lab's.
class Component extends DCLogic {
  constructor(props) {
    super(props);
    // ---- the gym's plates (colour lives only here) ----
    this.SPECS = [
      { kg: 25,  label: '25',  color: '#D3262E', ink: '#FFFFFF', d: 0.450, t: 0.056, kind: 'bumper' },
      { kg: 20,  label: '20',  color: '#1E5BC6', ink: '#FFFFFF', d: 0.450, t: 0.046, kind: 'bumper' },
      { kg: 15,  label: '15',  color: '#F3C318', ink: '#1A1A1A', d: 0.450, t: 0.036, kind: 'bumper' },
      { kg: 10,  label: '10',  color: '#2E8A4B', ink: '#FFFFFF', d: 0.450, t: 0.027, kind: 'bumper' },
      { kg: 5,   label: '5',   color: '#F2F2EE', ink: '#1A1A1A', d: 0.230, t: 0.024, kind: 'change' },
      { kg: 2.5, label: '2.5', color: '#D3262E', ink: '#FFFFFF', d: 0.190, t: 0.019, kind: 'change' },
      { kg: 2,   label: '2',   color: '#1E5BC6', ink: '#FFFFFF', d: 0.175, t: 0.017, kind: 'change' },
      { kg: 1.5, label: '1.5', color: '#F3C318', ink: '#1A1A1A', d: 0.160, t: 0.015, kind: 'change' },
      { kg: 1,   label: '1',   color: '#2E8A4B', ink: '#FFFFFF', d: 0.150, t: 0.013, kind: 'change' },
      { kg: 0.5, label: '0.5', color: '#F2F2EE', ink: '#1A1A1A', d: 0.135, t: 0.011, kind: 'change' }
    ];
    this.LB_SPECS = [
      { kg: 55,  label: '55',  color: '#D3262E', ink: '#FFFFFF', d: 0.450, t: 0.058, kind: 'bumper', unit: 'LB' },
      { kg: 45,  label: '45',  color: '#1E5BC6', ink: '#FFFFFF', d: 0.450, t: 0.050, kind: 'bumper', unit: 'LB' },
      { kg: 35,  label: '35',  color: '#F3C318', ink: '#1A1A1A', d: 0.450, t: 0.040, kind: 'bumper', unit: 'LB' },
      { kg: 25,  label: '25',  color: '#2E8A4B', ink: '#FFFFFF', d: 0.450, t: 0.030, kind: 'bumper', unit: 'LB' },
      { kg: 15,  label: '15',  color: '#F2F2EE', ink: '#1A1A1A', d: 0.300, t: 0.026, kind: 'change', unit: 'LB' },
      { kg: 10,  label: '10',  color: '#26282C', ink: '#FFFFFF', d: 0.250, t: 0.024, kind: 'change', unit: 'LB' },
      { kg: 5,   label: '5',   color: '#26282C', ink: '#FFFFFF', d: 0.205, t: 0.020, kind: 'change', unit: 'LB' },
      { kg: 2.5, label: '2.5', color: '#26282C', ink: '#FFFFFF', d: 0.165, t: 0.016, kind: 'change', unit: 'LB' }
    ];
    this.SPECS.forEach((sp) => { sp.unit = 'KG'; });
    this.specsFor = (u) => (u === 'lb' ? this.LB_SPECS : this.SPECS);
    this.cache = {};
    this.S = 8; this.H = 2.6; this.CUBE = 8;
    this.FLAG_FONTS = [
      { id: 'helvetica', label: 'Helvetica', css: 'Helvetica, "Helvetica Neue", Arial, sans-serif', weight: 700 },
      { id: 'anton', label: 'Anton', css: '"Anton", Impact, sans-serif', weight: 400 },
      { id: 'bebas', label: 'Bebas Neue', css: '"Bebas Neue", Impact, sans-serif', weight: 400 },
      { id: 'archivo', label: 'Archivo Black', css: '"Archivo Black", Arial Black, sans-serif', weight: 400 },
      { id: 'playfair', label: 'Playfair', css: '"Playfair Display", Georgia, serif', weight: 900 },
      { id: 'dmserif', label: 'DM Serif', css: '"DM Serif Display", Georgia, serif', weight: 400 },
      { id: 'spacemono', label: 'Space Mono', css: '"Space Mono", "Courier New", monospace', weight: 700 },
      { id: 'marker', label: 'Marker', css: '"Permanent Marker", "Comic Sans MS", cursive', weight: 400 }
    ];
    // scene state the gym code reads (art direction + the box)
    this.state = { view: 'overview', outline: true, shadows: true, spin: false, base: true, closed: false, plateSegs: 80,
      boxLight: '#EFE3CF', boxDark: '#4A3426', bgColor: '#00B3FF', bgMode: 'sky', cloudReal: 1, flagFont: 'playfair', media: null, unit: 'kg', scale: 1, framed: false };
    try {
      const saved = JSON.parse(localStorage.getItem('dz-art') || 'null');
      if (saved) ['boxLight', 'boxDark', 'bgColor'].forEach((k) => { if (/^#[0-9A-Fa-f]{6}$/.test(saved[k] || '')) this.state[k] = saved[k]; });
      if (saved && (saved.bgMode === 'sky' || saved.bgMode === 'colour')) this.state.bgMode = saved.bgMode;
      if (saved && this.FLAG_FONTS.some((f) => f.id === saved.flagFont)) this.state.flagFont = saved.flagFont;
      if (saved && isFinite(saved.cloudReal)) this.state.cloudReal = Math.min(1, Math.max(0, +saved.cloudReal));
    } catch (e) {}
    this.pal = { boxLight: this.state.boxLight, boxDark: this.state.boxDark, bgColor: this.state.bgColor };
    // the Layout Lab is the source of truth for the palette: follow it live
    this.onArtStore = (e) => {
      if (this.dead) return;
      if (e.key === 'dz-art' && e.newValue) {
        let a = null; try { a = JSON.parse(e.newValue); } catch (er) { return; }
        ['boxLight', 'boxDark', 'bgColor'].forEach((k) => { if (/^#[0-9A-Fa-f]{6}$/.test(a[k] || '')) { this.state[k] = a[k]; this.pal[k] = a[k]; } });
        if (a.bgMode === 'sky' || a.bgMode === 'colour') this.state.bgMode = a.bgMode;
        this.applyUILook(); this.setState({ palRev: (this.state.palRev || 0) + 1 });
      }
      if (e.key === 'input-custom-look' && e.newValue) { try { this.look = Object.assign({}, this.LOOK_DEF, JSON.parse(e.newValue)); this.applyUILook(); } catch (er) {} }
      if (e.key === 'layoutlab-look' && e.newValue) { try { this.slook = Object.assign({}, this.SLOOK_DEF, JSON.parse(e.newValue)); this.state.bgMode = this.slook.bg === 'sky' ? 'sky' : 'colour'; this.slookKey = null; } catch (er) {} }
    };
    window.addEventListener('storage', this.onArtStore);

    // ---- the Layout Lab's art direction for the 3D (its Look tab, saved in this browser) ----
    this.SLOOK_DEF = { duotone: false, duoDark: 'brown', duoLight: 'cream', posterize: 0, contrast: 1, bright: 1, saturate: 1, hue: 0,
      pixel: 1, blur: 0, grain: 0, halftone: 0, dotSize: 6, scan: 0, paper: 0, vignette: 0, ambient: 2.7, sunI: 1.5, bg: 'flat',
      sketch: true, skCol: 'brown', skWidth: 2.5, skRough: 6, skScale: 0.03, skBoil: 0, skGrain: 0.45, skDouble: true, skInner: true, skWarp: 0.35 };
    let sl = null; try { sl = JSON.parse(localStorage.getItem('layoutlab-look') || 'null'); } catch (e) {}
    this.slook = Object.assign({}, this.SLOOK_DEF, sl || {});
    if (sl && !sl.v2) this.slook.duotone = false;
    { const b = this.slook.bg, named = { orange: '#E8742C', cream: '#EFE3CF', brown: '#4A3426' };
      if (named[b]) { this.state.bgColor = named[b]; this.slook.bg = 'flat'; }
      this.state.bgMode = this.slook.bg === 'sky' ? 'sky' : 'colour'; }

    // ---- the screens' look: Input screens · custom (saved in this browser), with Will's black-and-white default ----
    this.UFONTS = {
      grotesk: ["'Space Grotesk', Helvetica, sans-serif", 700, 'Space Grotesk'], mono: ["'Space Mono', ui-monospace, monospace", 700, 'Space Mono'],
      archivo: ["'Archivo Black', Helvetica, sans-serif", 400, 'Archivo Black'], bebas: ["'Bebas Neue', Impact, sans-serif", 400, 'Bebas Neue'],
      anton: ["Anton, Impact, sans-serif", 400, 'Anton'], playfair: ["'Playfair Display', Georgia, serif", 900, 'Playfair'],
      dmsans: ["'DM Sans', Helvetica, sans-serif", 700, 'DM Sans'], helvetica: ["Helvetica, Arial, sans-serif", 700, 'Helvetica']
    };
    this.LOOK_DEF = {
      accent: '#000000', text: '#000000', ink: '#FFFFFF', surface: '#FFFFFF', card: '#FFFFFF', bg: '#FFFFFF', frC: null,
      fd: 'grotesk', ft: 'grotesk', tSize: 1, tW: 600, tTrack: 0, tSub: 0.48,
      hSize: 25, hTrack: -0.01, hLine: 1, caps: 'off',
      fStyle: 'outline', fH: 56, fR: 14, fSize: 24,
      dR: 0, dBw: 2, dBc: 'none', dSh: 'none', dGrab: 'off', dFit: 'fit', dMax: 62, dFix: 52,
      cR: 0, cBw: 0, cSh: 'none',
      bFill: 'solid', bR: 0, bH: 40, bBw: 0, bSh: 'none', bCase: 'off',
      frStyle: 'none', frW: 8, frR: 0, frTop: 'frame', frLine: 'off',
      rough: 4.5, grain: 0.039, boil: 'off', rkDrawer: 'on', rkCard: 'off', rkButton: 'on', rkField: 'off', rkControl: 'off', rkFrame: 'off'
    };
    let lk = null; try { lk = JSON.parse(localStorage.getItem('input-custom-look') || 'null'); } catch (e) {}
    this.look = Object.assign({}, this.LOOK_DEF, lk || {});

    // ---- the athlete's data: fresh for every run of the prototype ----
    this.BARS = { kg: [[20, 'Olympic bar'], [15, 'Women’s Olympic bar'], [10, 'Technique bar']], lb: [[45, 'Olympic bar'], [35, 'Women’s Olympic bar'], [15, 'Technique bar']] };
    this.DEMO_PRS = { 'Back squat': 140, 'Front squat': 115, 'Deadlift': 180, 'Clean': 100, 'Snatch': 80, 'Bench press': 100 };
    this.DEF = { name: '', unit: 'kg', own: { kg: [25, 20, 15, 10, 5, 2.5, 2, 1.5, 1, 0.5], lb: [55, 45, 35, 25, 15, 10, 5, 2.5] }, bar: { kg: 20, lb: 45 },
      prs: [['Back squat', null], ['Front squat', null], ['Deadlift', null], ['Clean', null], ['Snatch', null], ['Bench press', null]],
      wod: [{ lift: 'Back squat', sets: 5, reps: 5, pct: 75 }, { lift: 'Deadlift', sets: 3, reps: 3, pct: 80 }], kitGot: {} };
    this.d = JSON.parse(JSON.stringify(this.DEF));
    this.setIdx = 0; this.doneSets = [];

    // ---- the phone frame: 390 × 844, scaled to fit the board ----
    this.setOuter = (el) => {
      if (!el || this.outerEl) return;
      this.outerEl = el;
      const fit = () => {
        const w = el.clientWidth, h = el.clientHeight, framed = w > 430 || h > 900;
        const sc = Math.max(0.3, Math.min(framed ? 1.25 : 1, (h - (framed ? 32 : 0)) / 844, (w - (framed ? 32 : 0)) / 390));
        if (framed !== this.state.framed || Math.abs(sc - this.state.scale) > 0.004) this.setState({ framed, scale: sc });
      };
      this.outerRO = new ResizeObserver(fit); this.outerRO.observe(el); fit();
    };
    this.setPhone = (el) => { if (el && !this.phone) { this.phone = el; this.buildPhone(); } };
  }

  renderVals() {
    const st = this.state;
    return { setOuter: this.setOuter, setPhone: this.setPhone, palBg: this.uiBg || '#FFFFFF', scale: st.scale || 1,
      radius: st.framed ? '44px' : '0', shadow: st.framed ? '0 30px 60px rgba(43,30,22,0.28)' : 'none' };
  }

  // ---------------- data helpers ----------------
  specs() { return this.specsFor(this.d.unit); }
  own() { return this.d.own[this.d.unit] || []; }
  barW() { return (this.d.bar && this.d.bar[this.d.unit]) || (this.d.unit === 'kg' ? 20 : 45); }
  haveList(u) { return this.d.own[u] || []; }
  barOf(u) { return (this.d.bar && this.d.bar[u]) || (u === 'kg' ? 20 : 45); }
  demoPR(q) { const v = this.DEMO_PRS[q[0]] || 0; return this.d.unit === 'lb' ? Math.round(v * 2.2046 / 5) * 5 : v; }
  prOf(lift) { const r = this.d.prs.find((q) => q[0] === lift); return r && r[1] != null && r[1] > 0 ? r[1] : this.demoPR([lift]); }
  fmt(v) { return v == null ? '—' : (Math.round(v * 100) / 100).toLocaleString('en-US'); }
  setUnit(u) { this.d.unit = u; this.state.unit = u; }
  prData() { const prs = this.d.prs.filter((q) => q[1] != null && q[1] > 0).map((q) => ({ lift: q[0], value: this.fmt(q[1]) })); return prs.length ? { prs } : null; }

  // today's plan from the workout: every set's load from the plates the gym has, a warm-up before the first lift,
  // and the kit (per plate size, the most any one set needs on a side, times two)
  workoutPlan() {
    const u = this.d.unit, bar = this.barW(), denoms = this.own().slice().sort((a, b) => b - a);
    const solve = denoms.length ? this.solver(denoms) : null;
    const loadAt = (lo, hi, plus) => (solve ? this.loadable(lo, hi, plus, bar, denoms, solve) : { total: bar, side: [] });
    const groups = this.d.wod.map((e) => {
      const pr = this.prOf(e.lift), sets = [];
      for (let i = 0; i < e.sets; i++) { const c = loadAt(pr * e.pct / 100, null, false); sets.push({ label: 'Set ' + (i + 1), n: i + 1, of: e.sets, reps: e.reps, pct: e.pct + '%', total: c.total, side: c.side }); }
      return { name: e.lift, format: e.sets + ' × ' + e.reps + ' @ ' + e.pct + '%', pr, sets };
    }).filter((g) => g.sets.length);
    if (!groups.length) return null;
    const g0 = groups[0], first = g0.sets[0], warm = []; let last = -1;
    [[0.5, 5], [0.7, 3], [0.85, Math.max(1, first.reps)]].forEach(([f, r]) => {
      const c = loadAt(first.total * f, null, false);
      if (c.total <= last || c.total >= first.total) return; last = c.total;
      warm.push({ label: 'Round ' + (warm.length + 1), reps: r, pct: '≈' + Math.round(c.total / g0.pr * 100) + '%', total: c.total, side: c.side });
    });
    if (!warm.length) warm.push({ label: 'Round 1', reps: 5, pct: 'Empty bar', total: bar, side: [] });
    warm.forEach((w, i) => { w.n = i + 1; w.of = warm.length; });
    groups.unshift({ name: 'Warm-up', warm: true, sets: warm });
    const maxPer = {};
    groups.forEach((g) => g.sets.forEach((x) => { const n = {}; x.side.forEach((w) => { n[w] = (n[w] || 0) + 1; }); Object.keys(n).forEach((w) => { maxPer[w] = Math.max(maxPer[w] || 0, n[w]); }); }));
    const kit = Object.keys(maxPer).map(Number).sort((a, b) => b - a).map((w) => ({ w, qty: maxPer[w] * 2 }));
    const flat = []; groups.forEach((g, gi) => g.sets.forEach((x) => flat.push(Object.assign({ gi, group: g.warm ? 'Warm-up · ' + groups[1].name : g.name }, x))));
    return { groups, kit, flat, bar, unit: u };
  }

  // ---------------- the phone ----------------
  buildPhone() {
    const P = this.phone;
    // anything that breaks shows up on the phone, so it can be reported
    this.onWinErr = (e) => { if (!this.dead) this.reportError((e && e.error) || (e && e.message) || e); };
    window.addEventListener('error', this.onWinErr);
    P.classList.add('ios');
    // the 3D stage (the gym), then the frame and rough filters, then our UI layer, then the system chrome
    const stage = document.createElement('div'); Object.assign(stage.style, { position: 'absolute', inset: 0 }); P.appendChild(stage); this.stageEl = stage;
    const cv = document.createElement('canvas'); cv.setAttribute('aria-label', 'Your gym, in 3D'); Object.assign(cv.style, { display: 'block', width: '100%', height: '100%', touchAction: 'none' }); stage.appendChild(cv);
    this.frameEl = this.h('div', { position: 'absolute', inset: 0, pointerEvents: 'none', overflow: 'hidden', zIndex: 0, display: 'none' }, P);
    this.frameHole = this.h('div', { position: 'absolute' }, this.frameEl);
    const fx = document.createElement('div'); fx.setAttribute('aria-hidden', 'true'); Object.assign(fx.style, { position: 'absolute', width: 0, height: 0, overflow: 'hidden' });
    fx.innerHTML = '<svg width="0" height="0"><filter id="cu-rough" x="-25%" y="-25%" width="150%" height="150%"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="1" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0" xChannelSelector="R" yChannelSelector="G"/></filter>'
      + '<filter id="cu-rough-frame" filterUnits="userSpaceOnUse" x="-650" y="-650" width="1700" height="2150"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="1" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0" xChannelSelector="R" yChannelSelector="G"/></filter></svg>';
    P.appendChild(fx);
    this.turb = [...fx.querySelectorAll('feTurbulence')]; this.disp = [...fx.querySelectorAll('feDisplacementMap')];
    this.ui = this.h('div', { position: 'absolute', inset: 0, zIndex: 5 }, P); this.ui.classList.add('cu'); this.applyUILook();
    // every button gives under the finger: it sinks quickly and springs back with an ease-out
    { const SEL = 'button, .tap, [role=radio], [role=checkbox], [role=button], [role=switch]';
      let cur = null;
      const up = () => {
        const el = cur; cur = null; if (!el) return;
        const s0 = el.__ps || 0.95;
        if (el.__pa) { try { el.__pa.cancel(); } catch (e) {} el.__pa = null; }
        el.animate([{ transform: 'scale(' + s0 + ')' }, { transform: 'scale(1)' }], { duration: 280, easing: 'cubic-bezier(.2,.8,.25,1)' });
      };
      P.addEventListener('pointerdown', (e) => {
        const el = e.target && e.target.closest ? e.target.closest(SEL) : null;
        if (!el || !P.contains(el) || el.closest('[data-nopress]')) return;
        up(); cur = el;
        const s0 = el.__ps = 1 - Math.min(0.06, 10 / Math.max(40, el.offsetWidth || 40));
        el.__pa = el.animate([{ transform: 'scale(1)' }, { transform: 'scale(' + s0 + ')' }], { duration: 110, easing: 'cubic-bezier(.2,.8,.25,1)', fill: 'forwards' });
      }, true);
      ['pointerup', 'pointercancel'].forEach((ev) => window.addEventListener(ev, up, true));
      P.addEventListener('pointerleave', up); }
    this.raw = true;
    const sb = this.h('div', { position: 'absolute', left: 0, right: 0, top: 0, height: '54px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 30px 0 44px', boxSizing: 'border-box', pointerEvents: 'none', zIndex: 40, fontSize: '17px', fontWeight: 600, color: '#000' }, P);
    this.h('span', {}, sb, '9:41');
    this.h('span', { display: 'flex', gap: '6px', alignItems: 'center' }, sb).innerHTML = '<svg width="18" height="12" viewBox="0 0 18 12" aria-hidden="true" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg><svg width="26" height="12" viewBox="0 0 26 12" aria-hidden="true" fill="currentColor"><rect x="0.5" y="0.5" width="22" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="17" height="8" rx="2"/><rect x="23.5" y="4" width="1.8" height="4" rx="1" opacity=".4"/></svg>';
    this.statusBar = sb;
    this.h('div', { position: 'absolute', left: '50%', top: '11px', width: '126px', height: '37px', marginLeft: '-63px', borderRadius: '19px', background: '#000', zIndex: 45, pointerEvents: 'none' }, P);
    this.h('div', { position: 'absolute', left: '50%', bottom: '8px', width: '134px', height: '5px', marginLeft: '-67px', borderRadius: '3px', background: '#000', zIndex: 60, pointerEvents: 'none' }, P);
    this.haptic = this.h('div', { position: 'absolute', left: '12px', top: '58px', padding: '5px 10px', borderRadius: '12px', background: 'rgba(0,0,0,0.72)', color: '#FFF', fontSize: '12px', fontWeight: 600, zIndex: 55, opacity: 0, transition: 'opacity .2s', pointerEvents: 'none' }, P);
    this.raw = false;
    // 1 · the app opening, over everything until it is tapped
    this.showOpening();
    this.boot();
  }
  h(tag, css, parent, text) { const e = document.createElement(tag); if (css) { Object.assign(e.style, this.raw ? css : this.themeCss(css)); if (!this.raw) this.markRough(e, css); } if (this.raw && parent === this.ui) e.classList.add('sys'); if (text != null) e.textContent = text; if (parent) parent.appendChild(e); return e; }
  sys(fn) { const was = this.raw; this.raw = true; try { return fn(); } finally { this.raw = was; } }
  buzz(kind) { if (!this.haptic) return; this.haptic.textContent = '◉ Haptic · ' + kind; this.haptic.style.opacity = '1'; clearTimeout(this.hT); this.hT = setTimeout(() => { if (this.haptic) this.haptic.style.opacity = '0'; }, 900); }
  clearUI() { this.closeKeyboard(true); if (this.ui) this.ui.innerHTML = ''; this.sheetEl = null; this.cardEl = null; if (this.statusBar) this.statusBar.style.color = '#000'; }

  // ---------------- the two animation scenes ----------------
  // the layer's own element listens for taps too, so a tap always moves the app on even if the animation could not start
  animLayer(scene, opts) {
    const el = document.createElement('div'); el.setAttribute('data-nopress', '');
    Object.assign(el.style, { position: 'absolute', inset: 0, zIndex: 38, overflow: 'hidden', transition: 'opacity .55s ease', cursor: 'pointer', background: (this.pal && this.pal.bgColor) || '#E8742C' });
    this.phone.appendChild(el);
    let down = null;
    el.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY, t: Date.now() }; }, true);
    el.addEventListener('click', (e) => {
      const d = down; down = null;
      if (d && (Math.hypot(e.clientX - d.x, e.clientY - d.y) > 10 || Date.now() - d.t > 900)) return;   // a drag, not a tap
      if (opts.onTap) opts.onTap();
    });
    let L = null;
    try { L = new AnimLayer(el, scene, Object.assign({}, opts, { onTap: null })); }
    catch (err) { this.reportError(err); L = { destroy() {}, ready: () => true, D: null }; }
    L.el = el; return L;
  }
  reportError(err) {
    try { console.error(err); } catch (e) {}
    if (!this.phone) return;
    const p = this.errEl || (this.errEl = this.sys(() => this.h('div', { position: 'absolute', left: '12px', right: '12px', bottom: '40px', padding: '8px 10px', borderRadius: '10px', background: 'rgba(160,20,20,0.9)', color: '#FFF', fontSize: '11px', fontFamily: 'ui-monospace, Menlo, monospace', zIndex: 70, pointerEvents: 'none', whiteSpace: 'pre-wrap' }, this.phone)));
    p.textContent = String(err && err.message || err).slice(0, 240);
  }
  dropLayer(L, then) {
    if (!L || L.gone) return; L.gone = true;
    L.el.style.opacity = '0'; L.el.style.pointerEvents = 'none';
    setTimeout(() => { L.destroy(); L.el.remove(); if (then) then(); }, 560);
  }
  showOpening() {
    this.paused = true;
    try {
      this.openL = this.animLayer('open', { onTap: () => this.closeOpening() });
      this.openL.el.setAttribute('role', 'button'); this.openL.el.setAttribute('aria-label', 'pl8(math). Tap to start');
    } catch (err) { this.reportError(err); this.paused = false; }
  }
  // where the cube will sit on screen, and how tall it is there (phone px)
  cubeTarget() {
    const T = this.THREE, g = this.popG, cam = this.camera; if (!T || !g || !cam) return null;
    const s = g.scale.x, v = g.visible; g.scale.setScalar(1); g.visible = true; g.updateMatrixWorld(true);
    const b = new T.Box3().setFromObject(g); g.scale.setScalar(s); g.visible = v; g.updateMatrixWorld(true);
    if (b.isEmpty()) return null;
    const c = b.getCenter(new T.Vector3()), W = this.phone.clientWidth || 390, H = this.phone.clientHeight || 844;
    const pr = (x, y, z) => { const q = new T.Vector3(x, y, z).project(cam); return { x: (q.x + 1) / 2 * W, y: (1 - q.y) / 2 * H }; };
    const m = pr(c.x, c.y, c.z), top = pr(c.x, b.max.y, c.z), bot = pr(c.x, b.min.y, c.z);
    return { x: m.x, y: m.y, h: Math.abs(bot.y - top.y) };
  }
  closeOpening() {
    this.paused = false;            // 2 · the box pops in under the fading title, and waits for a tap
    const L = this.openL; this.openL = null;
    if (!L || L.gone) return;
    this.buzz('light');
    this.dropLayer(L);
  }
