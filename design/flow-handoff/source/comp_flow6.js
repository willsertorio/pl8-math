
  // ===================== FLOW, round 6: polish =====================
  // words appear one by one, no fade — the spoken timing stays
  flSay(text, then) {
    const F = this.FL, q = F.q; F.words.forEach(clearTimeout); F.words = [];
    q.getAnimations().forEach((a) => a.cancel());
    q.textContent = ''; q.setAttribute('aria-label', text); q.style.transform = ''; q.style.opacity = '1';
    const ws = text.split(/\s+/).filter(Boolean); let t = 0;
    ws.forEach((w, i) => {
      const s = document.createElement('span'); s.textContent = w; s.style.visibility = 'hidden'; q.appendChild(s);
      if (i < ws.length - 1) q.appendChild(document.createTextNode(' '));
      F.words.push(setTimeout(() => { if (!this.dead) s.style.visibility = 'visible'; }, t));
      t += 95 + 18 * w.replace(/[^\w’']/g, '').length;
      if (/[,;:]$/.test(w)) t += 230;
      if (/[.?!…]$/.test(w)) t += 420;
    });
    const total = t + 120;
    F.words.push(setTimeout(() => { if (!this.dead && then) then(); }, total));
    return total;
  }
  flSwipeQuiet(fn) { const F = this.FL; F.swipe = true; F.onSwipe = fn; F.onTap = fn; F.sw.style.display = 'none'; }
  // leaving a question: everything clears out fast (ease-out), then the next question starts on an empty screen
  flPanTo(step) {
    if (this.flPanning) return;
    if (this.flDirect) { this.flDirect = false; this.flGo(step); return; }
    this.flPanning = true;
    const F = this.FL, EO = 'cubic-bezier(.16,1,.3,1)';
    F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null; F.drag = null;
    F.q.getAnimations().forEach((a) => a.cancel());
    F.q.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-26px)', opacity: 0 }], { duration: 260, easing: EO, fill: 'forwards' });
    [...F.ui.children].forEach((el) => el.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-26px)', opacity: 0 }], { duration: 260, easing: EO, fill: 'forwards' }));
    (this.flSpk || []).forEach((d) => F.S.remove(d.m)); this.flSpk = [];
    const objs = F.objs.slice(), s0 = objs.map((o) => o.scale.clone());
    this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); objs.forEach((o, i) => o.scale.copy(s0[i]).multiplyScalar(Math.max(0.0001, 1 - e))); }, 0.3, () => {
      this.flPanning = false; this.flGo(step);
    });
  }
  flGo(step) {
    this.flClear(); this.flStep = step; this.flApplyStyle();
    ({ name: () => this.flName(), unit: () => this.flUnit(), plates: () => this.flPlates(), bar: () => this.flBarQ(), prs: () => this.flPRs(), prDial: () => this.flPRDial(0),
      wod: () => this.flWod(), kit: () => this.flKit(), sets: () => this.flSets(), menu: () => this.flMenu() })[step]();
    this.flFromMenu = false; this.flFromKit = false;
    // inside a menu item, a swipe up goes back to the menu
    const F = this.FL;
    if ((this.flMode === 'menu' || this.flMode === 'gym') && ['wod', 'prs', 'name', 'unit', 'plates', 'bar'].indexOf(step) >= 0) {
      F.swipe = true; F.onSwipe = () => { this.flCheckSound(); this.flMode = 'menu'; this.flPanTo('menu'); };
    }
  }

  // ---------------- 4 · plates: a checklist — draw a tick in YES or NO for each plate ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs(), n = specs.length;
    this.flCam([0, 0, 8.2], [0, 0, 0], 35);
    const k = 2 * 8.2 * Math.tan(17.5 * Math.PI / 180) / 844, top = 214, bot = 790, rowH = (bot - top) / n;
    const wx = (px) => (px - 195) * k, wy = (py) => (422 - py) * k;
    const ink = this.flInk(), box = Math.round(Math.min(46, rowH * 0.74)), XY = 262, XN = 334;
    const gray = new T.MeshBasicMaterial({ color: 0x9a9690, transparent: true, opacity: 0.3, depthWrite: false });
    const rows = []; this.flPlRows = rows;
    let done = false;
    const sketchBox = (cv, s) => {
      const x = cv.getContext('2d'), p = 12; x.clearRect(0, 0, cv.width, cv.height); x.save(); x.scale(cv.width / (s + 2 * p), cv.height / (s + 2 * p));
      x.strokeStyle = ink; x.lineWidth = 2.6; x.lineCap = 'round'; x.lineJoin = 'round';
      const J = cv._j || (cv._j = Array.from({ length: 24 }, () => (Math.random() - 0.5) * 2.2)); let ji = 0; const j = () => J[ji++ % 24], pts = [[p, p], [p + s, p], [p + s, p + s], [p, p + s]];
      x.beginPath(); pts.forEach((a, i) => { const b = pts[(i + 1) % 4]; x.moveTo(a[0] + j(), a[1] + j()); x.quadraticCurveTo((a[0] + b[0]) / 2 + j(), (a[1] + b[1]) / 2 + j(), b[0] + j(), b[1] + j()); }); x.stroke(); x.restore();
    };
    const paintPlate = (r) => r.meshes.forEach((m) => { m.material = r.state === 'no' ? gray : m.userData.m0; });
    const finish = () => {
      if (done || rows.some((r) => !r.state)) return;
      done = true;
      this.d.own[this.d.unit] = rows.filter((r) => r.state === 'yes').map((r) => r.s.kg);
      const yes = rows.filter((r) => r.state === 'yes');
      this.flLater(() => { this.flShine(yes.map((r) => r.w), 0.8); yes.forEach((r, i) => this.flLater(() => this.flSparkles(r.w.position.clone().setZ(0.4), 2, 0.35), i * 50)); }, 200);
      this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 1100);
    };
    const makeBox = (r, which, x, y) => {
      const s = box, p = 12, cv = document.createElement('canvas'), dpr = 2;
      cv.width = (s + 2 * p) * dpr; cv.height = (s + 2 * p) * dpr;
      Object.assign(cv.style, { position: 'absolute', left: (x - s / 2 - p) + 'px', top: (y - s / 2 - p) + 'px', width: (s + 2 * p) + 'px', height: (s + 2 * p) + 'px', pointerEvents: 'auto', touchAction: 'none', cursor: 'crosshair' });
      cv.setAttribute('role', 'checkbox'); cv.setAttribute('aria-label', (which === 'yes' ? 'Have ' : 'Don’t have ') + this.fmt(r.s.kg) + ' ' + this.d.unit);
      F.ui.appendChild(cv); sketchBox(cv, s);
      cv.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: 360, delay: r.i * 60 + (which === 'yes' ? 0 : 40), easing: 'cubic-bezier(.3,1.5,.5,1)', fill: 'backwards' });
      const B = { cv, s, p, which, pts: [] };
      const ctx = cv.getContext('2d');
      const draw = () => {
        sketchBox(cv, s); if (B.pts.length < 2) return;
        ctx.save(); ctx.scale(dpr, dpr); ctx.strokeStyle = ink; ctx.lineWidth = 4.2; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        ctx.beginPath(); B.pts.forEach(([a, b], i) => (i ? ctx.lineTo(a, b) : ctx.moveTo(a, b))); ctx.stroke(); ctx.restore();
      };
      B.clear = () => { B.pts = []; draw(); };
      let drawing = false, len = 0;
      const at = (e) => { const R = cv.getBoundingClientRect(), sc = R.width / (s + 2 * p); return [(e.clientX - R.left) / sc, (e.clientY - R.top) / sc]; };
      cv.addEventListener('pointerdown', (e) => { if (done) return; e.stopPropagation(); e.preventDefault(); try { cv.setPointerCapture(e.pointerId); } catch (er) {} drawing = true; len = 0; B.pts = [at(e)]; this.flAudio(); draw(); });
      cv.addEventListener('pointermove', (e) => { if (!drawing) return; e.stopPropagation(); const q = at(e), l = B.pts[B.pts.length - 1]; len += Math.hypot(q[0] - l[0], q[1] - l[1]); B.pts.push(q); draw(); if (B.pts.length % 6 === 0) this.flClick(2.2); });
      const accept = () => {
        // ticked: this row is decided; the other box empties
        r.state = which; (which === 'yes' ? r.no : r.yes).clear(); paintPlate(r); this.buzz('light'); this.flClick(which === 'yes' ? 1.2 : 0.7);
        if (which === 'yes') this.flShine([r.w], 0.4);
        finish();
      };
      const up = (e) => {
        if (!drawing) return; drawing = false; if (e && e.stopPropagation) e.stopPropagation();
        if (len < 6) {
          // a tap: the pen draws the tick for you, quickly
          const c0 = p + s / 2, pts = [[c0 - s * 0.3, c0 + s * 0.02], [c0 - s * 0.08, c0 + s * 0.26], [c0 + s * 0.34, c0 - s * 0.3]], seq = [];
          for (let i = 0; i < 2; i++) for (let k = 0; k <= 8; k++) seq.push([pts[i][0] + (pts[i + 1][0] - pts[i][0]) * k / 8 + (Math.random() - 0.5) * 1.2, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * k / 8 + (Math.random() - 0.5) * 1.2]);
          B.pts = [];
          this.flAnim((u) => { B.pts = seq.slice(0, Math.max(1, Math.ceil(u * seq.length))); draw(); }, 0.18, () => { if (!done) accept(); });
          return;
        }
        if (len < s * 0.3) { cv.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-4px)' }, { transform: 'translateX(4px)' }, { transform: 'translateX(0)' }], { duration: 220 }); B.clear(); return; }
        accept();
      };
      cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
      // a stroke that ends outside the box still counts
      const winUp = (e) => { if (!cv.isConnected) { window.removeEventListener('pointerup', winUp); window.removeEventListener('pointercancel', winUp); return; } up(e); };
      window.addEventListener('pointerup', winUp); window.addEventListener('pointercancel', winUp);
      return B;
    };
    this.flAfter('What are the plates available?', () => {
      [['YES', XY], ['NO', XN]].forEach(([l, x]) => { const h = this.fh('div', { position: 'absolute', left: x + 'px', top: (top - 16) + 'px', transform: 'translate(-50%,-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '15px', letterSpacing: '0.08em', pointerEvents: 'none' }, F.ui, l); h.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, fill: 'backwards' }); });
      specs.forEach((s, i) => {
        const y = top + rowH * (i + 0.5), g = this.plate(s), w = new T.Group(); w.add(g); g.rotation.x = Math.PI / 2;
        const dia = rowH * 0.84 * k * (0.62 + 0.38 * Math.min(1, s.d / 0.45)), sc = dia / s.d; w.scale.setScalar(sc);
        const ty = wy(y); w.position.set(wx(58), ty + 4, 0); this.flAdd(w);
        const meshes = []; g.traverse((m) => { if (m.isMesh) { m.userData.m0 = m.material; meshes.push(m); } });
        const r = { s, i, w, g, meshes, state: null };
        // each plate drops into its row and settles
        w.visible = false;
        this.flLater(() => { w.visible = true; this.flAnim((u) => { const b = u < 0.6 ? (u / 0.6) ** 2 : 1 - 0.18 * Math.sin((u - 0.6) / 0.4 * Math.PI) * (1 - u); w.position.y = ty + (1 - Math.min(1, b)) * 4; }, 0.55, () => this.flClick(0.5)); }, i * 70);
        const lab = this.fh('div', { position: 'absolute', left: '106px', top: y + 'px', transform: 'translateY(-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: Math.round(Math.min(20, rowH * 0.36)) + 'px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, this.fmt(s.kg) + ' ' + this.d.unit);
        lab.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, delay: i * 70 + 300, fill: 'backwards' });
        r.yes = makeBox(r, 'yes', XY, y); r.no = makeBox(r, 'no', XN, y);
        rows.push(r);
      });
    });
    F.tick = (dt, t) => { rows.forEach((r, i) => { r.g.rotation.y = Math.sin(t * 0.8 + i) * 0.12; }); this.flSpkTick(dt); };
  }

  // ---------------- 6 · the board: smaller, angled, pushed in with a horizontal spin ----------------
  get WB_REST() { return { s: 0.85, ry: -0.28, cam: { P: [0, 1.9, 7.0], T: [0, 1.1, 0] } }; }
  flWod() {
    const F = this.FL, T = this.THREE, R = this.WB_REST;
    this.flCam(R.cam.P, R.cam.T, 35);
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.18 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); this.flAdd(wb);
    const instant = this.flFromKit || this.flFromMenu;
    if (instant) { wb.rotation.y = R.ry; if (this.plan) this.flDrawBoard(wb, this.plan); } else wb.visible = false;
    let busy = false;
    this.flAfter(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?', () => {
      if (instant) return;
      // pushed in: it rolls on from the right spinning round on its wheels, overshoots a touch and rocks to rest, angled
      wb.visible = true; wb.position.x = 3.6; wb.rotation.y = -1.9; this.flClick(0.5);
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3), o = Math.sin(e * Math.PI) * 0.18; wb.position.x = 3.6 * (1 - e); wb.rotation.y = -1.9 + (R.ry + 1.9) * e + o; wb.userData.wheels.forEach((w) => { w.rotation.x = -(1 - e) * 40; }); }, 1.15, () => {
        this.flAnim((u) => { wb.rotation.z = 0.05 * Math.exp(-u * 5) * Math.sin(u * 16); wb.rotation.y = R.ry + 0.06 * Math.exp(-u * 4) * Math.sin(u * 11); }, 1.0);
      });
    });
    const ready = () => {
      this.plan = this.workoutPlan(); this.setIdx = 0; this.doneSets = []; this.d.kitGot = {};
      this.flDrawBoard(wb, this.plan); this.flShine([wb], 0.6);
      this.flLater(() => {
        const cam = F.cam, P0 = cam.position.clone(), T0 = new T.Vector3(...R.cam.T), cy = 1.45 * R.s, T1 = new T.Vector3(0, cy, 0), P1 = new T.Vector3(0.15, cy, 0.7), tgt = new T.Vector3();
        this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; cam.position.lerpVectors(P0, P1, e); tgt.lerpVectors(T0, T1, e); cam.lookAt(tgt); }, 1.15, () => { this.flCheckSound(); this.flGo('kit'); });
      }, 1100);
    };
    F.hit = (e) => {
      if (busy || !wb.visible || !this.flRay(e).intersectObject(wb, true).length) return null;
      return { up: (ev, tap) => { if (!tap || busy) return; this.buzz('light'); this.flCheckSound();
        this.flPickPhoto(() => { busy = true; this.reading('Reading your workout…', ready); }); } };
    };
    F.tick = (dt) => this.flSpkTick(dt);
  }

  // ---------------- the kit: dragging previews where you're going — down to the board, up to the bar ----------------
  flBarGroup() {
    const T = this.THREE, bar = new T.Group();
    const steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 20), m); c.rotation.z = Math.PI / 2; c.position.x = x; c.castShadow = true; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); cyl(0.03, 0.02, steel, s * 1.105); });
    bar.position.y = 0.9; return bar;
  }
  flKitPreview() {
    const F = this.FL, T = this.THREE, R = this.WB_REST;
    const WB = new T.Vector3(0, 0, -3.8), SB = new T.Vector3(5.2, 0, 0.2);
    // the board stands behind the plates, the bar waits off to the right
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); wb.rotation.y = R.ry; wb.position.copy(WB); if (this.plan) this.flDrawBoard(wb, this.plan); this.flAdd(wb);
    const bar = this.flBarGroup(); bar.position.x = SB.x; bar.position.z = SB.z; this.flAdd(bar);
    const c = F.cam, K = { P: c.position.clone(), T: c.position.clone().add(c.getWorldDirection(new T.Vector3()).multiplyScalar(6.5)) };
    const Bv = { P: WB.clone().add(new T.Vector3(...R.cam.P)), T: WB.clone().add(new T.Vector3(...R.cam.T)) };
    const Sv = { P: SB.clone().add(new T.Vector3(2.45, 1.25, 1.75)), T: SB.clone().add(new T.Vector3(0.78, 0.8, -0.08)) };
    const kitBg = new T.Color(this.flBgAlt ? this.pal.boxLight : this.pal.bgColor), wodBg = new T.Color(this.flUserBg ? this.pal.boxLight : this.pal.bgColor), mix = new T.Color();
    const tg = new T.Vector3();
    const pose = (v) => {
      // v < 0: toward the board; v > 0: toward the bar
      const a = Math.min(1, Math.abs(v)), e = a * a * (3 - 2 * a), D = v < 0 ? Bv : Sv;
      c.position.lerpVectors(K.P, D.P, e); tg.lerpVectors(K.T, D.T, e); c.lookAt(tg);
      F.ui.style.opacity = String(1 - Math.min(1, a * 2.2));
      (this.flKitItems || []).forEach((it) => it.o.scale.setScalar(Math.max(0.0001, 1 - (v < 0 ? e : 0))));
      mix.copy(kitBg).lerp(wodBg, v < 0 ? e : 0); F.L.style.backgroundColor = '#' + mix.getHexString();
    };
    let v = 0;
    const commit = (dir) => {
      F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null;
      const v0 = v, v1 = dir;
      this.flAnim((u) => { v = v0 + (v1 - v0) * (1 - Math.pow(1 - u, 3)); pose(v); }, 0.35, () => {
        F.ui.style.opacity = '';
        if (dir < 0) { this.flAgain = true; this.flFromKit = true; this.flCheckSound(); this.flGo('wod'); }
        else { this.flCheckSound(); this.flGo('sets'); }
      });
    };
    return {
      drag: (e) => {
        const sy = e.clientY; let moved = false;
        return {
          move: (ev) => { const dy = ev.clientY - sy; if (Math.abs(dy) > 6) moved = true; v = Math.max(-1, Math.min(1, -dy / 320)); pose(v); },
          up: (ev, tap) => {
            if (tap && !moved) { commit(1); return; }
            if (Math.abs(v) > 0.3) commit(v < 0 ? -1 : 1);
            else { const v0 = v; this.flAnim((u) => { v = v0 * Math.pow(1 - u, 3); pose(v); }, 0.3, () => { F.ui.style.opacity = ''; }); }
          }
        };
      }
    };
  }
  flMenuGo(it) {
    // zoom straight into the picked item, then its question
    const F = this.FL, T = this.THREE, c = F.cam, P0 = c.position.clone(), T0 = P0.clone().add(c.getWorldDirection(new T.Vector3()).multiplyScalar(7));
    const tp = it.w.position.clone().add(new T.Vector3(0, 0.75, 0)), P1 = tp.clone().add(new T.Vector3(0, 0.2, 2.3)), tg = new T.Vector3();
    F.hit = null; [...F.ui.children].forEach((el) => el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 220, fill: 'forwards' }));
    this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); c.position.lerpVectors(P0, P1, e); tg.lerpVectors(T0, tp, e); c.lookAt(tg); }, 0.5, () => { this.flDirect = true; this.flFromMenu = true; it.go(); });
  }
