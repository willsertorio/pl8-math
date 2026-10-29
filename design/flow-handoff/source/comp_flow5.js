
  // ===================== FLOW, round 5: question first, then the toy; spoken timing; pan-down transitions =====================
  flClear() {
    const F = this.FL;
    F.objs.forEach((o) => { F.S.remove(o); });
    F.objs = []; F.tick = null; F.drag = null; F.hit = null; F.swipe = false; F.sw.style.display = 'none'; F.ui.innerHTML = ''; F.tw = []; F.grab = null;
    F.onSwipe = null; F.onTap = null; F.onSwipeDown = null;
    F.words.forEach(clearTimeout); F.words = []; F.q.getAnimations().forEach((a) => a.cancel()); F.q.textContent = ''; F.q.removeAttribute('aria-label'); F.q.style.transform = ''; F.q.style.opacity = '';
    (this.flDusts || []).forEach((d) => F.S.remove(d.m)); this.flDusts = [];
    (this.flPD || []).forEach((d) => F.S.remove(d.m)); this.flPD = [];
    (this.flSpk || []).forEach((d) => F.S.remove(d.m)); this.flSpk = [];
    this.flWorld = null; (this.flTimers || []).forEach(clearTimeout); this.flTimers = [];
    this.flOnGrab = null; this.flOnDrop = null; this.flBarIn = null;
  }
  // the sentence, said: each word fades up; longer words take a beat longer; commas pause, full stops pause more
  flSay(text, then) {
    const F = this.FL, q = F.q; F.words.forEach(clearTimeout); F.words = [];
    q.getAnimations().forEach((a) => a.cancel());
    q.textContent = ''; q.setAttribute('aria-label', text); q.style.transform = ''; q.style.opacity = '1';
    const ws = text.split(/\s+/).filter(Boolean); let t = 0;
    ws.forEach((w, i) => {
      const s = document.createElement('span'); s.textContent = w; Object.assign(s.style, { display: 'inline-block', opacity: 0, transform: 'translateY(0.28em)', filter: 'blur(3px)' }); q.appendChild(s);
      if (i < ws.length - 1) q.appendChild(document.createTextNode(' '));
      F.words.push(setTimeout(() => { if (this.dead) return; s.animate([{ opacity: 0, transform: 'translateY(0.28em)', filter: 'blur(3px)' }, { opacity: 1, transform: 'none', filter: 'blur(0px)' }], { duration: 380, easing: 'cubic-bezier(.2,.7,.2,1)', fill: 'forwards' }); }, t));
      t += 95 + 18 * w.replace(/[^\w’']/g, '').length;
      if (/[,;:]$/.test(w)) t += 230;
      if (/[.?!…]$/.test(w)) t += 420;
    });
    const total = t + 200;
    F.words.push(setTimeout(() => { if (!this.dead && then) then(); }, total));
    return total;
  }
  // per screen: kit and sets default to the light studio and smooth edges; W/C (or the corner double-taps) flip whatever the screen has
  flStyleFor(step) { return step === 'kit' || step === 'sets' ? { alt: true, smooth: true } : { alt: false, smooth: false }; }
  flApplyStyle() {
    const F = this.FL; if (!F) return;
    const base = this.flStyleFor(this.flStep), alt = base.alt !== !!this.flUserBg, smooth = base.smooth !== !!this.flUserRough;
    this.flNoRough = smooth; window.__plNoRough = smooth;
    this.flBgAlt = alt;
    const bg = alt ? this.pal.boxLight : this.pal.bgColor, ink = alt ? this.pal.boxDark : this.pal.boxLight;
    this.FC.bg = bg; F.L.style.background = bg; F.q.style.color = ink; F.sw.style.color = ink;
    const g = 'rgba(108,55,19,0.09)';
    F.L.style.backgroundImage = alt ? 'radial-gradient(ellipse at 50% 55%, rgba(255,255,255,0.55), rgba(255,255,255,0) 70%), linear-gradient(' + g + ' 1px, transparent 1px), linear-gradient(90deg, ' + g + ' 1px, transparent 1px)' : 'none';
    F.L.style.backgroundSize = alt ? '100% 100%, 26px 26px, 26px 26px' : '';
    F.L.style.backgroundPosition = alt ? 'center, center ' + (this.flGridY || 0) + 'px, center ' + (this.flGridY || 0) + 'px' : '';
  }
  flToggleBg() { this.flUserBg = !this.flUserBg; this.flApplyStyle(); }
  flToggleRough() { this.flUserRough = !this.flUserRough; if (this.FL) this.flApplyStyle(); else { this.flNoRough = !this.flNoRough; window.__plNoRough = this.flNoRough; } }
  flInk() { return this.flBgAlt ? this.pal.boxDark : this.pal.boxLight; }

  flGo(step) {
    this.flClear(); this.flStep = step; this.flApplyStyle();
    ({ name: () => this.flName(), unit: () => this.flUnit(), plates: () => this.flPlates(), bar: () => this.flBarQ(), prs: () => this.flPRs(), prDial: () => this.flPRDial(0),
      wod: () => this.flWod(), kit: () => this.flKit(), sets: () => this.flSets(), menu: () => this.flMenu() })[step]();
    // arriving from a pan: the camera settles down onto the new scene
    if (this.flPanIn) {
      this.flPanIn = false;
      const c = this.FL.cam, P1 = c.position.clone(), d = new this.THREE.Vector3(); c.getWorldDirection(d);
      const T1 = P1.clone().add(d.multiplyScalar(5)), up = 3.2;
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3), k = up * (1 - e); c.position.set(P1.x, P1.y + k, P1.z); c.lookAt(T1.x, T1.y + k, T1.z); }, 0.7);
    }
  }
  // the outro shared by every question: the camera pans down, the question lifts away, the next one comes up from below
  flPanTo(step) {
    if (this.flPanning) return; this.flPanning = true;
    const F = this.FL, c = F.cam, P0 = c.position.clone(), d = new this.THREE.Vector3(); c.getWorldDirection(d);
    const T0 = P0.clone().add(d.multiplyScalar(5)), drop = 3.6, g0 = this.flGridY || 0;
    F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null;
    F.q.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-90px)', opacity: 0 }], { duration: 520, easing: 'cubic-bezier(.5,0,.75,0)', fill: 'forwards' });
    [...F.ui.children].forEach((el) => el.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-140px)', opacity: 0 }], { duration: 520, easing: 'cubic-bezier(.5,0,.75,0)', fill: 'forwards' }));
    this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2, k = drop * e; c.position.set(P0.x, P0.y - k, P0.z); c.lookAt(T0.x, T0.y - k, T0.z); this.flGridY = g0 - 260 * e; this.flApplyStyle(); }, 0.75, () => {
      this.flPanning = false; this.flPanIn = true; this.flGridY = (this.flGridY || 0) % 26; this.flGo(step);
    });
  }
  // a quick bright reflection over whatever is passed in, then back
  flShine(objs, dur) {
    const mats = new Map();
    objs.forEach((o) => o.traverse((m) => { if (m.isMesh) (Array.isArray(m.material) ? m.material : [m.material]).forEach((mt) => { if (mt && mt.emissive && !mats.has(mt)) mats.set(mt, { c: mt.emissive.clone(), i: mt.emissiveIntensity }); }); }));
    const W = new this.THREE.Color('#FFFFFF');
    this.flAnim((u) => { const k = Math.sin(Math.min(1, u) * Math.PI) * (u < 0.35 ? 1 : 0.85); mats.forEach((o, mt) => { mt.emissive.copy(o.c).lerp(W, k * 0.45); mt.emissiveIntensity = o.i + 0.3 * k; }); }, dur || 0.7, () => mats.forEach((o, mt) => { mt.emissive.copy(o.c); mt.emissiveIntensity = o.i; }));
    this.flClick(1.6);
  }
  // little four-point twinkles around a point
  flSparkles(p, n, spread) {
    const T = this.THREE, F = this.FL; this.flSpk = this.flSpk || [];
    if (!this.flStarTex) { const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d'); x.fillStyle = '#FFFFFF'; x.beginPath(); for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4, r = i % 2 ? 7 : 31; x.lineTo(32 + Math.cos(a) * r, 32 + Math.sin(a) * r); } x.closePath(); x.fill(); this.flStarTex = new T.CanvasTexture(c); }
    for (let i = 0; i < n; i++) {
      const m = new T.Sprite(new T.SpriteMaterial({ map: this.flStarTex, transparent: true, depthWrite: false, depthTest: false }));
      m.position.set(p.x + (Math.random() - 0.5) * spread, p.y + (Math.random() - 0.3) * spread, p.z + (Math.random() - 0.5) * spread * 0.4);
      m.scale.setScalar(0.0001); F.S.add(m);
      this.flSpk.push({ m, t: -i * 0.06, max: 0.55 + Math.random() * 0.3, s: 0.12 + Math.random() * 0.14 });
    }
  }
  flSpkTick(dt) {
    if (!this.flSpk || !this.flSpk.length) return;
    const F = this.FL;
    this.flSpk = this.flSpk.filter((d) => {
      d.t += dt; if (d.t < 0) return true; const u = d.t / d.max; if (u >= 1) { F.S.remove(d.m); return false; }
      d.m.scale.setScalar(Math.max(0.0001, d.s * Math.sin(u * Math.PI))); d.m.material.rotation += dt * 3; return true;
    });
  }
  // the reveal after the question: run fn once the words are out
  flAfter(text, fn) { this.flSay(text, () => { if (!this.dead) fn(); }); }

  // ---------------- a shared physics world (the Physics canvas's tuning) with a floor that can have holes and pads ----------------
  flPhysWorld(rects) {
    const PH = this.PHYS, C = window.PlateKit.CANNON, F = this.FL;
    const w = new C.World({ gravity: new C.Vec3(0, -PH.gravity, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = PH.iterations; w.solver.tolerance = PH.tolerance;
    const mP = new C.Material('plate'), mG = new C.Material('ground');
    w.addContactMaterial(new C.ContactMaterial(mP, mG, PH.pg)); w.addContactMaterial(new C.ContactMaterial(mP, mP, PH.pp));
    const grounds = [], box = (x0, x1, z0, z1, top, depth) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(new C.Box(new C.Vec3((x1 - x0) / 2, (depth || 0.5) / 2, (z1 - z0) / 2))); b.position.set((x0 + x1) / 2, top - (depth || 0.5) / 2, (z0 + z1) / 2); w.addBody(b); grounds.push(b); return b; };
    // the floor: a big slab, cut around the hole rects (rects: [{x, z, s, hole}])
    const holes = (rects || []).filter((r) => r.hole);
    if (!holes.length) box(-8, 8, -8, 8, 0, 1);
    else {
      const h = holes[0], x0 = h.x - h.s / 2, x1 = h.x + h.s / 2, z0 = h.z - h.s / 2, z1 = h.z + h.s / 2;
      box(-8, x0, -8, 8, 0, 1); box(x1, 8, -8, 8, 0, 1); box(x0, x1, -8, z0, 0, 1); box(x0, x1, z1, 8, 0, 1);
    }
    // fences just outside the view
    [[0, -3.3, 3.4, 0.2], [0, 2.6, 3.4, 0.2], [-1.75, -0.4, 0.2, 3.2], [1.75, -0.4, 0.2, 3.2]].forEach(([x, z, hx, hz]) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(new C.Box(new C.Vec3(hx, 1.5, hz))); b.position.set(x, 1.5, z); w.addBody(b); });
    const tR = new C.Vec3(), tW = new C.Vec3(), tV = new C.Vec3(), tF = new C.Vec3();
    w.addEventListener('preStep', () => {
      const gr = F.grab; if (!gr) return;
      const b = gr.b; b.pointToWorldFrame(gr.local, tW); tW.vsub(b.position, tR); b.angularVelocity.cross(tR, tV); tV.vadd(b.velocity, tV);
      const m = b.mass, k = PH.grabK, c = 2 * Math.sqrt(k) * PH.grabZeta;
      tF.set(m * (k * (gr.to.x - tW.x) - c * tV.x), m * (k * (gr.to.y - tW.y) - c * tV.y - w.gravity.y), m * (k * (gr.to.z - tW.z) - c * tV.z));
      const mx = m * PH.grabMaxF, len = tF.length(); if (len > mx) tF.scale(mx / len, tF);
      b.applyForce(tF, tR);
    });
    this.flWorld = w;
    return { w, C, mP, mG, grounds, box };
  }
  flPlateBody(W, s, x, y, z) {
    const PH = this.PHYS, C = W.C, R = s.d / 2, t = s.t, mass = s.unit === 'LB' ? s.kg * 0.4536 : s.kg;
    const b = new C.Body({ mass, material: W.mP, linearDamping: PH.linDamp, angularDamping: PH.angDamp, sleepSpeedLimit: PH.sleepSpeed, sleepTimeLimit: PH.sleepTime });
    b.addShape(new C.Cylinder(R, R, t, 28));
    const Ix = mass * (3 * R * R + t * t) / 12, Iy = 0.5 * mass * R * R; b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
    b.position.set(x, y, z); b.quaternion.setFromEuler((Math.random() - 0.5) * 0.06, Math.random() * 6.28, (Math.random() - 0.5) * 0.06);
    W.w.addBody(b); return b;
  }
  flImpactOn(W, b, mass, R, target) {
    const C = W.C;
    b.addEventListener('collide', (e) => {
      if (W.grounds.indexOf(e.body) < 0 && !e.body.userData) return;
      const ax = b.quaternion.vmult(new C.Vec3(0, 1, 0)), flat = Math.abs(ax.y) > 0.7, c = e.contact, ri = c.bi === b ? c.ri : c.rj;
      this.flImpact({ m: mass, v: Math.abs(c.getImpactVelocityAlongNormal()), x: flat ? b.position.x : b.position.x + ri.x, z: flat ? b.position.z : b.position.z + ri.z, R, flat, target });
    });
  }
  // pick something with the spring grab; disc test (rad) so holes still grab
  flGrabber(items, rad, liftY) {
    const F = this.FL, T = this.THREE, C = window.PlateKit.CANNON, PH = this.PHYS;
    return (e) => {
      const rc = this.flRay(e); let hit = null, bd = 1e9;
      items.forEach((it) => { if (!it.b || it.gone) return; const d = rc.ray.distanceToPoint(it.o.position); if (d < rad(it) && d < bd) { bd = d; hit = it; } });
      if (!hit) return null;
      this.buzz('selection'); this.flAudio(); if (this.flOnGrab) this.flOnGrab(hit);
      const b = hit.b; b.wakeUp();
      const pt = rc.ray.closestPointToPoint(hit.o.position, new T.Vector3());
      const local = b.pointToLocalFrame(new C.Vec3(pt.x, pt.y, pt.z));
      const planeY = Math.max(pt.y, 0.03) + (liftY || 0.35), plane = new T.Plane(new T.Vector3(0, 1, 0), -planeY), p = new T.Vector3();
      const G = F.grab = { b, local, to: new T.Vector3(pt.x, planeY, pt.z) }; b.angularDamping = PH.grabAngDamp;
      return {
        move: (ev) => { if (this.flRay(ev).ray.intersectPlane(plane, p)) G.to.set(Math.max(-1.5, Math.min(1.5, p.x)), planeY, Math.max(-3.0, Math.min(2.3, p.z))); },
        up: () => { F.grab = null; b.angularDamping = PH.angDamp; if (this.flOnDrop) this.flOnDrop(hit); }
      };
    };
  }

  // ---------------- 2 · the gym's name: two dials slide in from the left, seen a little from above ----------------
  flName() {
    const F = this.FL, chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('');
    this.flCam([0, 0.5, 10.5], [0, -0.4, 0], 35);
    const drums = [];
    this.flAfter('What’s the name of your Gym?', () => {
      [-0.62, 0.62].forEach((x, i) => {
        const D = this.flDrum(chars, { r: 0.95, a0: 0.38, w: 0.95, lw: 0.7, size: 120 }); D.g.position.set(-5, -0.45, 0); this.flAdd(D.g); D.set(this.flEditOne && this.d.name && this.d.name[i] ? Math.max(0, chars.indexOf(this.d.name[i])) : 0);
        const x0 = -5 - i * 0.6;
        this.flLater(() => { this.flClick(0.6); this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); D.g.position.x = x0 + (x - x0) * e; D.g.rotation.x = -0.4 * (1 - e) * Math.sin(u * 6); }, 0.75); }, i * 140);
        drums.push(D);
      });
      dim();
    });
    let cur = 0;
    const dim = () => drums.forEach((D, i) => { D.opacity = i === cur || D.lock ? 1 : 0.35; D.layout(); });
    const lockOne = () => {
      const D = drums[cur]; D.lock = true; this.buzz('light'); this.flClick(0.7);
      const g = D.g, y0 = g.position.y; this.flAnim((u) => { g.position.y = y0 - 0.08 * Math.sin(u * Math.PI); }, 0.25);
      cur++; dim();
      if (cur >= 2) {
        this.d.name = chars[drums[0].idx] + chars[drums[1].idx];
        // both picked: a reflection runs over the dials, then down to the next question
        this.flLater(() => { this.flShine(drums.map((q) => q.g), 0.8); drums.forEach((q) => this.flSparkles(q.g.position.clone().setZ(1), 4, 1.2)); }, 250);
        this.flLater(() => { if (this.flStep === 'name') this.flPanTo(this.flMode === 'gym' ? 'unit' : 'unit'); }, 1300);
      }
    };
    F.hit = (e) => {
      const D = drums[cur]; if (!D) return null;
      if (!this.flRay(e).intersectObject(D.g, true).length) return null;
      D.onTap = () => { if (!D.lock) lockOne(); };
      return this.flDrumDrag(D, e, 46);
    };
    F.tick = (dt) => { drums.forEach((D) => D.tick(dt, !!D.dragging)); this.flSpkTick(dt); };
  }

  // ---------------- 3 · kettlebells: they fall from the sky; drop one on the square — it bounces, the square sinks, the other is raptured ----------------
  flUnit() {
    const F = this.FL, T = this.THREE, name = this.d.name || '79';
    this.flCam([0, 6.2, 10.4], [0, -0.35, 0.45], 35);
    const SZ = 1.25, SQ = { x: 0, z: 1.55, s: SZ };
    const W = this.flPhysWorld([{ x: SQ.x, z: SQ.z, s: SZ, hole: true }]);
    const C = W.C;
    // the square is a pad set into a hole in the floor: its top sits flush, and it can sink
    const IN = SZ - 0.12, pad = new C.Body({ mass: 0, material: W.mG }); pad.addShape(new C.Box(new C.Vec3(IN / 2, 0.1, IN / 2))); pad.position.set(SQ.x, -0.1, SQ.z); W.w.addBody(pad); W.grounds.push(pad); pad.userData = { pad: true };
    const sq = new T.Group(), th = 0.06, Ml = new T.MeshBasicMaterial({ color: this.flInk() });
    [[0, -SZ / 2, SZ + th, th], [0, SZ / 2, SZ + th, th], [-SZ / 2, 0, th, SZ], [SZ / 2, 0, th, SZ]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.02, d), Ml); m.position.set(x, 0.01, z); sq.add(m); });
    sq.position.set(SQ.x, 0, SQ.z); this.flAdd(sq); sq.visible = false;
    // the frame stays put; only the platform inside it moves, like a scale. A depth-only floor hides it when it sinks.
    const occ = new T.Group(), oM = new T.MeshBasicMaterial({ colorWrite: false });
    [[-(SZ / 2 + 3), 0, 6, SZ + 12], [SZ / 2 + 3, 0, 6, SZ + 12], [0, -(SZ / 2 + 3), SZ, 6], [0, SZ / 2 + 3, SZ, 6]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 1, d), oM); m.position.set(x, -0.5, z); m.renderOrder = -1; occ.add(m); });
    occ.position.set(SQ.x, 0, SQ.z); this.flAdd(occ);
    const inner = new T.Group(), slab = new T.Mesh(new T.BoxGeometry(IN, 0.5, IN), this.toon(this.pal.boxLight)); slab.position.y = -0.25; slab.receiveShadow = true; inner.add(slab);
    const iM = new T.MeshBasicMaterial({ color: this.flInk() }), it2 = 0.035;
    [[0, -IN / 2 + it2 / 2, IN, it2], [0, IN / 2 - it2 / 2, IN, it2], [-IN / 2 + it2 / 2, 0, it2, IN], [IN / 2 - it2 / 2, 0, it2, IN]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.012, d), iM); m.position.set(x, 0.006, z); inner.add(m); });
    inner.position.set(SQ.x, 0, SQ.z); this.flAdd(inner); inner.visible = false;
    const bells = [], items = [];
    let chosen = null, padY = -0.1, padV = 0, sinking = false;
    this.flAfter('Cool. Let’s set ' + name + '. Do they use kilos or pounds there?', () => {
      sq.visible = true; this.popIn(sq, 0); inner.visible = true; this.popIn(inner, 60);
      [['KG', 'kg', -0.95], ['LB', 'lb', 0.95]].forEach(([lab, u, x], i) => this.flLater(() => {
        const g = this.kettlebell(lab), o = new T.Group(); g.position.y = -0.39; o.add(g); g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
        const sh = this.softShadow(0.62); this.flAdd(o); this.flAdd(sh);
        const b = new C.Body({ mass: 16, material: W.mP, linearDamping: 0.03, angularDamping: 0.3, sleepSpeedLimit: 0.06, sleepTimeLimit: 0.8 });
        b.addShape(new C.Cylinder(0.34, 0.4, 0.78, 12)); b.angularFactor.set(0, 0, 0); b.position.set(x, 5 + i * 0.6, -0.55); b.quaternion.setFromEuler(0, (Math.random() - 0.5) * 0.4, 0);
        W.w.addBody(b);
        const it = { o, g, b, sh, u, R: 0.4 }; items.push(it); bells.push(it);
        b.addEventListener('collide', (e) => {
          const v = Math.abs(e.contact.getImpactVelocityAlongNormal());
          if (v > 1) this.flImpact({ m: 16, v, x: b.position.x, z: b.position.z, R: 0.3, target: g });
          if (v > 1.2) this.flPhysDust(b.position.x, b.position.z, 200 * Math.min(1, v / 5), 2.4, 0.32, 1.5);
          if (e.body === pad && !chosen && !F.grab) choose(it);
        });
      }, i * 260));
    });
    const choose = (it) => {
      chosen = it; this.buzz('success'); this.setUnit(it.u);
      // a bounce on the scale, then the scale sinks and settles
      this.flLater(() => this.flClick(0.5), 60);
      this.flLater(() => { sinking = true; }, 700);
      // the other one is raptured
      const other = bells.find((q) => q !== it);
      this.flLater(() => {
        if (!other) return; other.rapt = true; other.abd = 0; other.b.type = C.Body.KINEMATIC; other.b.velocity.set(0, 0, 0); other.b.angularVelocity.set(0, 0, 0);
        other.y0 = other.b.position.y;
        other.g.traverse((m) => { if (m.isMesh && m.material) { m.material = m.material.clone(); m.material.transparent = true; } });
        // abducted: a beam comes down, it lifts slowly, spins and shrinks away into the light
        const beam = new T.Mesh(new T.CylinderGeometry(0.22, 0.62, 7, 28, 1, true), new T.MeshBasicMaterial({ color: '#FFFFFF', transparent: true, opacity: 0, depthWrite: false, side: T.DoubleSide, blending: T.AdditiveBlending }));
        beam.position.set(other.b.position.x, 3.5, other.b.position.z); this.flAdd(beam); other.beam = beam;
        const pool = new T.Mesh(new T.CircleGeometry(0.62, 28), new T.MeshBasicMaterial({ color: '#FFFFFF', transparent: true, opacity: 0, depthWrite: false, blending: T.AdditiveBlending })); pool.rotation.x = -Math.PI / 2; pool.position.set(other.b.position.x, 0.01, other.b.position.z); this.flAdd(pool); other.pool = pool;
      }, 450);
      this.flLater(() => { if (this.flStep === 'unit') { this.flCheckSound(); this.flPanTo('plates'); } }, 2300);
    };
    F.hit = (e) => { if (chosen) return null; return this.flGrabber(bells, () => 0.5, 0.55)(e); };
    F.tick = (dt, t) => {
      if (this.flWorld !== W.w) return;
      if (sinking) { padV += (-0.16 - padY) * 60 * dt - padV * 7 * dt; padY += padV * dt; pad.position.y = padY; inner.position.y = padY + 0.1; }
      W.w.step(1 / 120, dt, 8);
      bells.forEach((q) => {
        if (q.rapt) {
          q.abd += dt; const a = q.abd, beamA = Math.min(1, a / 0.3) * (a > 1.7 ? Math.max(0, 1 - (a - 1.7) / 0.4) : 1);
          q.beam.material.opacity = 0.32 * beamA; q.pool.material.opacity = 0.4 * beamA;
          const lift = a < 0.35 ? 0 : Math.pow(a - 0.35, 2) * 1.6, shrink = a < 0.9 ? 1 : Math.max(0.0001, 1 - (a - 0.9) / 0.8);
          q.b.velocity.set(0, 0, 0); q.b.position.y = q.y0 + lift + 0.04 * Math.sin(a * 9); q.b.quaternion.setFromEuler(0.06 * Math.sin(a * 5), a * a * 3, 0);
          q.o.scale.setScalar(shrink); q.sh.material.opacity = 0.5 * shrink; q.g.traverse((m) => { if (m.isMesh) m.material.opacity = Math.min(1, shrink * 1.4); });
        }
        // on the ground a bell stays where it lands: no skating across the floor
        if (!q.rapt && !(F.grab && F.grab.b === q.b) && q.b.position.y < 0.62) { const k = Math.exp(-16 * dt); q.b.velocity.x *= k; q.b.velocity.z *= k; q.b.angularVelocity.y *= k; }
        q.o.position.copy(q.b.position); q.o.quaternion.copy(q.b.quaternion);
        q.sh.position.set(q.b.position.x, (q === chosen ? padY + 0.105 : 0.003), q.b.position.z); const s = 1 + Math.max(0, q.b.position.y - 0.4) * 0.4; q.sh.scale.setScalar(s); if (!q.rapt) q.sh.material.opacity = 1 / (s * s);
        this.flSquashTick(q.g, dt);
      });
      this.flSpkTick(dt);
    };
  }

  // ---------------- 4 · plates: they fall in; drag each to the platform (have it) or the hole (don't) ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs();
    this.flCam([0, 8.4, 8.2], [0, -0.6, -0.9], 35);
    const HOLE = { x: -0.72, z: 1.0, s: 0.95, hole: true }, PAD = { x: 0.72, z: 1.0, s: 0.95, top: 0.14 };
    const W = this.flPhysWorld([HOLE]), C = W.C;
    const pad = W.box(PAD.x - PAD.s / 2, PAD.x + PAD.s / 2, PAD.z - PAD.s / 2, PAD.z + PAD.s / 2, PAD.top, PAD.top + 0.5);
    // the hole: a dark square with a little depth; the platform: a raised slab
    const holeG = new T.Group(), dk = new T.MeshBasicMaterial({ color: '#2A1A10' }), wallM = this.toon(this.pal.boxDark);
    const floorM = new T.Mesh(new T.PlaneGeometry(HOLE.s, HOLE.s), dk); floorM.rotation.x = -Math.PI / 2; floorM.position.y = -0.45; holeG.add(floorM);
    [[0, -HOLE.s / 2, HOLE.s, 0.02, 0], [0, HOLE.s / 2, HOLE.s, 0.02, 0], [-HOLE.s / 2, 0, 0.02, HOLE.s, 1], [HOLE.s / 2, 0, 0.02, HOLE.s, 1]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.45, d), wallM); m.position.set(x, -0.225, z); holeG.add(m); });
    const rim = new T.Mesh(new T.RingGeometry(0, 0.01, 4), dk); holeG.add(rim);
    holeG.position.set(HOLE.x, 0, HOLE.z);
    const padM = new T.Mesh(new T.BoxGeometry(PAD.s, PAD.top, PAD.s), [this.toon(this.pal.boxDark), this.toon(this.pal.boxDark), this.toon(this.pal.boxLight), this.toon(this.pal.boxDark), this.toon(this.pal.boxDark), this.toon(this.pal.boxDark)]);
    padM.position.set(PAD.x, PAD.top / 2, PAD.z); padM.castShadow = true; padM.receiveShadow = true;
    const fl = new T.Mesh(new T.PlaneGeometry(14, 14), new T.ShadowMaterial({ opacity: 0.2 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true;
    // a mask so plates falling in the hole vanish below the floor line (the floor itself is the page background)
    [holeG, padM, fl].forEach((o) => { o.visible = false; this.flAdd(o); });
    const items = []; this.flDbg = items;
    let touched = false, finished = false, reset = null;
    const drop = () => {
      items.forEach((it) => { if (it.b) W.w.removeBody(it.b); this.FL.S.remove(it.o); }); items.length = 0;
      const n = specs.length, row = Math.min(5, n);
      specs.forEach((s, i) => {
        const col = i % row, r = Math.floor(i / row), x = (col - (row - 1) / 2) * 0.56, z = -0.95 + r * 0.6;
        const g = this.plate(s), o = new T.Group(); o.add(g); g.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } }); o.visible = false; this.flAdd(o);
        const it = { o, g, s, R: s.d / 2 }; items.push(it);
        this.flLater(() => { if (this.flWorld !== W.w) return; it.b = this.flPlateBody(W, s, x, 2.2 + Math.random() * 0.3, z); this.flImpactOn(W, it.b, it.b.mass, it.R, g); o.visible = true; }, 120 + i * 120);
      });
    };
    this.flAfter('What are the plates available?', () => { [holeG, padM, fl].forEach((o) => { o.visible = true; this.popIn(o, 0); }); drop(); });
    const inRect = (p, R) => Math.abs(p.x - R.x) < R.s / 2 && Math.abs(p.z - R.z) < R.s / 2;
    this.flOnGrab = () => {
      if (touched) return; touched = true;
      // a small recycle sign: everything back to the start
      reset = this.fh('button', { position: 'absolute', right: '18px', bottom: '34px', width: '52px', height: '52px', borderRadius: '26px', border: 0, background: this.flInk(), color: this.FC.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', pointerEvents: 'auto' }, F.ui);
      reset.setAttribute('aria-label', 'Start again'); reset.className = 'tap';
      reset.innerHTML = '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 0 1 15.5-6.2L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-15.5 6.2L3 16"/><path d="M3 21v-5h5"/></svg>';
      reset.animate([{ transform: 'scale(0) rotate(-180deg)' }, { transform: 'none' }], { duration: 420, easing: 'cubic-bezier(.3,1.5,.5,1)' });
      reset.onclick = () => { this.buzz('light'); this.flClick(0.8); reset.animate([{ transform: 'rotate(0)' }, { transform: 'rotate(-360deg)' }], { duration: 500, easing: 'ease-out' }); drop(); };
    };
    this.flOnDrop = null;
    let stable = 0;
    F.hit = (e) => (finished ? null : this.flGrabber(items, (it) => it.R * 1.1, 0.4)(e));
    F.tick = (dt) => {
      if (this.flWorld !== W.w) return;
      W.w.step(1 / 120, dt, 8);
      items.forEach((it) => {
        if (!it.b) return; it.o.position.copy(it.b.position); it.o.quaternion.copy(it.b.quaternion); this.flSquashTick(it.g, dt);
        if (!it.gone && it.b.position.y < -0.35) { it.gone = true; it.b.sleep(); W.w.removeBody(it.b); it.o.visible = false; this.flThud(0.25); this.buzz('light'); }
      });
      this.flSpkTick(dt);
      if (finished || !items.length || items.some((it) => !it.b)) return;
      const sorted = items.every((it) => it.gone || (inRect(it.b.position, PAD) && it.b.position.y > PAD.top - 0.02 && it.b.velocity.length() < 0.35 && F.grab?.b !== it.b));
      stable = sorted ? stable + dt : 0;
      if (stable > 0.5) {
        finished = true;
        const have = items.filter((it) => !it.gone);
        this.d.own[this.d.unit] = have.map((it) => it.s.kg);
        if (reset) reset.remove();
        this.flShine(have.map((it) => it.o).concat([padM]), 0.9); have.forEach((it, k) => this.flLater(() => this.flSparkles(it.o.position.clone(), 2, 0.4), k * 60));
        this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 1500);
      }
    };
  }

  // ---------------- 4b · the bar: they slide in from the left; the bars lean, the labels and shadows don't ----------------
  flBarQ() {
    const F = this.FL, T = this.THREE, list = this.BARS[this.d.unit], n = list.length, SP = 1.02;
    this.flCam([0, 1.05, 7.0], [0, -0.5, 0], 35);
    const bars = [], labels = [];
    const pre = this.flEditOne && this.d.bar ? list.findIndex((q) => q[0] === this.d.bar[this.d.unit]) : -1;
    let pos = pre >= 0 ? pre : 1, vel = 0, idx = pos, dragging = false, done = false, ready = false;
    this.flAfter('What bar do you use?', () => {
      list.forEach(([w], i) => {
        const wrap = this.barModel(w, i), bar = wrap.userData.bar;
        // barModel built a label mesh at -1.55: replace it with interface text (no sketch)
        wrap.children.slice().forEach((c) => { if (c !== bar && c.material && c.material.map && c.position.y < -1.4) wrap.remove(c); });
        const tilt = new T.Group(); wrap.remove(bar); tilt.add(bar); wrap.add(tilt); tilt.rotation.z = -0.24; wrap.userData.tilt = tilt;
        wrap.position.set(-6 - i * 1.2, -0.3, 0); this.flAdd(wrap); bars.push(wrap);
        const lab = this.fh('div', { position: 'absolute', left: 0, top: 0, transform: 'translate(-50%,-50%)', color: this.flInk(), fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '22px', whiteSpace: 'nowrap', opacity: 0, transition: 'opacity .3s', pointerEvents: 'none' }, F.ui, this.fmt(w) + ' ' + this.d.unit);
        labels.push(lab);
      });
      // they slide in from the left, one after another, each braking into its place
      bars.forEach((g, i) => this.flLater(() => { this.flClick(0.6); }, i * 110));
      const t0 = this.FL.t;
      this.flBarIn = { t0 };
      this.flLater(() => { ready = true; labels.forEach((l) => { l.style.opacity = '1'; }); }, 950);
    });
    const v = new T.Vector3();
    F.tick = (dt, t) => {
      if (!bars.length) return;
      if (!dragging) { pos += vel * dt; vel *= Math.exp(-dt * 5); pos = Math.max(-0.3, Math.min(n - 0.7, pos)); if (Math.abs(vel) < 1.5) pos += (Math.max(0, Math.min(n - 1, Math.round(pos))) - pos) * (1 - Math.exp(-dt * 10)); }
      const i0 = Math.max(0, Math.min(n - 1, Math.round(pos))); if (i0 !== idx) { idx = i0; this.flClick(0.8); this.buzz('selection'); }
      const it = this.flBarIn ? Math.min(1, (this.FL.t - this.flBarIn.t0) / 0.9) : 1;
      bars.forEach((g, i) => {
        const k = Math.min(1, Math.max(0, it * 1.35 - i * 0.18)), e = 1 - Math.pow(1 - k, 3), tx = (i - pos) * SP;
        g.position.x = tx + (1 - e) * (-6 - i * 0.8);
        g.userData.bar.rotation.y = (t || 0) * 0.6 + i;
        g.userData.tilt.rotation.z = -0.24 + (1 - e) * 0.5;
        v.set(g.position.x, -1.85, 0).project(F.cam); const L = labels[i]; L.style.left = ((v.x + 1) / 2 * 100) + '%'; L.style.top = ((1 - v.y) / 2 * 100) + '%';
      });
      this.flSpkTick(dt);
    };
    const pick = () => {
      if (done) return; done = true; this.d.bar[this.d.unit] = list[idx][0];
      const g = bars[idx]; this.flShine([g], 0.9);
      // a twinkle: a quick wiggle and sparkles up the bar
      this.flAnim((u) => { g.userData.tilt.rotation.z = -0.24 + 0.12 * Math.sin(u * Math.PI * 4) * (1 - u); }, 0.8);
      for (let k = 0; k < 4; k++) this.flLater(() => this.flSparkles(new T.Vector3(g.position.x, -1 + k * 0.6, 0.2), 2, 0.5), k * 90);
      this.flLater(() => { if (this.flStep === 'bar') { this.flCheckSound(); this.flPanTo(this.flMode === 'gym' ? 'menu' : 'prs'); } }, 1300);
    };
    const ppi = 390 * SP / (F.cam.position.z * 0.2914);
    F.hit = (e) => {
      if (!ready || done) return null;
      let x0 = e.clientX, sx = e.clientX, sy = e.clientY, t0 = performance.now(); dragging = true; this.flAudio();
      return {
        move: (ev) => { const dx = ev.clientX - x0, now = performance.now(); const d = -dx / ppi; pos += d; vel = d / Math.max(0.008, (now - t0) / 1000); x0 = ev.clientX; t0 = now; },
        up: (ev, tap) => {
          dragging = false; if (performance.now() - t0 > 90) vel = 0;
          const dx = ev.clientX - sx, dy = ev.clientY - sy;
          if (!tap && dy < -55 && Math.abs(dy) > Math.abs(dx) * 1.5 && (this.flMode === 'menu' || this.flMode === 'gym')) { this.flCheckSound(); this.flMode = 'menu'; this.flPanTo('menu'); return; }
          if (tap || (dy < -55 && Math.abs(dy) > Math.abs(dx) * 1.5)) { vel = 0; pos = idx; this.buzz('light'); this.flCheckSound(); pick(); }
        }
      };
    };
  }

  // ---------------- 5 · PRs: tap the notebook, it opens; upload or type; it closes and shines ----------------
  notebookModel2(title) {
    const T = this.THREE, g = new T.Group(), W = 1.05, H = 1.4, D = 0.1;
    const tex = (draw, w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; t.anisotropy = 4; t.userData = { c, draw }; return t; };
    const coverT = tex((x) => {
      x.fillStyle = this.pal.boxDark; x.fillRect(0, 0, 512, 680);
      x.fillStyle = 'rgba(255,255,255,0.07)'; for (let i = 0; i < 680; i += 6) x.fillRect(0, i, 512, 2);
      x.fillStyle = this.pal.boxLight; x.fillRect(70, 230, 372, 170);
      x.fillStyle = this.pal.boxDark; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '400 92px "Permanent Marker", "Comic Sans MS", cursive'; x.fillText(title, 256, 318);
    }, 512, 680);
    const pageC = document.createElement('canvas'); pageC.width = 512; pageC.height = 680; const pageT = new T.CanvasTexture(pageC); pageT.colorSpace = T.SRGBColorSpace;
    const drawPage = (rows) => {
      const x = pageC.getContext('2d'); x.fillStyle = '#FBF8F2'; x.fillRect(0, 0, 512, 680);
      x.strokeStyle = 'rgba(70,110,190,0.28)'; x.lineWidth = 2; for (let y = 120; y < 680; y += 62) { x.beginPath(); x.moveTo(30, y); x.lineTo(490, y); x.stroke(); }
      x.strokeStyle = 'rgba(210,60,60,0.35)'; x.beginPath(); x.moveTo(78, 0); x.lineTo(78, 680); x.stroke();
      x.fillStyle = '#1C2A55'; x.font = '400 48px "Permanent Marker", cursive'; x.fillText('PRs', 96, 88);
      x.font = '400 34px "Permanent Marker", cursive';
      (rows || []).forEach((r, i) => { x.fillText(r, 96, 170 + i * 62); });
      pageT.needsUpdate = true;
    };
    drawPage(null);
    const side = this.toon(this.pal.boxDark), pages = this.toon('#F6F2EA'), pageFace = this.toon('#FFFFFF'); pageFace.map = pageT;
    const coverM = this.toon('#FFFFFF'); coverM.map = coverT;
    // the block of pages with the back cover, the first page on its top face
    const block = new T.Mesh(new T.BoxGeometry(W, H, D * 0.8), [pages, side, pages, pages, pageFace, side]); block.position.z = -D * 0.1; g.add(block);
    // the front cover on a hinge at the spine
    const hinge = new T.Group(); hinge.position.set(-W / 2, 0, D * 0.35); g.add(hinge);
    const cover = new T.Mesh(new T.BoxGeometry(W, H, 0.025), [side, side, side, side, coverM, side]); cover.position.x = W / 2; hinge.add(cover);
    const ring = new T.TorusGeometry(0.055, 0.012, 6, 12), rm = this.toon('#C9CED4');
    g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    g.userData = { hinge, drawPage };
    return g;
  }
  flPRs() {
    const F = this.FL, T = this.THREE;
    this.flCam([0, 0.6, 6.4], [0, 0.05, 0], 35);
    const nb = this.notebookModel2('MY PRs'); nb.rotation.set(-0.28, 0.18, 0.06); nb.visible = false; this.flAdd(nb);
    const sh = this.softShadow(0.6); sh.position.set(0, -0.95, 0); sh.scale.set(1, 0.5, 1); sh.visible = false; this.flAdd(sh);
    const rows = () => this.d.prs.filter((q) => q[1] != null).map((q) => q[0] + '  ' + this.fmt(q[1]) + ' ' + this.d.unit);
    if (this.d.prs.some((q) => q[1] != null)) nb.userData.drawPage(rows());
    let open = false, busy = false, opts = null;
    const fm = this.flFromMenu; if (fm) { nb.visible = true; sh.visible = true; }
    this.flAfter(this.flMode === 'menu' ? 'Your PRs.' : 'Alright. And what are your PRs?', () => { if (fm) return; nb.visible = true; sh.visible = true; this.popIn(nb, 0); this.popIn(sh, 0); });
    F.tick = (dt, t) => { nb.position.y = 0.06 * Math.sin(t * 1.4); if (!open) nb.rotation.y = 0.18 + 0.08 * Math.sin(t * 0.7); this.flSpkTick(dt); };
    const hinge = nb.userData.hinge;
    const setOpen = (o, then) => {
      open = o; const a0 = hinge.rotation.y, a1 = o ? -2.5 : 0, r0 = nb.rotation.y, r1 = o ? 0.02 : 0.18;
      this.flClick(o ? 0.5 : 0.4);
      this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; hinge.rotation.y = a0 + (a1 - a0) * e; nb.rotation.y = r0 + (r1 - r0) * e; nb.position.x = (o ? 0.35 : 0) * e + (o ? 0 : 0.35) * (1 - e); }, 0.6, then);
    };
    const leave = () => {
      // close, shine, and down to the workout (or back to the menu)
      busy = true; if (opts) opts.remove();
      setOpen(false, () => { this.flShine([nb], 0.8); this.flSparkles(new T.Vector3(0, 0.2, 0.5), 7, 1.3); this.flLater(() => { this.flCheckSound(); this.flPanTo(this.flMode === 'menu' ? 'menu' : 'wod'); }, 1000); });
    };
    const showOpts = () => {
      opts = this.fh('div', { position: 'absolute', left: 0, right: 0, top: '78%', display: 'flex', justifyContent: 'center', gap: '12px', pointerEvents: 'auto' }, F.ui);
      [['Upload', () => this.flPickPhoto(() => this.reading('Reading your PRs…', () => { this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); nb.userData.drawPage(rows()); this.flLater(leave, 700); }))],
        ['Type', () => { this.flPrRet = this.flMode === 'menu' ? 'menu' : 'wod'; this.flGo('prDial'); }]].forEach(([l, fn], i) => {
        const b = this.fh('button', { height: '50px', padding: '0 26px', borderRadius: '25px', border: 0, background: i ? 'transparent' : this.flInk(), boxShadow: i ? 'inset 0 0 0 2.5px ' + this.flInk() : 'none', color: i ? this.flInk() : this.FC.bg, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '18px', cursor: 'pointer' }, opts, l);
        b.className = 'tap'; b.animate([{ opacity: 0, transform: 'translateY(10px)' }, { opacity: 1, transform: 'none' }], { duration: 320, delay: i * 80, fill: 'backwards' });
        b.onclick = () => { this.buzz('light'); this.flCheckSound(); fn(); };
      });
    };
    F.hit = (e) => {
      if (busy || !nb.visible || !this.flRay(e).intersectObject(nb, true).length) return null;
      return { up: (ev, tap) => { if (!tap || busy) return; this.buzz('light');
        if (!open) setOpen(true, showOpts); else { if (opts) { opts.remove(); opts = null; } setOpen(false); } } };
    };
  }
  // the system's own menu: photo library, take photo or file
  flPickPhoto(then) {
    const inp = document.createElement('input'); inp.type = 'file'; inp.accept = 'image/*';
    Object.assign(inp.style, { position: 'fixed', left: '-9999px', opacity: 0 });
    document.body.appendChild(inp);
    inp.addEventListener('change', () => { const f = inp.files && inp.files[0]; inp.remove(); if (f) then(f); });
    inp.click();
  }
  // typing PRs: one lift at a time, with a kg / lb switch
  flPRDial(i) {
    this.flClear(); this.flStep = 'prDial'; this.flApplyStyle();
    const F = this.FL, lifts = this.d.prs, q = lifts[i];
    this.prUnit = this.prUnit || this.d.unit;
    this.flCam([0, 0.2, 9.5], [0, -0.25, 0], 35);
    let D = null, vals = [], u = this.prUnit, notch = [];
    const conv = (v, from, to) => (from === to ? v : to === 'lb' ? v * 2.20462 : v / 2.20462);
    const build = (keep) => {
      if (D) { F.S.remove(D.g); F.objs = F.objs.filter((o) => o !== D.g); }
      const stp = u === 'lb' ? 5 : 2.5, max = u === 'lb' ? 700 : 320; vals = []; for (let v = 0; v <= max; v += stp) vals.push(v);
      D = this.flDrum(vals.map((v) => this.fmt(v)), { r: 1.05, a0: 0.33, w: 1.5, lw: 1.35, size: 112, wrap: false });
      D.g.position.y = -0.2; this.flAdd(D.g);
      const start = keep != null ? keep : conv(q[1] != null ? q[1] : this.demoPR(q), this.d.unit, u);
      D.set(Math.max(0, Math.min(vals.length - 1, Math.round(start / stp))));
    };
    this.flAfter(q[0] + '?', () => {
      build(null); this.popIn(D.g, 0);
      [-1, 1].forEach((s) => { const m = new this.THREE.Mesh(new this.THREE.ConeGeometry(0.09, 0.2, 3), new this.THREE.MeshBasicMaterial({ color: this.flInk() })); m.rotation.z = s * Math.PI / 2; m.position.set(s * 0.98, -0.2, 0.05); this.flAdd(m); this.popIn(m, 100); notch.push(m); });
      // the switch
      const sw = this.fh('div', { position: 'absolute', left: '50%', top: '79%', transform: 'translateX(-50%)', display: 'flex', padding: '4px', borderRadius: '22px', boxShadow: 'inset 0 0 0 2.5px ' + this.flInk(), pointerEvents: 'auto' }, F.ui);
      const paint = () => [...sw.children].forEach((b) => { const on = b.dataset.u === u; b.style.background = on ? this.flInk() : 'transparent'; b.style.color = on ? this.FC.bg : this.flInk(); b.setAttribute('aria-checked', String(on)); });
      ['kg', 'lb'].forEach((k) => {
        const b = this.fh('button', { width: '68px', height: '38px', borderRadius: '19px', border: 0, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '17px', textTransform: 'uppercase', cursor: 'pointer' }, sw, k);
        b.dataset.u = k; b.setAttribute('role', 'radio'); b.className = 'tap';
        b.onclick = () => { if (u === k) return; const cur = vals[D.idx]; const nu = k; const kept = conv(cur, u, nu); u = this.prUnit = nu; build(kept); paint(); this.flClick(0.9); this.buzz('selection'); };
      });
      paint();
      this.flSwipeQuiet(() => {
        const v = vals[D.idx], inUnit = conv(v, u, this.d.unit);
        q[1] = Math.round(inUnit / (this.d.unit === 'lb' ? 5 : 2.5)) * (this.d.unit === 'lb' ? 5 : 2.5);
        if (i + 1 < lifts.length) this.flPRDial(i + 1); else this.flPanTo(this.flPrRet || 'wod');
      });
    });
    F.hit = (e) => (D && this.flRay(e).intersectObject(D.g, true).length ? this.flDrumDrag(D, e, 40) : null);
    F.tick = (dt) => { if (D) D.tick(dt, !!D.dragging); };
  }

  // ---------------- 6 · today's workout: the whiteboard swings in; tap it for the system's photo menu ----------------
  flDrawBoard(g, plan) {
    const { c, tex } = g.userData, x = c.getContext('2d'), W = c.width, H = c.height, F = '"Permanent Marker", "Comic Sans MS", cursive';
    // the board in the light studio colour, with the same fine grid
    x.fillStyle = this.pal.boxLight; x.fillRect(0, 0, W, H);
    x.strokeStyle = 'rgba(108,55,19,0.11)'; x.lineWidth = 2;
    for (let i = 0; i <= W; i += 40) { x.beginPath(); x.moveTo(i, 0); x.lineTo(i, H); x.stroke(); }
    for (let j = 0; j <= H; j += 40) { x.beginPath(); x.moveTo(0, j); x.lineTo(W, j); x.stroke(); }
    x.fillStyle = this.pal.boxDark; x.strokeStyle = this.pal.boxDark;
    x.font = '400 64px ' + F; x.fillText("Today's sesh", 48, 100);
    { const tw = x.measureText("Today's sesh").width; x.lineWidth = 5; x.beginPath(); x.moveTo(48, 124); x.lineTo(48 + tw, 118); x.stroke(); }
    if (plan) {
      const gs = plan.groups.filter((q) => !q.warm), L = 'ABCDEFGH'; let y = 210;
      gs.slice(0, 4).forEach((q, i) => {
        x.font = '400 50px ' + F; x.fillText(L[i] + '. ' + q.name.toUpperCase(), 48, y);
        x.font = '400 40px ' + F; x.fillText(q.format, 100, y + 56); x.fillText('→ ' + this.fmtW(q.sets[0].total) + ' ' + plan.unit, 600, y + 56);
        y += 150;
      });
    }
    tex.needsUpdate = true;
  }
  flWod() {
    const F = this.FL, T = this.THREE;
    this.flCam([0, 2.0, 7.4], [0, 1.35, 0], 35);
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.18 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const wb = this.whiteboardModel(); wb.visible = false; this.flAdd(wb);
    let busy = false;
    this.flAfter(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?', () => {
      // pushed in from the side, swinging round as it rolls, then rocking to a stop
      wb.visible = true; wb.position.x = 3.8; wb.rotation.y = -0.85; this.flClick(0.5);
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); wb.position.x = 3.8 * (1 - e); wb.rotation.y = -0.85 * (1 - e) + 0.12 * Math.sin(e * Math.PI) ; wb.userData.wheels.forEach((w) => { w.rotation.x = -(1 - e) * 40; }); }, 1.1, () => {
        this.flAnim((u) => { wb.rotation.z = 0.06 * Math.exp(-u * 5) * Math.sin(u * 16); wb.rotation.y = 0.05 * Math.exp(-u * 4) * Math.sin(u * 11); }, 1.0);
      });
    });
    const ready = () => {
      this.plan = this.workoutPlan(); this.setIdx = 0; this.doneSets = []; this.d.kitGot = {};
      this.flDrawBoard(wb, this.plan); this.flShine([wb], 0.6);
      this.flLater(() => {
        const cam = F.cam, P0 = cam.position.clone(), T0 = new T.Vector3(0, 1.35, 0), T1 = new T.Vector3(0, 1.45, 0), P1 = new T.Vector3(0, 1.45, 0.75), tgt = new T.Vector3();
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

  // ---------------- 7 · kit: swipe up to start; swipe down zooms out, back to the whiteboard ----------------
  flKitBack() {
    const F = this.FL, c = F.cam, P0 = c.position.clone(), d = new this.THREE.Vector3(); c.getWorldDirection(d);
    const T0 = P0.clone().add(d.multiplyScalar(5));
    F.onSwipe = null; F.onTap = null; F.onSwipeDown = null; F.hit = null; [...F.ui.children].forEach((el) => el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 300, fill: 'forwards' }));
    this.flAnim((u) => { const e = u * u; c.position.set(P0.x, P0.y + 4 * e, P0.z + 5 * e); c.lookAt(T0); }, 0.6, () => { this.flAgain = true; this.flGo('wod'); });
  }

  // ---------------- 8 · sets: the bar centred in the space above the card ----------------
  flSetsCam() { this.flCam([2.45, 1.2, 1.75], [0.78, 0.74, -0.08], 40); }

  // ---------------- after the session: a menu you drag through — Train, My PRs, Gym ----------------
  gymBoxModel(name) {
    const T = this.THREE, g = new T.Group(), S = 1.15, K = this.toon(this.pal.boxDark);
    const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d');
    x.fillStyle = this.pal.boxLight; x.fillRect(0, 0, 256, 256); x.fillStyle = this.pal.boxDark; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '900 120px "Playfair Display", Georgia, serif'; x.fillText(name || '79', 128, 140);
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; const front = this.toon('#FFFFFF'); front.map = t;
    const L = this.toon(this.pal.boxLight);
    const cube = new T.Mesh(new T.BoxGeometry(S, S, S), [L, L, L, L, front, L]); cube.position.y = S / 2; g.add(cube);
    const e = new T.LineSegments(new T.EdgesGeometry(cube.geometry), new T.LineBasicMaterial({ color: this.pal.boxDark })); e.position.copy(cube.position); g.add(e);
    g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    return g;
  }
  flMenu() {
    const F = this.FL, T = this.THREE;
    this.flMode = 'menu';
    this.flCam([0, 1.4, 7.2], [0, 0.55, 0], 35);
    const SP = 1.9, items = [
      { key: 'train', label: 'Train', make: () => { const g = this.whiteboardModel(); g.scale.setScalar(0.62); this.flDrawBoard(g, null); return g; }, go: () => { this.flMode = 'menu'; this.flAgain = true; this.flPanTo('wod'); } },
      { key: 'prs', label: 'My PRs', make: () => { const g = this.notebookModel2('MY PRs'); g.position.y = 0.8; g.rotation.x = -0.25; return g; }, go: () => this.flPanTo('prs') },
      { key: 'gym', label: 'Gym', make: () => this.gymBoxModel(this.d.name), go: () => { this.flMode = 'gym'; this.flPanTo('name'); } }
    ];
    const n = items.length, labels = [];
    let pos = this.flMenuPos != null ? this.flMenuPos : 0, vel = 0, idx = Math.round(pos), dragging = false;
    items.forEach((it, i) => {
      const w = new T.Group(), m = it.make(); w.add(m); it.m = m; it.w = w; w.position.x = (i - pos) * SP; this.flAdd(w); this.popIn(w, 120 + i * 90);
      const sh = this.softShadow(0.7); sh.scale.set(1, 0.6, 1); w.add(sh);
      const lab = this.fh('div', { position: 'absolute', left: 0, top: 0, transform: 'translate(-50%,-50%)', color: this.flInk(), fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '26px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, it.label);
      labels.push(lab);
    });
    const v = new T.Vector3();
    F.tick = (dt, t) => {
      if (!dragging) { pos += vel * dt; vel *= Math.exp(-dt * 5); pos = Math.max(-0.3, Math.min(n - 0.7, pos)); if (Math.abs(vel) < 1.5) pos += (Math.max(0, Math.min(n - 1, Math.round(pos))) - pos) * (1 - Math.exp(-dt * 10)); }
      const i0 = Math.max(0, Math.min(n - 1, Math.round(pos))); if (i0 !== idx) { idx = i0; this.flClick(0.8); this.buzz('selection'); }
      this.flMenuPos = pos;
      items.forEach((it, i) => {
        const d = i - pos, ad = Math.abs(d); it.w.position.x = d * SP; it.w.position.z = -Math.min(1, ad) * 0.6;
        it.m.rotation.y = (it.key === 'prs' ? 0.18 : 0) + 0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4);
        v.set(it.w.position.x, -0.45, it.w.position.z).project(F.cam); const L = labels[i]; L.style.left = ((v.x + 1) / 2 * 100) + '%'; L.style.top = ((1 - v.y) / 2 * 100) + '%'; L.style.opacity = String(Math.max(0.25, 1 - ad * 0.75));
      });
      this.flSpkTick(dt);
    };
    const ppi = 390 * SP / (F.cam.position.z * 0.2914 * 1.15);
    F.hit = (e) => {
      let x0 = e.clientX, sx = e.clientX, sy = e.clientY, t0 = performance.now(); dragging = true; this.flAudio();
      return {
        move: (ev) => { const dx = ev.clientX - x0, now = performance.now(); const d = -dx / ppi; pos += d; vel = d / Math.max(0.008, (now - t0) / 1000); x0 = ev.clientX; t0 = now; },
        up: (ev, tap) => {
          dragging = false; if (performance.now() - t0 > 90) vel = 0;
          if (tap) { const it = items[idx]; this.buzz('light'); this.flCheckSound(); this.flMenuGo(it); }
        }
      };
    };
  }
  // the scale, then the menu
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light'); this.dropLayer(L);
    this.plan = null; this.flBar = null; this.flMenuPos = 0; this.flGo('menu');
  }
