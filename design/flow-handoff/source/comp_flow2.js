
  // ===================== FLOW, round 2 (these override the first versions above) =====================
  flClear() {
    const F = this.FL;
    F.objs.forEach((o) => { F.S.remove(o); });
    F.objs = []; F.tick = null; F.drag = null; F.hit = null; F.swipe = false; F.sw.style.display = 'none'; F.sw.style.bottom = '34px'; F.ui.innerHTML = ''; F.tw = []; F.grab = null;
    F.onSwipe = null; F.onTap = null;
    F.words.forEach(clearTimeout); F.words = []; F.q.textContent = ''; F.q.removeAttribute('aria-label');
    (this.flDusts || []).forEach((d) => F.S.remove(d.m)); this.flDusts = [];
    this.flWorld = null; (this.flTimers || []).forEach(clearTimeout); this.flTimers = [];
  }
  flLater(fn, ms) { const t = setTimeout(() => { if (!this.dead) fn(); }, ms); (this.flTimers = this.flTimers || []).push(t); return t; }

  // ---------------- sound: a short mechanical click (dials, sliders), a thud (drops) ----------------
  flAudio() {
    if (this.flAC) return this.flAC;
    try { const AC = window.AudioContext || window.webkitAudioContext; if (AC) this.flAC = new AC(); } catch (e) {}
    if (this.flAC && !this.flNoise) {
      const n = Math.floor(this.flAC.sampleRate * 0.05), b = this.flAC.createBuffer(1, n, this.flAC.sampleRate), d = b.getChannelData(0);
      for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / n, 6);
      this.flNoise = b;
    }
    return this.flAC;
  }
  flClick(pitch) {
    const ac = this.flAudio(); if (!ac || !this.flNoise) return;
    if (ac.state === 'suspended') { try { ac.resume(); } catch (e) {} }
    const now = ac.currentTime; if (this.flLastClick && now - this.flLastClick < 0.025) return; this.flLastClick = now;
    const src = ac.createBufferSource(); src.buffer = this.flNoise; src.playbackRate.value = 0.9 + Math.random() * 0.2;
    const bp = ac.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 2400 * (pitch || 1); bp.Q.value = 3.5;
    const g = ac.createGain(); g.gain.setValueAtTime(0.55, now); g.gain.exponentialRampToValueAtTime(0.001, now + 0.045);
    src.connect(bp).connect(g).connect(ac.destination); src.start(now); src.stop(now + 0.06);
    // a little wooden body under the click
    const o = ac.createOscillator(), og = ac.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(420 * (pitch || 1), now); o.frequency.exponentialRampToValueAtTime(180, now + 0.04);
    og.gain.setValueAtTime(0.12, now); og.gain.exponentialRampToValueAtTime(0.001, now + 0.05); o.connect(og).connect(ac.destination); o.start(now); o.stop(now + 0.06);
  }
  flThud(k) {
    const ac = this.flAudio(); if (!ac) return; if (ac.state === 'suspended') { try { ac.resume(); } catch (e) {} }
    const now = ac.currentTime, a = Math.min(1, k || 0.6);
    const o = ac.createOscillator(), g = ac.createGain(); o.type = 'sine'; o.frequency.setValueAtTime(120, now); o.frequency.exponentialRampToValueAtTime(42, now + 0.25);
    g.gain.setValueAtTime(0.7 * a, now); g.gain.exponentialRampToValueAtTime(0.001, now + 0.3); o.connect(g).connect(ac.destination); o.start(now); o.stop(now + 0.32);
    if (this.flNoise) { const s = ac.createBufferSource(); s.buffer = this.flNoise; const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 900; const sg = ac.createGain(); sg.gain.setValueAtTime(0.5 * a, now); sg.gain.exponentialRampToValueAtTime(0.001, now + 0.12); s.connect(lp).connect(sg).connect(ac.destination); s.start(now); }
  }

  // ---------------- dust: low-poly puffs that roll out and shrink ----------------
  flDust(x, y, z, count, power, size) {
    const T = this.THREE, F = this.FL; this.flDusts = this.flDusts || [];
    const M = this.flDustMat || (this.flDustMat = this.toon(this.FC.light));
    const G = this.flDustGeo || (this.flDustGeo = new T.IcosahedronGeometry(1, 0));
    for (let i = 0; i < count; i++) {
      const m = new T.Mesh(G, M), a = Math.random() * Math.PI * 2, sp = (0.6 + Math.random()) * power;
      m.position.set(x + Math.cos(a) * 0.15, y + 0.03, z + Math.sin(a) * 0.15); m.rotation.set(Math.random() * 3, Math.random() * 3, 0);
      const s = (0.03 + Math.random() * 0.05) * (0.7 + power * 0.4) * (size || 1); m.scale.setScalar(s); F.S.add(m);
      this.flDusts.push({ m, v: new T.Vector3(Math.cos(a) * sp, 0.5 + Math.random() * 1.1 * power, Math.sin(a) * sp), life: 0, max: 0.55 + Math.random() * 0.4, s });
    }
  }
  flDustTick(dt) {
    if (!this.flDusts || !this.flDusts.length) return;
    const F = this.FL;
    this.flDusts = this.flDusts.filter((d) => {
      d.life += dt; const u = d.life / d.max; if (u >= 1) { F.S.remove(d.m); return false; }
      d.v.multiplyScalar(Math.exp(-dt * 3.2)); d.v.y -= dt * 0.8;
      d.m.position.addScaledVector(d.v, dt); if (d.m.position.y < 0.02) d.m.position.y = 0.02;
      d.m.scale.setScalar(Math.max(0.001, d.s * (1 + u * 0.8) * (1 - u * u))); d.m.rotation.x += dt * 2; return true;
    });
  }

  // ---------------- dials: low poly, a clear reading window, a click per notch ----------------
  flDrum(labels, o) {
    const T = this.THREE, n = labels.length, r = o.r || 0.95, a0 = o.a0 || 0.36, W = o.w || 0.9, wrap = o.wrap !== false;
    const g = new T.Group(), segs = 10;
    const flat = (hex) => { const m = this.toon(hex); m.flatShading = true; return m; };
    const body = new T.Mesh(new T.CylinderGeometry(r - 0.03, r - 0.03, W, segs, 1), flat(this.FC.dark)); body.rotation.z = Math.PI / 2; g.add(body);
    [-1, 1].forEach((s) => { const rim = new T.Mesh(new T.CylinderGeometry(r + 0.04, r + 0.04, 0.07, segs), flat(this.FC.light)); rim.rotation.z = Math.PI / 2; rim.position.x = s * (W / 2 + 0.03); g.add(rim); });
    // the reading window: a cream frame around the front row
    const fh = a0 * r * 1.02, fw = W + 0.14, bt = 0.035, fm = new T.MeshBasicMaterial({ color: this.FC.light }), frame = new T.Group();
    [[0, fh / 2, fw, bt], [0, -fh / 2, fw, bt], [-fw / 2, 0, bt, fh + bt], [fw / 2, 0, bt, fh + bt]].forEach(([x, y, w, h]) => { const m = new T.Mesh(new T.BoxGeometry(w, h, 0.03), fm); m.position.set(x, y, r + 0.06); frame.add(m); });
    g.add(frame);
    const tex = {}, texOf = (i) => tex[i] || (tex[i] = this.textTex(labels[i], { w: 256, h: 140, size: o.size || 112, col: this.FC.light, dy: 6 }));
    const K = Math.ceil(1.45 / a0) + 1, pool = [];
    for (let k = -K; k <= K; k++) {
      const m = new T.Mesh(new T.PlaneGeometry(o.lw || 0.62, a0 * r * 0.95), new T.MeshBasicMaterial({ transparent: true, depthWrite: false })); g.add(m); pool.push(m);
    }
    g.position.z = -r;
    const D = { g, n, pos: 0, vel: 0, idx: 0, lock: false, body, opacity: 1, frame };
    const norm = (i) => (wrap ? ((i % n) + n) % n : Math.max(0, Math.min(n - 1, i)));
    D.set = (i) => { D.pos = i; D.idx = norm(i); };
    D.layout = () => {
      const base = Math.floor(D.pos);
      pool.forEach((m, j) => {
        const li = base + j - K, th = (li - D.pos) * a0, inRange = wrap || (li >= 0 && li < n);
        m.visible = inRange && Math.abs(th) < 1.45;
        if (!m.visible) return;
        const mi = norm(li); if (m.userData.li !== mi) { m.userData.li = mi; m.material.map = texOf(mi); m.material.needsUpdate = true; }
        const front = Math.max(0, 1 - Math.abs(th) / (a0 * 0.75));     // 1 on the reading line, 0 a notch away
        m.position.set(0, -r * Math.sin(th), r * Math.cos(th) + 0.004 + front * 0.03); m.rotation.x = th;
        m.scale.setScalar(1 + 0.18 * front);
        m.material.opacity = D.opacity * (0.28 + 0.72 * front) * Math.max(0, Math.cos(th * 1.05));
      });
      frame.visible = D.opacity > 0.5;
    };
    D.tick = (dt, dragging) => {
      if (!dragging) {
        D.pos += D.vel * dt; D.vel *= Math.exp(-dt * 4.5);
        if (!wrap) { if (D.pos < 0) { D.pos += (0 - D.pos) * 0.3; D.vel = 0; } if (D.pos > n - 1) { D.pos += (n - 1 - D.pos) * 0.3; D.vel = 0; } }
        if (Math.abs(D.vel) < 2) D.pos += (Math.round(D.pos) - D.pos) * (1 - Math.exp(-dt * 12));
      }
      const i = norm(Math.round(D.pos));
      if (i !== D.idx) { D.idx = i; this.flClick(1); }
      D.layout();
    };
    D.layout();
    return D;
  }

  // ---------------- 3 · kettlebells: one solid piece, a soft shadow; the square gives under the drop ----------------
  kettlebell(label) {
    const T = this.THREE, g = new T.Group(), M = this.toon(this.FC.dark); M.flatShading = true;
    // the bell: a sphere cut flat at the bottom, closed with a disc (no ring around the foot)
    const cut = Math.PI * 0.84, body = new T.Mesh(new T.SphereGeometry(0.42, 16, 12, 0, Math.PI * 2, 0, cut), M);
    const yb = 0.42 * Math.cos(cut); body.position.y = -yb; g.add(body);
    const foot = new T.Mesh(new T.CircleGeometry(0.42 * Math.sin(cut), 16), M); foot.rotation.x = Math.PI / 2; foot.position.y = 0.001; g.add(foot);
    const top = 0.42 - yb;
    const handle = new T.Mesh(new T.TorusGeometry(0.24, 0.058, 8, 18, Math.PI), M); handle.position.y = top + 0.12; g.add(handle);
    [-1, 1].forEach((s) => { const h = new T.Mesh(new T.CylinderGeometry(0.058, 0.07, 0.2, 8), M); h.position.set(s * 0.24, top + 0.04, 0); g.add(h); });
    const lab = new T.Mesh(new T.PlaneGeometry(0.5, 0.32), new T.MeshBasicMaterial({ map: this.textTex(label, { w: 256, h: 160, size: 120, col: this.FC.light }), transparent: true }));
    lab.position.set(0, -yb, 0.43); g.add(lab);
    g.userData.label = label; return g;
  }
  softShadow(r) {
    const T = this.THREE;
    if (!this.flShadowTex) { const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d'), gr = x.createRadialGradient(64, 64, 4, 64, 64, 62); gr.addColorStop(0, 'rgba(0,0,0,0.38)'); gr.addColorStop(0.55, 'rgba(0,0,0,0.16)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = gr; x.fillRect(0, 0, 128, 128); this.flShadowTex = new T.CanvasTexture(c); }
    const m = new T.Mesh(new T.PlaneGeometry(r * 2, r * 2), new T.MeshBasicMaterial({ map: this.flShadowTex, transparent: true, depthWrite: false })); m.rotation.x = -Math.PI / 2; m.position.y = 0.003; return m;
  }
  flUnit() {
    const F = this.FL, T = this.THREE, name = this.d.name || '79';
    this.flCam([0, 6.2, 10.4], [0, -0.35, 0.45], 35);
    this.flSay('Cool. Let’s set ' + name + '. Do they use kilos or pounds there?');
    const sq = new T.Group(), SZ = 1.25, th = 0.06, SQ = [0, 1.55];
    const Ml = new T.MeshBasicMaterial({ color: this.FC.light });
    [[0, -SZ / 2, SZ + th, th], [0, SZ / 2, SZ + th, th], [-SZ / 2, 0, th, SZ], [SZ / 2, 0, th, SZ]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.02, d), Ml); m.position.set(x, 0.01, z); sq.add(m); });
    sq.position.set(SQ[0], 0, SQ[1]); this.flAdd(sq); this.popIn(sq, 900);
    const bells = [['KG', 'kg', -0.95], ['LB', 'lb', 0.95]].map(([lab, u, x], i) => {
      const g = this.kettlebell(lab), sh = this.softShadow(0.62); g.position.set(x, 0, -0.55); sh.position.set(x, 0.003, -0.55);
      this.flAdd(g); this.flAdd(sh); this.popIn(g, 600 + i * 140);
      return { g, sh, u, home: new T.Vector3(x, 0, -0.55) };
    });
    let done = false;
    const shadowAt = (b) => { b.sh.position.set(b.g.position.x, 0.003, b.g.position.z); const s = 1 + b.g.position.y * 0.5; b.sh.scale.setScalar(s); b.sh.material.opacity = 1 / (s * s); };
    F.hit = (e) => {
      if (done) return null;
      const rc = this.flRay(e), b = bells.find((q) => rc.intersectObject(q.g, true).length); if (!b) return null;
      this.buzz('selection'); this.flAudio();
      const GY = -0.42, off = new T.Vector3(); { const p = this.flPlane(e, new T.Vector3(0, 1, 0), GY); if (p) off.copy(b.g.position).sub(p); off.y = 0; }
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 1, 0), GY); if (!p) return; const x = p.x + off.x, z = p.z + off.z; b.g.position.set(x, 0.42, z); b.g.rotation.z = Math.max(-0.25, Math.min(0.25, ((x - b.lx) || 0) * -1.5)); b.lx = x; shadowAt(b); },
        up: () => {
          const p = b.g.position, inside = Math.abs(p.x - SQ[0]) < SZ / 2 && Math.abs(p.z - SQ[1]) < SZ / 2;
          const from = p.clone(), to = inside ? new T.Vector3(SQ[0], 0, SQ[1]) : b.home.clone(), r0 = b.g.rotation.z;
          if (inside) done = true;
          // it falls: accelerating, not easing in
          this.flAnim((u) => { const e2 = inside ? u * u : this.outCubic(u); b.g.position.lerpVectors(from, to, inside ? Math.min(1, u * 1.6) : e2); b.g.position.y = from.y * (1 - e2); b.g.rotation.z = r0 * (1 - e2); shadowAt(b); }, inside ? 0.26 : 0.32, () => {
            if (!inside) return;
            this.buzz('success');
            this.flImpact({ m: 16, v: 4.2, x: SQ[0], z: SQ[1], R: 0.3, target: null });
            const g = b.g; this.flAnim((u) => { const s = 1 + 0.14 * Math.sin(u * Math.PI) * (1 - u); g.scale.set(1 + (s - 1) * 0.6, 1 - (s - 1), 1 + (s - 1) * 0.6); }, 0.35);
            // the square gives a little under the weight, and settles a hair lower
            this.flAnim((u) => { sq.position.y = -0.05 * Math.sin(Math.min(1, u * 1.4) * Math.PI / 2) * (1 - 0.6 * Math.max(0, u - 0.7) / 0.3) - 0.0; g.position.y = sq.position.y; }, 0.5);
            this.setUnit(b.u);
            this.flLater(() => { if (this.flStep === 'unit') this.flGo('plates'); }, 1000);
          });
        }
      };
    };
  }

  // ---------------- 4b · which bar: a horizontal 3D slider, the pick in the middle ----------------
  barModel(w, i) {
    const T = this.THREE, g = new T.Group(), L = [1, 0.914, 0.8][i] || 1, th = [1, 0.88, 0.8][i] || 1;
    const flat = (hex) => { const m = this.toon(hex); m.flatShading = true; return m; };
    const shaft = flat('#B4BAC1'), sleeve = flat('#EDEFF1'), collar = flat('#5E6670');
    const cyl = (r, len, m, y) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 8), m); c.position.y = y; g.add(c); return c; };
    const half = 1.1 * L, sl = 0.42 * L, sr = 0.025 * th * 1.6, rr = 0.0142 * th * 1.7;
    cyl(rr, (half - sl) * 2, shaft, 0);
    [-1, 1].forEach((s) => { cyl(rr * 2.6, 0.035, collar, s * (half - sl)); cyl(sr, sl, sleeve, s * (half - sl / 2)); cyl(sr * 1.15, 0.02, collar, s * half); });
    const lab = new T.Mesh(new T.PlaneGeometry(0.62, 0.26), new T.MeshBasicMaterial({ map: this.textTex(this.fmt(w) + ' ' + this.d.unit, { w: 320, h: 130, size: 92, col: this.FC.light }), transparent: true }));
    lab.position.y = -1.55;
    const sh = this.softShadow(0.42); sh.scale.set(1, 0.55, 1); sh.position.y = -1.22;
    const wrap = new T.Group(); wrap.add(g); wrap.add(lab); wrap.add(sh); wrap.userData.bar = g;
    return wrap;
  }
  flBarQ() {
    const F = this.FL, T = this.THREE, list = this.BARS[this.d.unit], n = list.length, SP = 1.02;
    this.flCam([0, 1.05, 7.0], [0, -0.5, 0], 35);
    this.flSay('What bar do you use?');
    const bars = list.map(([w], i) => { const g = this.barModel(w, i); g.position.y = -0.3; this.flAdd(g); this.popIn(g, 350 + i * 90); return g; });
    let pos = 1, vel = 0, idx = Math.round(pos), dragging = false;
    const layout = (t) => bars.forEach((g, i) => {
      const d = i - pos, ad = Math.abs(d);
      g.position.x = d * SP;
      g.userData.bar.rotation.y = (t || 0) * 0.6 + i; g.rotation.z = -0.24;   // leaning a little
    });
    bars.forEach((g, i) => this.flLater(() => { g.userData.popped = true; }, 900 + i * 90));
    F.tick = (dt, t) => {
      if (!dragging) { pos += vel * dt; vel *= Math.exp(-dt * 5); pos = Math.max(-0.3, Math.min(n - 0.7, pos)); if (Math.abs(vel) < 1.5) pos += (Math.max(0, Math.min(n - 1, Math.round(pos))) - pos) * (1 - Math.exp(-dt * 10)); }
      const i = Math.max(0, Math.min(n - 1, Math.round(pos))); if (i !== idx) { idx = i; this.flClick(0.8); this.buzz('selection'); }
      layout(t);
    };
    const pick = () => { this.d.bar[this.d.unit] = list[idx][0]; this.flGo('prs'); };
    const ppi = 390 * SP / (F.cam.position.z * 0.2914);
    F.hit = (e) => {
      let x0 = e.clientX, y0 = e.clientY, sx = e.clientX, sy = e.clientY, t0 = performance.now(); dragging = true; this.flAudio();
      return {
        move: (ev) => { const dx = ev.clientX - x0, now = performance.now(); const d = -dx / ppi; pos += d; vel = d / Math.max(0.008, (now - t0) / 1000); x0 = ev.clientX; t0 = now; },
        up: (ev, tap) => {
          dragging = false; if (performance.now() - t0 > 90) vel = 0;
          const dx = ev.clientX - sx, dy = ev.clientY - sy;
          if (tap || (dy < -55 && Math.abs(dy) > Math.abs(dx) * 1.5)) { vel = 0; pos = idx; this.buzz('light'); pick(); }
        }
      };
    };
    this.flLater(() => { if (this.flStep === 'bar') { F.sw.style.display = 'block'; } }, 900);
  }

  // ---------------- 7 · the kit: plates fall from the sky, land with dust; you can drag and throw them ----------------
  flKit(mid) {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flStep = 'kit';
    this.flCam([0, 5.0, 5.0], [0, -1.15, -0.75], 35);
    const C = window.PlateKit.CANNON, w = new C.World({ gravity: new C.Vec3(0, -9.81, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = 14;
    const mP = new C.Material('p'), mG = new C.Material('g');
    w.addContactMaterial(new C.ContactMaterial(mP, mG, { friction: 0.5, restitution: 0.22 }));
    w.addContactMaterial(new C.ContactMaterial(mP, mP, { friction: 0.35, restitution: 0.12 }));
    const ground = new C.Body({ mass: 0, material: mG }); ground.addShape(new C.Plane()); ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0); w.addBody(ground);
    // invisible fences just outside the view, so a throw stays on screen
    [[0, -3.1, 3.2, 0.2], [0, 1.3, 3.2, 0.2], [-1.65, -0.9, 0.2, 2.6], [1.65, -0.9, 0.2, 2.6]].forEach(([x, z, hx, hz]) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(new C.Box(new C.Vec3(hx, 1.5, hz))); b.position.set(x, 1.5, z); w.addBody(b); });
    this.flWorld = w;
    // a floor that only shows shadows
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.22 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const sp = this.specs(), kit = P.kit, n = kit.length, cols = Math.min(3, Math.max(1, n)), rows = Math.ceil(n / cols), gx = 0.66, gz = 0.66, items = [];
    kit.forEach((k, i) => {
      const s = sp.find((q) => q.kg === k.w); if (!s) return;
      const cx = (i % cols - (cols - 1) / 2) * gx, cz = (Math.floor(i / cols) - (rows - 1) / 2) * gz - 0.45;
      for (let j = 0; j < k.qty; j++) {
        const g = this.plate(s), o = new T.Group(); o.add(g); g.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
        o.visible = false; this.flAdd(o);
        const R = s.d / 2, t = s.t, mass = s.unit === 'LB' ? s.kg * 0.4536 : s.kg;
        const it = { o, R, t, mass, s, landed: false };
        items.push(it);
        this.flLater(() => {
          if (this.flWorld !== w) return;
          const b = new C.Body({ mass, material: mP, linearDamping: 0.04, angularDamping: 0.08, sleepSpeedLimit: 0.08, sleepTimeLimit: 0.7 });
          b.addShape(new C.Cylinder(R, R, t, 16));
          const Ix = mass * (3 * R * R + t * t) / 12, Iy = 0.5 * mass * R * R; b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
          b.position.set(cx + (Math.random() - 0.5) * 0.05, 5 + j * 0.35 + Math.random() * 0.6, cz + (Math.random() - 0.5) * 0.05);
          b.quaternion.setFromEuler((Math.random() - 0.5) * 0.3, Math.random() * 6.28, (Math.random() - 0.5) * 0.3);
          b.velocity.set(0, -3, 0); b.angularVelocity.set((Math.random() - 0.5) * 0.8, (Math.random() - 0.5) * 1.5, (Math.random() - 0.5) * 0.8);
          b.addEventListener('collide', (e) => {
            const v = Math.abs(e.contact.getImpactVelocityAlongNormal()); if (v < 2 || it.landed) return;
            // first landing only: a small puff, a thud, a little shake
            it.landed = true;
            const f = Math.min(1, mass / 25) * Math.min(1, v / 7);
            this.flDust(b.position.x, 0, b.position.z, Math.round(3 + 7 * f), 0.35 + 0.7 * f, 0.45);
            this.flShake = Math.max(this.flShake || 0, 0.02 + 0.07 * f); this.flThud(0.25 + 0.6 * f); this.buzz('light');
          });
          w.addBody(b); it.b = b; o.visible = true;
        }, (mid ? 100 : 250) + i * 170 + j * 90);
      }
    });
    F.tick = (dt) => {
      if (this.flWorld !== w) return;
      if (F.grab && F.grab.b) { const G = F.grab, b = G.b; const v = G.to.clone().sub(new T.Vector3(b.position.x, b.position.y, b.position.z)).multiplyScalar(14); b.velocity.set(v.x, v.y, v.z); b.angularVelocity.scale(0.9, b.angularVelocity); b.wakeUp(); }
      w.step(1 / 120, dt, 8);
      items.forEach((it) => { if (!it.b) return; it.o.position.copy(it.b.position); it.o.quaternion.copy(it.b.quaternion); });
    };
    // pick a plate up: a disc test from the ray (works through the hole), then it follows the finger and can be thrown
    F.hit = (e) => {
      const rc = this.flRay(e); let hit = null, bd = 1e9;
      items.forEach((it) => { if (!it.b) return; const d = rc.ray.distanceToPoint(it.o.position); if (d < it.R * 1.1 && d < bd) { bd = d; hit = it; } });
      if (!hit) return null;
      this.buzz('selection'); this.flAudio();
      const H = 0.55, plane = new T.Plane(new T.Vector3(0, 1, 0), -H), p = new T.Vector3();
      const G = F.grab = { b: hit.b, to: new T.Vector3(hit.b.position.x, H, hit.b.position.z) };
      return {
        move: (ev) => { const r2 = this.flRay(ev); if (r2.ray.intersectPlane(plane, p)) G.to.set(Math.max(-1.45, Math.min(1.45, p.x)), H, Math.max(-2.9, Math.min(1.1, p.z))); },
        up: () => { F.grab = null; const v = hit.b.velocity; const sp2 = Math.hypot(v.x, v.z), mx = 5; if (sp2 > mx) { v.x *= mx / sp2; v.z *= mx / sp2; } }
      };
    };
    // the chips; the session starts with a swipe up or a tap
    const c = this.flCard(), got = this.d.kitGot = this.d.kitGot || {};
    const wrap = this.fh('div', { display: 'flex', flexWrap: 'wrap', gap: '8px' }, c);
    kit.forEach((k) => {
      const s = sp.find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
      const b = this.fh('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', borderRadius: '999px', border: '2px solid ' + this.FC.dark, fontFamily: 'inherit', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }, wrap);
      b.className = 'tap'; b.setAttribute('role', 'checkbox');
      this.fh('span', { width: Math.round(10 + s.d * 14) + 'px', height: Math.round(10 + s.d * 14) + 'px', borderRadius: '50%', background: s.color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.2)' }, b);
      this.fh('span', {}, b, k.qty + ' × ' + this.fmt(k.w) + ' ' + P.unit);
      const paint = () => { const on = !!got[k.w]; b.style.background = on ? this.FC.dark : 'transparent'; b.style.color = on ? this.FC.light : this.FC.dark; b.setAttribute('aria-checked', String(on)); };
      paint(); b.onclick = () => { if (got[k.w]) delete got[k.w]; else { got[k.w] = true; this.buzz('light'); } paint(); };
    });
    c.style.bottom = '84px';
    this.flLater(() => { if (this.flStep === 'kit') this.flSwipe(() => this.flGo('sets')); }, 900);
  }

  // ---------------- 8 · set by set: close on one end of the bar; white card; swipe for the next set ----------------
  flSets() {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flCam([2.05, 1.32, 1.55], [0.5, 0.86, -0.12], 40);
    const bar = new T.Group(), flat = (hex) => { const m = this.toon(hex); m.flatShading = true; return m; };
    const steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 20), m); c.rotation.z = Math.PI / 2; c.position.x = x; c.castShadow = true; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); });
    bar.position.y = 0.9; this.flAdd(bar);
    this.flBar = { bar, on: [], side: [], y: 0.9 };
    F.tick = (dt) => {
      const B = this.flBar; if (!B) return;
      B.on.forEach((m) => {
        m.t += dt;
        if (m.out) { const q = Math.min(1, m.t / 0.3); m.o.position.x = m.x + m.sg * 0.9 * q * q; m.o.position.y = B.y - 0.8 * Math.max(0, q - 0.5); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.6) / 0.4)); if (q >= 1) { F.S.remove(m.o); m.gone = true; } return; }
        const q = Math.min(1, Math.max(0, (m.t - m.dl) / 0.34)); m.o.visible = m.t >= m.dl;
        m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * this.outCubic(q); m.o.position.y = B.y;
        if (q >= 1 && !m.seat) { m.seat = true; this.flClick(0.45); this.buzz('light'); }
      });
      B.on = B.on.filter((m) => !m.gone);
    };
    this.flLoad(this.setIdx);
    this.flSetCard(0);
  }
  flSetCard(dir) {
    const F = this.FL, P = this.plan, i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    const last = this.doneSets.filter(Boolean).length >= P.flat.length - 1;
    const old = F.ui.querySelector('[data-setcard]');
    if (old) { old.removeAttribute('data-setcard'); old.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-60px)', opacity: 0 }], { duration: 260, easing: 'ease-in', fill: 'forwards' }); setTimeout(() => old.remove(), 270); }
    [...F.ui.querySelectorAll('[data-plates]')].forEach((e) => e.remove());
    const c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px 18px 18px', borderRadius: '22px', background: '#FFFFFF', color: '#000000', fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 10px 30px rgba(0,0,0,0.18)' }, F.ui);
    c.setAttribute('data-setcard', '');
    c.animate([{ transform: dir ? 'translateY(70px)' : 'translateY(120%)', opacity: dir ? 0 : 1 }, { transform: 'none', opacity: 1 }], { duration: dir ? 320 : 420, delay: dir ? 120 : 0, easing: 'cubic-bezier(.2,.9,.25,1)', fill: 'backwards' });
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'rgba(0,0,0,0.5)' }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 12px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? '#000000' : 'rgba(0,0,0,0.12)' }, dots); });
    if (last) {
      const b = this.fh('button', { width: '100%', height: '56px', marginTop: '16px', border: 0, borderRadius: '16px', background: '#000000', color: '#FFFFFF', fontFamily: 'inherit', fontWeight: 900, fontSize: '19px', cursor: 'pointer' }, c, 'End session');
      b.className = 'tap'; b.onclick = () => { this.buzz('success'); this.doneSets[this.setIdx] = true; this.flFinish(); };
    }
    const pl = this.fh('button', { position: 'absolute', right: '16px', top: '64px', display: 'flex', alignItems: 'center', gap: '6px', height: '38px', padding: '0 14px', border: 0, borderRadius: '19px', background: '#FFFFFF', color: '#000000', fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '15px', cursor: 'pointer', pointerEvents: 'auto' }, F.ui);
    pl.setAttribute('data-plates', ''); pl.className = 'tap'; pl.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></svg>Plates';
    pl.setAttribute('aria-label', 'See the plate kit'); pl.onclick = () => { this.buzz('light'); this.flClear(); this.flKit(true); };
    // the next set: swipe up (or tap); the last one ends with its button
    if (last) { F.swipe = false; F.onSwipe = null; F.onTap = null; F.sw.style.display = 'none'; }
    else this.flSwipe(() => this.flCheck());
    F.sw.style.bottom = '196px';
  }
  flCheck() {
    const P = this.plan, n = P.flat.length, i = this.setIdx;
    this.doneSets[i] = true; this.buzz('success');
    if (this.doneSets.filter(Boolean).length >= n) { this.flFinish(); return; }
    let j = i + 1; while (j < n && this.doneSets[j]) j++;
    if (j >= n) { j = 0; while (j < n && this.doneSets[j]) j++; }
    this.setIdx = j; this.flSetCard(1); this.flLater(() => { if (this.flBar) this.flLoad(j); }, 250);
  }
  flFinish() {
    const F = this.FL; F.ui.innerHTML = ''; F.swipe = false; F.onSwipe = null; F.onTap = null; F.sw.style.display = 'none'; F.sw.style.bottom = '34px';
    this.flLater(() => this.showSessionOver(), 500);
  }
