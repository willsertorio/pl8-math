
  // ===================== FLOW, round 8 =====================
  // ---------- going back to the menu follows the finger: the screen pans with you, let go past a point and it carries on ----------
  flPanBackBind() {
    const F = this.FL; if (F.pbBound) return; F.pbBound = true;
    const L = F.L; let S = null;
    L.addEventListener('pointerdown', (e) => {
      if (!F.panBack || F.drag || this.flPanning || (e.target.closest && e.target.closest('button'))) { S = null; return; }
      S = { y0: e.clientY, x0: e.clientX, px: 0, G: this.flPanGeo(), P0: F.cam.position.clone(), g0: this.flGridY || 0, on: false };
    });
    L.addEventListener('pointermove', (e) => {
      if (!S || !F.panBack) return;
      const dy = e.clientY - S.y0, dx = e.clientX - S.x0;
      if (!S.on) { if (-dy > 14 && -dy > Math.abs(dx) * 1.3) S.on = true; else return; }
      this.flPanLive(S, Math.max(0, -dy - 14));
    });
    const up = () => {
      if (!S) return; const s = S; S = null; if (!s.on) return;
      if (s.px > 110) this.flPanFinish(s, 'menu');
      else { const p0 = s.px; this.flAnim((u) => this.flPanLive(s, p0 * Math.pow(1 - u, 3)), 0.28); }
    };
    L.addEventListener('pointerup', up); L.addEventListener('pointercancel', up);
  }
  flPanLive(s, px) {
    const F = this.FL; s.px = px;
    F.cam.position.copy(s.P0).addScaledVector(s.G.up, -px * s.G.wpp); this.flPanSet(px); this.flGridY = s.g0 - px; this.flApplyStyle();
  }
  // carry an interactive pan the rest of the way, then the next screen comes up from below
  flPanFinish(s, step) {
    const F = this.FL, p0 = s.px, H = s.G.H; this.flPanning = true;
    F.hit = null; F.onTap = null; F.onSwipe = null; F.panBack = false;
    const d = Math.max(0.12, 0.3 * (1 - p0 / H));
    this.flAnim((u) => this.flPanLive(s, p0 + (H - p0) * u * (2 - u) * 0.5 + (H - p0) * u * u * 0.5), d, () => {
      this.flPanning = false; this.flCheckSound(); this.flMode = 'menu'; this.flPanIn = { g0: s.g0 - H }; this.flGo(step);
    });
  }
  flPanBackGo() { const s = { px: 0, G: this.flPanGeo(), P0: this.FL.cam.position.clone(), g0: this.flGridY || 0 }; this.flPanFinish(s, 'menu'); }

  // ---------------- 4 · plates: draw anywhere — one long line can tick a whole column ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs(), n = specs.length;
    this.flCam([0, 0, 8.2], [0, 0, 0], 35);
    const k = 2 * 8.2 * Math.tan(17.5 * Math.PI / 180) / 844, top = 214, bot = 790, rowH = (bot - top) / n;
    const wx = (px) => (px - 195) * k, wy = (py) => (422 - py) * k;
    const ink = this.flInk(), box = Math.round(Math.min(46, rowH * 0.74)), XY = 262, XN = 334, dpr = 2;
    const gray = new T.MeshBasicMaterial({ color: 0x9a9690, transparent: true, opacity: 0.3, depthWrite: false });
    const rows = [], boxes = []; this.flPlRows = rows;
    let done = false, ready = false;
    const paintPlate = (r) => r.meshes.forEach((m) => { m.material = r.state === 'no' ? gray : m.userData.m0; });
    const editing = !!this.flEditOne; let idleT = null;
    const finish = () => {
      if (done || rows.some((r) => !r.state)) return;
      if (editing) {
        // editing from the gym: changes save as you go; once you stop for a moment it goes back
        this.d.own[this.d.unit] = rows.filter((r) => r.state === 'yes').map((r) => r.s.kg);
        clearTimeout(idleT); idleT = this.flLater(() => { if (this.flStep !== 'plates' || done) return; done = true; this.flShine(rows.filter((r) => r.state === 'yes').map((r) => r.w), 0.8); this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 900); }, 1800);
        return;
      }
      done = true;
      this.d.own[this.d.unit] = rows.filter((r) => r.state === 'yes').map((r) => r.s.kg);
      const yes = rows.filter((r) => r.state === 'yes');
      this.flLater(() => { this.flShine(yes.map((r) => r.w), 0.8); yes.forEach((r, i) => this.flLater(() => this.flSparkles(r.w.position.clone().setZ(0.4), 2, 0.35), i * 50)); }, 350);
      this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 1250);
    };
    // each box: a sketchy square on its own little canvas, with a tick that draws itself in
    const makeBox = (r, which, x, y) => {
      const s = box, p = 12, cv = document.createElement('canvas');
      cv.width = (s + 2 * p) * dpr; cv.height = (s + 2 * p) * dpr;
      Object.assign(cv.style, { position: 'absolute', left: (x - s / 2 - p) + 'px', top: (y - s / 2 - p) + 'px', width: (s + 2 * p) + 'px', height: (s + 2 * p) + 'px', pointerEvents: 'none' });
      cv.setAttribute('role', 'checkbox'); cv.setAttribute('aria-label', (which === 'yes' ? 'Have ' : 'Don’t have ') + this.fmt(r.s.kg) + ' ' + this.d.unit); cv.setAttribute('aria-checked', 'false');
      F.ui.appendChild(cv);
      const J = Array.from({ length: 24 }, () => (Math.random() - 0.5) * 2.2), ctx = cv.getContext('2d');
      const B = { cv, which, r, x0: x - s / 2, y0: y - s / 2, s, tick: 0, acc: 0 };
      const tickPts = (() => { const c0 = p + s / 2, a = [[c0 - s * 0.3, c0 + s * 0.02], [c0 - s * 0.08, c0 + s * 0.26], [c0 + s * 0.34, c0 - s * 0.3]], q = []; for (let i = 0; i < 2; i++) for (let k2 = 0; k2 <= 8; k2++) q.push([a[i][0] + (a[i + 1][0] - a[i][0]) * k2 / 8 + (Math.random() - 0.5) * 1.4, a[i][1] + (a[i + 1][1] - a[i][1]) * k2 / 8 + (Math.random() - 0.5) * 1.4]); return q; })();
      B.draw = () => {
        let ji = 0; const j = () => J[ji++ % 24];
        ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.strokeStyle = ink; ctx.lineWidth = 2.6; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        const pts = [[p, p], [p + s, p], [p + s, p + s], [p, p + s]];
        ctx.beginPath(); pts.forEach((a, i) => { const b = pts[(i + 1) % 4]; ctx.moveTo(a[0] + j(), a[1] + j()); ctx.quadraticCurveTo((a[0] + b[0]) / 2 + j(), (a[1] + b[1]) / 2 + j(), b[0] + j(), b[1] + j()); }); ctx.stroke();
        const m = Math.ceil(B.tick * tickPts.length);
        if (m > 1) { ctx.lineWidth = 4.4; ctx.beginPath(); tickPts.slice(0, m).forEach(([a, b], i) => (i ? ctx.lineTo(a, b) : ctx.moveTo(a, b))); ctx.stroke(); }
      };
      B.set = (on) => {
        cv.setAttribute('aria-checked', String(on));
        if (!on) { if (B.tick) { B.tick = 0; B.draw(); } return; }
        if (B.tick >= 1) return;
        this.flAnim((u) => { B.tick = u; B.draw(); }, 0.16);
      };
      B.draw();
      cv.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: 360, delay: r.i * 60 + (which === 'yes' ? 0 : 40), easing: 'cubic-bezier(.3,1.5,.5,1)', fill: 'backwards' });
      boxes.push(B); return B;
    };
    const decide = (B) => {
      const r = B.r; if (r.state === B.which) return;
      r.state = B.which; B.set(true); (B.which === 'yes' ? r.no : r.yes).set(false); paintPlate(r);
      this.buzz('light'); this.flClick(B.which === 'yes' ? 1.2 : 0.7);
      if (B.which === 'yes') this.flShine([r.w], 0.4);
    };
    // one drawing surface over the whole screen: the pen leaves a trail that fades; every box the line runs through gets ticked
    const pad = document.createElement('canvas'), pctx = pad.getContext('2d');
    pad.width = 390 * dpr; pad.height = 844 * dpr;
    Object.assign(pad.style, { position: 'absolute', left: 0, top: 0, width: '390px', height: '844px', pointerEvents: 'none', touchAction: 'none', zIndex: 2 });
    pad.setAttribute('aria-hidden', 'true');
    F.ui.appendChild(pad);
    const loc = (e) => { const R = pad.getBoundingClientRect(), sc = R.width / 390; return [(e.clientX - R.left) / sc, (e.clientY - R.top) / sc]; };
    const inBox = (B, x, y, pad2) => x >= B.x0 - pad2 && x <= B.x0 + B.s + pad2 && y >= B.y0 - pad2 && y <= B.y0 + B.s + pad2;
    let st = null;
    const fadeTrail = () => { const a = pad.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 380, easing: 'ease-out' }); a.onfinish = () => { pctx.setTransform(1, 0, 0, 1, 0, 0); pctx.clearRect(0, 0, pad.width, pad.height); }; };
    pad.addEventListener('pointerdown', (e) => {
      if (done || !ready) return; e.stopPropagation(); e.preventDefault(); clearTimeout(idleT);
      try { pad.setPointerCapture(e.pointerId); } catch (er) {}
      pad.getAnimations().forEach((a) => a.cancel()); pctx.setTransform(1, 0, 0, 1, 0, 0); pctx.clearRect(0, 0, pad.width, pad.height);
      const q = loc(e); st = { last: q, start: q, len: 0, hit: false, n: 0 }; boxes.forEach((B) => { B.acc = 0; });
      this.flAudio();
    });
    pad.addEventListener('pointermove', (e) => {
      if (!st) return; e.stopPropagation();
      const q = loc(e), l = st.last, seg = Math.hypot(q[0] - l[0], q[1] - l[1]); if (seg < 1) return;
      st.len += seg; st.last = q;
      pctx.setTransform(dpr, 0, 0, dpr, 0, 0); pctx.strokeStyle = ink; pctx.lineWidth = 4.2; pctx.lineCap = 'round'; pctx.beginPath(); pctx.moveTo(l[0], l[1]); pctx.lineTo(q[0], q[1]); pctx.stroke();
      // how much of this bit of line runs inside each box
      const steps = Math.max(1, Math.ceil(seg / 3));
      for (let i = 1; i <= steps; i++) {
        const x = l[0] + (q[0] - l[0]) * i / steps, y = l[1] + (q[1] - l[1]) * i / steps;
        boxes.forEach((B) => { if (inBox(B, x, y, 4)) { B.acc += seg / steps; if (B.acc >= B.s * 0.22) { st.hit = true; decide(B); } } });
      }
      if (++st.n % 6 === 0) this.flClick(2.2);
    });
    const up = (e) => {
      if (!st) return; const s0 = st; st = null; if (e && e.stopPropagation) e.stopPropagation();
      if (s0.len < 6) {
        // a tap on a box ticks it
        const B = boxes.find((b) => inBox(b, s0.start[0], s0.start[1], 8)); if (B) decide(B);
      } else if (!s0.hit && F.panBack && s0.start[1] - s0.last[1] > 90 && Math.abs(s0.last[0] - s0.start[0]) < (s0.start[1] - s0.last[1]) / 1.5) {
        fadeTrail(); this.flPanBackGo(); return;
      }
      fadeTrail(); finish();
    };
    pad.addEventListener('pointerup', up); pad.addEventListener('pointercancel', up);
    const winUp = (e) => { if (!pad.isConnected) { window.removeEventListener('pointerup', winUp); window.removeEventListener('pointercancel', winUp); return; } up(e); };
    window.addEventListener('pointerup', winUp); window.addEventListener('pointercancel', winUp);
    this.flAfter('What are the plates available?', () => {
      [['YES', XY], ['NO', XN]].forEach(([l, x]) => { const h = this.fh('div', { position: 'absolute', left: x + 'px', top: (top - 16) + 'px', transform: 'translate(-50%,-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 800, fontSize: '13px', letterSpacing: '0.08em', pointerEvents: 'none' }, F.ui, l); h.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, fill: 'backwards' }); });
      specs.forEach((s, i) => {
        const y = top + rowH * (i + 0.5), g = this.plate(s), w = new T.Group(); w.add(g); g.rotation.x = Math.PI / 2;
        const dia = rowH * 0.84 * k * (0.62 + 0.38 * Math.min(1, s.d / 0.45)), sc = dia / s.d; w.scale.setScalar(sc);
        const ty = wy(y); w.position.set(wx(58), ty + 4, 0); this.flAdd(w);
        const meshes = []; g.traverse((m) => { if (m.isMesh) { m.userData.m0 = m.material; meshes.push(m); } });
        const r = { s, i, w, g, meshes, state: null };
        w.visible = false;
        this.flLater(() => { w.visible = true; this.flAnim((u) => { const b = u < 0.6 ? (u / 0.6) ** 2 : 1 - 0.18 * Math.sin((u - 0.6) / 0.4 * Math.PI) * (1 - u); w.position.y = ty + (1 - Math.min(1, b)) * 4; }, 0.55, () => this.flClick(0.5)); }, i * 70);
        const lab = this.fh('div', { position: 'absolute', left: '106px', top: y + 'px', transform: 'translateY(-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: Math.round(Math.min(20, rowH * 0.36)) + 'px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, this.fmt(s.kg) + ' ' + this.d.unit);
        lab.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, delay: i * 70 + 300, fill: 'backwards' });
        r.yes = makeBox(r, 'yes', XY, y); r.no = makeBox(r, 'no', XN, y);
        rows.push(r);
      });
      pad.style.pointerEvents = 'auto'; ready = true; F.ui.appendChild(pad);
      // editing: what you said before is already ticked
      if (editing) { const own = (this.d.own && this.d.own[this.d.unit]) || []; rows.forEach((r, i) => { r.state = own.indexOf(r.s.kg) >= 0 ? 'yes' : 'no'; paintPlate(r); this.flLater(() => (r.state === 'yes' ? r.yes : r.no).set(true), 380 + i * 60); }); }
    });
    F.tick = (dt, t) => { rows.forEach((r, i) => { r.g.rotation.y = Math.sin(t * 0.8 + i) * 0.12; }); this.flSpkTick(dt); };
  }

  // ---------------- 6 · the board: rolls in and stops, no wobble; upload, see the plan, tap it to start ----------------
  flWod() {
    const F = this.FL, T = this.THREE, R = this.WB_REST;
    this.flCam(R.cam.P, R.cam.T, 35);
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.18 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); this.flAdd(wb);
    const instant = this.flFromKit || this.flFromMenu;
    let busy = false, hasPlan = false;
    if (instant) { wb.rotation.y = R.ry; if (this.plan) { this.flDrawBoard(wb, this.plan); hasPlan = true; } } else wb.visible = false;
    this.flAfter(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?', () => {
      if (instant) return;
      // pushed in: it rolls on from the right, turning as it comes, and slows to a stop — no bounce
      wb.visible = true; wb.position.x = 3.6; wb.rotation.y = -1.9; this.flClick(0.5);
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 4), er = 1 - Math.pow(1 - Math.min(1, u * 1.08), 3); wb.position.x = 3.6 * (1 - e); wb.rotation.y = -1.9 + (R.ry + 1.9) * er; wb.userData.wheels.forEach((w) => { w.rotation.x = -(1 - e) * 40; }); }, 1.3);
    });
    const start = () => {
      busy = true; this.flCheckSound(); this.buzz('light');
      const cam = F.cam, P0 = cam.position.clone(), T0 = new T.Vector3(...R.cam.T), cy = 1.45 * R.s, T1 = new T.Vector3(0, cy, 0), P1 = new T.Vector3(0.15, cy, 0.7), tgt = new T.Vector3();
      this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; cam.position.lerpVectors(P0, P1, e); tgt.lerpVectors(T0, T1, e); cam.lookAt(tgt); }, 1.0, () => { this.flGo('kit'); });
    };
    const ready = () => {
      this.plan = this.workoutPlan(); this.lastPlan = this.plan; this.setIdx = 0; this.doneSets = []; this.d.kitGot = {};
      this.flDrawBoard(wb, this.plan); this.flShine([wb], 0.6); this.flSparkles(new T.Vector3(0.4, 1.6, 0.4), 5, 1.2);
      busy = false; hasPlan = true;
    };
    // the uploaded workout can be scrubbed off the board, just like in the app; a clean board uploads again
    const WP = this.flBoardWiper(wb, () => { hasPlan = false; this.plan = null; this.lastPlan = null; });
    F.hit = (e) => {
      if (busy || !wb.visible || !this.flRay(e).intersectObject(wb, true).length) return null;
      let moved = false;
      return {
        move: (ev) => {
          if (!hasPlan) return;
          if (!moved) { if (Math.hypot(ev.clientX - e.clientX, ev.clientY - e.clientY) < 10) return; moved = true; this.flAudio(); }
          WP.wipeAt(ev); if (Math.random() < 0.18) { this.flClick(2.6); this.buzz('selection'); }
        },
        up: (ev, tap) => { if (!tap || busy) return;
          if (hasPlan) { start(); return; }
          this.buzz('light'); this.flCheckSound(); WP.reset();
          this.flPickPhoto(() => { busy = true; this.reading('Reading your workout…', ready); }); } };
    };
    F.tick = (dt) => this.flSpkTick(dt);
  }

  // ---------------- the kit: drag down zooms back out of the board; drag up (or tap) and the camera goes down to the bar ----------------
  flKitPreview() {
    const F = this.FL, T = this.THREE, R = this.WB_REST, c = F.cam;
    const WB = new T.Vector3(0, 0, -40);
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); wb.rotation.y = R.ry; wb.position.copy(WB); if (this.plan) this.flDrawBoard(wb, this.plan); wb.visible = false; this.flAdd(wb);
    const cy = 1.45 * R.s, Z = { P: WB.clone().add(new T.Vector3(0.15, cy, 0.7)), T: WB.clone().add(new T.Vector3(0, cy, 0)) };
    const Bv = { P: WB.clone().add(new T.Vector3(...R.cam.P)), T: WB.clone().add(new T.Vector3(...R.cam.T)) };
    const K = { P: c.position.clone(), Q: c.quaternion.clone(), T: c.position.clone().add(c.getWorldDirection(new T.Vector3()).multiplyScalar(6.5)), fov: this.flFov || 35 };
    // below the kit, one screen down, the bar waits exactly as the sets will show it
    const G0 = this.flPanGeo(), down = G0.up.clone().multiplyScalar(-G0.H * G0.wpp), KP = K.P.clone().add(down);
    const camK = new T.PerspectiveCamera(40, 1, 0.1, 100); camK.position.copy(KP); camK.quaternion.copy(K.Q); camK.updateMatrixWorld(true);
    const camS = new T.PerspectiveCamera(40, 1, 0.1, 100); camS.position.set(2.45, 1.25, 1.75); camS.lookAt(0.78, 0.8, -0.08); camS.updateMatrixWorld(true);
    const upS = new T.Vector3(0, 1, 0).applyQuaternion(camS.quaternion), wppS = 2 * camS.position.distanceTo(new T.Vector3(0.78, 0.8, -0.08)) * Math.tan(20 * Math.PI / 180) / G0.H;
    const proxy = new T.Group(); proxy.matrixAutoUpdate = false; proxy.visible = false;
    const bar = this.flBarGroup(); proxy.add(bar); this.flAdd(proxy);
    const kitBg = new T.Color(this.flBgAlt ? this.pal.boxLight : this.pal.bgColor), wodBg = new T.Color(this.flUserBg ? this.pal.boxLight : this.pal.bgColor), mix = new T.Color();
    const tg = new T.Vector3(), items = () => this.flKitItems || [];
    const pose = (v) => {
      const a = Math.min(1, Math.abs(v));
      F.ui.style.opacity = String(1 - Math.min(1, a * 2.6));
      if (v <= 0) proxy.visible = false;
      if (v <= 0) {
        // back: first the plates fold away into the board's surface, then the camera pulls back out of the board
        const a1 = Math.min(1, a / 0.28), a2 = Math.max(0, (a - 0.28) / 0.72), e2 = a2 < 0.5 ? 4 * a2 * a2 * a2 : 1 - Math.pow(-2 * a2 + 2, 3) / 2;
        items().forEach((it) => it.o.scale.setScalar(Math.max(0.0001, 1 - a1 * a1)));
        this.flFov = K.fov;
        if (a2 <= 0) { wb.visible = false; c.position.copy(K.P); c.quaternion.copy(K.Q); }
        else { wb.visible = true; c.position.lerpVectors(Z.P, Bv.P, e2); tg.lerpVectors(Z.T, Bv.T, e2); c.lookAt(tg); }
        mix.copy(kitBg).lerp(wodBg, e2); F.L.style.backgroundColor = '#' + mix.getHexString();
        F.L.style.backgroundImage = a2 > 0 ? 'none' : '';
        if (a2 <= 0) this.flApplyStyle();
      } else {
        // next: a pan straight down, the bar comes up from below
        const e = a < 0.5 ? 2 * a * a : 1 - Math.pow(-2 * a + 2, 2) / 2;
        wb.visible = false; items().forEach((it) => it.o.scale.setScalar(1));
        c.quaternion.copy(K.Q); c.position.copy(K.P).addScaledVector(down, e);
        proxy.visible = e > 0.002; if (proxy.visible) this.flProxyAt(proxy, c, camS, upS, wppS, G0.H * (1 - e));
        this.flFov = K.fov + (40 - K.fov) * e;
        this.flGridY = -G0.H * e; this.flApplyStyle();
      }
    };
    let v = 0;
    const commit = (dir) => {
      F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null;
      const v0 = v, v1 = dir;
      this.flAnim((u) => { v = v0 + (v1 - v0) * (1 - Math.pow(1 - u, 3)); pose(v); }, dir < 0 ? 0.55 : 0.4, () => {
        F.ui.style.opacity = ''; F.L.style.backgroundColor = ''; F.L.style.backgroundImage = ''; this.flGridY = 0;
        if (dir < 0) { this.flAgain = true; this.flFromKit = true; this.flCheckSound(); this.flGo('wod'); }
        else { this.flCheckSound(); this.flGo('sets'); }
      });
    };
    return {
      drag: (e) => {
        const sy = e.clientY; let moved = false;
        return {
          move: (ev) => { const dy = ev.clientY - sy; if (Math.abs(dy) > 6) moved = true; v = Math.max(-1, Math.min(1, -dy / 340)); pose(v); },
          up: (ev, tap) => {
            if (tap && !moved) { commit(1); return; }
            if (Math.abs(v) > 0.3) commit(v < 0 ? -1 : 1);
            else { const v0 = v; this.flAnim((u) => { v = v0 * Math.pow(1 - u, 3); pose(v); }, 0.3, () => { F.ui.style.opacity = ''; F.L.style.backgroundColor = ''; F.L.style.backgroundImage = ''; this.flGridY = 0; this.flApplyStyle(); }); }
          }
        };
      }
    };
  }

  // ---------------- the menu: tap an object and it wakes up where it is ----------------
  penModel() {
    const T = this.THREE, g = new T.Group(), body = this.toon(this.pal.boxDark), tipM = this.toon('#E9E2D6'), capM = this.toon('#111111');
    const b = new T.Mesh(new T.CylinderGeometry(0.035, 0.035, 0.72, 10), body); g.add(b);
    const cone = new T.Mesh(new T.ConeGeometry(0.035, 0.12, 10), tipM); cone.position.y = -0.42; cone.rotation.x = Math.PI; g.add(cone);
    const nib = new T.Mesh(new T.ConeGeometry(0.012, 0.04, 8), capM); nib.position.y = -0.49; nib.rotation.x = Math.PI; g.add(nib);
    g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    return g;
  }
  // a box whose lid, front and side fold away to leave a tiny gym: floor, two walls, the bar on its hooks, the flag, the plates
  gymRoomModel(name) {
    const T = this.THREE, g = new T.Group(), S = 1.15, th = 0.04, ink = this.pal.boxDark;
    const mat = () => { const m = this.toon(this.pal.boxLight); m.transparent = true; return m; };
    const edge = (mesh) => { const e = new T.LineSegments(new T.EdgesGeometry(mesh.geometry), new T.LineBasicMaterial({ color: ink, transparent: true })); mesh.add(e); return e; };
    const slab = (w, h, d) => { const m = new T.Mesh(new T.BoxGeometry(w, h, d), mat()); m.castShadow = true; m.receiveShadow = true; edge(m); return m; };
    const floor = slab(S, th, S); floor.position.y = th / 2; g.add(floor);
    const back = slab(S, S, th); back.position.set(0, S / 2, -S / 2 + th / 2); g.add(back);
    const left = slab(th, S, S); left.position.set(-S / 2 + th / 2, S / 2, 0); g.add(left);
    // the parts that open: lid lifts off, front and right fall outward
    const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d');
    x.fillStyle = this.pal.boxLight; x.fillRect(0, 0, 256, 256); x.fillStyle = ink; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '900 120px "Playfair Display", Georgia, serif'; x.fillText(name || '79', 128, 140);
    const tx = new T.CanvasTexture(c); tx.colorSpace = T.SRGBColorSpace;
    const fm = mat(), frontFace = this.toon('#FFFFFF'); frontFace.map = tx; frontFace.transparent = true;
    const frontPivot = new T.Group(); frontPivot.position.set(0, 0, S / 2); g.add(frontPivot);
    const front = new T.Mesh(new T.BoxGeometry(S, S, th), [fm, fm, fm, fm, frontFace, fm]); front.position.set(0, S / 2, -th / 2); front.castShadow = true; const fe = edge(front); frontPivot.add(front);
    const rightPivot = new T.Group(); rightPivot.position.set(S / 2, 0, 0); g.add(rightPivot);
    const right = slab(th, S, S); right.position.set(-th / 2, S / 2, 0); rightPivot.add(right);
    const lid = slab(S, th, S); lid.position.set(0, S - th / 2, 0); g.add(lid);
    // inside
    const inside = new T.Group(); g.add(inside);
    const items = {};
    { // the bar on two hooks, on the back wall
      const grp = new T.Group(), bar = this.flBarGroup(); bar.position.y = 0; bar.scale.setScalar(0.47); grp.add(bar);
      const K = this.toon('#2B2B2B');
      [-0.3, 0.3].forEach((hx) => { const h = new T.Mesh(new T.BoxGeometry(0.05, 0.12, 0.09), K); h.position.set(hx, -0.03, -0.03); grp.add(h); });
      grp.position.set(0, 0.72, -S / 2 + th + 0.07); inside.add(grp); items.bar = grp;
    }
    { // the flag with the gym's name, on the left wall
      const fc = document.createElement('canvas'); fc.width = 320; fc.height = 200; const f = fc.getContext('2d');
      f.fillStyle = ink; f.fillRect(0, 0, 320, 200); f.fillStyle = this.pal.boxLight; f.textAlign = 'center'; f.textBaseline = 'middle'; f.font = '900 118px "Playfair Display", Georgia, serif'; f.fillText(name || '79', 160, 108);
      const ft = new T.CanvasTexture(fc); ft.colorSpace = T.SRGBColorSpace;
      const geo = new T.PlaneGeometry(0.62, 0.39, 10, 1), flag = new T.Mesh(geo, new T.MeshBasicMaterial({ map: ft, side: T.DoubleSide, transparent: true }));
      flag.userData.p0 = geo.attributes.position.array.slice();
      const grp = new T.Group(); grp.add(flag); grp.rotation.y = Math.PI / 2; grp.position.set(-S / 2 + th + 0.02, 0.68, 0.02); inside.add(grp); items.flag = grp; items.flagMesh = flag;
    }
    { // the plates, stacked and sorted on the floor
      const grp = new T.Group(), own = (this.d.own && this.d.own[this.d.unit]) || [], sp = this.specs().filter((s) => !own.length || own.indexOf(s.kg) >= 0).slice(0, 6);
      sp.forEach((s, i) => {
        const col = i % 3, row = Math.floor(i / 3), sc = 0.42;
        for (let j = 0; j < 2; j++) { const p = this.plate(s); p.scale.setScalar(sc); p.position.set((col - 1) * 0.27, 0.005 + j * s.t * sc + s.t * sc / 2, row * 0.27); p.traverse((m) => { if (m.isMesh) m.castShadow = true; }); grp.add(p); }
      });
      grp.position.set(0.12, th, 0.02); inside.add(grp); items.plates = grp;
    }
    { // a kettlebell in the corner: kilos or pounds
      const kb = this.kettlebell(this.d.unit.toUpperCase()), grp = new T.Group(); kb.scale.setScalar(0.32); kb.position.y = 0; grp.add(kb);
      grp.position.set(-0.36, th, 0.36); inside.add(grp); items.bell = grp;
    }
    const fade = [front, right, lid].map((m) => m);
    const setOp = (m, o) => m.traverse((q) => { if (q.material) (Array.isArray(q.material) ? q.material : [q.material]).forEach((mt) => { mt.opacity = o; mt.transparent = o < 1; mt.depthWrite = o > 0.5; }); });
    g.userData = {
      items, S,
      open: (k) => {
        const e = Math.min(1, Math.max(0, k)), a = Math.min(1, e / 0.7);
        const fall = a * a * (3 - 2 * a);
        frontPivot.rotation.x = fall * Math.PI / 2; rightPivot.rotation.z = -fall * Math.PI / 2;
        lid.position.y = S - th / 2 + fall * 0.9; lid.rotation.z = fall * 0.4;
        const fo = Math.max(0, 1 - Math.max(0, (e - 0.35) / 0.4));
        fade.forEach((m) => { setOp(m, fo); m.visible = fo > 0.01; });
        Object.keys(items).forEach((key, i) => { const o = items[key]; if (!o.isObject3D || key === 'flagMesh') return; const q = Math.min(1, Math.max(0, (e - 0.45 - i * 0.08) / 0.35)); o.scale.setScalar(Math.max(0.0001, this.outBack(q, 1.6))); });
      },
      wave: (t) => { const m = items.flagMesh, p = m.geometry.attributes.position, a = p.array, p0 = m.userData.p0; for (let i = 0; i < a.length; i += 3) { const xx = p0[i] + 0.31; a[i + 2] = Math.sin(t * 3 + xx * 9) * 0.025 * xx; } p.needsUpdate = true; }
    };
    g.userData.open(0);
    return g;
  }
  flMenu() {
    const F = this.FL, T = this.THREE;
    this.flMode = 'menu'; this.flEditOne = false;
    const MC = { P: new T.Vector3(0, 1.4, 7.2), T: new T.Vector3(0, 0.55, 0) };
    this.flCam(MC.P.toArray(), MC.T.toArray(), 35);
    const SP = 1.9, plan = this.lastPlan;
    const items = [
      { key: 'train', label: 'Train', make: () => { const g = this.whiteboardModel(); g.scale.setScalar(0.62); this.flDrawBoard(g, plan); return g; } },
      { key: 'prs', label: 'My PRs', make: () => { const g = this.notebookModel2('MY PRs'); g.position.y = 0.8; g.rotation.x = -0.25; return g; } },
      { key: 'gym', label: 'Gym', make: () => this.gymRoomModel(this.d.name) }
    ];
    const n = items.length, labels = [];
    let pos = this.flMenuPos != null ? this.flMenuPos : 0, vel = 0, idx = Math.round(pos), dragging = false;
    // the active item: k goes 0 → 1 as it wakes up
    let act = null, k = 0, busy = false;
    items.forEach((it, i) => {
      const w = new T.Group(), m = it.make(); w.add(m); it.m = m; it.w = w; w.position.x = (i - pos) * SP; this.flAdd(w);
      const sh = this.softShadow(0.7); sh.scale.set(1, 0.6, 1); w.add(sh); it.sh = sh;
      const lab = this.fh('div', { position: 'absolute', left: 0, top: 0, transform: 'translate(-50%,-50%)', color: this.flInk(), fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '22px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, it.label);
      labels.push(lab);
    });
    const tr = items[0], nbI = items[1], gy = items[2];
    // several gyms: inside the gym, the rooms sit side by side (along the screen's right); the last slot adds a new one
    const gyms = this.flGymList(); let gcur = this.flGymIdx, gpos = gcur, gtgt = gcur, gdrag = false;
    const rooms = gyms.map((g, j) => (j === gcur ? gy.m : this.gymRoomModel(g.name, g))); rooms.push(this.gymAddModel());
    rooms.forEach((r, j) => { if (j !== gcur) { r.userData.open(1); r.scale.setScalar(0.0001); gy.w.add(r); } });
    const RIGHT = new T.Vector3(0.794, 0, -0.607), GSP = 2.4;
    const gymSettle = () => {
      if (busy) return;
      const j = Math.round(gtgt);
      if (j !== gcur && j < gyms.length) {
        gyms[gcur] = this.flGymSnap(); this.flGymLoad(gyms[j]); gcur = j; this.flGymIdx = j;
        rooms[j].userData.open(1); gy.m = rooms[j]; this.buzz('selection');
      }
    };
    const newGym = () => {
      this.buzz('light'); this.flCheckSound(); busy = true;
      gyms[gcur] = this.flGymSnap();
      gyms.push({ name: '', unit: this.d.unit, own: { kg: [], lb: [] }, bar: JSON.parse(JSON.stringify(this.d.bar || {})) });
      this.flGymIdx = gyms.length - 1; this.flGymLoad(gyms[this.flGymIdx]); gcur = this.flGymIdx; gtgt = gpos = gcur;
      this.flMenuActive = 'gym'; this.flEditOne = false; this.flMode = 'gym'; this.flPanTo('name');
    };
    const askDelete = () => {
      this.buzz('warning');
      const nm = gyms[gcur].name || 'this gym';
      if (gyms.length <= 1) { this.flAlert('Can’t delete ' + nm, 'You need at least one gym.', [{ label: 'OK', bold: true }]); return; }
      this.flAlert('Delete ' + nm + '?', 'Its plates and bar settings will be removed.', [{ label: 'Cancel', bold: true }, { label: 'Delete', destructive: true, fn: () => {
        gyms.splice(gcur, 1); this.flGymIdx = Math.max(0, gcur - 1); this.flGymLoad(gyms[this.flGymIdx]); this.flGyms = gyms;
        this.buzz('success'); this.flMenuActive = 'gym'; this.flGo('menu');
      } }]);
    };
    // the notebook's page and the pen
    const rows = () => this.d.prs.filter((q) => q[1] != null).map((q) => q[0] + '  ' + this.fmt(q[1]) + ' ' + this.d.unit);
    nbI.m.userData.drawPage(rows());
    const pen = this.penModel(); pen.position.set(0.55, 0.36, 0.34); pen.rotation.set(0.5, 0, -0.95); pen.scale.setScalar(0.0001); nbI.w.add(pen);
    // the board's state: the last session, wiped clean, or a fresh upload
    let board = plan ? 'plan' : 'clean';
    // cameras: the menu, and a gentle move toward the active item (the gym gets its isometric corner view)
    const camFor = (it) => {
      const c = it.w.position.clone();
      if (it.key === 'gym') return { P: c.clone().add(new T.Vector3(3.9, 3.6, 5.1)), T: c.clone().add(new T.Vector3(0, 0.42, 0)) };
      if (it.key === 'prs') return { P: c.clone().add(new T.Vector3(0, 1.2, 6.5)), T: c.clone().add(new T.Vector3(0, 0.74, 0)) };
      return { P: c.clone().add(new T.Vector3(0, 1.2, 5.2)), T: c.clone().add(new T.Vector3(0, 0.82, 0)) };
    };
    const tg = new T.Vector3();
    const applyK = () => {
      const kk = k, e = kk * kk * (3 - 2 * kk);
      if (act) {
        const A = camFor(act); F.cam.position.lerpVectors(MC.P, A.P, e); tg.lerpVectors(MC.T, A.T, e); F.cam.lookAt(tg);
        labels.forEach((L, i) => { L.style.opacity = String((items[i] === act ? 1 : 0.25) * (1 - e)); });
        if (act === nbI) {
          nbI.m.userData.hinge.rotation.y = -2.95 * e; nbI.m.rotation.set(-0.25 + 0.15 * e, 0.18 * (1 - e), 0); nbI.m.scale.setScalar(1 - 0.3 * e); nbI.m.position.x = 0.37 * e;
          pen.scale.setScalar(Math.max(0.0001, this.outBack(Math.min(1, Math.max(0, (kk - 0.4) / 0.6)), 1.4)));
        }
        if (act === gy) gy.m.userData.open(kk);
        if (act === tr) tr.m.rotation.y = 0;
      } else { F.cam.position.copy(MC.P); F.cam.lookAt(MC.T); }
    };
    const activate = (it, instant) => {
      act = it; this.flMenuActive = it.key; dragging = false; vel = 0; pos = items.indexOf(it); this.flMenuPos = pos;
      if (instant) { k = 1; applyK(); return; }
      const k0 = k; busy = true; this.flClick(0.9);
      this.flAnim((u) => { k = k0 + (1 - k0) * (1 - Math.pow(1 - u, 3)); applyK(); }, it === gy ? 1.1 : 0.6, () => { busy = false; if (it === gy) this.flSparkles(gy.w.position.clone().add(new T.Vector3(0, 0.9, 0.3)), 5, 1); });
    };
    const deactivate = (k0) => {
      busy = true; const from = k0 != null ? k0 : k;
      this.flAnim((u) => { k = from * Math.pow(1 - u, 3); applyK(); }, 0.45, () => { k = 0; applyK(); act = null; this.flMenuActive = null; busy = false; labels.forEach((L) => { L.style.opacity = ''; }); });
    };
    // first-time: the items pop in; back from an edit: the item is already awake
    const back = this.flMenuActive && items.find((q) => q.key === this.flMenuActive);
    if (back) activate(back, true); else items.forEach((it, i) => this.popIn(it.w, 120 + i * 90));
    const v = new T.Vector3();
    F.tick = (dt, t) => {
      if (!act) {
        if (!dragging) { pos += vel * dt; vel *= Math.exp(-dt * 5); pos = Math.max(-0.3, Math.min(n - 0.7, pos)); if (Math.abs(vel) < 1.5) pos += (Math.max(0, Math.min(n - 1, Math.round(pos))) - pos) * (1 - Math.exp(-dt * 10)); }
        const i0 = Math.max(0, Math.min(n - 1, Math.round(pos))); if (i0 !== idx) { idx = i0; this.buzz('selection'); }
        this.flMenuPos = pos;
      }
      items.forEach((it, i) => {
        const d = i - pos, ad = Math.abs(d), ke = act && it !== act ? k * k * (3 - 2 * k) : 0; it.w.position.x = d * SP + Math.sign(d) * ke * 1.6; it.w.position.z = -Math.min(1, ad) * 0.6;
        const calm = it === act ? 1 - Math.min(1, k * 1.5) : 1;
        if (it.key === 'gym') it.m.rotation.y = (0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4)) * calm;
        else if (it.key === 'prs') { if (it !== act) it.m.rotation.y = 0.18 + 0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4); }
        else it.m.rotation.y = 0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4) * calm;
        v.set(it.w.position.x, -0.45, it.w.position.z).project(F.cam); const L = labels[i]; L.style.left = ((v.x + 1) / 2 * 100) + '%'; L.style.top = ((1 - v.y) / 2 * 100) + '%';
        if (!act) L.style.opacity = String(Math.max(0.25, 1 - ad * 0.75));
      });
      { // the row of gyms
        const show = act === gy ? k * k * (3 - 2 * k) : 0;
        if (act !== gy) { gtgt = gcur; }
        if (!gdrag) gpos += (gtgt - gpos) * (1 - Math.exp(-dt * 9));
        rooms.forEach((r, j) => { r.position.copy(RIGHT).multiplyScalar((j - gpos) * GSP); if (r !== gy.m) { r.scale.setScalar(Math.max(0.0001, show)); r.rotation.y = 0; } if (show > 0.5) r.userData.wave(t + j); });
        if (!gdrag && Math.abs(gtgt - gpos) < 0.02) gymSettle();
        gy.sh.position.x = gy.m.position.x; gy.sh.position.z = gy.m.position.z; gy.sh.visible = Math.abs(gpos - gcur) < 0.5;
      }
      this.flSpkTick(dt);
    };
    // ---- what each awake item does
    const hitObj = (e, o) => this.flRay(e).intersectObject(o, true).length > 0;
    const edit = (key, step) => { this.buzz('light'); this.flCheckSound(); this.flMenuActive = key; this.flEditOne = true; this.flMode = 'gym'; busy = true; this.flPanTo(step); };
    const trainStart = () => {
      busy = true; this.buzz('light'); this.flCheckSound();
      this.plan = this.lastPlan; this.setIdx = 0; this.doneSets = []; this.d.kitGot = {}; this.flMode = 'menu'; this.flAgain = true;
      const sc = 0.62, cy = 1.45 * sc, c0 = tr.w.position.clone(), P0 = F.cam.position.clone(), T0 = tg.clone(), P1 = c0.clone().add(new T.Vector3(0.1, cy, 0.5)), T1 = c0.clone().add(new T.Vector3(0, cy, 0)), q = new T.Vector3();
      labels.forEach((L) => { L.style.opacity = '0'; });
      this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; F.cam.position.lerpVectors(P0, P1, e); q.lerpVectors(T0, T1, e); F.cam.lookAt(q); }, 0.9, () => { this.flMenuActive = 'train'; this.flGo('kit'); });
    };
    // wiping the board: the marker comes off wherever the finger scrubs; enough of it and the board is clean
    const wb = tr.m, bc = wb.userData.c, bx = bc.getContext('2d'), clean = document.createElement('canvas'); clean.width = bc.width; clean.height = bc.height;
    { const tmp = this.whiteboardModel(); this.flDrawBoard(tmp, null); clean.getContext('2d').drawImage(tmp.userData.c, 0, 0); }
    const cells = new Set(), CW = 10, CH = 5;
    const wipeAt = (e) => {
      const hit = this.flRay(e).intersectObject(wb.userData.board, false)[0]; if (!hit || !hit.uv) return;
      const x = hit.uv.x * bc.width, y = (1 - hit.uv.y) * bc.height, r = 92;
      bx.save(); bx.beginPath(); bx.arc(x, y, r, 0, Math.PI * 2); bx.clip(); bx.drawImage(clean, 0, 0); bx.restore(); wb.userData.tex.needsUpdate = true;
      if (y > 150) { for (let ox = -1; ox <= 1; ox++) for (let oy = -1; oy <= 1; oy++) { const cx = Math.floor((x + ox * r * 0.6) / bc.width * CW), cyy = Math.floor((y + oy * r * 0.6 - 150) / (bc.height - 150) * CH); if (cx >= 0 && cx < CW && cyy >= 0 && cyy < CH) cells.add(cx + ',' + cyy); } }
      if (board === 'plan' && cells.size >= CW * CH * 0.45) {
        board = 'clean'; this.lastPlan = null; bx.drawImage(clean, 0, 0); wb.userData.tex.needsUpdate = true;
        this.buzz('success'); this.flCheckSound(); this.flSparkles(tr.w.position.clone().add(new T.Vector3(0, 0.95, 0.3)), 5, 0.9);
      }
    };
    const upload = () => {
      this.buzz('light'); this.flCheckSound();
      this.flPickPhoto(() => { busy = true; this.reading('Reading your workout…', () => {
        this.lastPlan = this.workoutPlan(); this.flDrawBoard(wb, this.lastPlan); board = 'plan'; cells.clear(); busy = false;
        this.flShine([wb], 0.6); this.flSparkles(tr.w.position.clone().add(new T.Vector3(0, 0.95, 0.3)), 5, 0.9);
      }); });
    };
    const prUpload = () => {
      this.buzz('light'); this.flCheckSound();
      this.flPickPhoto(() => { busy = true; this.reading('Reading your PRs…', () => {
        this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); nbI.m.userData.drawPage(rows()); busy = false;
        this.flShine([nbI.m], 0.7); this.flSparkles(nbI.w.position.clone().add(new T.Vector3(0.4, 0.9, 0.4)), 5, 1);
      }); });
    };
    // swipe up while an item is awake: it settles back into the menu with your finger
    const backDrag = (sy) => ({
      move: (ev) => { const p = Math.max(0, Math.min(1, (sy - ev.clientY - 10) / 300)); k = 1 - p; applyK(); },
      up: () => { if (k < 0.65) deactivate(k); else { const k0 = k; this.flAnim((u) => { k = k0 + (1 - k0) * (1 - Math.pow(1 - u, 3)); applyK(); }, 0.25); } }
    });
    const ppi = 390 * SP / (F.cam.position.z * 0.2914 * 1.15);
    F.hit = (e) => {
      if (busy) return { up: () => {} };
      if (act) {
        const sx = e.clientX, sy = e.clientY;
        // a gesture on an awake item: decide by what's under the finger and which way it goes
        let mode = null, inner = null, g0 = gpos;
        const onBoard = act === tr && hitObj(e, wb.userData.board);
        // press and hold a gym to delete it
        const lp = act === gy && Math.round(gtgt) < gyms.length && hitObj(e, gy.m) ? setTimeout(() => { if (!mode) { mode = 'held'; askDelete(); } }, 600) : null;
        return {
          move: (ev) => {
            const dx = ev.clientX - sx, dy = ev.clientY - sy;
            if (!mode) {
              if (Math.hypot(dx, dy) < 10) return;
              clearTimeout(lp);
              if (act === gy && Math.abs(dx) > Math.abs(dy)) { mode = 'gyms'; gdrag = true; g0 = gpos; }
              else if (-dy > Math.abs(dx) * (onBoard && board === 'plan' ? 2.6 : 1.3)) { mode = 'back'; inner = backDrag(sy); }
              else if (onBoard && board === 'plan') { mode = 'wipe'; this.flAudio(); }
              else mode = 'none';
            }
            if (mode === 'back') inner.move(ev);
            if (mode === 'gyms') gpos = Math.max(-0.25, Math.min(rooms.length - 0.75, g0 - dx / 420));
            if (mode === 'wipe') { wipeAt(ev); if (Math.random() < 0.18) { this.flClick(2.6); this.buzz('selection'); } }
          },
          up: (ev, tap) => {
            clearTimeout(lp);
            if (mode === 'held') return;
            if (mode === 'gyms') { gdrag = false; const dx = ev.clientX - sx; gtgt = Math.max(0, Math.min(rooms.length - 1, Math.round(gpos + (dx < -40 ? 0.35 : dx > 40 ? -0.35 : 0)))); return; }
            if (mode === 'back') { inner.up(ev); return; }
            if (!tap) return;
            if (act === tr) { if (!hitObj(ev, tr.m)) return; if (board === 'plan') trainStart(); else upload(); return; }
            if (act === nbI) { if (hitObj(ev, pen)) { this.buzz('light'); this.flCheckSound(); this.flMenuActive = 'prs'; this.flPrRet = 'menu'; this.flEditOne = true; busy = true; this.flPanTo('prDial'); return; }
              if (hitObj(ev, nbI.m)) prUpload(); return; }
            if (act === gy) {
              if (Math.round(gtgt) >= gyms.length) { if (hitObj(ev, rooms[rooms.length - 1])) newGym(); return; }
              const I = gy.m.userData.items;
              if (hitObj(ev, I.flag)) edit('gym', 'name'); else if (hitObj(ev, I.bar)) edit('gym', 'bar'); else if (hitObj(ev, I.plates)) edit('gym', 'plates'); else if (hitObj(ev, I.bell)) edit('gym', 'unit');
            }
          }
        };
      }
      let x0 = e.clientX, t0 = performance.now(); dragging = true; this.flAudio();
      return {
        move: (ev) => { const dx = ev.clientX - x0, now = performance.now(); const d = -dx / ppi; pos += d; vel = d / Math.max(0.008, (now - t0) / 1000); x0 = ev.clientX; t0 = now; },
        up: (ev, tap) => {
          dragging = false; if (performance.now() - t0 > 90) vel = 0;
          if (tap) { const it = items[idx]; this.buzz('light'); this.flCheckSound(); activate(it); }
        }
      };
    };
  }
  // the scale, then the menu — the board keeps the session you just did
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light'); this.dropLayer(L);
    if (this.plan) this.lastPlan = this.plan;
    this.plan = null; this.flBar = null; this.flMenuPos = 0; this.flMenuActive = null; this.flMode = 'menu'; this.flGo('menu');
  }
