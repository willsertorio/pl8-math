
  // ---------------- smoothing pass (Oct 9): these override the Onboarding versions above ----------------
  // no on-screen "haptic" sign: a real buzz where the phone has one
  buzz(kind) {
    try { if (navigator.vibrate) navigator.vibrate(kind === 'success' ? [10, 40, 10] : kind === 'selection' ? 5 : 8); } catch (e) {}
  }
  // the box opens: walls that face the overview camera go all the way down, together with the front wall
  openBox() {
    const O = this.onb; O.phase = 'opening'; O.pt = 0; this.popG.visible = true;
    O.s0 = this.spinY; O.s1 = Math.round(this.spinY / (Math.PI * 2)) * Math.PI * 2;
    const P = this.SHOTS.overview.P, v = new this.THREE.Vector3(P[0], P[1], P[2]);
    this.wallDown = this.walls.map((w) => v.clone().sub(w.p).dot(w.n) < 0);
  }
  poseBox(k, lift, lidUp) {
    const H = this.H, C = this.CUBE, D = this.wallDown;
    this.wallMeshes.forEach((w, i) => {
      if (D && D[i]) { w.scale.y = Math.max(0.001, k * C / H); w.visible = k > 0.002; }
      else { w.scale.y = (H + (C - H) * k) / H; w.visible = true; }
    });
    this.frontWall.visible = k > 0.002; this.frontWall.scale.y = Math.max(0.001, k * C / H);
    this.lid.visible = lidUp < 30; this.lid.position.y = C + 0.075 + lidUp;
    this.slab.visible = true; this.thinFloor.visible = false;
    this.boxP = k;
    this.root.position.y = lift;
  }
  // after the box: walls back to room height (the cut-away hides the ones in front of the camera)
  endOpening() {
    this.wallDown = null;
    this.wallMeshes.forEach((w) => { w.scale.y = 1; w.visible = true; });
    (this.sceneProps || []).forEach((q) => { if (q.y0 != null) { q.obj.position.y = q.y0; } });
  }
  // the room is furnished before the box opens (platform, rack, chalk, notebook, fan);
  // only the whiteboard rolls in and the bench is tossed in, together
  setFurnished() {
    const PI = Math.PI;
    this.cutLines.forEach((m) => { m.visible = false; });
    this.flipG.rotation.x = PI; this.flipG.position.y = -0.02; this.flipG.scale.set(1, 1, 1);
    this.well.visible = false;
    this.rackG.visible = true; this.rackG.position.y = 0;
    if (this.onb) { this.onb.rackT = -100; this.onb.fired.rackLand = 1; }
    if (this.chalkG && this.CHALK) { this.chalkG.visible = true; this.chalkG.position.set(this.CHALK[0], 0, this.CHALK[1]); this.chalkG.rotation.set(0, 0, 0); }
    if (this.notebookG && this.NB) { this.notebookG.visible = true; this.notebookG.position.set(this.NB[0], this.NB[1], this.NB[2]); this.notebookG.rotation.set(0, 0, 0); }
    if (this.fanG) { this.fanG.visible = !this.noFloorFan; this.fanG.scale.setScalar(1); }
  }
  furnish(PT) {
    const PI = Math.PI, cl = (x) => Math.min(1, Math.max(0, x)), O = this.onb;
    const outCubic = (x) => 1 - Math.pow(1 - cl(x), 3);
    const wob = (since, amp, k = 4.5, w = 15) => since < 0 ? 0 : amp * Math.exp(-since * k) * Math.sin(since * w);
    if (!O.fired.furnished) { O.fired.furnished = 1; this.setFurnished(); this.setClip(false); }
    const g0 = 0.15, bx = (PT - g0) / 1.1, bk = outCubic(bx), B = this.BOARD;
    this.boardG.visible = PT > g0;
    this.boardG.position.set(B[0] - (1 - bk) * 1.2, 0, B[1] + (1 - bk) * 3.6);
    this.boardG.rotation.set(wob(PT - g0 - 1.1, 0.07, 4, 16), this.BOARD_RY + (1 - bk) * PI * 1.25, 0);
    this.wheels.forEach((w) => { w.rotation.x = -(1 - bk) * 110; });
    const BN = this.BENCH, b0 = g0 + 0.1, dur = 0.85, x = (PT - b0) / dur, v = cl(x), o = this.benchG;
    const from = [BN[0] + 3.0, 1.2, BN[1] + 2.6], to = [BN[0], 0, BN[1]];
    o.visible = x >= 0;
    o.position.set(from[0] + (to[0] - from[0]) * v, from[1] * (1 - v) + to[1] * v + 2.0 * 4 * v * (1 - v), from[2] + (to[2] - from[2]) * v);
    const since = PT - b0 - dur;
    o.rotation.set(wob(since, 0.11, 5, 17), this.CHAIR_RY - 2.2 * (1 - v), wob(since + 0.05, 0.077, 5, 21));
    if (x >= 1 && !O.fired.benchLand) { O.fired.benchLand = 1; this.emitDust(BN[0], BN[1], 26, 1.1, 0.4, 0.5); this.shakeKick(0.12); }
  }
  // the flag only ever billows out from the wall (it used to dip into it and vanish in places)
  poseFlag(e, t) {
    const F = this.flag, pos = F.geo.attributes.position, b = F.base, H = F.H;
    for (let i = 0; i < pos.count; i++) {
      const x = b[i * 3], y = b[i * 3 + 1], z = b[i * 3 + 2], sag = (H / 2 - y) / H, sg = Math.pow(Math.max(0, sag), 1.25);
      const w = 0.1 * sg * Math.sin(x * 5.2 - t * 7.4 + y * 2.4) + 0.035 * sag * Math.sin(x * 11.5 + t * 12.5 + y * 6);
      pos.setXYZ(i,
        x + e * 0.035 * sag * Math.sin(t * 4.6 + 0.8),
        y + e * 0.025 * sag * Math.sin(t * 6.3 + x * 3.1),
        z + e * (w + 0.1 * sg + 0.035 * Math.max(0, sag)) * this.flagOut());
    }
    pos.needsUpdate = true; F.geo.computeVertexNormals();
  }
  // which way is "away from the wall" in the cloth's own space (+1 or -1), found once
  flagOut() {
    if (this.flagOutS) return this.flagOutS;
    const T = this.THREE, cl = this.flagCloth, w = this.walls && this.walls[0];
    let s = 1;
    if (cl && this.walls) {
      cl.updateMatrixWorld(true);
      const p0 = cl.localToWorld(new T.Vector3(0, 0, 0)), p1 = cl.localToWorld(new T.Vector3(0, 0, 1)), d = p1.sub(p0);
      this.root.updateMatrixWorld(true);
      const inv = new T.Matrix4().copy(this.root.matrixWorld).invert(), pr = p0.clone().applyMatrix4(inv), dr = d.clone().transformDirection(inv);
      // the wall nearest the flag; its normal points into the room
      let best = null, bd = 1e9;
      this.walls.forEach((q) => { const dd = Math.abs(pr.clone().sub(q.p).dot(q.n)); if (dd < bd) { bd = dd; best = q; } });
      if (best) s = dr.dot(best.n) >= 0 ? 1 : -1;
    }
    this.flagOutS = s; return s;
  }

  // ---------------- the bar: crisp (no sketch wobble), and on the floor for pulls ----------------
  liftOnFloor(i) {
    const P = this.plan; if (!P || !P.flat || !P.flat[i]) return false;
    const x = P.flat[i], g = P.groups && P.groups[x.gi];
    return /dead|snatch|clean/i.test((x.group || '') + ' ' + ((g && (g.name || g.lift)) || ''));
  }
  barAim(i) {
    const floor = this.liftOnFloor(i), was = !!this.barGoal;
    this.barGoal = floor ? 1 : 0;
    if (was !== floor && this.onb && this.onb.phase === 'sets') this.camTo('setv', 1.1);
  }
  barTick(dt) {
    if (!this.barG) return;
    const O = this.onb, live = O && this.plan && (O.phase === 'sets' || O.phase === 'kit' || O.phase === 'complete');
    const goal = live ? (this.barGoal || 0) : 0;
    this.barF = this.barF == null ? 0 : this.barF;
    const sp = dt / 0.75; this.barF = goal > this.barF ? Math.min(goal, this.barF + sp) : Math.max(goal, this.barF - sp);
    const x = this.barF, e = x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
    if (!this.barHome) this.barHome = this.barG.position.clone();
    const PZ = this.PLAT ? this.PLAT[1] : 0, R = this.RACK || [0, 0];
    this.barDZ = PZ - (R[1] - 0.77);
    this.barYc = 1.265 + (0.225 - 1.265) * e; this.barE = e;
    this.barG.position.set(this.barHome.x, this.barHome.y + (this.barYc - 1.265), this.barHome.z + this.barDZ * e);
    if (goal === 1 && x >= 1 && !this.barLanded) { this.barLanded = true; this.shakeKick(0.08); const B = this.RACK || [0, 0]; this.emitDust(B[0], R[1] - 0.77 + this.barDZ, 30, 1.4, 0.3, 0.6); }
    if (x < 1) this.barLanded = false;
  }
  barPose(o, a, y) {
    const R = this.RACK || [0, 0], yb = this.barYc != null ? this.barYc : 1.265, e = this.barE || 0;
    const yy = 0.05 + (y - 0.05) * (yb - 0.05) / (1.265 - 0.05);
    o.position.set(a + R[0], yy, -0.77 + (this.barDZ || 0) * e + R[1]);
  }
  // the bar lives on layer 2 only: the room pass (layer 0) skips it, its shadow still falls
  layerBar() {
    this.barLayered = true;
    this.barG.traverse((o) => o.layers.set(2));
    this.scene.traverse((o) => { if (o.isLight) o.layers.enable(2); });
    if (this.sun && this.sun.shadow) this.sun.shadow.camera.layers.enable(2);
  }
  // the bar is drawn after the look pass, straight, over a depth-only copy of the room
  crispBar(camera) {
    const T = this.THREE, R = this.renderer, S = this.scene;
    if (!this.barLayered) this.layerBar();
    if (!this.depthOnly) this.depthOnly = new T.MeshBasicMaterial({ colorWrite: false });
    const ac = R.autoClear, bg = S.background, su = R.shadowMap.autoUpdate;
    R.autoClear = false; S.background = null; R.shadowMap.autoUpdate = false;
    R.clearDepth();
    camera.layers.set(this.dimK > 0.01 ? 1 : 0);
    S.overrideMaterial = this.depthOnly; R.render(S, camera); S.overrideMaterial = null;
    camera.layers.set(2); R.render(S, camera); camera.layers.set(0);
    S.background = bg; R.autoClear = ac; R.shadowMap.autoUpdate = su;
  }

  // ---------------- Gym (from the tab bar): one drawer with everything about the gym ----------------
  gymSave() {
    const d = this.d; if (!d.gyms) { d.gyms = []; d.gi = 0; }
    d.gyms[d.gi] = { name: d.name, unit: d.unit, own: JSON.parse(JSON.stringify(d.own)), bar: Object.assign({}, d.bar) };
  }
  gymLoad(i) {
    const d = this.d, g = d.gyms[i]; if (!g) return;
    d.gi = i; d.name = g.name; this.setUnit(g.unit); d.own = JSON.parse(JSON.stringify(g.own)); d.bar = Object.assign({}, g.bar);
    this.flagAnim = null; if (d.name) { this.nameToFlag(); this.flagAnim = { t0: this.onb.t }; }
    this.setPiles(true); this.setBarModel(true); this.drawPR(this.prData());
  }
  showGymHome() {
    this.clearUI(); this.closeKeyboard(true);
    const O = this.onb; O.phase = 'gymEdit'; this.gymMode = 'edit';
    this.gymSave();
    this.camTo('corner'); this.setPiles(false);
    if (this.d.name && !this.flagAnim) this.flagAnim = { t0: O.t - 10 };
    const done = () => { this.closeKeyboard(true); this.gymSave(); this.closeSheet(); this.drawPR(this.prData()); O.phase = 'home'; this.showHome(); };
    const { body } = this.sheet({ title: '', left: 'Back', onLeft: done, right: 'Done', onRight: done, height: 600 });
    const label = (t) => this.h('div', { fontSize: '15px', fontWeight: 700, color: '#000', padding: '18px 4px 8px', fontFamily: 'var(--f-display)', textTransform: 'var(--tt)' }, body, t);
    // gyms: one chip per gym, plus add; remove under them
    label('Gyms');
    const gw = this.chipWrap(body); gw.setAttribute('aria-label', 'Your gyms');
    const gyms = this.d.gyms;
    gyms.forEach((g, i) => {
      const c = this.chip(gw, { label: g.name || 'New gym', dot: i === this.d.gi ? 'var(--c-ink)' : 'transparent', size: 8, on: i === this.d.gi, onToggle: () => {
        if (i === this.d.gi) { this.showGymHome(); return; }
        this.gymSave(); this.gymLoad(i); this.showGymHome();
      } });
      c.setAttribute('role', 'radio'); c.firstChild.style.display = 'none';
    });
    const add = this.chip(gw, { label: '+ Add gym', dot: 'transparent', size: 0, on: false, onToggle: () => {
      this.gymSave();
      gyms.push({ name: '', unit: this.d.unit, own: JSON.parse(JSON.stringify(this.DEF.own)), bar: Object.assign({}, this.DEF.bar) });
      this.gymLoad(gyms.length - 1); this.showGymHome(); this.editGymName();
    } });
    add.setAttribute('role', 'button'); add.removeAttribute('aria-checked'); add.firstChild.style.display = 'none';
    if (gyms.length > 1) {
      const rm = this.h('button', { alignSelf: 'flex-start', marginTop: '10px', border: 0, background: 'none', padding: '6px 4px', fontSize: '15px', fontWeight: 600, color: '#D70015', cursor: 'pointer', fontFamily: 'var(--f-display)' }, body, 'Remove ' + (this.d.name || 'this gym'));
      rm.className = 'tap';
      rm.onclick = () => { gyms.splice(this.d.gi, 1); this.gymLoad(Math.max(0, this.d.gi - 1)); this.showGymHome(); };
    }
    // the name: tap to type, the flag follows
    label('Name');
    const f = this.h('button', { display: 'flex', alignItems: 'center', width: '100%', height: 'var(--f-h)', padding: 'var(--f-pad)', borderRadius: 'var(--f-r)', background: 'var(--f-bg)', border: 'var(--f-bd)', borderBottom: 'var(--f-bdb)', boxShadow: 'var(--f-sh)', fontSize: '20px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', color: '#000', textAlign: 'left', cursor: 'text' }, body);
    f.className = 'tap'; this.gymNameEl = this.h('span', {}, f, this.d.name || 'Add a name');
    f.onclick = () => this.editGymName();
    // kilos or pounds
    label('Units');
    const seg = this.h('div', {}, body);
    this.segmented([['kg', 'Kilograms'], ['lb', 'Pounds']], this.d.unit, (v) => {
      if (v === this.d.unit) return;
      this.setUnit(v); this.setPiles(true); this.setBarModel(true); this.showGymHome();
    }, seg);
    // the plates on the shelf
    label('Plates');
    const pw = this.chipWrap(body); pw.setAttribute('aria-label', 'Plates');
    const own = this.own();
    this.specs().forEach((sp) => {
      this.chip(pw, { label: this.fmt(sp.kg) + ' ' + this.d.unit, dot: sp.color, size: Math.round(10 + sp.d * 14), on: own.indexOf(sp.kg) >= 0, onToggle: (on) => {
        const a = this.own(), i = a.indexOf(sp.kg);
        if (on && i < 0) a.push(sp.kg); if (!on && i >= 0) a.splice(i, 1);
        this.buzz('light'); this.pilePop(sp.kg, on);
      } });
    });
    // the bar
    label('Bar');
    const bw = this.chipWrap(body); bw.setAttribute('aria-label', 'Bar');
    const bars = [];
    this.BARS[this.d.unit].forEach(([w, l]) => {
      const c = this.chip(bw, { label: this.fmt(w) + ' ' + this.d.unit + ' · ' + l.replace(' bar', ''), dot: 'transparent', size: 0, on: this.barW() === w, onToggle: () => {
        this.d.bar[this.d.unit] = w; this.setBarModel(true); this.showGymHome();
      } });
      c.setAttribute('role', 'radio'); c.firstChild.style.display = 'none'; bars.push(c);
    });
    this.h('div', { height: '24px' }, body);
  }
  editGymName() {
    const el = this.gymNameEl;
    this.openKeyboard('text', (k) => {
      if (k === 'done') { this.closeKeyboard(); this.gymSave(); this.showGymHome(); return; }
      let v = this.d.name || '';
      v = k === 'del' ? v.slice(0, -1) : (v + k).slice(0, 8);
      this.d.name = v.toUpperCase();
      if (el && el.isConnected) el.textContent = this.d.name || 'Add a name';
      if (this.d.name) { this.nameToFlag(); if (!this.flagAnim) this.flagAnim = { t0: this.onb.t }; } else { this.flagAnim = null; }
    }, true);
  }
  // home: the gym floats a little in space under the overview camera
  floatTick(dt, t) {
    const O = this.onb, on = O && O.phase === 'home' ? 1 : 0;
    this.floatK = (this.floatK || 0) + (on - (this.floatK || 0)) * (1 - Math.exp(-dt * 1.4));
    if (this.floatK < 0.0005 && !this.floatOn) return;
    const k = this.floatK, r = this.root;
    r.position.y = k * (0.2 + 0.14 * Math.sin(t * 0.75));
    r.rotation.x = k * 0.016 * Math.sin(t * 0.52); r.rotation.z = k * 0.016 * Math.sin(t * 0.43 + 1.2);
    this.floatOn = k >= 0.0005;
    if (!this.floatOn) { r.position.y = 0; r.rotation.x = 0; r.rotation.z = 0; }
  }
