
  // ---------------- the gym's layout, from the Layout Lab (saved in this browser, or the layout Will settled on) ----------------
  static get LAYOUT_DEFAULT() { return __LAYOUT_DEFAULT__; }
  applyLayout() {
    const T = this.THREE, H = this.H;
    let Ly = null; try { Ly = JSON.parse(localStorage.getItem('layoutlab-v4') || 'null'); } catch (e) {}
    if (!Ly || !Ly.objects) Ly = this.constructor.LAYOUT_DEFAULT;
    const ob = (k) => (Ly.objects && Ly.objects[k]) || {}, P = (k, def) => ob(k).p || def, R = (k, def) => (ob(k).r != null ? ob(k).r : def) * Math.PI / 180;
    const cols = (Ly.room && Ly.room.cols) || 9, rows = (Ly.room && Ly.room.rows) || 7;
    const x0 = -this.S / 2, z0 = -this.S / 2, x1 = x0 + cols, z1 = z0 + rows, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    this.ROOM = { x0, x1, z0, z1, cx, cz, W: cols, D: rows };
    [this.prG, this.flagG, this.ghostFlagG].forEach((o) => { if (o) this.root.attach(o); });
    [this.slab, this.thinFloor, this.frontWall, this.lid].forEach((o) => { if (o) o.visible = false; });
    (this.seamMeshes || []).forEach((m) => { m.visible = false; });
    this.walls.forEach((w) => { w.g.visible = false; });
    const g = new T.Group(); this.root.add(g); this.roomG = g;
    // the floor is a frame around the platform's 2.44 m trap door, so the platform can turn up out of it
    const pl = P('platform', [0.66, 0, -1.86]), PX = pl[0], PZ = pl[2], HO = 2.44, hh = HO / 2, ax = PX - hh, bx = PX + hh, az = PZ - hh, bz = PZ + hh;
    const fx0 = x0 - 0.16, fx1 = x1 + 0.16, fz0 = z0 - 0.16, fz1 = z1 + 0.16, th = 0.3, fo = { ink: false, cast: false };
    this.slab = new T.Group(); g.add(this.slab);
    this.box(fx1 - fx0, th, az - fz0, '#FFFFFF', (fx0 + fx1) / 2, -th / 2, (fz0 + az) / 2, this.slab, fo);
    this.box(fx1 - fx0, th, fz1 - bz, '#FFFFFF', (fx0 + fx1) / 2, -th / 2, (bz + fz1) / 2, this.slab, fo);
    this.box(ax - fx0, th, HO, '#FFFFFF', (fx0 + ax) / 2, -th / 2, PZ, this.slab, fo);
    this.box(fx1 - bx, th, HO, '#FFFFFF', (bx + fx1) / 2, -th / 2, PZ, this.slab, fo);
    { const e = new T.LineSegments(new T.EdgesGeometry(new T.BoxGeometry(fx1 - fx0, th, fz1 - fz0)), this.inkMat); e.position.set((fx0 + fx1) / 2, -th / 2, (fz0 + fz1) / 2); this.slab.add(e); this.inkLines.push(e); }
    this.thinFloor = new T.Group();
    const seam = (w, d, x, z) => { if (w > 0.002 && d > 0.002) this.box(w, 0.002, d, '#111111', x, 0.001, z, g, { ink: false, cast: false }); };
    for (let i = 1; i < cols; i++) { const x = x0 + i; if (x > ax && x < bx) { seam(0.004, az - z0, x, (z0 + az) / 2); seam(0.004, z1 - bz, x, (bz + z1) / 2); } else seam(0.004, rows, x, cz); }
    for (let j = 1; j < rows; j++) { const z = z0 + j; if (z > az && z < bz) { seam(ax - x0, 0.004, (x0 + ax) / 2, z); seam(x1 - bx, 0.004, (bx + x1) / 2, z); } else seam(cols, 0.004, cx, z); }
    this.well.position.set(PX, 0, PZ);
    this.walls = []; this.wallMeshes = [];
    const wall = (nx, nz, px, pz, w, d, lw, ld) => {
      const wg = new T.Group(); g.add(wg);
      const m = this.put(new T.BoxGeometry(w, H, d).translate(0, H / 2, 0), '#FFFFFF', px - nx * 0.075, 0, pz - nz * 0.075, wg);
      this.box(lw, 0.014, ld, '#111111', px + nx * 0.003, 0.007, pz + nz * 0.003, wg, { ink: false, cast: false });
      this.walls.push({ g: wg, n: new T.Vector3(nx, 0, nz), p: new T.Vector3(px, 0, pz) }); this.wallMeshes.push(m);
      return wg;
    };
    this.backWall = wall(0, 1, cx, z0, cols + 0.3, 0.15, cols, 0.006);
    this.leftWall = wall(1, 0, x0, cz, 0.15, rows + 0.3, 0.006, rows);
    this.rightWall = wall(-1, 0, x1, cz, 0.15, rows + 0.3, 0.006, rows);
    this.frontWall = this.put(new T.BoxGeometry(cols + 0.3, H, 0.15).translate(0, H / 2, 0), '#FFFFFF', cx, 0, z1 + 0.075, g); this.frontWall.visible = false;
    this.lid = this.box(cols + 0.3, 0.15, rows + 0.3, '#FFFFFF', cx, this.CUBE + 0.075, cz, g); this.lid.visible = false;
    // furniture where the layout put it
    const rk = P('rack', [0.61, 0, -2.31]);
    this.PLAT = [PX, PZ]; this.RACK = [rk[0], rk[2]];
    this.flipG.position.set(PX, 0, PZ);
    this.cutLines.forEach((m) => { m.position.x += PX; m.position.z += PZ; });
    this.rackG.position.set(this.RACK[0], 0, this.RACK[1]);
    const bn = P('bench', [0.95, 0, 0.63]); this.BENCH = [bn[0], bn[2]]; this.CHAIR_RY = R('bench', 180);
    this.benchG.position.set(this.BENCH[0], 0, this.BENCH[1]); this.benchG.rotation.set(0, this.CHAIR_RY, 0);
    if (this.bottleG.parent) this.bottleG.parent.remove(this.bottleG);
    const bd = P('board', [-2.16, 0, -3.07]); this.BOARD = [bd[0], bd[2]]; this.BOARD_RY = R('board', 25);
    this.boardG.position.set(this.BOARD[0], 0, this.BOARD[1]); this.boardG.rotation.set(0, this.BOARD_RY, 0);
    const fl = P('flag', [3.2, 1.95, -3.99]); this.flagG.position.set(fl[0], fl[1], fl[2]); this.flagG.rotation.set(0, R('flag', 0), 0);
    if (this.ghostFlagG) { this.ghostFlagG.position.copy(this.flagG.position); this.ghostFlagG.rotation.copy(this.flagG.rotation); }
    const pr = P('pr', [-3.97, 1.15, -2.76]); this.prG.position.set(pr[0], pr[1], pr[2]); this.prG.rotation.set(0, R('pr', 90), 0);
    this.SHELF_P = P('shelf', [0.06, 0.3, 2.32]);
    this.buildPlatePiles('kg');
    // added props: the wall fan (with its switch and cable), the bar holder, the window, and anything else placed in the Layout Lab
    this.fanG = this.buildFanG(); this.fanG.visible = false; this.root.add(this.fanG); this.noFloorFan = true;
    this.KIT_C = [3.45, -1.85]; this.sceneProps = [];
    const make = { wallfan: () => this.buildWallFanG(), barholder: () => this.buildBarHolderG(), wallwindow: () => this.buildWallWindowG(), cooler: () => this.buildCoolerG(), plant: () => this.buildPlantG(),
      block: () => { const b = new T.Group(); this.box(0.5, 0.5, 0.5, '#FFFFFF', 0, 0.25, 0, b); return b; } };
    (Ly.added || []).forEach((q) => {
      const ap = (o) => { if (q.p) o.position.fromArray(q.p); if (q.r != null) o.rotation.y = q.r * Math.PI / 180; if (q.s) o.scale.setScalar(q.s); };
      if (q.kind === 'kitplates') { if (q.p) this.KIT_C = [q.p[0], q.p[2]]; return; }
      if (q.kind === 'fan') { ap(this.fanG); this.noFloorFan = false; return; }
      const mk = make[q.kind]; if (!mk) return;
      const o = mk(); ap(o); this.root.add(o); this.sceneProps.push({ kind: q.kind, obj: o });
    });
    this.fanG.traverse((o) => { if (o.userData.spin) this.fanBlades = o; });
    this.layoutShots = Object.assign({}, Ly.shots || {});
    // two close-ups for the setup: the flag on its wall, and the bar on the rack
    { const f = this.flagG.position, n = new T.Vector3(0, 0, 1).applyAxisAngle(new T.Vector3(0, 1, 0), this.flagG.rotation.y);
      this.layoutShots.nameFlag = { T: [f.x, f.y - 0.5, f.z], P: [f.x + n.x * 4.4 - n.z * 0.6, f.y + 0.2, f.z + n.z * 4.4 + n.x * 0.6], fov: 50 };
      const bx = this.RACK[0], bz = this.RACK[1] - 0.77;
      // three-quarter view from the bar's end, close enough to see sleeve length and thickness change
      this.layoutShots.bar = { T: [bx + 0.55, 1.22, bz], P: [bx + 2.25, 1.9, bz + 2.35], fov: 50 };
      }
  }

  // the wall fan spins (its switch turns it on and off), sweeps, stirs the flag; wall props hide with their wall
  propsTick(dt, t) {
    this.barTick(dt); this.floatTick(dt, t);
    if (this.fanOn === undefined) { let v = null; try { v = localStorage.getItem('layoutlab-fanon'); } catch (er) {} this.fanOn = v !== 'off'; this.fanSpd = this.fanOn ? 1 : 0; this.fanPh = 0; }
    this.fanSpd += ((this.fanOn ? 1 : 0) - this.fanSpd) * (1 - Math.exp(-dt * (this.fanOn ? 1.6 : 0.9)));
    this.fanPh += dt * this.fanSpd;
    const sweep = Math.sin(this.fanPh / 1.8) * 0.5, cam = this.camera, cut = this.boxP < 0.02;
    let wallFan = false;
    (this.sceneProps || []).forEach((q) => {
      const onWall = q.kind === 'wallfan' || q.kind === 'barholder' || q.kind === 'wallwindow';
      if (onWall) {
        if (q.kind === 'wallfan') wallFan = true;
        const pos = q.obj.position; let show = true;
        (this.walls || []).forEach((w) => { if (Math.abs(pos.clone().sub(w.p).dot(w.n)) < 0.35 && cut) show = cam.position.clone().sub(w.p).dot(w.n) > 0; });
        q.obj.visible = show;
        // while the box opens, things on a wall that goes all the way down ride down with it
        if (this.wallDown) this.walls.forEach((w, i) => {
          if (!this.wallDown[i] || Math.abs(pos.clone().sub(w.p).dot(w.n)) >= 0.35) return;
          if (q.y0 == null) { q.y0 = pos.y; const T = this.THREE, bb = new T.Box3().setFromObject(q.obj), wp = q.obj.getWorldPosition(new T.Vector3()); q.top = q.y0 + (bb.max.y - wp.y); }
          const top = this.boxP * this.CUBE; pos.y = q.y0 - Math.max(0, q.top - top); q.obj.visible = top > 0.06;
        });
      }
      q.obj.traverse((o) => {
        if (o.userData.spin) o.rotation.z -= 0.25 * this.fanSpd * Math.min(3, dt * 60);
        if (o.userData.osc) o.rotation.y = sweep;
        if (o.userData.rocker) o.rotation.x = this.fanOn ? -0.32 : 0.32;
      });
    });
    const O = this.onb, busy = (this.flagAnim && O && O.t - this.flagAnim.t0 < 3.5) || !O || O.phase === 'idle' || O.phase === 'opening';
    if (this.flag && this.flagG && this.flagG.visible && !busy) {
      const e = wallFan ? this.fanSpd * (0.22 + 0.16 * (sweep + 0.5)) : 0;
      if (e > 0.002 || this.flagE > 0.002) this.poseFlag(e, t);
      this.flagE = e;
    }
  }
  fanSwitchHit(ray) {
    const fans = (this.sceneProps || []).filter((q) => q.kind === 'wallfan' && q.obj.visible);
    const h = ray.intersectObjects(fans.map((q) => q.obj), true).find((x) => x.object.isMesh);
    return !!(h && h.object.userData.fanSwitch);
  }

  // the whiteboard, in marker: today's lifts and their working loads
  drawWB(plan) {
    const A = this.wbArt; if (!A) return;
    const cv = A.cv, x = cv.getContext('2d'), W = cv.width, H = cv.height, F = '"Permanent Marker", "Comic Sans MS", cursive';
    x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, W, H);
    x.fillStyle = '#111111'; x.strokeStyle = '#111111'; x.textBaseline = 'alphabetic';
    const title = "Today's sesh"; x.font = '400 64px ' + F; x.fillText(title, 40, 92);
    { const tw = x.measureText(title).width; x.lineWidth = 5; x.beginPath(); x.moveTo(40, 118); x.lineTo(40 + tw, 112); x.stroke(); }
    if (plan) {
      const gs = plan.groups.filter((q) => !q.warm), L = 'ABCDEFGH';
      let y = 196; const gap = gs.length > 3 ? 104 : 132;
      gs.slice(0, 4).forEach((q, i) => {
        x.font = '400 46px ' + F; x.fillText(L[i] + '. ' + q.name.toUpperCase(), 40, y);
        x.font = '400 36px ' + F; x.fillText(q.format, 86, y + 50);
        x.fillText('→ ' + this.fmtW(q.sets[0].total) + ' ' + plan.unit, 560, y + 50);
        y += gap;
      });
    }
    A.rec.orig = x.getImageData(0, 0, W, H); A.tex.needsUpdate = true; this.artKey = null;
  }

  // the PR board fills, the bell rings, then on to the whiteboard
  finishPR(data) {
    const O = this.onb; if (!O) return;
    this.clearUI();
    if (data) { this.drawPR(data); O.phase = 'prFilled'; O.pfT = O.t; }
    else this.goToBoard();
  }
  goToBoard() {
    const O = this.onb;
    O.phase = 'toBoard'; O.bt0 = O.t;
    this.flyTo(this.SHOTS.board.T, this.SHOTS.board.P, 2.3, true); this.fovGoal = this.SHOTS.board.fov || 50;
  }
  // keep the drawer's view offset through the PR -> board move so the frame doesn't jump
  shiftGoal() {
    const c = this.coverFrac(), O = this.onb;
    if (c > 0) { this.lastCover = c; return c * 0.5; }
    if (O && (O.phase === 'prFilled' || O.phase === 'toBoard')) return (this.lastCover || 0) * 0.5;
    return 0;
  }
  beginWorkout(plan) {
    const O = this.onb;
    this.plan = plan; this.setIdx = 0; this.doneSets = []; this.inSession = false; this.finishing = false; this.d.kitGot = {};
    if (this.pileUnit !== this.d.unit) this.buildPlatePiles(this.d.unit);
    this.drawWB(plan);
    Object.keys(O.fired).forEach((k) => { if (/^kit\d/.test(k)) delete O.fired[k]; });
    this.kitOutT = null; this.kitMode = 'drop';
    this.drawPR(this.prData());
    this.buildKit(plan);
    O.phase = 'kit'; O.kt0 = O.t;
    if (O.rackT == null) { O.rackT = O.t + 0.35; this.rackG.visible = true; this.rackG.position.y = 40; }
    this.controls.enabled = false;
    this.camTo('kit', 1.6);
    this.showKit();
  }
  goTab(id) {
    if (!this.plan) return;
    const O = this.onb;
    if (this.grab) { this.grab = null; }
    if (id === 'kit') { O.phase = 'kit'; this.camTo('kit', 1.2); this.showKit(); return; }
    O.phase = 'sets'; this.camTo('setv', 1.6);
    try { const AC = window.AudioContext || window.webkitAudioContext; if (AC && !this.ac) this.ac = new AC(); if (this.ac && this.ac.state === 'suspended') this.ac.resume(); } catch (e) {}
    if (O.rackT == null) { O.rackT = O.t + 0.5; this.rackG.visible = true; this.rackG.position.y = 40; }
    this.showSet(this.setIdx, O.rackT != null && O.t < O.rackT + 0.9 ? O.rackT + 0.9 : null);
    this.showSetCard();
  }
  finishWorkout() {
    const O = this.onb; O.phase = 'complete'; this.finishing = true;
    this.clearUI(); this.ringBell();
    this.camTo('setv', 1.2);
    setTimeout(() => { if (!this.dead) this.showSessionOver(); }, 900);
  }
  // a new session from home: the whiteboard, and today's workout
  trainAgain() {
    const O = this.onb; if (!O) return;
    this.plan = null; this.inSession = false; this.d.kitGot = {};
    Object.keys(O.fired).forEach((k) => { if (/^kit\d/.test(k)) delete O.fired[k]; });
    this.drawWB(null);
    O.phase = 'wb';
    this.camTo('board', 1.8);
    this.showWod('home');
  }

  componentWillUnmount() {
    this.dead = true;
    clearInterval(this.boilT); clearTimeout(this.hT);
    if (this.openL) this.openL.destroy(); if (this.doneL) this.doneL.destroy();
    this.closeKeyboard(true);
    if (this.onArtStore) window.removeEventListener('storage', this.onArtStore);
    if (this.onWinErr) window.removeEventListener('error', this.onWinErr);
    if (this.raf) cancelAnimationFrame(this.raf);
    if (this.ro) this.ro.disconnect();
    if (this.outerRO) this.outerRO.disconnect();
    if (this.controls) this.controls.dispose();
    if (this.renderer) this.renderer.dispose();
    if (this.spin) this.spin.r.dispose();
  }
