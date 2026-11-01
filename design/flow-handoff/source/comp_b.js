
  // ---------------- camera helpers for the screens ----------------
  camTo(name, dur) {
    const S = this.SHOTS && this.SHOTS[name]; if (!S || !this.camera) return;
    let T = S.T, P = S.P;
    // pulls start on the floor: aim the set view lower
    if (name === 'setv' && this.plan && this.liftOnFloor(this.setIdx)) {
      const R = this.RACK || [0, 0], PZ = this.PLAT ? this.PLAT[1] : R[1], ex = R[0] + 1.1 * (this.barSX || 1);
      T = [ex - 0.35, 0.3, PZ]; P = [ex + 1.55, 1.7, PZ + 2.0];
    }
    this.flyTo(T, P, dur || 1.15); this.fovGoal = S.fov || 50;
  }
  // how much of the screen the open drawer or floating card covers, from the bottom (0..1)
  coverFrac() {
    const el = this.sheetEl && this.sheetEl.isConnected ? this.sheetEl : this.cardEl && this.cardEl.isConnected ? this.cardEl : null;
    if (!el || this.kbdTall) return this.kbdTall ? 0.5 : 0;
    const H = 844; return Math.min(0.9, Math.max(0, (H - el.offsetTop) / H));
  }
  bigQ(body, q) {
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', padding: '6px 4px 8px' }, body, q);
    this.h('div', { height: '10px' }, body);
  }
  secondary(parent, label, fn) {
    const b = this.h('button', { height: 'var(--b-h)', border: 'var(--bd)', borderRadius: 'var(--r-btn)', background: 'var(--c-soft)', color: '#000', fontSize: '17px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--b-tt)', cursor: 'pointer' }, parent, label);
    b.className = 'tap'; b.classList.replace('k-card', 'k-button'); b.onclick = fn; return b;
  }

  // ---------------- 3 · gym setup: one question at a time (name → units → plates → bar), each one building the gym ----------------
  showGym() {
    this.clearUI();
    const step = this.gymStep = Math.max(0, Math.min(3, this.gymStep || 0)), edit = this.gymMode === 'edit';
    const go = (s) => { this.gymStep = s; this.showGym(); };
    const back = step > 0 ? () => go(step - 1) : edit ? () => this.showHome() : null;
    const nextStep = () => { this.closeKeyboard(true); if (step < 3) go(step + 1); else this.finishSetup(); };
    const cont = (body, label, enabled) => {
      const b = this.bigButton(body, label || 'Continue', () => { if (b.dataset.on === '1') { this.buzz('light'); nextStep(); } });
      const set = (on) => { b.dataset.on = on ? '1' : '0'; b.style.opacity = on ? '1' : '0.35'; b.style.cursor = on ? 'pointer' : 'default'; };
      set(enabled !== false); b.style.marginTop = '16px'; return set;
    };
    const opts = { title: '', left: back ? 'Back' : '', onLeft: back };
    if (step === 0) {
      // name: the keyboard is already up; with the first letter the flag pops onto the back wall and unrolls with the name
      this.camTo('nameFlag');
      const { body } = this.sheet(Object.assign(opts, { height: 560 }));
      this.bigQ(body, 'Where are you training now?');
      const f = this.h('div', { display: 'flex', alignItems: 'center', height: 'var(--f-h)', padding: 'var(--f-pad)', borderRadius: 'var(--f-r)', background: 'var(--f-bg)', border: 'var(--f-bd)', borderBottom: 'var(--f-bdb)', boxShadow: 'var(--f-sh)', fontSize: 'var(--f-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)' }, body);
      const val = this.h('span', {}, f, this.d.name || '');
      this.h('span', { width: '2px', height: '26px', background: this.tint, animation: 'is-blink 1s infinite', marginLeft: '1px' }, f);
      const ph = this.h('span', { color: 'rgba(60,60,67,0.3)' }, f, this.d.name ? '' : 'e.g. 79');
      const setBtn = cont(body, 'Continue', !!this.d.name);
      this.openKeyboard('text', (k) => {
        if (k === 'done') { if (this.d.name) { this.buzz('light'); nextStep(); } return; }
        let v = this.d.name || '';
        v = k === 'del' ? v.slice(0, -1) : (v + k).slice(0, 8);
        this.d.name = v.toUpperCase(); val.textContent = this.d.name; ph.textContent = this.d.name ? '' : 'e.g. 79';
        setBtn(!!this.d.name); this.nameToFlag();
      }, true);
    } else if (step === 1) {
      // units: a checkmark list; the plate shelf swaps to the other plates
      this.camTo('corner'); this.setPiles(true);
      const { body } = this.sheet(opts);
      this.bigQ(body, 'Is the gym kilos or pounds?');
      const g = this.section(body), rows = [];
      [['kg', 'Kilograms'], ['lb', 'Pounds']].forEach(([v, l]) => {
        const rr = this.row(g, { label: l });
        const ck = this.h('span', { width: '20px', textAlign: 'right', color: this.tint, fontSize: '19px', fontWeight: 600 }, rr.r, this.d.unit === v ? '✓' : '');
        rows.push({ v, ck });
        rr.r.classList.add('tap'); rr.r.setAttribute('role', 'radio'); rr.r.setAttribute('aria-checked', this.d.unit === v ? 'true' : 'false');
        rr.r.onclick = () => { if (this.d.unit === v) return; this.setUnit(v); this.buzz('selection'); rows.forEach((q) => { q.ck.textContent = q.v === v ? '✓' : ''; q.ck.parentNode.setAttribute('aria-checked', q.v === v ? 'true' : 'false'); }); this.setPiles(true); this.setBarModel(); };
      });
      cont(body);
    } else if (step === 2) {
      // plates: chips; each one pops its pile on or off its peg
      this.camTo('corner'); this.setPiles(false);
      const { body } = this.sheet(opts);
      this.bigQ(body, 'Which plates does your gym have?');
      const wrap = this.chipWrap(body); wrap.setAttribute('aria-label', 'Plates');
      const own = this.own();
      this.specs().forEach((sp) => {
        this.chip(wrap, { label: this.fmt(sp.kg) + ' ' + this.d.unit, dot: sp.color, size: Math.round(10 + sp.d * 14), on: own.indexOf(sp.kg) >= 0, onToggle: (on) => {
          const a = this.own(), i = a.indexOf(sp.kg);
          if (on && i < 0) a.push(sp.kg); if (!on && i >= 0) a.splice(i, 1);
          this.buzz('light'); this.pilePop(sp.kg, on);
        } });
      });
      cont(body);
    } else {
      // the bar: the one on the rack changes to match (shorter sleeves, thinner grip for the lighter bars)
      this.camTo('bar'); this.setBarModel();
      const { body } = this.sheet(opts);
      this.bigQ(body, 'Which bar do you use?');
      const g = this.section(body), rows = [];
      this.BARS[this.d.unit].forEach(([w, l]) => {
        const rr = this.row(g, { label: '' }); rr.lab.remove();
        const tx = this.h('div', { flex: 1, minWidth: 0, padding: '12px 0' }, rr.r);
        this.h('div', { fontSize: '17px' }, tx, this.fmt(w) + ' ' + this.d.unit + ' · ' + l);
        const ck = this.h('span', { width: '20px', textAlign: 'right', color: this.tint, fontSize: '19px', fontWeight: 600 }, rr.r, this.barW() === w ? '✓' : '');
        rows.push({ w, ck });
        rr.r.classList.add('tap'); rr.r.setAttribute('role', 'radio');
        rr.r.onclick = () => { this.d.bar[this.d.unit] = w; this.buzz('selection'); rows.forEach((q) => { q.ck.textContent = q.w === w ? '✓' : ''; }); this.setBarModel(true); };
      });
      cont(body, 'Done');
    }
  }
  // the flag follows the name as it is typed
  nameToFlag() {
    const name = this.d.name || '';
    if (!name) { this.flagAnim = null; return; }
    this.FLAG_TEXT = name;
    const ff = this.FLAG_FONTS.find((q) => q.id === this.state.flagFont) || this.FLAG_FONTS[0];
    this.drawFlag(ff);
    if (!this.flagAnim) this.flagAnim = { t0: this.onb ? this.onb.t : 0 };
  }
  // the plate shelf: one pile per plate size; switched-on sizes pop onto their pegs
  setPiles(animate) {
    if (this.pileUnit !== this.d.unit) { this.buildPlatePiles(this.d.unit); this.pileAnim = {}; }
    const now = this.onb ? this.onb.t : 0, own = this.own();
    this.pileAnim = this.pileAnim || {};
    const seen = {};
    this.plateItems.forEach((pi) => {
      if (seen[pi.k]) return; seen[pi.k] = 1;
      const on = own.indexOf(pi.kg) >= 0, cur = this.pileAnim[pi.k];
      if (!cur || cur.on !== on) this.pileAnim[pi.k] = { on, t0: animate ? now + 0.25 + pi.k * 0.08 : now - 10 };
    });
  }
  pilePop(kg, on) {
    const now = this.onb ? this.onb.t : 0;
    this.plateItems.forEach((pi) => { if (pi.kg === kg) this.pileAnim[pi.k] = { on, t0: now }; });
  }
  // per frame while the gym is being set up: the flag and the piles follow the answers
  runSetup(dt, t) {
    const cl = (x) => Math.min(1, Math.max(0, x));
    const outBack = (x, k = 1.8) => { x = cl(x); const c = k + 1; return 1 + c * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); };
    const outCubic = (x) => 1 - Math.pow(1 - cl(x), 3);
    [this.ghostG, this.ghostFlagG].forEach((g) => { if (g) g.visible = false; });
    const F = this.flagAnim;
    if (F) {
      const rt = t - F.t0, rx = rt / 0.35, ux = (rt - 0.2) / 0.85;
      this.flagG.visible = true;
      this.flagG.scale.set(Math.max(0.0001, outBack(rx, 2.0)), 1, 1);
      const sy = Math.max(0.0001, outCubic(ux)), FH = this.flag.H;
      this.flagCloth.scale.y = sy; this.flagCloth.position.y = -FH / 2 * sy;
      const sf = rt - 0.2, e = sf < 0 ? 0 : sf < 0.85 ? 0.6 + 0.4 * Math.sin((sf / 0.85) * Math.PI / 2) : Math.exp(-(sf - 0.85) * 1.2);
      if (rt < 3.5) this.poseFlag(e, t);
    } else this.flagG.visible = false;
    // plates slide along their peg like they would by hand: on, innermost first; off, outermost first. No popping.
    const A = this.pileAnim || {};
    (this.plateItems || []).forEach((pi) => {
      const a = A[pi.k]; if (!a) { pi.o.visible = false; return; }
      this.posePlate(pi); pi.o.scale.setScalar(1);
      const off = 0.32 + (pi.n - pi.i) * (pi.t + 0.003);
      if (a.on) {
        const q = (t - a.t0 - pi.i * 0.07) / 0.34;
        if (q <= 0) { pi.o.visible = false; return; }
        const e = outCubic(q); pi.o.visible = true; pi.o.position.x = pi.bx + off * (1 - e);
      } else {
        const q = (t - a.t0 - (pi.n - 1 - pi.i) * 0.05) / 0.26;
        if (q >= 1 || a.t0 < t - 5) { pi.o.visible = false; return; }
        const c = cl(q); pi.o.visible = true; pi.o.position.x = pi.bx + off * c * c;
      }
    });
  }
  // the bar on the rack takes the chosen bar's length and grip
  setBarModel(kick) {
    if (!this.barG) return;
    const w = this.barW(), u = this.d.unit, list = this.BARS[u].map((b) => b[0]), i = Math.max(0, list.indexOf(w));
    const L = [1, 0.914, 0.8][i], th = [1, 0.88, 0.8][i];
    this.barSX = L; this.barG.scale.set(L, th, th);
    if (kick) this.shakeKick(0.05);
  }
  finishSetup() {
    const O = this.onb, own = this.own();
    this.clearUI();
    // the gym is set: piles and flag stay as they are, the rest of the onboarding takes over from here
    if (this.pileUnit !== this.d.unit) this.buildPlatePiles(this.d.unit);
    const order = []; this.plateItems.forEach((pi) => { if (pi.i === 0 && own.indexOf(pi.kg) >= 0) order.push(pi.k); });
    O.rank = {}; order.forEach((k, i) => { O.rank[k] = i; }); O.have = own.slice();
    O.flagAt = -100; O.rt0 = O.t - 200;
    if (!this.d.name) { this.d.name = '79'; this.nameToFlag(); }
    this.flagAnim = null;
    this.flagG.visible = true; this.flagG.scale.set(1, 1, 1); this.flagCloth.scale.y = 1; this.flagCloth.position.y = -this.flag.H / 2;
    if (this.gymMode === 'edit') { this.drawPR(this.prData()); this.showHome(); return; }
    // 4 · on to the PR board
    O.phase = 'toPR'; O.pt = 0; this.camTo('pr', 1.5);
  }

  // ---------------- 4 · PRs: upload, scan or type ----------------
  showPRs(mode) {
    this.clearUI(); this.prMode = mode || 'first';
    this.camTo('pr');
    const home = this.prMode === 'home';
    const toList = (src) => {
      if (src !== 'typed') this.d.prs.forEach((q) => { q[1] = this.demoPR(q); });
      this.drawPR(this.prData()); this.prList(src);
    };
    this.chooser({ left: home ? 'Back' : '', onLeft: home ? () => this.showHome() : null,
      q: 'Add your PRs',
      options: [
        { icon: 'photo', label: 'Upload a screenshot', tag: 'Fastest', fn: () => this.photoPicker('pr', () => { this.closeSheet(); this.reading('Reading your PRs…', () => toList('upload')); }, () => this.showPRs(this.prMode)) },
        { icon: 'camera', label: 'Scan with the camera', fn: () => { this.closeSheet(); this.scanner({ title: 'Scan your PRs', onCancel: () => this.showPRs(this.prMode), onCapture: () => toList('scan'), draw: (x) => {
          x.fillStyle = '#F4EFE2'; x.fillRect(0, 0, 780, 1000);
          x.strokeStyle = 'rgba(60,90,160,0.25)'; x.lineWidth = 2; for (let y = 120; y < 1000; y += 70) { x.beginPath(); x.moveTo(0, y); x.lineTo(780, y); x.stroke(); }
          x.fillStyle = '#222'; x.font = '58px "Permanent Marker", cursive'; x.fillText('PRs', 60, 100);
          x.font = '46px "Permanent Marker", cursive';
          this.d.prs.forEach((q, i) => x.fillText(q[0] + ' ' + this.fmt(this.demoPR(q)), 60, 245 + i * 140));
          return { count: this.d.prs.length, top: 19.5, gap: 14, h: 6, widths: this.d.prs.map((q) => Math.min(88, 18 + (q[0].length + 4) * 3.4)) };
        } }); } },
        { icon: 'keys', label: 'Type them in', fn: () => this.prList('typed') }
      ] });
  }
  prList(src) {
    this.clearUI(); this.camTo('pr');
    const home = this.prMode === 'home';
    const { body } = this.sheet({ title: '', left: 'Back', onLeft: () => (home ? this.showHome() : this.showPRs(this.prMode)), right: home ? 'Done' : 'Next', onRight: () => {
      this.closeKeyboard(true); this.closeSheet();
      if (home) { this.drawPR(this.prData()); this.showHome(); return; }
      this.finishPR(this.prData());
    } });
    const g = this.section(body), rows = [];
    this.d.prs.forEach((q, i) => {
      const rr = this.row(g, { label: q[0] });
      const v = this.h('span', { color: q[1] == null ? 'rgba(60,60,67,0.3)' : 'rgba(60,60,67,0.6)', fontVariantNumeric: 'tabular-nums' }, rr.r, q[1] == null ? 'Add' : this.fmt(q[1]) + ' ' + this.d.unit);
      this.h('span', { color: 'rgba(60,60,67,0.3)', fontSize: '15px' }, rr.r, '›');
      rows.push({ rr, v });
      rr.r.classList.add('tap');
      rr.r.onclick = () => {
        rows.forEach((x, j) => { x.rr.r.style.background = j === i ? 'var(--c-sel)' : 'transparent'; x.v.style.color = j === i ? this.tint : 'var(--c-ink2)'; });
        let buf = '';
        rr.r.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        this.openKeyboard('num', (k) => {
          if (k === 'done') { rows.forEach((x) => { x.rr.r.style.background = 'transparent'; x.v.style.color = 'var(--c-ink2)'; }); this.closeKeyboard(); this.buzz('light'); return; }
          if (k === 'del') buf = buf.slice(0, -1); else if (!(k === '.' && buf.indexOf('.') >= 0) && buf.length < 6) buf += k;
          const n = parseFloat(buf); q[1] = isFinite(n) ? n : null;
          v.textContent = (buf || '0') + ' ' + this.d.unit; v.style.color = this.tint; this.drawPR(this.prData());
        });
      };
    });
  }

  // ---------------- 5 · today's workout: scan, upload or type ----------------
  showWod(mode) {
    this.clearUI(); this.wodMode = mode || 'first';
    this.camTo('board');
    const home = this.wodMode === 'home';
    this.chooser({ left: home ? 'Back' : '', onLeft: home ? () => { this.onb.phase = 'home'; this.showHome(); } : null,
      q: "Add today's workout",
      options: [
        { icon: 'camera', label: 'Scan the whiteboard', fn: () => { this.closeSheet(); this.scanner({ title: 'Scan the workout', onCancel: () => this.showWod(this.wodMode), onCapture: () => this.wodReady('scan'), draw: (x) => {
          const gr = x.createLinearGradient(0, 0, 780, 1000); gr.addColorStop(0, '#E9E6DF'); gr.addColorStop(1, '#CFCAC0'); x.fillStyle = gr; x.fillRect(0, 0, 780, 1000);
          x.fillStyle = '#B9B3A8'; x.fillRect(0, 0, 780, 30); x.fillRect(0, 970, 780, 30);
          x.fillStyle = '#1F3A73'; x.font = '64px "Permanent Marker", cursive'; x.fillText('WOD 10/08', 60, 150);
          x.font = '52px "Permanent Marker", cursive';
          const lines = this.d.wod.map((e) => e.lift + '  ' + e.sets + 'x' + e.reps + ' @' + e.pct + '%');
          lines.forEach((t, i) => x.fillText(t, 60, 290 + i * 110));
          x.fillStyle = '#9C2C2C'; x.font = '44px "Permanent Marker", cursive'; x.fillText('rest 1:30 btw sets', 60, 290 + lines.length * 110 + 40);
          return { count: lines.length, top: 23, gap: 11, h: 6, widths: lines.map((t) => Math.min(88, 14 + t.length * 3.3)) };
        } }); } },
        { icon: 'photo', label: 'Upload a screenshot', fn: () => this.photoPicker('wod', () => { this.closeSheet(); this.reading('Reading the workout…', () => this.wodReady('upload')); }, () => this.showWod(this.wodMode)) },
        { icon: 'keys', label: 'Type it in', fn: () => { this.closeSheet(); this.review('typed'); } }
      ] });
  }
  // what was read is written on the whiteboard; one tap to start, or edit / cancel
  wodReady(src) {
    this.clearUI(); this.camTo('board');
    this.plan = this.workoutPlan(); this.drawWB(this.plan); this.buzz('success');
    const { body } = this.sheet({ title: '' });
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', padding: '2px 4px 16px' }, body, 'Ready to lift?');
    this.bigButton(body, 'Start training', () => { this.closeSheet(); const p = this.workoutPlan(); if (p) this.beginWorkout(p); });
    const row = this.h('div', { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '10px' }, body);
    this.secondary(row, 'Edit', () => this.review(src));
    this.secondary(row, 'Cancel', () => { this.plan = null; this.drawWB(null); this.showWod(this.wodMode); });
  }
  review(src) {
    this.clearUI(); this.camTo('board');
    const { body } = this.sheet({ detent: 'large', title: '', left: 'Cancel', onLeft: () => (src === 'typed' ? this.showWod(this.wodMode) : this.wodReady(src)), right: 'Done', onRight: () => {
      if (!this.d.wod.length) return;
      this.closeSheet(); this.wodReady(src);
    } });
    const host = this.h('div', {}, body);
    const draw = () => {
      host.innerHTML = '';
      this.d.wod.forEach((e, i) => {
        const g = this.section(host);
        if (i > 0) g.style.marginTop = '20px';
        const r1 = this.row(g, { label: 'Lift' });
        const sel = this.h('select', { border: 0, background: 'none', fontSize: '17px', color: 'rgba(60,60,67,0.6)', textAlign: 'right', fontFamily: 'inherit', cursor: 'pointer', appearance: 'none' }, r1.r);
        this.d.prs.forEach((q) => { const op = this.h('option', null, sel, q[0]); if (q[0] === e.lift) op.selected = true; });
        sel.onchange = () => { e.lift = sel.value; };
        this.h('span', { color: 'rgba(60,60,67,0.3)', fontSize: '13px' }, r1.r, '⌃⌄');
        const num = (label, key, unit, step, lo, hi) => {
          const rr = this.row(g, { label });
          const v = this.h('span', { fontVariantNumeric: 'tabular-nums', color: 'rgba(60,60,67,0.6)', minWidth: '44px', textAlign: 'right' }, rr.r, e[key] + unit);
          rr.r.appendChild(this.stepper(() => { e[key] = Math.max(lo, e[key] - step); v.textContent = e[key] + unit; this.buzz('selection'); }, () => { e[key] = Math.min(hi, e[key] + step); v.textContent = e[key] + unit; this.buzz('selection'); }));
        };
        num('Sets', 'sets', '', 1, 1, 12); num('Reps', 'reps', '', 1, 1, 30); num('Of your PR', 'pct', '%', 2.5, 30, 110);
        this.row(g, { label: 'Remove', labelColor: '#FF3B30', onClick: () => { this.d.wod.splice(i, 1); draw(); } });
      });
      const ga = this.section(host);
      ga.style.marginTop = '20px';
      this.row(ga, { label: '+  Add exercise', labelColor: this.tint, onClick: () => { this.d.wod.push({ lift: this.d.prs[0][0], sets: 3, reps: 5, pct: 70 }); draw(); } });
    };
    draw();
  }

  // ---------------- 6 · plate kit: the session's plates drop onto the floor; chips to keep track ----------------
  showKit() {
    this.clearUI();
    const P = this.plan; if (!P) return;
    const mid = !!this.inSession, U = this.d.unit.toUpperCase(), got = this.d.kitGot || (this.d.kitGot = {});
    const bar = this.h('div', { position: 'absolute', left: '10px', right: '12px', bottom: '24px', padding: '12px', borderRadius: 'var(--r-float)', background: 'rgba(249,249,249,0.78)', backdropFilter: 'blur(20px) saturate(1.8)', WebkitBackdropFilter: 'blur(20px) saturate(1.8)', border: 'var(--bd)', boxShadow: 'var(--sh-float)', zIndex: 20 }, this.ui);
    this.cardEl = bar;
    if (!P.kit.length) this.h('div', { textAlign: 'center', fontSize: '15px', fontWeight: '600', color: '#3c3c43', padding: '4px 8px 12px' }, bar, 'Just the bar');
    else {
      const wrap = this.chipWrap(bar); wrap.style.margin = '0 0 12px'; wrap.setAttribute('aria-label', 'Plates to grab');
      P.kit.forEach((k) => {
        const sp = this.specs().find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
        this.chip(wrap, { label: k.qty + ' × ' + this.fmt(k.w) + ' ' + U, dot: sp.color, size: Math.round(10 + sp.d * 14), on: !!got[k.w], check: true, onToggle: (v) => { if (v) got[k.w] = true; else delete got[k.w]; if (v) this.buzz('light'); } });
      });
    }
    this.bigButton(bar, mid ? 'Back to the set' : 'Start session', () => { this.inSession = true; this.goTab('sets'); }, { height: '56px', fontSize: '19px' });
  }

  // ---------------- 7 · set by set: the set, its load, one Done ----------------
  showSetCard() {
    this.clearUI();
    const P = this.plan; if (!P) return;
    const i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    const bar = this.h('div', { position: 'absolute', left: '10px', right: '12px', bottom: '24px', padding: '14px 16px 16px', borderRadius: 'var(--r-float)', background: 'rgba(249,249,249,0.78)', backdropFilter: 'blur(20px) saturate(1.8)', WebkitBackdropFilter: 'blur(20px) saturate(1.8)', border: 'var(--bd)', boxShadow: 'var(--sh-float)', display: 'flex', flexDirection: 'column', gap: '12px', zIndex: 20 }, this.ui);
    this.cardEl = bar;
    const info = this.h('div', { display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: '10px' }, bar);
    const il = this.h('div', { minWidth: 0 }, info);
    this.h('div', { fontSize: '13px', fontWeight: 700, color: 'rgba(60,60,67,0.6)', textTransform: 'uppercase', letterSpacing: '0.08em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }, il, x.group);
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', whiteSpace: 'nowrap' }, il, x.label + ' of ' + x.of);
    this.h('div', { flex: 'none', textAlign: 'right', fontSize: '17px', fontWeight: 600, fontVariantNumeric: 'tabular-nums' }, info, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + this.d.unit);
    const dots = this.h('div', { display: 'flex', gap: '6px' }, bar);
    const base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.h('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? '#1C1C1E' : 'rgba(0,0,0,0.12)' }, dots); });
    this.bigButton(bar, 'Done', () => this.checkSet(), { height: '56px', fontSize: '19px' });
    // a quiet way back to the plate kit, keeping the place in the session
    const pl = this.h('button', { position: 'absolute', right: '16px', top: '104px', zIndex: 20, display: 'flex', alignItems: 'center', gap: '6px', height: '36px', padding: '0 14px', border: 'var(--bd)', borderRadius: 'var(--r-btn)', background: 'rgba(249,249,249,0.78)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', boxShadow: 'var(--sh)', fontSize: '15px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', color: 'var(--c-ink)', cursor: 'pointer' }, this.ui);
    pl.classList.replace('k-card', 'k-button'); pl.classList.add('tap');
    pl.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></svg>Plates';
    pl.setAttribute('aria-label', 'See the plate kit'); pl.onclick = () => this.goTab('kit');
  }
  checkSet() {
    const P = this.plan; if (!P || this.finishing) return;
    const n = P.flat.length, i = this.setIdx;
    this.doneSets[i] = true; this.buzz('success');
    if (this.doneSets.filter(Boolean).length >= n) { this.finishWorkout(); return; }
    let j = i + 1; while (j < n && this.doneSets[j]) j++;
    if (j >= n) { j = 0; while (j < n && this.doneSets[j]) j++; }
    this.setIdx = j; this.showSetCard();
    setTimeout(() => { if (!this.dead && this.plan) this.showSet(j, null, { next: true }); }, 350);
  }

  // ---------------- 8 · session over: the UI Animation Lab's scale, with this session's plates and volume ----------------
  showSessionOver() {
    // the scale weighs the heaviest set of the session: its bar and plates, both sides
    const P = this.plan, u = this.d.unit, sp = this.specs(), plates = [];
    const top = P && P.flat.length ? P.flat.reduce((a, x) => (x.total > a.total ? x : a), P.flat[0]) : null;
    (top ? top.side : []).forEach((w) => { const s = sp.find((q) => q.kg === w); if (s) plates.push(s, s); });
    plates.sort((a, b) => b.kg - a.kg);
    this.doneL = this.animLayer('done', { plates: plates.slice(0, 16), total: top ? Math.round(top.total * 10) / 10 : 0, unit: u, bar: P ? P.bar : 20, label: 'Heaviest set',
      onTap: () => { if (this.doneL && (this.doneL.ready() || Date.now() - this.doneT > 6000)) this.closeSessionOver(); } });
    this.doneT = Date.now();
    this.doneL.el.setAttribute('role', 'button'); this.doneL.el.setAttribute('aria-label', 'Session over. Tap to go back to your gym');
  }
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light');
    this.dropLayer(L);
    // 9 · back home: the kit is put away, the gym in overview, a tab bar below
    const O = this.onb;
    if (this.kitItems) this.kitOutT = O.t;
    (this.onBar || []).forEach((m) => { if (!m.out) { m.out = true; m.outT = O.t + 0.6 + (m.k || 0) * 0.08; } });
    this.barSide = [];
    this.plan = null; this.inSession = false; this.d.kitGot = {}; this.finishing = false;
    this.drawWB(null);
    O.phase = 'home';
    this.camTo('overview', 1.8);
    this.showHome();
  }
  showHome() {
    this.clearUI();
    const O = this.onb; if (O && O.phase !== 'home') O.phase = 'home';
    this.controls.enabled = true;
    if (this.camera && this.SHOTS) this.camTo('overview', 1.6);
    const nav = this.h('nav', { position: 'absolute', left: 0, right: 0, bottom: 0, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', padding: '8px 12px 30px', background: 'var(--c-sheet)', border: 'var(--d-bd)', borderBottom: '0', boxShadow: 'var(--sh-sheet)', zIndex: 20 }, this.ui);
    nav.setAttribute('aria-label', 'Main');
    this.cardEl = nav;
    const items = [
      ['train', 'Train', '<path d="M2 12h20M5 8v8M8 6v12M16 6v12M19 8v8"/>'],
      ['prs', 'PRs', '<path d="M8 4h8v5a4 4 0 0 1-8 0V4zM8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M8 20h8"/>'],
      ['gym', 'Gym', '<path d="M3 21V9l9-5 9 5v12M9 21v-6h6v6"/>']
    ];
    items.forEach(([id, label, icon]) => {
      const b = this.h('button', { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', height: '54px', border: 0, background: 'none', color: '#000', fontSize: '13px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--b-tt)', cursor: 'pointer', padding: '6px 0 0' }, nav);
      b.className = 'tap'; b.setAttribute('aria-label', label);
      b.innerHTML = '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + icon + '</svg><span>' + label + '</span>';
      b.onclick = () => this.pickTab(id);
    });
  }
  pickTab(id) {
    this.buzz('selection'); this.controls.enabled = false;
    if (id === 'train') { this.trainAgain(); return; }
    if (id === 'prs') { this.prMode = 'home'; this.prList('home'); return; }
    if (id === 'gym') { this.flagAnim = this.d.name ? { t0: this.onb.t - 10 } : null; this.showGymHome(); }
  }
