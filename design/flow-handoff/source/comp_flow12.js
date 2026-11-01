
  // ===================== FLOW, round 12: Will's type and palettes =====================
  get FLPALS() {
    return [
      { name: 'Swiss red', bg: '#E5321C', light: '#F4F1EA', dark: '#151515', card: '#FFFFFF', acc: '#E5321C' },
      { name: 'Current', bg: '#FF6200', light: '#F0E2F3', dark: '#6C3713', card: '#FFFFFF', acc: '#FF6200' },
      { name: 'Ink blue', bg: '#2A4BFF', light: '#EEF0F6', dark: '#0C1A4A', card: '#FFFFFF', acc: '#2A4BFF' },
      { name: 'Chalk green', bg: '#1F6B49', light: '#EEE9DC', dark: '#16261D', card: '#FBF9F3', acc: '#E8B43A' },
      { name: 'Mono', bg: '#141414', light: '#F2F2F0', dark: '#141414', card: '#FFFFFF', acc: '#FF6200' }
    ];
  }
  flRgba(hex, a) { const n = parseInt(String(hex || '#6C3713').slice(1), 16); return 'rgba(' + (n >> 16 & 255) + ',' + (n >> 8 & 255) + ',' + (n & 255) + ',' + a + ')'; }
  // switch palette: everything on screen is rebuilt in the new colours
  flPalSet(i, rebuild) {
    const L = this.FLPALS; this.flPalIdx = ((i % L.length) + L.length) % L.length; const p = L[this.flPalIdx];
    try { localStorage.setItem('pl8.flow.pal', String(this.flPalIdx)); } catch (e) {}
    this.pal = { boxLight: p.light, boxDark: p.dark, bgColor: p.bg, card: p.card, acc: p.acc };
    Object.assign(this.state, { boxLight: p.light, boxDark: p.dark, bgColor: p.bg });
    window.__flPal = { boxLight: p.light, boxDark: p.dark, bgColor: p.bg };
    if (this.FC) Object.assign(this.FC, { bg: p.bg, light: p.light, dark: p.dark });
    if (this.phone) this.phone.style.background = p.bg;
    // on the opening screen: redraw it in the new (inverted) colours
    if (!this.FL && rebuild && this.openL && !this.openL.gone) {
      const old = this.openL; this.openL = this.animLayer('open', { onTap: () => this.closeOpening() });
      try { old.destroy(); } catch (e) {} old.el.remove();
    }
    if (!this.FL) return;
    this.flApplyStyle();
    if (rebuild && this.flStep && this.flStep !== 'done' && !this.flPanning) { const st = this.flStep; this.flGo(st === 'prDial' ? 'prDial' : st); }
  }
  // keys: W rough edges, C background. On the phone: tap the clock for the next palette,
  // double-tap the Dynamic Island for rough edges, double-tap the battery for the background
  frame() {
    if (this.flKeyed) return; this.flKeyed = true;
    let i0 = 0; try { i0 = parseInt(localStorage.getItem('pl8.flow.pal') || '0', 10) || 0; } catch (e) {}
    this.flPalSet(i0, false);
    try { const q = parseInt(localStorage.getItem('pl8.flow.qtop2') || '', 10); if (q > 0) this.flQTop = q; } catch (e) {}
    try { const c = parseFloat(localStorage.getItem('pl8.flow.collage') || '0'); if (c > 0) this.flCol = Math.min(1, c); } catch (e) {}
    this.onFlKey = (e) => { if (e.target && /input|textarea/i.test(e.target.tagName)) return; if (e.key === 'w' || e.key === 'W') this.flToggleRough(); if (e.key === 'c' || e.key === 'C') this.flToggleBg(); if (e.key === 'p' || e.key === 'P') this.flPalSet(this.flPalIdx + 1, true);
      // ↑ / ↓ move the question (Shift: 10px steps), 0 puts it back
      // Option/Alt + ↑ / ↓ move the question (Shift: 10px steps), 0 puts it back
      if (e.altKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) { e.preventDefault(); this.flQMove((e.key === 'ArrowUp' ? -1 : 1) * (e.shiftKey ? 10 : 2)); return; }
      if (e.key === '0') { e.preventDefault(); this.flQMove(null); return; }
      // ↑ / ↓ make the question's letters more (or less) of a collage; Backspace clears it
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') { e.preventDefault(); this.flCollageSet((this.flCol || 0) + (e.key === 'ArrowUp' ? 0.1 : -0.1)); }
      if (e.key === 'Backspace') { e.preventDefault(); this.flCollageSet(0); } };
    window.addEventListener('keydown', this.onFlKey);
    if (!this.phone) return;
    const zone = (css, fn, dbl) => {
      const z = document.createElement('div'); z.setAttribute('aria-hidden', 'true'); z.setAttribute('data-nopress', '');
      Object.assign(z.style, Object.assign({ position: 'absolute', top: 0, height: '54px', zIndex: 60, touchAction: 'manipulation' }, css));
      let last = 0;
      z.addEventListener('pointerup', (e) => { e.stopPropagation(); const now = performance.now(); if (!dbl || now - last < 380) { last = 0; fn(); this.buzz('success'); try { this.flCheckSound(); } catch (er) {} } else last = now; });
      z.addEventListener('pointerdown', (e) => e.stopPropagation());
      z.addEventListener('click', (e) => e.stopPropagation());
      this.phone.appendChild(z);
    };
    zone({ left: 0, width: '110px' }, () => this.flPalSet(this.flPalIdx + 1, true), false);
    zone({ left: '50%', width: '140px', marginLeft: '-70px' }, () => this.flToggleRough(), true);
    zone({ right: 0, width: '110px' }, () => this.flToggleBg(), true);
  }
  // the question's distance from the top of the screen, tweakable with the arrow keys; remembered in this browser
  flQMove(d) {
    const v = d == null ? 150 : Math.max(50, Math.min(400, (this.flQTop || 150) + d)); this.flQTop = v;
    try { localStorage.setItem('pl8.flow.qtop2', String(v)); } catch (e) {}
    if (this.FL) { this.FL.q.style.top = v + 'px'; if (this.flStep === 'plates') this.flGo('plates'); else this.flQShift(this.flStep); }
    this.flTip('Question top: ' + this.flQTop + 'px' + (this.flQTop === 150 ? ' (default)' : ''));
  }
  // a small readout at the bottom of the phone, so the number can be copied into the iOS app
  flTip(msg) {
    if (!this.phone || msg == null) return;
    let t = this.flQTip;
    if (!t) { t = this.flQTip = document.createElement('div'); Object.assign(t.style, { position: 'absolute', left: '50%', bottom: '18px', transform: 'translateX(-50%)', zIndex: 70, padding: '6px 12px', borderRadius: '12px', background: 'rgba(0,0,0,0.72)', color: '#fff', font: "500 13px 'Helvetica Neue', Helvetica, Arial, sans-serif", fontVariantNumeric: 'tabular-nums', pointerEvents: 'none', transition: 'opacity .3s' }); t.setAttribute('aria-live', 'polite'); this.phone.appendChild(t); }
    t.textContent = msg; t.style.opacity = '1';
    clearTimeout(this.flQTipT); this.flQTipT = setTimeout(() => { if (this.flQTip) this.flQTip.style.opacity = '0'; }, 1400);
  }
  flQShift(step) {
    const F = this.FL; if (!F) return;
    const want = ['name', 'unit', 'bar', 'prs', 'prDial', 'wod'].indexOf(step) >= 0 ? (this.flQTop || 150) - 92 : 0;
    const have = F.qStep === step ? (F.qShift || 0) : 0, d = want - have;
    F.qStep = step; F.qShift = want; if (!d) return;
    const G = this.flPanGeo(); F.cam.position.addScaledVector(G.up, d * G.wpp);
    if (this.flCamT) this.flCamT.addScaledVector(G.up, d * G.wpp);
  }
  // the whiteboard's shadow: the same soft blob the menu uses (in the board's own units, so it follows it around)
  flBoardShadow(wb) { const sh = this.softShadow(0.7 / 0.62); sh.scale.set(1, 0.6, 1); sh.position.y = 0.004; wb.add(sh); return sh; }
  // the question, said: each word appears; every letter is its own piece so the words can turn into a collage
  flSay(text, then) {
    const F = this.FL, q = F.q; F.words.forEach(clearTimeout); F.words = [];
    q.getAnimations().forEach((a) => a.cancel());
    q.textContent = ''; q.setAttribute('aria-label', text); q.style.opacity = '1';
    const ws = text.split(/\s+/).filter(Boolean); let t = 0, n = 0;
    ws.forEach((w, i) => {
      const s = document.createElement('span'); Object.assign(s.style, { visibility: 'hidden', display: 'inline-block', whiteSpace: 'nowrap' }); s.setAttribute('aria-hidden', 'true');
      [...w].forEach((ch) => { const l = document.createElement('span'); l.textContent = ch; l.className = 'fl-ch'; l.dataset.k = String(n++); l.style.display = 'inline-block'; s.appendChild(l); });
      q.appendChild(s);
      if (i < ws.length - 1) q.appendChild(document.createTextNode(' '));
      F.words.push(setTimeout(() => { if (!this.dead) s.style.visibility = 'visible'; }, t));
      t += 95 + 18 * w.replace(/[^\w’']/g, '').length;
      if (/[,;:]$/.test(w)) t += 230;
      if (/[.?!…]$/.test(w)) t += 420;
    });
    this.flCollage();
    const total = t + 120;
    F.words.push(setTimeout(() => { if (!this.dead && then) then(); }, total));
    return total;
  }
  // collage: 0 is clean type; up to 1, the letters spread apart, tilt, hop up and down and change size a little —
  // always the same way for the same letter, so it looks cut and pasted, not jittery
  flCollage() {
    const F = this.FL; if (!F) return;
    const k = this.flCol || 0, rnd = (i, s) => { const x = Math.sin((i + 1) * 12.9898 + s * 78.233) * 43758.5453; return (x - Math.floor(x)) * 2 - 1; };
    F.q.style.letterSpacing = k ? 'calc(-0.035em + ' + (k * 0.09).toFixed(3) + 'em)' : '';
    F.q.querySelectorAll('.fl-ch').forEach((l) => {
      const i = +l.dataset.k;
      l.style.transform = k ? 'translateY(' + (rnd(i, 1) * 5 * k).toFixed(2) + 'px) rotate(' + (rnd(i, 2) * 14 * k).toFixed(2) + 'deg) scale(' + (1 + rnd(i, 3) * 0.12 * k).toFixed(3) + ')' : '';
    });
  }
  flCollageSet(v) {
    this.flCol = Math.round(Math.max(0, Math.min(1, v)) * 10) / 10;
    try { localStorage.setItem('pl8.flow.collage', String(this.flCol)); } catch (e) {}
    this.flCollage();
    this.flTip('Collage: ' + Math.round(this.flCol * 100) + '%' + (this.flCol ? '' : ' (clean)'));
  }
