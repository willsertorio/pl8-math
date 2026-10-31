  // ---------------- the prototype's opening: pl8() → pl8(math) → plates → the a turns into maths ----------------
  // every step is a cut: letters and symbols just appear, nothing fades
  buildIntro() {
    if (!this.textLayer) return;
    const o = this.o, L = this.textLayer; L.innerHTML = '';
    this.timers.forEach(clearTimeout); this.timers = [];
    const F = this.FONTS.find((f) => f[0] === o.font) || this.FONTS[0], ff = "'" + F[0] + "', " + F[2], col = this.colour(o.textColor), wt = o.weight || F[1];
    const up = (s) => (o.upper ? s.toUpperCase() : s);
    const box = this.el('div', { position: 'absolute', left: (o.textX * 100) + '%', top: (o.textY * 100) + '%',
      transform: 'translate(-50%,-50%) rotate(' + o.rotate + 'deg) skewX(' + (-o.skew) + 'deg) scale(' + o.scaleX + ',' + o.scaleY + ')',
      zIndex: o.behind ? 0 : 3, opacity: o.textOpacity, mixBlendMode: o.textBlend, pointerEvents: 'none' }, L);
    const shadow = o.shadowCol === 'none' ? 'none' : o.shadowX + 'px ' + o.shadowY + 'px ' + o.shadowBlur + 'px ' + this.colour(o.shadowCol);
    const row = this.el('div', { display: 'flex', alignItems: 'baseline', whiteSpace: 'nowrap', fontFamily: ff, fontWeight: wt, fontStyle: o.italic ? 'italic' : 'normal',
      fontSize: o.size + 'px', lineHeight: o.lineH, letterSpacing: o.spacing + 'em', color: col, textShadow: shadow }, box);
    row.setAttribute('aria-label', up('pl8(math)'));
    const sp = (t, css) => this.el('span', Object.assign({ display: 'inline-block', whiteSpace: 'pre' }, css || {}), row, t);
    const head = sp(up('pl8')), lp = sp('('), slots = up('math').split('').map((ch) => sp(ch, { display: 'none', textAlign: 'center' })), rp = sp(')');
    const I = this.intro = { box, row, head, lp, rp, slots, cyc: null };
    // pl8(), then m · a · t · h, then the plates, then the a starts changing
    this.holdPl = true;
    let at = 650;
    slots.forEach((s) => { this.timers.push(setTimeout(() => { if (!this.dead) s.style.display = 'inline-block'; }, at)); at += 190; });
    at += 380;
    this.timers.push(setTimeout(() => { if (this.dead) return; this.holdPl = false; }, at));
    at += 1100;
    this.timers.push(setTimeout(() => {
      if (this.dead || I.closing) return;
      const a = slots[1]; a.style.width = a.getBoundingClientRect().width / this.scaleOf() + 'px';   // the slot keeps the a's width
      const SYM = ['π', 'α', 'Σ', '∞', 'θ', 'λ', 'Δ', '√', 'β', 'φ', '∫', 'μ', 'Ω', '≈', 'ε', '±'];
      let k = 0;
      const tick = () => { if (this.dead || I.closing) return; a.textContent = SYM[k % SYM.length]; k++; I.cyc = setTimeout(tick, 280); this.timers.push(I.cyc); };
      tick();
    }, at));
  }
  scaleOf() { const r = this.stage.getBoundingClientRect(); return r.width ? r.width / (this.W || 390) : 1; }
  // the tap: the plates sweep off to the side, the words go, and the brackets snap shut where the cube will be
  closeIntro(target, done) {
    const I = this.intro; if (!I || I.closing) { if (done && !I) done(); return; }
    I.closing = true; this.holdPl = false;
    this.clearT0 = performance.now(); this.plates.forEach((p) => { p.cd = Math.random() * 70; });
    I.head.style.visibility = 'hidden'; I.slots.forEach((s) => { s.style.visibility = 'hidden'; });
    const sc = this.scaleOf(), S = this.stage.getBoundingClientRect();
    const rel = (e) => { const r = e.getBoundingClientRect(); return { x: (r.left - S.left) / sc, y: (r.top - S.top) / sc, w: r.width / sc, h: r.height / sc }; };
    const a = rel(I.lp), b = rel(I.rp);
    const tx = target ? target.x : this.W / 2, ty = target ? target.y : this.Hh / 2;
    const gh = this.o.size * 0.95, k = target && target.h ? Math.max(1, Math.min(4, target.h * 0.92 / gh)) : 1.6;
    // each bracket: its inner edge ends on the cube's centre line, grown to the cube's height
    const mv = (el, r, side) => {
      const ex = side < 0 ? tx - r.w * k * 0.2 : tx + r.w * k * 0.2;   // glyph boxes carry side bearings: overlap them so the ink meets
      const dx = ex - (r.x + r.w / 2), dy = ty - (r.y + r.h / 2);
      el.style.transformOrigin = '50% 50%';
      this.go(el, [{ transform: 'none' }, { transform: 'translate(' + dx.toFixed(1) + 'px,' + dy.toFixed(1) + 'px) scale(' + k.toFixed(3) + ')' }], { d: 560, delay: 90, easing: 'cubic-bezier(.6,0,.9,.4)' });
    };
    mv(I.lp, a, -1); mv(I.rp, b, 1);
    this.timers.push(setTimeout(() => { if (!this.dead && done) done(); }, 660));
  }
  // plates sweeping off: ease-out, each to just past the left edge
  clearShift(p, hw, z) {
    if (!this.clearT0) return 0;
    const u = Math.min(1, Math.max(0, (performance.now() - this.clearT0 - (p.cd || 0)) / 520)), e = 1 - Math.pow(1 - u, 3);
    const R = p.r0 * this.o.size2 / (hw * z);
    return -e * (p.u + 1.25 + 2.4 * R);
  }
