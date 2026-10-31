
  // ===================== FLOW, round 3 =====================
  // ---- the Physics canvas's tuning, in one place (Will's saved defaults there) ----
  get PHYS() {
    return { gravity: 9.81, iterations: 20, tolerance: 0.0005, pg: { friction: 0.55, restitution: 0.2 }, pp: { friction: 0.35, restitution: 0.12 },
      linDamp: 0.03, angDamp: 0.06, sleepSpeed: 0.06, sleepTime: 0.8, grabK: 260, grabZeta: 0.85, grabMaxF: 140, grabAngDamp: 0.45,
      shake: 0.1, dustAmount: 0.05, dustSize: 0.2, dustLinger: 0.24, dustSpread: 0.05, dustRise: 0.94, dustMinImpact: 1.2, dustColor: '#E9E2D6',
      lp: { size: [0.05, 0.11], life: [0.9, 1.7], count: 0.45 } };
  }
  // an impact on the floor: trauma (shake), a squash, a tiny zoom punch, and low-poly dust — as the Physics canvas does it
  flImpact(o) {
    const P = this.PHYS, v = o.v; if (v < 1.2) return;
    const f = o.m / 25, hit = Math.min(1, v / 12);
    this.flTrauma = Math.min(0.7, (this.flTrauma || 0) + 0.45 * f * (0.35 + 0.65 * hit));
    const juice = Math.min(1, (0.3 + 0.7 * hit) * (0.25 + 0.75 * Math.sqrt(f)));
    if (o.target) o.target.userData.squash = { t: 0, amp: 0.22 * juice };
    this.flFovKick = Math.min(0.025, (this.flFovKick || 0) + 0.012 * f * hit);
    this.flThud(0.2 + 0.7 * f * (0.4 + 0.6 * hit));
    if (v < P.dustMinImpact) return;
    const k = f * (0.45 + 0.55 * hit), sm = 0.2 + 1.25 * f;
    if (o.flat !== false) this.flPhysDust(o.x, o.z, 6 * f + 110 * k, 0.4 * f + 2.8 * k, o.R || 0.2, sm);
    else this.flPhysDust(o.x, o.z, 4 * f + 60 * k, 0.3 * f + 2.2 * k, 0.03 + 0.06 * f, sm);
  }
  flPhysDust(x, z, count, speed, ringR, sm) {
    const T = this.THREE, P = this.PHYS, L = P.lp, F = this.FL; this.flPD = this.flPD || [];
    const raw = count * L.count * P.dustAmount, n = Math.min(220, Math.floor(raw) + (Math.random() < raw % 1 ? 1 : 0));
    const G = this.flPDG || (this.flPDG = new T.IcosahedronGeometry(1, 0));
    const M = this.flPDM || (this.flPDM = new T.MeshStandardMaterial({ color: P.dustColor, flatShading: true, roughness: 0.85, metalness: 0 }));
    const rnd = (r) => r[0] + Math.random() * (r[1] - r[0]);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, rr = ringR * (0.8 + Math.random() * 0.3), m = new T.Mesh(G, M);
      m.position.set(x + Math.cos(a) * rr, 0.04 + Math.random() * 0.04, z + Math.sin(a) * rr); m.castShadow = true;
      const sp = speed * P.dustSpread * (0.3 + Math.random() * 0.8);
      const d = { m, v: new T.Vector3(Math.cos(a) * sp, (0.2 + Math.random() * 0.6) * speed * 0.5 * P.dustRise, Math.sin(a) * sp),
        spin: new T.Vector3((Math.random() - 0.5) * 1.6, (Math.random() - 0.5) * 1.6, (Math.random() - 0.5) * 1.6), life: 0, max: rnd(L.life) * P.dustLinger,
        s0: (rnd(L.size) + speed * 0.012) * P.dustSize * (sm || 1) };
      m.rotation.set(Math.random() * 6.28, Math.random() * 6.28, Math.random() * 6.28); m.scale.setScalar(0.0001);
      F.S.add(m); this.flPD.push(d);
    }
  }
  flPhysDustTick(dt) {
    if (!this.flPD || !this.flPD.length) return;
    const F = this.FL, P = this.PHYS, drag = Math.exp(-3.0 * dt);
    this.flPD = this.flPD.filter((d) => {
      d.life += dt; const t = d.life / d.max; if (t >= 1) { F.S.remove(d.m); return false; }
      d.v.x *= drag; d.v.z *= drag; d.v.y = d.v.y * drag + 0.18 * P.dustRise * dt;
      d.m.position.addScaledVector(d.v, dt); const fy = d.s0 * 0.6; if (d.m.position.y < fy) { d.m.position.y = fy; if (d.v.y < 0) d.v.y = 0; }
      d.m.rotation.x += d.spin.x * dt; d.m.rotation.y += d.spin.y * dt; d.m.rotation.z += d.spin.z * dt;
      const pop = t < 0.22 ? 1 - Math.pow(1 - t / 0.22, 3) : 1, shrink = t > 0.45 ? Math.max(0, 1 - (t - 0.45) / 0.55) : 1;
      d.m.scale.setScalar(Math.max(0.0001, d.s0 * (0.35 + pop + 0.7 * t) * shrink)); return true;
    });
  }
  // squash on whatever was hit (local y is the plate's axis)
  flSquashTick(o, dt) {
    const q = o.userData.squash; if (!q) return;
    q.t += dt; const a = q.amp * Math.exp(-q.t * 9) * Math.cos(q.t * 34);
    o.scale.set(1 + a * 0.45, 1 - a, 1 + a * 0.45); if (q.t > 0.6) { o.userData.squash = null; o.scale.set(1, 1, 1); }
  }
  // the camera after the scene: shake (trauma² × 0.1, a smooth thump) and the zoom punch
  flCamFx(dt, now) {
    const F = this.FL, cam = F.cam, P = this.PHYS;
    const s = (this.flTrauma || 0) ** 2 * P.shake, off = new this.THREE.Vector3();
    if (s > 0.0001) { const tt = now, k = 0.05 * s; off.set((Math.sin(tt * 31) * 0.7 + Math.sin(tt * 17.3 + 0.7) * 0.3) * k, (Math.sin(tt * 37.7 + 1.3) * 0.7 + Math.sin(tt * 13.1 + 2.2) * 0.3) * k, Math.sin(tt * 29.3 + 2.1) * k * 0.4); }
    this.flTrauma = Math.max(0, (this.flTrauma || 0) - dt * 2.6);
    const kick = this.flFovKick || 0; this.flFovKick = kick * Math.exp(-7 * dt);
    return { off, fov: (this.flFov || cam.fov) * (1 - kick) };
  }

  // ---- C: orange or the light purple of the other scenes ----
  flToggleBg() {
    const F = this.FL; if (!F) return;
    this.flBgAlt = !this.flBgAlt;
    const bg = this.flBgAlt ? this.pal.boxLight : this.pal.bgColor, ink = this.flBgAlt ? this.pal.boxDark : this.pal.boxLight;
    this.FC.bg = bg; F.L.style.background = bg; F.q.style.color = ink; F.sw.style.color = ink;
  }
  // a crisp "check" when you move on
  flCheckSound() {
    const ac = this.flAudio(); if (!ac) return; if (ac.state === 'suspended') { try { ac.resume(); } catch (e) {} }
    const now = ac.currentTime;
    [[1320, 0], [1980, 0.055]].forEach(([fq, dl]) => {
      const o = ac.createOscillator(), g = ac.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(fq, now + dl);
      g.gain.setValueAtTime(0.0001, now + dl); g.gain.exponentialRampToValueAtTime(0.22, now + dl + 0.006); g.gain.exponentialRampToValueAtTime(0.0001, now + dl + 0.09);
      o.connect(g).connect(ac.destination); o.start(now + dl); o.stop(now + dl + 0.1);
    });
  }
  flSwipe(fn) {
    const F = this.FL, go = () => { this.flCheckSound(); fn(); };
    F.swipe = true; F.onSwipe = go; F.onTap = () => { this.buzz('light'); go(); }; F.sw.style.display = 'block';
  }

  // ---------------- 7 · the kit, with the Physics canvas's world and grab ----------------
  flKit(mid) {
    const F = this.FL, T = this.THREE, P = this.plan, PH = this.PHYS; if (!P) { this.flGo('wod'); return; }
    this.flStep = 'kit';
    this.flCam([0, 5.0, 5.0], [0, -1.15, -0.75], 35);
    const C = window.PlateKit.CANNON, w = new C.World({ gravity: new C.Vec3(0, -PH.gravity, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = PH.iterations; w.solver.tolerance = PH.tolerance;
    const mP = new C.Material('plate'), mG = new C.Material('ground');
    w.addContactMaterial(new C.ContactMaterial(mP, mG, PH.pg)); w.addContactMaterial(new C.ContactMaterial(mP, mP, PH.pp));
    const ground = new C.Body({ mass: 0, material: mG }); ground.addShape(new C.Plane()); ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0); w.addBody(ground);
    [[0, -3.1, 3.2, 0.2], [0, 1.3, 3.2, 0.2], [-1.65, -0.9, 0.2, 2.6], [1.65, -0.9, 0.2, 2.6]].forEach(([x, z, hx, hz]) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(new C.Box(new C.Vec3(hx, 1.5, hz))); b.position.set(x, 1.5, z); w.addBody(b); });
    this.flWorld = w;
    // the grab: a critically-damped spring at the point you grabbed (k 260, ζ 0.85, capped at 140 m/s² × mass)
    const tR = new C.Vec3(), tW = new C.Vec3(), tV = new C.Vec3(), tF = new C.Vec3();
    w.addEventListener('preStep', () => {
      const gr = F.grab; if (!gr) return;
      const b = gr.b; b.pointToWorldFrame(gr.local, tW); tW.vsub(b.position, tR); b.angularVelocity.cross(tR, tV); tV.vadd(b.velocity, tV);
      const m = b.mass, k = PH.grabK, c = 2 * Math.sqrt(k) * PH.grabZeta;
      tF.set(m * (k * (gr.to.x - tW.x) - c * tV.x), m * (k * (gr.to.y - tW.y) - c * tV.y - w.gravity.y), m * (k * (gr.to.z - tW.z) - c * tV.z));
      const mx = m * PH.grabMaxF, len = tF.length(); if (len > mx) tF.scale(mx / len, tF);
      b.applyForce(tF, tR);
    });
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.22 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const sp = this.specs(), kit = P.kit, n = kit.length, cols = Math.min(3, Math.max(1, n)), rows = Math.ceil(n / cols), gx = 0.66, gz = 0.66, items = [];
    kit.forEach((k, i) => {
      const s = sp.find((q) => q.kg === k.w); if (!s) return;
      const cx = (i % cols - (cols - 1) / 2) * gx, cz = (Math.floor(i / cols) - (rows - 1) / 2) * gz - 0.45;
      for (let j = 0; j < k.qty; j++) {
        const g = this.plate(s), o = new T.Group(); o.add(g); g.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
        o.visible = false; this.flAdd(o);
        const R = s.d / 2, t = s.t, mass = s.unit === 'LB' ? s.kg * 0.4536 : s.kg, it = { o, g, R, t, mass, s };
        items.push(it);
        this.flLater(() => {
          if (this.flWorld !== w) return;
          const b = new C.Body({ mass, material: mP, linearDamping: PH.linDamp, angularDamping: PH.angDamp, sleepSpeedLimit: PH.sleepSpeed, sleepTimeLimit: PH.sleepTime });
          b.addShape(new C.Cylinder(R, R, t, 28));
          const Ix = mass * (3 * R * R + t * t) / 12, Iy = 0.5 * mass * R * R; b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
          b.position.set(cx + (Math.random() - 0.5) * 0.1, 4.5 + j * 0.4 + Math.random() * 0.6, cz + (Math.random() - 0.5) * 0.1);
          b.quaternion.setFromEuler(Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI);
          b.angularVelocity.set((Math.random() - 0.5) * 4, (Math.random() - 0.5) * 4, (Math.random() - 0.5) * 4);
          b.addEventListener('collide', (e) => {
            if (e.body !== ground) return;   // only floor hits shake and raise dust
            const ax = b.quaternion.vmult(new C.Vec3(0, 1, 0)), flat = Math.abs(ax.y) > 0.7, c = e.contact, ri = c.bi === b ? c.ri : c.rj;
            this.flImpact({ m: mass, v: Math.abs(c.getImpactVelocityAlongNormal()), x: flat ? b.position.x : b.position.x + ri.x, z: flat ? b.position.z : b.position.z + ri.z, R, flat, target: g });
          });
          w.addBody(b); it.b = b; o.visible = true;
        }, (mid ? 100 : 250) + i * 170 + j * 90);
      }
    });
    F.tick = (dt) => {
      if (this.flWorld !== w) return;
      w.step(1 / 120, dt, 8);
      items.forEach((it) => { if (!it.b) return; it.o.position.copy(it.b.position); it.o.quaternion.copy(it.b.quaternion); this.flSquashTick(it.g, dt); });
    };
    F.hit = (e) => {
      const rc = this.flRay(e); let hit = null, bd = 1e9;
      items.forEach((it) => { if (!it.b) return; const d = rc.ray.distanceToPoint(it.o.position); if (d < it.R * 1.1 && d < bd) { bd = d; hit = it; } });
      if (!hit) return null;
      this.buzz('selection'); this.flAudio();
      const b = hit.b; b.wakeUp();
      const pt = rc.ray.closestPointToPoint(hit.o.position, new T.Vector3());
      const local = b.pointToLocalFrame(new C.Vec3(pt.x, pt.y, pt.z));
      const planeY = Math.max(pt.y, 0.03) + 0.35, plane = new T.Plane(new T.Vector3(0, 1, 0), -planeY), p = new T.Vector3();
      const G = F.grab = { b, local, to: new T.Vector3(pt.x, planeY, pt.z) }; b.angularDamping = PH.grabAngDamp;
      return {
        move: (ev) => { if (this.flRay(ev).ray.intersectPlane(plane, p)) G.to.set(Math.max(-1.45, Math.min(1.45, p.x)), planeY, Math.max(-2.9, Math.min(1.1, p.z))); },
        up: () => { F.grab = null; b.angularDamping = PH.angDamp; }
      };
    };
    const c = this.flCard(), got = this.d.kitGot = this.d.kitGot || {};
    const wrap = this.fh('div', { display: 'flex', flexWrap: 'wrap', gap: '8px' }, c);
    kit.forEach((k) => {
      const s = sp.find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
      const bt = this.fh('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', borderRadius: '999px', border: '2px solid ' + this.FC.dark, fontFamily: 'inherit', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }, wrap);
      bt.className = 'tap'; bt.setAttribute('role', 'checkbox');
      this.fh('span', { width: Math.round(10 + s.d * 14) + 'px', height: Math.round(10 + s.d * 14) + 'px', borderRadius: '50%', background: s.color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.2)' }, bt);
      this.fh('span', {}, bt, k.qty + ' × ' + this.fmt(k.w) + ' ' + P.unit);
      const paint = () => { const on = !!got[k.w]; bt.style.background = on ? this.FC.dark : 'transparent'; bt.style.color = on ? this.FC.light : this.FC.dark; bt.setAttribute('aria-checked', String(on)); };
      paint(); bt.onclick = () => { if (got[k.w]) delete got[k.w]; else { got[k.w] = true; this.buzz('light'); } paint(); };
    });
    c.style.bottom = '84px';
    this.flLater(() => { if (this.flStep === 'kit') this.flSwipe(() => this.flGo('sets')); }, 900);
  }

  // ---------------- 8 · sets: the end of the bar, orbit a little; swipe up/down between sets ----------------
  flSets() {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flStep = 'sets';
    this.flCam([2.45, 1.25, 1.75], [0.78, 0.8, -0.08], 40);
    const rest = { P: new T.Vector3(2.45, 1.25, 1.75), T: new T.Vector3(0.78, 0.8, -0.08) };   // aimed below the bar, so it sits higher on screen
    const bar = new T.Group();
    const steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 20), m); c.rotation.z = Math.PI / 2; c.position.x = x; c.castShadow = true; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); cyl(0.03, 0.02, steel, s * 1.105); });
    bar.position.y = 0.9; this.flAdd(bar);
    this.flBar = { bar, on: [], side: [], y: 0.9 };
    // orbit: yaw and a little pitch around the sleeve end, easing back when you let go
    const orb = this.flOrb = { yaw: 0, pitch: 0, ty: 0, tp: 0, drag: false };
    const off0 = rest.P.clone().sub(rest.T), sph = new T.Spherical().setFromVector3(off0);
    F.tick = (dt) => {
      const B = this.flBar; if (!B) return;
      if (!orb.drag) { orb.ty *= Math.exp(-dt * 2.5); orb.tp *= Math.exp(-dt * 2.5); }
      orb.yaw += (orb.ty - orb.yaw) * (1 - Math.exp(-dt * 10)); orb.pitch += (orb.tp - orb.pitch) * (1 - Math.exp(-dt * 10));
      const s2 = new T.Spherical(sph.radius, Math.max(0.35, Math.min(Math.PI - 0.35, sph.phi - orb.pitch)), sph.theta + orb.yaw);
      F.cam.position.copy(rest.T).add(new T.Vector3().setFromSpherical(s2)); F.cam.lookAt(rest.T);
      B.on.forEach((m) => {
        m.t += dt;
        if (m.out) { const q = Math.min(1, m.t / 0.3); m.o.position.x = m.x + m.sg * 0.9 * q * q; m.o.position.y = B.y - 0.8 * Math.max(0, q - 0.5); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.6) / 0.4)); if (q >= 1) { F.S.remove(m.o); m.gone = true; } return; }
        const q = Math.min(1, Math.max(0, (m.t - m.dl) / 0.34)); m.o.visible = m.t >= m.dl;
        m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * this.outCubic(q); m.o.position.y = B.y;
        if (q >= 1 && !m.seat) { m.seat = true; this.flClick(0.45); this.buzz('light'); }
      });
      B.on = B.on.filter((m) => !m.gone);
    };
    // one gesture handler for the whole screen: sideways drag orbits; a quick vertical swipe changes the set; a tap moves on
    F.hit = (e) => {
      const sx = e.clientX, sy = e.clientY; let lx = sx, ly = sy; orb.drag = true;
      return {
        move: (ev) => { const dx = ev.clientX - lx, dy = ev.clientY - ly; lx = ev.clientX; ly = ev.clientY;
          if (Math.abs(ev.clientX - sx) > Math.abs(ev.clientY - sy) * 0.8) { orb.ty = Math.max(-0.7, Math.min(0.7, orb.ty - dx * 0.006)); orb.tp = Math.max(-0.25, Math.min(0.25, orb.tp + dy * 0.003)); } },
        up: (ev, tap) => {
          orb.drag = false;
          const dx = ev.clientX - sx, dy = ev.clientY - sy;
          if (tap) { this.flSetGo(1, true); return; }
          if (Math.abs(dy) > 55 && Math.abs(dy) > Math.abs(dx) * 1.3) this.flSetGo(dy < 0 ? 1 : -1, false);
        }
      };
    };
    F.swipe = false; F.onSwipe = null; F.onTap = null;
    this.flLoad(this.setIdx);
    this.flSetCard(0);
  }
  // move between sets: forward marks the set done; back from the first set returns to the plates
  flSetGo(dir, tap) {
    const P = this.plan; if (!P) return;
    const n = P.flat.length, i = this.setIdx;
    if (dir > 0) {
      if (i >= n - 1) return;   // the last set ends with its button
      this.doneSets[i] = true; this.flCheckSound(); this.buzz('success');
      this.setIdx = i + 1; this.flSetCard(1); this.flLater(() => { if (this.flBar) this.flLoad(this.setIdx); }, 250);
    } else {
      this.flCheckSound(); this.buzz('light');
      if (i === 0) { this.flClear(); this.flKit(true); return; }
      this.setIdx = i - 1; this.doneSets[this.setIdx] = false; this.flSetCard(-1); this.flLater(() => { if (this.flBar) this.flLoad(this.setIdx); }, 250);
    }
  }
  flSetCard(dir) {
    const F = this.FL, P = this.plan, i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    const last = i >= P.flat.length - 1;
    const old = F.ui.querySelector('[data-setcard]');
    if (old) { old.removeAttribute('data-setcard'); old.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(' + (dir < 0 ? 60 : -60) + 'px)', opacity: 0 }], { duration: 260, easing: 'ease-in', fill: 'forwards' }); setTimeout(() => old.remove(), 270); }
    const c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px 18px 18px', borderRadius: '22px', background: '#FFFFFF', color: '#000000', fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 10px 30px rgba(0,0,0,0.18)' }, F.ui);
    c.setAttribute('data-setcard', '');
    c.animate([{ transform: dir ? 'translateY(' + (dir < 0 ? -70 : 70) + 'px)' : 'translateY(120%)', opacity: dir ? 0 : 1 }, { transform: 'none', opacity: 1 }], { duration: dir ? 320 : 420, delay: dir ? 120 : 0, easing: 'cubic-bezier(.2,.9,.25,1)', fill: 'backwards' });
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'rgba(0,0,0,0.5)' }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 12px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? '#000000' : 'rgba(0,0,0,0.12)' }, dots); });
    if (last) {
      const b = this.fh('button', { width: '100%', height: '56px', marginTop: '16px', border: 0, borderRadius: '16px', background: '#000000', color: '#FFFFFF', fontFamily: 'inherit', fontWeight: 900, fontSize: '19px', cursor: 'pointer' }, c, 'End session');
      b.className = 'tap'; b.onclick = () => { this.flCheckSound(); this.buzz('success'); this.doneSets[this.setIdx] = true; this.flFinish(); };
    }
    F.sw.style.display = last ? 'none' : 'block'; F.sw.style.bottom = '196px';
  }
