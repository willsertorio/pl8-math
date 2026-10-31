
  // ===================== FLOW, round 4 =====================
  // no swipe arrow anywhere
  flSwipe(fn) {
    const F = this.FL, go = () => { this.flCheckSound(); fn(); };
    F.swipe = true; F.onSwipe = go; F.onTap = () => { this.buzz('light'); go(); }; F.sw.style.display = 'none';
  }
  // C: orange, or the light purple as a studio, with a fine grid
  flToggleBg() {
    const F = this.FL; if (!F) { this.flBgAlt = !this.flBgAlt; this.flBgPending = true; return; }
    if (this.flBgPending) { this.flBgPending = false; } else this.flBgAlt = !this.flBgAlt;
    const bg = this.flBgAlt ? this.pal.boxLight : this.pal.bgColor, ink = this.flBgAlt ? this.pal.boxDark : this.pal.boxLight;
    this.FC.bg = bg; F.L.style.background = bg; F.q.style.color = ink; F.sw.style.color = ink;
    const g = 'rgba(108,55,19,0.09)';
    F.L.style.backgroundImage = this.flBgAlt ? 'radial-gradient(ellipse at 50% 55%, rgba(255,255,255,0.55), rgba(255,255,255,0) 70%), linear-gradient(' + g + ' 1px, transparent 1px), linear-gradient(90deg, ' + g + ' 1px, transparent 1px)' : 'none';
    F.L.style.backgroundSize = this.flBgAlt ? '100% 100%, 26px 26px, 26px 26px' : '';
    F.L.style.backgroundPosition = this.flBgAlt ? 'center, center, center' : '';
  }
  flInk() { return this.flBgAlt ? this.pal.boxDark : this.pal.boxLight; }
  flLinks(list, top) {
    const F = this.FL, row = this.fh('div', { position: 'absolute', left: 0, right: 0, top: top || '74%', display: 'flex', justifyContent: 'center', gap: '28px', pointerEvents: 'auto' }, F.ui);
    list.forEach(([label, fn], i) => {
      const b = this.fh('button', { border: 0, background: 'none', padding: '10px 6px', color: this.flInk(), fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 800, fontSize: '17px', textDecoration: 'underline', textUnderlineOffset: '4px', cursor: 'pointer' }, row, label);
      b.className = 'tap'; b.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 300, delay: 700 + i * 90, fill: 'backwards' });
      b.onclick = () => { this.buzz('light'); this.flCheckSound(); fn(); };
    });
  }

  // ---------------- 3 · kettlebells: drop them anywhere; on the square it sinks like a scale ----------------
  flUnit() {
    const F = this.FL, T = this.THREE, name = this.d.name || '79';
    this.flCam([0, 6.2, 10.4], [0, -0.35, 0.45], 35);
    this.flSay('Cool. Let’s set ' + name + '. Do they use kilos or pounds there?');
    const sq = new T.Group(), SZ = 1.25, th = 0.06, SQ = [0, 1.55];
    const Ml = new T.MeshBasicMaterial({ color: this.flInk() });
    [[0, -SZ / 2, SZ + th, th], [0, SZ / 2, SZ + th, th], [-SZ / 2, 0, th, SZ], [SZ / 2, 0, th, SZ]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.02, d), Ml); m.position.set(x, 0.01, z); sq.add(m); });
    sq.position.set(SQ[0], 0, SQ[1]); this.flAdd(sq); this.popIn(sq, 900);
    const bells = [['KG', 'kg', -0.95], ['LB', 'lb', 0.95]].map(([lab, u, x], i) => {
      const g = this.kettlebell(lab), sh = this.softShadow(0.62); g.position.set(x, 0, -0.55); sh.position.set(x, 0.003, -0.55);
      this.flAdd(g); this.flAdd(sh); this.popIn(g, 600 + i * 140);
      return { g, sh, u };
    });
    let done = false, onSq = null;
    const shadowAt = (b) => { b.sh.position.set(b.g.position.x, 0.003, b.g.position.z); const s = 1 + Math.max(0, b.g.position.y) * 0.5; b.sh.scale.setScalar(s); b.sh.material.opacity = 1 / (s * s); };
    const inSq = (p) => Math.abs(p.x - SQ[0]) < SZ / 2 && Math.abs(p.z - SQ[1]) < SZ / 2;
    F.tick = () => { if (onSq) { onSq.g.position.y = sq.position.y; shadowAt(onSq); } };
    F.hit = (e) => {
      if (done) return null;
      const rc = this.flRay(e), b = bells.find((q) => rc.intersectObject(q.g, true).length); if (!b) return null;
      this.buzz('selection'); this.flAudio();
      const GY = -0.42, off = new T.Vector3(); { const p = this.flPlane(e, new T.Vector3(0, 1, 0), GY); if (p) off.copy(b.g.position).sub(p); off.y = 0; }
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 1, 0), GY); if (!p) return;
          const x = Math.max(-1.55, Math.min(1.55, p.x + off.x)), z = Math.max(-1.6, Math.min(2.4, p.z + off.z));
          b.g.position.set(x, 0.42, z); b.g.rotation.z = Math.max(-0.25, Math.min(0.25, ((x - b.lx) || 0) * -1.5)); b.lx = x; shadowAt(b); },
        up: () => {
          // it falls where you let go
          const from = b.g.position.clone(), r0 = b.g.rotation.z, hitSq = inSq(from);
          this.flAnim((u) => { b.g.position.y = from.y * (1 - u * u); b.g.rotation.z = r0 * (1 - u); shadowAt(b); }, 0.26, () => {
            this.flImpact({ m: 16, v: 4.2, x: from.x, z: from.z, R: 0.3, target: null });
            this.flPhysDust(from.x, from.z, 260, 2.6, 0.32, 1.6);     // a visible puff on top of the canvas's subtle one
            const g = b.g; this.flAnim((u) => { const s = 1 + 0.14 * Math.sin(u * Math.PI) * (1 - u); g.scale.set(1 + (s - 1) * 0.6, 1 - (s - 1), 1 + (s - 1) * 0.6); }, 0.35);
            if (!hitSq) return;
            // on the square: the platform sinks into the floor like a scale, bounces and settles
            done = true; onSq = b; this.buzz('success');
            this.flAnim((u) => { sq.position.y = -0.14 * (1 - Math.exp(-u * 6) * Math.cos(u * 14)); }, 1.1);
            this.setUnit(b.u);
            this.flLater(() => { if (this.flStep === 'unit') { this.flCheckSound(); this.flGo('plates'); } }, 1300);
          });
        }
      };
    };
  }

  // ---------------- 5 · PRs: a notebook to tap (upload); type or skip under it ----------------
  notebookModel(title) {
    const T = this.THREE, g = new T.Group(), W = 1.05, H = 1.4, D = 0.1;
    const c = document.createElement('canvas'); c.width = 512; c.height = 680; const x = c.getContext('2d');
    x.fillStyle = this.pal.boxDark; x.fillRect(0, 0, 512, 680);
    x.fillStyle = 'rgba(255,255,255,0.07)'; for (let i = 0; i < 680; i += 6) x.fillRect(0, i, 512, 2);
    x.fillStyle = this.pal.boxLight; x.fillRect(70, 230, 372, 170);
    x.fillStyle = this.pal.boxDark; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '400 92px "Permanent Marker", "Comic Sans MS", cursive'; x.fillText(title, 256, 318);
    const tex = new T.CanvasTexture(c); tex.colorSpace = T.SRGBColorSpace; tex.anisotropy = 4;
    const cover = this.toon('#FFFFFF'); cover.map = tex;
    const side = this.toon(this.pal.boxDark), pages = this.toon('#F6F2EA');
    const book = new T.Mesh(new T.BoxGeometry(W, H, D), [pages, side, pages, pages, cover, side]); g.add(book);
    // the spiral down the left edge
    const ring = new T.TorusGeometry(0.055, 0.012, 6, 12), rm = this.toon('#C9CED4');
    g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    return g;
  }
  flPRs() {
    const F = this.FL, T = this.THREE;
    this.flCam([0, 0.6, 6.4], [0, 0.05, 0], 35);
    this.flSay('Alright. And what are your PRs?');
    const nb = this.notebookModel('MY PRs'); nb.rotation.set(-0.28, 0.18, 0.06); this.flAdd(nb); this.popIn(nb, 450);
    const sh = this.softShadow(0.6); sh.position.set(0, -0.95, 0); sh.scale.set(1, 0.5, 1); this.flAdd(sh); this.popIn(sh, 450);
    const fill = () => { this.d.prs.forEach((q) => { if (q[1] == null) q[1] = this.demoPR(q); }); };
    F.tick = (dt, t) => { nb.position.y = 0.06 * Math.sin(t * 1.4); nb.rotation.y = 0.18 + 0.08 * Math.sin(t * 0.7); };
    F.hit = (e) => {
      if (!this.flRay(e).intersectObject(nb, true).length) return null;
      return { up: (ev, tap) => { if (!tap) return; this.buzz('light'); this.flCheckSound();
        this.flAnim((u) => nb.scale.setScalar(1 - 0.08 * Math.sin(u * Math.PI)), 0.25);
        this.photoPicker('pr', () => { this.closeSheet(); this.reading('Reading your PRs…', () => { this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); this.flGo('wod'); }); }, () => {}); } };
    };
    this.flLinks([['Type them', () => this.flGo('prDial')], ['Skip', () => { fill(); this.flGo('wod'); }]], '80%');
  }

  // ---------------- 6 · today's workout: the whiteboard is pushed in; tap it to take a photo ----------------
  whiteboardModel() {
    const T = this.THREE, g = new T.Group(), BW = 1.7, BH = 1.1, Y = 1.45, K = this.toon(this.pal.boxDark);
    const c = document.createElement('canvas'); c.width = 1024; c.height = 662; const tex = new T.CanvasTexture(c); tex.colorSpace = T.SRGBColorSpace; tex.anisotropy = 4;
    const face = new T.MeshBasicMaterial({ map: tex });
    const board = new T.Mesh(new T.BoxGeometry(BW, BH, 0.04), [K, K, K, K, face, K]); board.position.y = Y; g.add(board);
    const fr = (w, h, x, y) => { const m = new T.Mesh(new T.BoxGeometry(w, h, 0.07), K); m.position.set(x, y, 0); g.add(m); };
    fr(BW + 0.1, 0.06, 0, Y + BH / 2); fr(BW + 0.1, 0.06, 0, Y - BH / 2); fr(0.06, BH, -BW / 2, Y); fr(0.06, BH, BW / 2, Y);
    const tray = new T.Mesh(new T.BoxGeometry(BW * 0.6, 0.03, 0.12), K); tray.position.set(0, Y - BH / 2 - 0.04, 0.06); g.add(tray);
    const wheels = [];
    [-1, 1].forEach((s) => {
      const leg = new T.Mesh(new T.BoxGeometry(0.05, Y + 0.05, 0.05), K); leg.position.set(s * (BW / 2 - 0.05), (Y + 0.05) / 2 + 0.05, 0); g.add(leg);
      const foot = new T.Mesh(new T.BoxGeometry(0.06, 0.05, 0.62), K); foot.position.set(s * (BW / 2 - 0.05), 0.09, 0); g.add(foot);
      [-1, 1].forEach((z) => { const w = new T.Mesh(new T.CylinderGeometry(0.05, 0.05, 0.04, 10), this.toon('#333333')); w.rotation.z = Math.PI / 2; w.position.set(s * (BW / 2 - 0.05), 0.05, z * 0.27); g.add(w); wheels.push(w); });
    });
    g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    g.userData = { tex, c, wheels, board };
    this.flDrawBoard(g, null);
    return g;
  }
  flDrawBoard(g, plan) {
    const { c, tex } = g.userData, x = c.getContext('2d'), W = c.width, H = c.height, F = '"Permanent Marker", "Comic Sans MS", cursive';
    x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, W, H);
    x.fillStyle = '#111111'; x.strokeStyle = '#111111';
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
    this.flSay(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?');
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.18 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const wb = this.whiteboardModel(); this.flAdd(wb);
    // pushed in from the side: it rolls, stops, rocks once
    wb.position.x = 3.6; wb.rotation.y = -0.18;
    this.flLater(() => {
      this.flClick(0.5);
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); wb.position.x = 3.6 * (1 - e); wb.rotation.y = -0.18 * (1 - e); wb.userData.wheels.forEach((w) => { w.rotation.x = -(1 - e) * 40; }); }, 0.95, () => {
        this.flAnim((u) => { wb.rotation.z = 0.05 * Math.exp(-u * 5) * Math.sin(u * 16); }, 0.9);
      });
    }, 350);
    let busy = false;
    const ready = () => {
      // the plan goes on the board, then we zoom into it and on to the plates
      this.plan = this.workoutPlan(); this.setIdx = 0; this.doneSets = []; this.d.kitGot = {};
      this.flDrawBoard(wb, this.plan);
      this.flLater(() => {
        const cam = F.cam, P0 = cam.position.clone(), T0 = new T.Vector3(0, 1.35, 0), T1 = new T.Vector3(0, 1.45, 0), P1 = new T.Vector3(0, 1.45, 0.75), tgt = new T.Vector3();
        this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; cam.position.lerpVectors(P0, P1, e); tgt.lerpVectors(T0, T1, e); cam.lookAt(tgt); }, 1.15, () => {
          this.flCheckSound(); this.flGo('kit');
        });
      }, 1100);
    };
    F.hit = (e) => {
      if (busy || !this.flRay(e).intersectObject(wb, true).length) return null;
      return { up: (ev, tap) => { if (!tap || busy) return; this.buzz('light'); this.flCheckSound();
        this.scanner({ title: 'Scan the workout', onCancel: () => {}, onCapture: () => { busy = true; ready(); }, draw: (x) => {
          const gr = x.createLinearGradient(0, 0, 780, 1000); gr.addColorStop(0, '#E9E6DF'); gr.addColorStop(1, '#CFCAC0'); x.fillStyle = gr; x.fillRect(0, 0, 780, 1000);
          x.fillStyle = '#B9B3A8'; x.fillRect(0, 0, 780, 30); x.fillRect(0, 970, 780, 30);
          x.fillStyle = '#1F3A73'; x.font = '64px "Permanent Marker", cursive'; x.fillText('WOD', 60, 150);
          x.font = '52px "Permanent Marker", cursive';
          this.d.wod.forEach((w, i) => { x.fillText(w.lift, 60, 300 + i * 200); x.fillText(w.sets + 'x' + w.reps + ' @ ' + w.pct + '%', 100, 370 + i * 200); });
          return { count: this.d.wod.length, top: 26, gap: 20, h: 14, widths: this.d.wod.map(() => 70) };
        } }); } };
    };
    this.flLinks([['Upload a screenshot', () => { if (busy) return; this.photoPicker('wod', () => { this.closeSheet(); busy = true; this.reading('Reading your workout…', ready); }, () => {}); }]], '80%');
  }

  // ---------------- 7 · the kit: piles drop one plate at a time, neat and countable ----------------
  flKitLayout(kit, sp) {
    // heaviest on the left; one pile per size, spaced by their size; wraps to a second row if wide
    const piles = kit.map((k) => ({ k, s: sp.find((q) => q.kg === k.w) })).filter((p) => p.s);
    const rows = [[]], gap = 0.14, maxW = 1.95; let w = 0;
    piles.forEach((p) => { const d = p.s.d; if (w + d > maxW && rows[rows.length - 1].length) { rows.push([]); w = 0; } rows[rows.length - 1].push(p); w += d + gap; });
    rows.forEach((r, ri) => {
      const tw = r.reduce((a, p) => a + p.s.d, 0) + gap * (r.length - 1); let x = -tw / 2;
      const rowD = Math.max(...r.map((p) => p.s.d));
      r.forEach((p) => { p.x = x + p.s.d / 2; x += p.s.d + gap; p.z = 0.35 + (ri - (rows.length - 1) / 2) * (rowD + 0.22); });
    });
    return piles;
  }
  flKit(mid) {
    const F = this.FL, T = this.THREE, P = this.plan, PH = this.PHYS; if (!P) { this.flGo('wod'); return; }
    this.flStep = 'kit';
    this.flCam([0, 6.3, 5.57], [0, -1.3, -0.3], 35);
    const C = window.PlateKit.CANNON, w = new C.World({ gravity: new C.Vec3(0, -PH.gravity, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = PH.iterations; w.solver.tolerance = PH.tolerance;
    const mP = new C.Material('plate'), mG = new C.Material('ground');
    w.addContactMaterial(new C.ContactMaterial(mP, mG, PH.pg)); w.addContactMaterial(new C.ContactMaterial(mP, mP, PH.pp));
    const ground = new C.Body({ mass: 0, material: mG }); ground.addShape(new C.Plane()); ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0); w.addBody(ground);
    [[0, -3.1, 3.2, 0.2], [0, 1.3, 3.2, 0.2], [-1.65, -0.9, 0.2, 2.6], [1.65, -0.9, 0.2, 2.6]].forEach(([x, z, hx, hz]) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(new C.Box(new C.Vec3(hx, 1.5, hz))); b.position.set(x, 1.5, z); w.addBody(b); });
    this.flWorld = w;
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
    const sp = this.specs(), piles = this.flKitLayout(P.kit, sp), items = []; this.flKitItems = items;
    const placed = !!this.flKitPlaced; this.flKitPlaced = false;
    let order = 0;
    piles.forEach((pl) => {
      const s = pl.s, R = s.d / 2, t = s.t, mass = s.unit === 'LB' ? s.kg * 0.4536 : s.kg;
      for (let j = 0; j < pl.k.qty; j++) {
        const g = this.plate(s), o = new T.Group(); o.add(g); g.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
        o.visible = false; this.flAdd(o);
        const it = { o, g, R, t, mass, s }; items.push(it);
        // one after another, flat, straight down onto its pile — easy to count
        const drop = () => {
          if (this.flWorld !== w) return;
          const b = new C.Body({ mass, material: mP, linearDamping: PH.linDamp, angularDamping: PH.angDamp, sleepSpeedLimit: PH.sleepSpeed, sleepTimeLimit: PH.sleepTime });
          b.addShape(new C.Cylinder(R, R, t, 28));
          const Ix = mass * (3 * R * R + t * t) / 12, Iy = 0.5 * mass * R * R; b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
          // already laid out (coming back from the sets): resting in place; otherwise straight down onto its spot
          if (placed) { b.position.set(pl.x, t / 2 + 0.002, pl.z); b.quaternion.setFromEuler(0, pl.yaw || 0, 0); b.sleep(); }
          else { b.position.set(pl.x, 1.5 + j * (t + 0.01), pl.z); b.quaternion.setFromEuler((Math.random() - 0.5) * 0.04, pl.yaw != null ? pl.yaw : Math.random() * 6.28, (Math.random() - 0.5) * 0.04); }
          b.addEventListener('collide', (e) => {
            if (e.body !== ground) { if (!it.clicked && Math.abs(e.contact.getImpactVelocityAlongNormal()) > 1.5) { it.clicked = true; this.flClick(0.4); } return; }
            const ax = b.quaternion.vmult(new C.Vec3(0, 1, 0)), flat = Math.abs(ax.y) > 0.7, c = e.contact, ri = c.bi === b ? c.ri : c.rj;
            this.flImpact({ m: mass, v: Math.abs(c.getImpactVelocityAlongNormal()), x: flat ? b.position.x : b.position.x + ri.x, z: flat ? b.position.z : b.position.z + ri.z, R, flat, target: g });
          });
          w.addBody(b); it.b = b; o.visible = true; if (placed) { o.position.copy(b.position); o.quaternion.copy(b.quaternion); }
        };
        if (placed) drop(); else this.flLater(drop, (mid ? 100 : 300) + order * 150);
        order++;
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
    // the chips, on a white card
    const c = this.flCard(), got = this.d.kitGot = this.d.kitGot || {};
    Object.assign(c.style, { background: this.pal.card || '#FFFFFF', color: this.pal.boxDark, boxShadow: '0 10px 30px rgba(0,0,0,0.18)' });
    const wrap = this.fh('div', { display: 'flex', flexWrap: 'wrap', gap: '8px' }, c);
    P.kit.forEach((k) => {
      const s = sp.find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
      const bt = this.fh('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', borderRadius: '999px', border: '2px solid ' + this.pal.boxDark, fontFamily: 'inherit', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }, wrap);
      bt.className = 'tap'; bt.setAttribute('role', 'checkbox');
      this.fh('span', { width: Math.round(10 + s.d * 14) + 'px', height: Math.round(10 + s.d * 14) + 'px', borderRadius: '50%', background: s.color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.2)' }, bt);
      this.fh('span', {}, bt, k.qty + ' × ' + this.fmt(k.w) + ' ' + P.unit);
      const paint = () => { const on = !!got[k.w]; bt.style.background = on ? this.pal.boxDark : 'transparent'; bt.style.color = on ? this.pal.boxLight : this.pal.boxDark; bt.setAttribute('aria-checked', String(on)); };
      paint(); bt.onclick = () => { if (got[k.w]) delete got[k.w]; else { got[k.w] = true; this.buzz('light'); } paint(); };
    });
    c.style.bottom = '24px';
    // a drag anywhere off the plates previews where it goes: down to the board, up to the bar; a tap starts the session
    { const plateHit = F.hit, PV = this.flKitPreview(); F.hit = (e) => plateHit(e) || PV.drag(e); }
  }
