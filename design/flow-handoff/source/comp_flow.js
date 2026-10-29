
  // ===================== FLOW: one question at a time, a small 3D toy under it (no gym box) =====================
  // overrides: after the opening the flow takes over, the gym never renders
  frame() {
    if (this.flKeyed) return; this.flKeyed = true;
    this.onFlKey = (e) => { if (e.target && /input|textarea/i.test(e.target.tagName)) return; if (e.key === 'w' || e.key === 'W') this.flToggleRough(); if (e.key === 'c' || e.key === 'C') this.flToggleBg(); };
    window.addEventListener('keydown', this.onFlKey);
    // on the phone: double-tap the clock for rough edges, double-tap the battery for the background
    if (this.phone) [['left', () => this.flToggleRough()], ['right', () => this.flToggleBg()]].forEach(([side, fn]) => {
      const z = document.createElement('div'); z.setAttribute('aria-hidden', 'true'); z.setAttribute('data-nopress', '');
      Object.assign(z.style, { position: 'absolute', top: 0, [side]: 0, width: '110px', height: '54px', zIndex: 60, touchAction: 'manipulation' });
      let last = 0;
      z.addEventListener('pointerup', (e) => { e.stopPropagation(); const now = performance.now(); if (now - last < 380) { last = 0; fn(); this.buzz('success'); try { this.flCheckSound(); } catch (er) {} } else last = now; });
      z.addEventListener('pointerdown', (e) => e.stopPropagation());
      z.addEventListener('click', (e) => e.stopPropagation());
      this.phone.appendChild(z);
    });
  }
  closeOpening() {
    const L = this.openL; this.openL = null;
    if (!L || L.gone) return;
    this.buzz('light');
    this.dropLayer(L);
    this.flowStart();
  }
  flowStart() {
    if (this.FL) return;
    if (!this.THREE) { setTimeout(() => { if (!this.dead) this.flowStart(); }, 100); return; }
    const T = this.THREE, P = this.phone;
    const pal = this.pal || { boxLight: '#EFE3CF', boxDark: '#4A3426', bgColor: '#E8742C' };
    this.FC = { bg: pal.bgColor, light: pal.boxLight, dark: pal.boxDark };
    const L = this.fh('div', { position: 'absolute', inset: 0, zIndex: 4, background: this.FC.bg, overflow: 'hidden', touchAction: 'none' }, P);
    L.setAttribute('data-nopress', '');
    const cv = document.createElement('canvas'); Object.assign(cv.style, { position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block' }); L.appendChild(cv);
    const R = new T.WebGLRenderer({ canvas: cv, antialias: true, alpha: true });
    R.setPixelRatio(Math.min(2, window.devicePixelRatio || 1)); R.setClearColor(0x000000, 0);
    R.outputColorSpace = T.SRGBColorSpace; R.toneMapping = T.NoToneMapping;
    const S = new T.Scene(), cam = new T.PerspectiveCamera(35, 390 / 844, 0.1, 100);
    S.add(new T.HemisphereLight(0xffffff, 0x8a7a70, 2.2));
    const sun = new T.DirectionalLight(0xffffff, 1.6); sun.position.set(2.5, 6, 4); S.add(sun);
    R.shadowMap.enabled = true; R.shadowMap.type = T.PCFSoftShadowMap; sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024);
    { const c = sun.shadow.camera; c.left = -4; c.right = 4; c.top = 4; c.bottom = -4; c.near = 0.5; c.far = 20; } sun.shadow.bias = -0.0008; this.flSun = sun;
    // the question, top and centred; then the swipe hint, an icon only
    const q = this.fh('div', { position: 'absolute', left: '28px', right: '28px', top: '92px', textAlign: 'center', color: this.FC.light, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '30px', lineHeight: 1.1, letterSpacing: '-0.01em', pointerEvents: 'none', zIndex: 3 }, L);
    q.setAttribute('aria-live', 'polite');
    const sw = this.fh('div', { position: 'absolute', left: '50%', bottom: '34px', width: '44px', height: '44px', marginLeft: '-22px', display: 'none', visibility: 'hidden', color: this.FC.light, pointerEvents: 'none', zIndex: 3 }, L);
    sw.innerHTML = '<svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 14l6-6 6 6"/></svg>';
    sw.animate([{ transform: 'translateY(4px)' }, { transform: 'translateY(-6px)' }], { duration: 900, iterations: Infinity, direction: 'alternate', easing: 'ease-in-out' });
    const ui = this.fh('div', { position: 'absolute', inset: 0, zIndex: 4, pointerEvents: 'none' }, L);
    this.FL = { L, cv, R, S, cam, q, sw, ui, objs: [], tick: null, swipe: false, words: [], t: 0 };
    const size = () => { const w = L.clientWidth || 390, h = L.clientHeight || 844; R.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); };
    size(); new ResizeObserver(size).observe(L);
    this.flBindPointer();
    let last = performance.now();
    const loop = (now) => {
      if (this.dead) return;
      this.flRaf = requestAnimationFrame(loop);
      const dt = Math.min(0.05, (now - last) / 1000); last = now; this.FL.t += dt;
      if (this.FL.tick) this.FL.tick(dt, this.FL.t);
      this.flTween(dt); this.flDustTick(dt); this.flPhysDustTick(dt);
      const fx = this.flCamFx(dt, now / 1000), c0 = cam.position.clone(), f0 = cam.fov;
      cam.position.add(fx.off); cam.fov = fx.fov; cam.updateProjectionMatrix();
      GLFX.draw(R, S, cam, { contrast: 1, bright: 1, sketch: !this.flNoRough, skCol: this.FC.dark, skWidth: 2.2, skRough: 5, skScale: 0.03, skGrain: 0.4, skDouble: true, skWarp: 0 });
      cam.position.copy(c0); cam.fov = f0; cam.updateProjectionMatrix();
    };
    this.flRaf = requestAnimationFrame(loop);
    this.d.gyms = null;
    if (this.flBgPending) this.flToggleBg();
    this.flGo('name');
  }
  componentWillUnmount() { this.dead = true; cancelAnimationFrame(this.flRaf); cancelAnimationFrame(this.raf); }

  // ---------------- shared pieces ----------------
  // words appear one at a time, like the session-over line (260 ms apart, no motion)
  flSay(text, then) {
    const F = this.FL, q = F.q; F.words.forEach(clearTimeout); F.words = [];
    q.textContent = ''; q.setAttribute('aria-label', text);
    const ws = text.split(/\s+/).filter(Boolean);
    const spans = ws.map((w, i) => { const s = document.createElement('span'); s.textContent = w + (i < ws.length - 1 ? ' ' : ''); s.style.visibility = 'hidden'; q.appendChild(s); return s; });
    spans.forEach((s, i) => F.words.push(setTimeout(() => { if (!this.dead) s.style.visibility = 'visible'; }, i * 260)));
    F.words.push(setTimeout(() => { if (!this.dead && then) then(); }, ws.length * 260));
    return ws.length * 260;
  }
  flClear() {
    const F = this.FL;
    F.objs.forEach((o) => { F.S.remove(o); });
    F.objs = []; F.tick = null; F.drag = null; F.hit = null; F.swipe = false; F.sw.style.display = 'none'; F.ui.innerHTML = ''; F.tw = [];
    F.onSwipe = null; F.onTap = null;
    F.words.forEach(clearTimeout); F.words = []; F.q.textContent = ''; F.q.removeAttribute('aria-label');
  }
  fh(tag, css, parent, text) { const r = this.raw; this.raw = true; const e = this.h(tag, css, parent, text); this.raw = r; if (parent === this.ui) e.classList.remove('sys'); return e; }
  flAdd(o) { this.FL.S.add(o); this.FL.objs.push(o); return o; }
  flCam(P, T, fov) { const c = this.FL.cam; c.position.set(P[0], P[1], P[2]); c.fov = fov || 35; this.flFov = c.fov; c.updateProjectionMatrix(); c.lookAt(T[0], T[1], T[2]); }
  flSwipe(fn) { const F = this.FL; F.swipe = true; F.onSwipe = fn; F.onTap = () => { this.buzz('light'); fn(); }; F.sw.style.display = 'block'; }
  // tiny tween list: {o, k, from, to, d, t, ease, done}
  flAnim(fn, d, done) { (this.FL.tw = this.FL.tw || []).push({ fn, d, t: 0, done }); }
  flTween(dt) {
    const F = this.FL; if (!F.tw || !F.tw.length) return;
    F.tw = F.tw.filter((a) => { a.t += dt; const u = Math.min(1, a.t / a.d); a.fn(u); if (u >= 1) { if (a.done) a.done(); return false; } return true; });
  }
  outBack(x, k) { x = Math.min(1, Math.max(0, x)); k = k == null ? 1.8 : k; const c = k + 1; return 1 + c * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); }
  outCubic(x) { x = Math.min(1, Math.max(0, x)); return 1 - Math.pow(1 - x, 3); }
  popIn(o, delay, s1) {
    s1 = s1 || 1; o.scale.setScalar(0.0001);
    setTimeout(() => { if (this.dead) return; this.flAnim((u) => o.scale.setScalar(Math.max(0.0001, s1 * this.outBack(u, 1.7))), 0.5); }, delay || 0);
  }
  toon(hex) {
    const T = this.THREE;
    if (!this.flRamp) { const d = new Uint8Array([90, 90, 90, 255, 175, 175, 175, 255, 255, 255, 255, 255]); const tx = new T.DataTexture(d, 3, 1, T.RGBAFormat); tx.minFilter = tx.magFilter = T.NearestFilter; tx.needsUpdate = true; this.flRamp = tx; }
    return new T.MeshToonMaterial({ color: hex, gradientMap: this.flRamp });
  }
  textTex(txt, opts) {
    const o = opts || {}, T = this.THREE, c = document.createElement('canvas'), W = o.w || 256, H = o.h || 256;
    c.width = W; c.height = H; const x = c.getContext('2d');
    if (o.bg) { x.fillStyle = o.bg; x.fillRect(0, 0, W, H); }
    x.fillStyle = o.col || this.FC.light; x.textAlign = 'center'; x.textBaseline = 'middle';
    x.font = (o.weight || 900) + ' ' + (o.size || 190) + "px 'Space Grotesk', Arial, sans-serif";
    x.fillText(txt, W / 2, H / 2 + (o.dy || 8));
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; t.anisotropy = 4; return t;
  }
  flRay(e) {
    const F = this.FL, r = F.cv.getBoundingClientRect(), T = this.THREE;
    const v = new T.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    const rc = this.flRc || (this.flRc = new T.Raycaster()); rc.setFromCamera(v, F.cam); return rc;
  }
  flPlane(e, n, c) { const T = this.THREE, rc = this.flRay(e), p = new T.Vector3(); return rc.ray.intersectPlane(new T.Plane(n, c), p) ? p : null; }
  flBindPointer() {
    const F = this.FL, L = F.L;
    L.addEventListener('pointerdown', (e) => {
      if (e.target.closest && e.target.closest('button')) return;
      F.down = { x: e.clientX, y: e.clientY, t: performance.now(), obj: false };
      if (F.hit) { const h = F.hit(e); if (h) { F.down.obj = true; F.drag = h; try { L.setPointerCapture(e.pointerId); } catch (er) {} } }
    });
    L.addEventListener('pointermove', (e) => { if (F.drag && F.drag.move) F.drag.move(e); });
    const up = (e) => {
      const d = F.down; F.down = null; if (!d) return;
      const dx = e.clientX - d.x, dy = e.clientY - d.y, tap = Math.hypot(dx, dy) < 8 && performance.now() - d.t < 450;
      if (F.drag) { const g = F.drag; F.drag = null; if (g.up) g.up(e, tap); return; }
      if (F.swipe && dy < -55 && Math.abs(dx) < Math.abs(dy) && F.onSwipe) { this.buzz('light'); F.onSwipe(); return; }
      if (dy > 55 && Math.abs(dx) < Math.abs(dy) && F.onSwipeDown) { this.buzz('light'); F.onSwipeDown(); return; }
      if (tap && F.onTap) F.onTap(e);
    };
    L.addEventListener('pointerup', up); L.addEventListener('pointercancel', up);
  }
  flGo(step) {
    this.flClear(); this.flStep = step;
    ({ name: () => this.flName(), unit: () => this.flUnit(), plates: () => this.flPlates(), bar: () => this.flBarQ(), prs: () => this.flPRs(), prDial: () => this.flPRDial(0),
      wod: () => this.flWod(), kit: () => this.flKit(), sets: () => this.flSets() })[step]();
  }

  // ---------------- a drum: a pool of label plates on the front of a cylinder; pos is a float index ----------------
  flDrum(labels, o) {
    const T = this.THREE, n = labels.length, r = o.r || 0.95, a0 = o.a0 || 0.36, W = o.w || 0.9, wrap = o.wrap !== false;
    const g = new T.Group();
    const body = new T.Mesh(new T.CylinderGeometry(r - 0.03, r - 0.03, W, 48, 1), this.toon(this.FC.dark)); body.rotation.z = Math.PI / 2; g.add(body);
    [-1, 1].forEach((s) => { const rim = new T.Mesh(new T.CylinderGeometry(r + 0.025, r + 0.025, 0.05, 48), this.toon(this.FC.light)); rim.rotation.z = Math.PI / 2; rim.position.x = s * (W / 2 + 0.02); g.add(rim); });
    const tex = {}, texOf = (i) => tex[i] || (tex[i] = this.textTex(labels[i], { w: 256, h: 140, size: o.size || 112, col: this.FC.light, dy: 6 }));
    const K = Math.ceil(1.45 / a0) + 1, pool = [];
    for (let k = -K; k <= K; k++) {
      const m = new T.Mesh(new T.PlaneGeometry(o.lw || 0.62, a0 * r * 0.95), new T.MeshBasicMaterial({ transparent: true, depthWrite: false })); g.add(m); pool.push(m);
    }
    g.position.z = -r;
    const D = { g, n, pos: 0, vel: 0, idx: 0, lock: false, body, opacity: 1 };
    const norm = (i) => (wrap ? ((i % n) + n) % n : Math.max(0, Math.min(n - 1, i)));
    D.set = (i) => { D.pos = i; D.idx = norm(i); };
    D.layout = () => {
      const base = Math.floor(D.pos);
      pool.forEach((m, j) => {
        const li = base + j - K, th = (li - D.pos) * a0, inRange = wrap || (li >= 0 && li < n);
        m.visible = inRange && Math.abs(th) < 1.45;
        if (!m.visible) return;
        const mi = norm(li); if (m.userData.li !== mi) { m.userData.li = mi; m.material.map = texOf(mi); m.material.needsUpdate = true; }
        m.position.set(0, -r * Math.sin(th), r * Math.cos(th) + 0.004); m.rotation.x = th;
        m.material.opacity = D.opacity * Math.max(0, Math.cos(th * 1.05));
      });
    };
    D.tick = (dt, dragging) => {
      if (!dragging) {
        D.pos += D.vel * dt; D.vel *= Math.exp(-dt * 4.5);
        if (!wrap) { if (D.pos < 0) { D.pos += (0 - D.pos) * 0.3; D.vel = 0; } if (D.pos > n - 1) { D.pos += (n - 1 - D.pos) * 0.3; D.vel = 0; } }
        if (Math.abs(D.vel) < 2) D.pos += (Math.round(D.pos) - D.pos) * (1 - Math.exp(-dt * 12));
      }
      const i = norm(Math.round(D.pos));
      if (i !== D.idx) { D.idx = i; this.buzz('selection'); }
      D.layout();
    };
    D.layout();
    return D;
  }
  // drag a drum: pixels to angle, with a flick
  flDrumDrag(D, e, ppi) {
    let y0 = e.clientY, t0 = performance.now(), dragged = false;
    return {
      move: (ev) => { const dy = ev.clientY - y0, now = performance.now(); if (Math.abs(dy) > 2) dragged = true; const d = -dy / ppi; D.pos += d; D.vel = d / Math.max(0.008, (now - t0) / 1000); y0 = ev.clientY; t0 = now; D.dragging = true; },
      up: () => { D.dragging = false; if (performance.now() - t0 > 90) D.vel = 0; if (D.onTap && !dragged) D.onTap(); }
    };
  }
  // ---------------- 2 · where are you training: two dials, tap to lock each ----------------
  flName() {
    const F = this.FL, chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('');
    this.flCam([0, 0.5, 10.5], [0, -0.35, 0], 35);
    this.flSay('So, where are you training now?');
    const drums = [-0.62, 0.62].map((x, i) => {
      const D = this.flDrum(chars, { r: 0.95, a0: 0.38, w: 0.95, lw: 0.7, size: 120 }); D.g.position.x = x; D.g.position.y = -0.45; this.flAdd(D.g); this.popIn(D.g, 300 + i * 120); return D;
    });
    drums[0].set(0); drums[1].set(0);
    let cur = 0;
    const dim = () => drums.forEach((D, i) => { D.opacity = i === cur || D.lock ? 1 : 0.35; D.layout(); });
    dim();
    const lockOne = () => {
      const D = drums[cur]; D.lock = true; this.buzz('light');
      const g = D.g, y0 = g.position.y; this.flAnim((u) => { g.position.y = y0 - 0.08 * Math.sin(u * Math.PI); }, 0.25);
      cur++; dim();
      if (cur >= 2) {
        this.d.name = chars[drums[0].idx] + chars[drums[1].idx];
        setTimeout(() => { if (!this.dead && this.flStep === 'name') this.flGo('unit'); }, 650);
      }
    };
    drums.forEach((D, i) => { D.onTap = () => { if (i === cur && !D.lock) lockOne(); }; });
    F.hit = (e) => {
      const rc = this.flRay(e), D = drums[cur]; if (!D) return null;
      if (!rc.intersectObject(D.g, true).length) { const o = drums.find((q) => !q.lock && rc.intersectObject(q.g, true).length); return null; }
      return this.flDrumDrag(D, e, 46);
    };
    F.tick = (dt) => drums.forEach((D) => D.tick(dt, !!D.dragging));
  }

  // ---------------- 3 · kilos or pounds: drag a kettlebell into the square ----------------
  kettlebell(label) {
    const T = this.THREE, g = new T.Group(), M = this.toon(this.FC.dark);
    const body = new T.Mesh(new T.SphereGeometry(0.42, 32, 24), M); body.scale.set(1, 0.92, 1); body.position.y = 0.42; g.add(body);
    const base = new T.Mesh(new T.CylinderGeometry(0.26, 0.28, 0.05, 32), M); base.position.y = 0.04; g.add(base);
    const handle = new T.Mesh(new T.TorusGeometry(0.24, 0.055, 14, 40, Math.PI), M); handle.position.y = 0.78; g.add(handle);
    [-1, 1].forEach((s) => { const h = new T.Mesh(new T.CylinderGeometry(0.055, 0.06, 0.16, 14), M); h.position.set(s * 0.24, 0.72, 0); g.add(h); });
    const lab = new T.Mesh(new T.PlaneGeometry(0.5, 0.32), new T.MeshBasicMaterial({ map: this.textTex(label, { w: 256, h: 160, size: 120, col: this.FC.light }), transparent: true }));
    lab.position.set(0, 0.42, 0.43); g.add(lab);
    g.userData.label = label; return g;
  }
  flUnit() {
    const F = this.FL, T = this.THREE, name = this.d.name || '79';
    this.flCam([0, 6.2, 10.4], [0, -0.35, 0.45], 35);
    this.flSay('Cool. Let’s set ' + name + '. Do they use kilos or pounds there?');
    // the square on the floor, near us
    const sq = new T.Group(), SZ = 1.25, th = 0.05, SQ = [0, 1.55];
    const Ml = new T.MeshBasicMaterial({ color: this.FC.light });
    [[0, -SZ / 2, SZ + th, th], [0, SZ / 2, SZ + th, th], [-SZ / 2, 0, th, SZ], [SZ / 2, 0, th, SZ]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.01, d), Ml); m.position.set(x, 0.005, z); sq.add(m); });
    sq.position.set(SQ[0], 0, SQ[1]); this.flAdd(sq); this.popIn(sq, 900);
    // a soft floor shadow per bell
    const shadow = () => { const m = new T.Mesh(new T.CircleGeometry(0.4, 32), new T.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.16 })); m.rotation.x = -Math.PI / 2; m.position.y = 0.002; return m; };
    const bells = [['KG', 'kg', -0.95], ['LB', 'lb', 0.95]].map(([lab, u, x], i) => {
      const g = this.kettlebell(lab), sh = shadow(); g.position.set(x, 0, -0.55); sh.position.set(x, 0.002, -0.55);
      this.flAdd(g); this.flAdd(sh); this.popIn(g, 600 + i * 140);
      return { g, sh, u, home: new T.Vector3(x, 0, -0.55) };
    });
    let done = false;
    F.hit = (e) => {
      if (done) return null;
      const rc = this.flRay(e), b = bells.find((q) => rc.intersectObject(q.g, true).length); if (!b) return null;
      this.buzz('selection');
      const GY = -0.42, off = new T.Vector3(); { const p = this.flPlane(e, new T.Vector3(0, 1, 0), GY); if (p) off.copy(b.g.position).sub(p); off.y = 0; }   // drag on the plane at the grab height, so the bell stays under the finger
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 1, 0), GY); if (!p) return; const x = p.x + off.x, z = p.z + off.z; b.g.position.set(x, 0.28, z); b.sh.position.set(x, 0.002, z); b.g.rotation.z = Math.max(-0.25, Math.min(0.25, (x - b.lx || 0) * -1.5)); b.lx = x; },
        up: () => {
          const p = b.g.position, inside = Math.abs(p.x - SQ[0]) < SZ / 2 && Math.abs(p.z - SQ[1]) < SZ / 2;
          const from = p.clone(), to = inside ? new T.Vector3(SQ[0], 0, SQ[1]) : b.home.clone(), r0 = b.g.rotation.z;
          if (inside) done = true;
          this.flAnim((u) => { const e2 = this.outCubic(u); b.g.position.lerpVectors(from, to, e2); b.g.position.y = from.y * (1 - e2); b.sh.position.set(b.g.position.x, 0.002, b.g.position.z); b.g.rotation.z = r0 * (1 - e2); }, 0.32, () => {
            if (!inside) return;
            this.buzz('success');
            const g = b.g; this.flAnim((u) => { const s = 1 + 0.12 * Math.sin(u * Math.PI) * (1 - u); g.scale.set(1 + (s - 1) * 0.6, 1 - (s - 1), 1 + (s - 1) * 0.6); }, 0.35);
            this.setUnit(b.u);
            setTimeout(() => { if (!this.dead && this.flStep === 'unit') this.flGo('plates'); }, 900);
          });
        }
      };
    };
  }

  // ---------------- 4 · which plates: drag the missing ones out of the circle ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs(), n = specs.length, own = this.own();
    this.flCam([0, 0.4, 10.2], [0, 0.0, 0], 35);
    this.flSay('What are the plates available?');
    const C = new T.Vector3(0, 0.05, 0), RR = 1.0;
    const gray = new T.MeshBasicMaterial({ color: 0x9a9690, transparent: true, opacity: 0.32, depthWrite: false });
    const items = specs.map((sp, i) => {
      const a = Math.PI / 2 - i * Math.PI * 2 / n, slot = new T.Vector3(C.x + Math.cos(a) * RR, C.y + Math.sin(a) * RR, 0);
      const g = this.plate(sp), k = 1.2 + 1.7 * (0.45 - sp.d);   // bigger than life; the small change plates more so, so they read
      const w = new T.Group(); w.add(g); g.rotation.x = Math.PI / 2; w.position.copy(slot); this.flAdd(w); this.popIn(w, 700 + i * 70, k);
      const meshes = []; g.traverse((m) => { if (m.isMesh) { m.userData.m0 = m.material; meshes.push(m); } });
      const it = { sp, w, slot, k, meshes, on: own.indexOf(sp.kg) >= 0 };
      it.paint = () => it.meshes.forEach((m) => { m.material = it.on ? m.userData.m0 : gray; });
      if (!it.on) { w.position.copy(slot).sub(C).multiplyScalar(1.55).add(C); }
      it.paint(); return it;
    });
    const sync = () => { this.d.own[this.d.unit] = items.filter((q) => q.on).map((q) => q.sp.kg); };
    F.hit = (e) => {
      const rc = this.flRay(e); let hit = null, bd = 1e9;   // a disc test, so the hole in the middle still grabs the plate
      items.forEach((q) => { const d = rc.ray.distanceToPoint(q.w.position), R = q.sp.d / 2 * q.w.scale.x * 1.15; if (d < R && d < bd) { bd = d; hit = q; } }); if (!hit) return null;
      this.buzz('selection');
      const z0 = new T.Plane(new T.Vector3(0, 0, 1), 0), p0 = new T.Vector3(); rc.ray.intersectPlane(z0, p0);
      const off = hit.w.position.clone().sub(p0); off.z = 0;
      const sc0 = hit.w.scale.x; this.flAnim((u) => hit.w.scale.setScalar(sc0 * (1 + 0.12 * this.outCubic(u))), 0.15);
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 0, 1), 0); if (!p) return; hit.w.position.set(p.x + off.x, p.y + off.y, 0.35); hit.w.rotation.z = Math.sin(performance.now() / 120) * 0.04;
          const out = hit.w.position.clone().setZ(0).distanceTo(C) > RR + 0.42; if (out === hit.on) { hit.on = !out; hit.paint(); this.buzz('light'); } },
        up: () => {
          const from = hit.w.position.clone(), out = from.clone().setZ(0).distanceTo(C) > RR + 0.42;
          hit.on = !out; hit.paint(); sync();
          let to;
          if (out) { const v = from.clone().setZ(0).sub(C); const len = Math.min(Math.max(v.length(), RR + 0.6), 2.25); to = C.clone().add(v.setLength(len)); to.x = Math.max(-1.5, Math.min(1.5, to.x)); to.y = Math.max(-1.9, Math.min(2.2, to.y)); }
          else to = hit.slot.clone();
          this.flAnim((u) => { const e2 = this.outCubic(u); hit.w.position.lerpVectors(from, to, e2); hit.w.rotation.z *= 0.8; hit.w.scale.setScalar(hit.k * (1.12 - 0.12 * e2)); }, 0.3);
        }
      };
    };
    F.tick = (dt, t) => items.forEach((q, i) => { if (F.drag && F.drag.it === q) return; q.w.children[0].rotation.y = Math.sin(t * 0.8 + i) * 0.12; });
    setTimeout(() => { if (!this.dead && this.flStep === 'plates') { this.flSwipe(() => { sync(); this.flGo('bar'); }); F.onTap = null; } }, 1200);   // taps here are for dragging plates, so only a swipe moves on
  }

  // ---------------- 5 · PRs: upload, take a photo, or dial them in ----------------
  flIcons(list) {
    const F = this.FL, row = this.fh('div', { position: 'absolute', left: 0, right: 0, top: '50%', transform: 'translateY(-50%)', display: 'flex', justifyContent: 'center', gap: '22px', pointerEvents: 'auto' }, F.ui);
    const ICON = {
      photo: '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-9 9"/>',
      camera: '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.6"/>',
      dial: '<rect x="6" y="3" width="12" height="18" rx="3"/><path d="M9 8l3-3 3 3M9 16l3 3 3-3"/><path d="M9.5 12h5"/>'
    };
    list.forEach(([k, label, fn], i) => {
      const b = this.fh('button', { width: '84px', height: '84px', borderRadius: '42px', border: 0, background: this.FC.light, color: this.FC.dark, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', boxShadow: '0 6px 0 ' + this.FC.dark }, row);
      b.setAttribute('aria-label', label); b.className = 'tap';
      b.innerHTML = '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[k] + '</svg>';
      b.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: 450, delay: 500 + i * 110, easing: 'cubic-bezier(.3,1.5,.5,1)', fill: 'backwards' });
      b.onclick = () => { this.buzz('light'); fn(); };
    });
  }
  flPRs() {
    this.flCam([0, 0, 7], [0, 0, 0], 35);
    this.flSay('Alright. And what are your PRs?');
    const fill = () => { this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); };
    this.flIcons([
      ['photo', 'Upload a screenshot', () => this.photoPicker('pr', () => { this.closeSheet(); this.reading('Reading your PRs…', () => { fill(); this.flGo('wod'); }); }, () => {})],
      ['camera', 'Take a photo', () => this.scanner({ title: 'Scan your PRs', onCancel: () => {}, onCapture: () => { fill(); this.flGo('wod'); }, draw: (x) => {
        x.fillStyle = '#F4EFE2'; x.fillRect(0, 0, 780, 1000);
        x.strokeStyle = 'rgba(60,90,160,0.25)'; x.lineWidth = 2; for (let y = 120; y < 1000; y += 70) { x.beginPath(); x.moveTo(0, y); x.lineTo(780, y); x.stroke(); }
        x.fillStyle = '#222'; x.font = '58px "Permanent Marker", cursive'; x.fillText('PRs', 60, 100);
        x.font = '46px "Permanent Marker", cursive';
        this.d.prs.forEach((q, i) => x.fillText(q[0] + ' ' + this.fmt(this.demoPR(q)), 60, 245 + i * 140));
        return { count: this.d.prs.length, top: 19.5, gap: 14, h: 6, widths: this.d.prs.map((q) => Math.min(88, 18 + (q[0].length + 4) * 3.4)) };
      } })],
      ['dial', 'Dial them in', () => this.flGo('prDial')]
    ]);
  }
  // one lift at a time: the question is the lift, one big number dial, swipe up for the next
  flPRDial(i) {
    this.flClear(); this.flStep = 'prDial';
    const F = this.FL, lifts = this.d.prs, q = lifts[i], u = this.d.unit, stp = u === 'lb' ? 5 : 2.5, max = u === 'lb' ? 700 : 320;
    const vals = []; for (let v = 0; v <= max; v += stp) vals.push(v);
    this.flCam([0, 0.2, 9.5], [0, -0.25, 0], 35);
    this.flSay(q[0] + '?');
    const labels = vals.map((v) => this.fmt(v));
    const D = this.flDrum(labels, { r: 1.05, a0: 0.33, w: 1.5, lw: 1.35, size: 112, wrap: false });
    D.g.position.y = -0.2; this.flAdd(D.g); this.popIn(D.g, 250);
    // the reading line: a small cream notch each side of the dial
    [-1, 1].forEach((s) => { const m = new this.THREE.Mesh(new this.THREE.ConeGeometry(0.09, 0.2, 3), new this.THREE.MeshBasicMaterial({ color: this.FC.light })); m.rotation.z = s * Math.PI / 2; m.position.set(s * 0.98, -0.2, 0.05); this.flAdd(m); this.popIn(m, 400); });
    const start = q[1] != null ? q[1] : this.demoPR(q); D.set(Math.max(0, Math.round(start / stp)));
    const unit = this.fh('div', { position: 'absolute', right: '34px', top: 'calc(50% + 8px)', color: this.FC.light, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '22px' }, F.ui, u);
    unit.setAttribute('aria-hidden', 'true');
    F.hit = (e) => (this.flRay(e).intersectObject(D.g, true).length ? this.flDrumDrag(D, e, 40) : null);
    F.tick = (dt) => D.tick(dt, !!D.dragging);
    setTimeout(() => { if (!this.dead && this.flStep === 'prDial') this.flSwipe(() => {
      q[1] = vals[D.idx];
      if (i + 1 < lifts.length) this.flPRDial(i + 1); else this.flGo('wod');
    }); }, 500);
  }

  // ---------------- 6 · today's workout: upload or take a photo ----------------
  flWod() {
    this.flCam([0, 0, 7], [0, 0, 0], 35);
    this.flSay(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?');
    const go = () => { this.plan = this.workoutPlan(); this.setIdx = 0; this.doneSets = []; this.d.kitGot = {}; this.flGo('kit'); };
    this.flIcons([
      ['photo', 'Upload a screenshot', () => this.photoPicker('wod', () => { this.closeSheet(); this.reading('Reading your workout…', go); }, () => {})],
      ['camera', 'Take a photo', () => this.scanner({ title: 'Scan the workout', onCancel: () => {}, onCapture: go, draw: (x) => {
        const gr = x.createLinearGradient(0, 0, 780, 1000); gr.addColorStop(0, '#E9E6DF'); gr.addColorStop(1, '#CFCAC0'); x.fillStyle = gr; x.fillRect(0, 0, 780, 1000);
        x.fillStyle = '#B9B3A8'; x.fillRect(0, 0, 780, 30); x.fillRect(0, 970, 780, 30);
        x.fillStyle = '#1F3A73'; x.font = '64px "Permanent Marker", cursive'; x.fillText('WOD', 60, 150);
        x.font = '52px "Permanent Marker", cursive';
        this.d.wod.forEach((w, i) => { x.fillText(w.lift, 60, 300 + i * 200); x.fillText(w.sets + 'x' + w.reps + ' @ ' + w.pct + '%', 100, 370 + i * 200); });
        return { count: this.d.wod.length, top: 26, gap: 20, h: 14, widths: this.d.wod.map(() => 70) };
      } })]
    ]);
  }

  // ---------------- the bottom card (kit and sets), in the opening's colours ----------------
  flCard() {
    const F = this.FL, c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px', borderRadius: '22px', background: this.FC.light, color: this.FC.dark, fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 8px 0 ' + this.FC.dark }, F.ui);
    c.animate([{ transform: 'translateY(120%)' }, { transform: 'none' }], { duration: 420, easing: 'cubic-bezier(.2,.9,.25,1)' });
    return c;
  }
  flBtn(parent, label, fn) {
    const b = this.fh('button', { width: '100%', height: '56px', border: 0, borderRadius: '16px', background: this.FC.dark, color: this.FC.light, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '19px', cursor: 'pointer' }, parent, label);
    b.className = 'tap'; b.onclick = () => { this.buzz('light'); fn(); }; return b;
  }

  // ---------------- 7 · the plate kit: the plates drop in, one pile each ----------------
  flKit(mid) {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flCam([0, 5.0, 5.0], [0, -1.15, -0.75], 35);
    const sp = this.specs(), kit = P.kit, n = kit.length, cols = Math.min(3, Math.max(1, n)), rows = Math.ceil(n / cols), gx = 0.62, gz = 0.62;
    kit.forEach((k, i) => {
      const s = sp.find((q) => q.kg === k.w); if (!s) return;
      const cx = (i % cols - (cols - 1) / 2) * gx, cz = (Math.floor(i / cols) - (rows - 1) / 2) * gz - 0.45;
      for (let j = 0; j < k.qty; j++) {
        const g = this.plate(s); const w = new T.Group(); w.add(g); w.position.set(cx, s.t / 2 + j * (s.t + 0.004), cz); g.rotation.y = Math.random() * 6.28;
        w.visible = false; this.flAdd(w);
        const y1 = w.position.y, delay = 250 + i * 160 + j * 70;
        setTimeout(() => { if (this.dead || this.flStep !== 'kit') return; w.visible = true; this.flAnim((u) => { const b = u < 0.7 ? (u / 0.7) * (u / 0.7) : 1 - 0.25 * Math.sin((u - 0.7) / 0.3 * Math.PI); w.position.y = y1 + (1 - Math.min(1, b)) * 2.4; }, 0.55, () => { if (j === k.qty - 1) this.buzz('light'); }); }, delay);
      }
    });
    const c = this.flCard(), got = this.d.kitGot = this.d.kitGot || {};
    const wrap = this.fh('div', { display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '14px' }, c);
    kit.forEach((k) => {
      const s = sp.find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
      const b = this.fh('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', borderRadius: '999px', border: '2px solid ' + this.FC.dark, fontFamily: 'inherit', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }, wrap);
      b.className = 'tap'; b.setAttribute('role', 'checkbox');
      const dot = this.fh('span', { width: Math.round(10 + s.d * 14) + 'px', height: Math.round(10 + s.d * 14) + 'px', borderRadius: '50%', background: s.color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.2)' }, b);
      this.fh('span', {}, b, k.qty + ' × ' + this.fmt(k.w) + ' ' + P.unit);
      const paint = () => { const on = !!got[k.w]; b.style.background = on ? this.FC.dark : 'transparent'; b.style.color = on ? this.FC.light : this.FC.dark; b.setAttribute('aria-checked', String(on)); };
      paint(); b.onclick = () => { if (got[k.w]) delete got[k.w]; else { got[k.w] = true; this.buzz('light'); } paint(); };
    });
    this.flBtn(c, mid ? 'Back to the set' : 'Start session', () => this.flGo('sets'));
  }

  // ---------------- 8 · set by set: the bar, the plates sliding on, one Done ----------------
  flSets() {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flCam([3.3, 2.5, 6.6], [-0.05, -0.05, 0], 35);
    // the bar: shaft, collars, sleeves; a soft shadow under it
    const bar = new T.Group(), steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 24), m); c.rotation.z = Math.PI / 2; c.position.x = x; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); });
    this.flAdd(bar);
    this.flBar = { bar, on: [], side: [], y: 0.9 };
    const floorY = () => (this.liftOnFloor(this.setIdx) ? 0.225 : 0.9);
    bar.position.y = floorY(); this.flBar.y = bar.position.y;
    F.tick = (dt) => {
      const B = this.flBar, goal = floorY(); B.y += (goal - B.y) * (1 - Math.exp(-dt * 6)); bar.position.y = B.y;
      B.on.forEach((m) => {
        m.t += dt;
        if (m.out) { const q = Math.min(1, m.t / 0.3); m.o.position.x = m.x + m.sg * 0.9 * q * q; m.o.position.y = B.y - 0.8 * Math.max(0, q - 0.5); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.6) / 0.4)); if (q >= 1) { F.S.remove(m.o); m.gone = true; } return; }
        const q = Math.min(1, Math.max(0, (m.t - m.dl) / 0.34)); m.o.visible = m.t >= m.dl;
        m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * this.outCubic(q); m.o.position.y = B.y;
        if (q >= 1 && !m.seat) { m.seat = true; this.buzz('light'); }
      });
      B.on = B.on.filter((m) => !m.gone);
    };
    this.flLoad(this.setIdx);
    this.flSetCard();
  }
  flLoad(i) {
    const B = this.flBar, T = this.THREE, x = this.plan.flat[i], sp = this.specs(), next = x.side.slice(), prev = B.side;
    let c = 0; while (c < prev.length && c < next.length && prev[c] === next[c]) c++;
    B.on.forEach((m) => { if (!m.out && m.k >= c) { m.out = true; m.t = 0; } });
    let cum = 0;
    next.forEach((w, k) => {
      const s = sp.find((q) => q.kg === w); if (!s) return;
      const xp = 0.695 + cum + s.t / 2; cum += s.t + 0.002;
      if (k < c) return;
      [-1, 1].forEach((sg) => {
        const g = this.plate(s), o = new T.Group(); o.add(g); g.rotation.set(Math.random() * 6.28, 0, Math.PI / 2); o.position.set(sg * 1.5, B.y, 0); o.visible = false;
        this.FL.S.add(o); this.FL.objs.push(o);
        B.on.push({ o, sg, k, x: sg * xp, t: 0, dl: 0.15 + (k - c) * 0.18 + (sg > 0 ? 0.05 : 0) });
      });
    });
    B.side = next;
  }
  flSetCard() {
    const F = this.FL, P = this.plan, i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    F.ui.innerHTML = '';
    const c = this.flCard();
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', opacity: 0.75 }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 10px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px', marginBottom: '14px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? this.FC.dark : 'rgba(0,0,0,0.12)' }, dots); });
    this.flBtn(c, 'Done', () => this.flCheck());
    const pl = this.fh('button', { position: 'absolute', right: '16px', top: '64px', display: 'flex', alignItems: 'center', gap: '6px', height: '38px', padding: '0 14px', border: 0, borderRadius: '19px', background: this.FC.light, color: this.FC.dark, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '15px', cursor: 'pointer', pointerEvents: 'auto' }, F.ui);
    pl.className = 'tap'; pl.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></svg>Plates';
    pl.setAttribute('aria-label', 'See the plate kit'); pl.onclick = () => { this.buzz('light'); this.flClear(); this.flStep = 'kit'; this.flKit(true); };
  }
  flCheck() {
    const P = this.plan, n = P.flat.length, i = this.setIdx;
    this.doneSets[i] = true; this.buzz('success');
    if (this.doneSets.filter(Boolean).length >= n) { this.flFinish(); return; }
    let j = i + 1; while (j < n && this.doneSets[j]) j++;
    if (j >= n) { j = 0; while (j < n && this.doneSets[j]) j++; }
    this.setIdx = j; this.flSetCard(); setTimeout(() => { if (!this.dead && this.flBar) this.flLoad(j); }, 300);
  }
  flFinish() {
    this.FL.ui.innerHTML = '';
    setTimeout(() => { if (!this.dead) this.showSessionOver(); }, 500);
  }
  // after the scale: back to "what are we doing today?"
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light'); this.dropLayer(L);
    this.plan = null; this.flBar = null; this.flAgain = true; this.flGo('wod');
  }
