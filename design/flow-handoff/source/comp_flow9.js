
  // ===================== FLOW, round 9 =====================
  // ---------- the kit laid out to count at a glance: one line per size, each plate flat on its own spot ----------
  flKitLayout(kit, sp) {
    const groups = kit.map((k) => ({ k, s: sp.find((q) => q.kg === k.w) })).filter((g) => g.s);
    const gIn = 0.05, gOut = 0.24, maxW = 2.2, rowGap = 0.16;
    groups.forEach((g) => { g.w = g.k.qty * g.s.d + (g.k.qty - 1) * gIn; });
    const rows = [[]]; let w = 0;
    groups.forEach((g) => { const add = (rows[rows.length - 1].length ? gOut : 0) + g.w; if (w + add > maxW && rows[rows.length - 1].length) { rows.push([]); w = 0; } rows[rows.length - 1].push(g); w += (rows[rows.length - 1].length > 1 ? gOut : 0) + g.w; });
    const depth = rows.map((r) => Math.max(...r.map((g) => g.s.d)));
    const total = depth.reduce((a, d) => a + d, 0) + rowGap * (rows.length - 1);
    const out = []; let z = 0.35 - total / 2, n = 0;
    rows.forEach((r, ri) => {
      const tw = r.reduce((a, g) => a + g.w, 0) + gOut * (r.length - 1); let x = -tw / 2;
      const zc = z + depth[ri] / 2;
      r.forEach((g) => {
        for (let j = 0; j < g.k.qty; j++) { out.push({ k: { w: g.k.w, qty: 1 }, s: g.s, x: x + g.s.d / 2 + j * (g.s.d + gIn), z: zc, yaw: (n++ * 1.37) % 6.28 }); }
        x += g.w + gOut;
      });
      z += depth[ri] + rowGap;
    });
    return out;
  }

  // ---------- sets: one card per set; dragging up or down slides the next card in under your finger ----------
  flSetCardEl(i) {
    const F = this.FL, P = this.plan, x = P.flat[i], grp = P.groups[x.gi], last = i >= P.flat.length - 1;
    const c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px 18px 18px', borderRadius: '22px', background: this.pal.card || '#FFFFFF', color: this.pal.boxDark, fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 10px 30px rgba(0,0,0,0.18)' }, F.ui);
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', color: this.pal.boxDark, opacity: 0.6 }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 12px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    c.paintDots = () => { dots.innerHTML = ''; grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? (this.pal.acc || this.pal.bgColor) : j === i ? this.pal.boxDark : this.pal.boxDark + '22' }, dots); }); };
    c.paintDots();
    if (last) {
      const b = this.fh('button', { width: '100%', height: '56px', marginTop: '16px', border: 0, borderRadius: '16px', background: this.pal.boxDark, color: this.pal.boxLight, fontFamily: 'inherit', fontWeight: 900, fontSize: '19px', cursor: 'pointer' }, c, 'End session');
      b.className = 'tap'; b.onclick = () => { this.flCheckSound(); this.buzz('success'); this.doneSets[this.setIdx] = true; this.flFinish(); };
    }
    return c;
  }
  flSetCard(dir) {
    const F = this.FL, i = Math.min(this.setIdx, this.plan.flat.length - 1), last = i >= this.plan.flat.length - 1;
    const old = F.ui.querySelector('[data-setcard]');
    if (old) { old.removeAttribute('data-setcard'); old.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(' + (dir < 0 ? 60 : -60) + 'px)', opacity: 0 }], { duration: 260, easing: 'ease-in', fill: 'forwards' }); setTimeout(() => old.remove(), 270); }
    const c = this.flSetCardEl(i); c.setAttribute('data-setcard', '');
    c.animate([{ transform: dir ? 'translateY(' + (dir < 0 ? -70 : 70) + 'px)' : 'translateY(120%)', opacity: dir ? 0 : 1 }, { transform: 'none', opacity: 1 }], { duration: dir ? 320 : 420, delay: dir ? 120 : 0, easing: 'cubic-bezier(.2,.9,.25,1)', fill: 'backwards' });
    F.sw.style.display = 'none';
  }
  // the card swap, following the finger: up for the next set, down for the one before
  flCardDrag() {
    const F = this.FL, P = this.plan, n = P.flat.length, i0 = this.setIdx, cur = F.ui.querySelector('[data-setcard]');
    if (!cur) return null;
    cur.getAnimations().forEach((a) => a.cancel());
    const off = cur.getBoundingClientRect().height / (F.ui.getBoundingClientRect().height / 844 || 1) + 40;
    let peek = null, pdir = 0, dy = 0, PL = null;
    const place = () => {
      const dir = dy < 0 ? 1 : dy > 0 ? -1 : 0, j = i0 + dir, ok = dir && j >= 0 && j < n;
      if (dir !== pdir) { if (peek) { peek.remove(); peek = null; } if (PL) { PL.cancel(); PL = null; } pdir = dir; if (ok) { peek = this.flSetCardEl(j); peek.style.pointerEvents = 'none'; PL = this.flPlateSwap(j); } }
      const d = ok ? dy : dy * 0.25, a = Math.min(1, Math.abs(d) / off);
      if (PL) PL.at(a);
      cur.style.transform = 'translateY(' + d.toFixed(1) + 'px)'; cur.style.opacity = String(1 - a * 0.9);
      if (peek) { peek.style.transform = 'translateY(' + ((dir > 0 ? off : -off) + d).toFixed(1) + 'px)'; peek.style.opacity = String(0.1 + a * 0.9); }
      return ok;
    };
    return {
      move: (y) => { dy = y; place(); },
      up: (vel) => {
        const ok = place(), go = ok && (Math.abs(dy) > off * 0.32 || (Math.abs(vel) > 0.5 && Math.sign(vel) === Math.sign(dy)));
        const d0 = ok ? dy : dy * 0.25, d1 = go ? (pdir > 0 ? -off : off) : 0, EO = 'cubic-bezier(.2,.9,.25,1)';
        const curEnd = go ? 'translateY(' + d1 + 'px)' : 'none';
        cur.animate([{ transform: 'translateY(' + d0 + 'px)', opacity: cur.style.opacity }, { transform: curEnd, opacity: go ? 0 : 1 }], { duration: 240, easing: EO });
        cur.style.transform = curEnd; cur.style.opacity = go ? '0' : '1';
        if (peek) {
          const pEnd = go ? 'none' : 'translateY(' + (pdir > 0 ? off : -off) + 'px)';
          peek.animate([{ transform: peek.style.transform, opacity: peek.style.opacity }, { transform: pEnd, opacity: go ? 1 : 0 }], { duration: 240, easing: EO });
          peek.style.transform = pEnd; peek.style.opacity = go ? '1' : '0';
        }
        if (PL) { const P0 = PL, a0 = P0.a; this.flAnim((u) => P0.at(a0 + ((go ? 1 : 0) - a0) * (1 - Math.pow(1 - u, 3))), 0.24, () => (go ? P0.commit() : P0.cancel())); }
        if (!go) { const p = peek; setTimeout(() => { if (p) p.remove(); cur.style.transform = ''; }, 250); return; }
        // committed: the set changes and the bar re-loads
        if (pdir > 0) { this.doneSets[i0] = true; this.buzz('success'); } else { this.doneSets[i0 - 1] = false; this.buzz('light'); }
        this.flCheckSound(); this.setIdx = i0 + pdir;
        const p = peek; cur.removeAttribute('data-setcard'); p.setAttribute('data-setcard', ''); p.style.pointerEvents = 'auto'; p.paintDots();
        setTimeout(() => { cur.remove(); p.style.transform = ''; }, 250);
      }
    };
  }
  // the plates for set j, driven by a (0 → 1): the outer ones slide off the sleeve, the new ones slide on, with the finger
  flPlateSwap(j) {
    const B = this.flBar, T = this.THREE, F = this.FL; if (!B) return null;
    const next = this.plan.flat[j].side.slice(), prev = B.side, sp = this.specs();
    let c = 0; while (c < prev.length && c < next.length && prev[c] === next[c]) c++;
    const leaving = B.on.filter((m) => !m.out && m.k >= c).sort((p, q) => q.k - p.k);
    leaving.forEach((m) => { m.manual = true; });
    const entering = []; let cum = 0;
    next.forEach((w, k) => {
      const s = sp.find((q) => q.kg === w); if (!s) return;
      const xp = 0.695 + cum + s.t / 2; cum += s.t + 0.002;
      if (k < c) return;
      [-1, 1].forEach((sg) => { const g = this.plate(s), o = new T.Group(); o.add(g); g.rotation.set(Math.random() * 6.28, 0, Math.PI / 2); o.position.set(sg * 1.5, B.y, 0); o.visible = false; F.S.add(o); F.objs.push(o); entering.push({ o, sg, k, x: sg * xp, t: 10, dl: 0, seat: true }); });
    });
    const nl = Math.max(1, leaving.length / 2), ne = Math.max(1, (next.length - c));
    const S = { a: 0,
      at: (a) => {
        S.a = a;
        leaving.forEach((m, i) => { const q = Math.min(1, Math.max(0, a * 1.4 - Math.floor(i / 2) * 0.4 / nl)), e = q * q; m.o.position.x = m.x + m.sg * 0.9 * e; m.o.position.y = B.y - 0.5 * Math.max(0, e - 0.6); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.75) / 0.25)); });
        entering.forEach((m) => { const q = Math.min(1, Math.max(0, a * 1.4 - 0.25 - (m.k - c) * 0.15 / ne)), e = 1 - Math.pow(1 - q, 3); m.o.visible = q > 0; m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * e; });
      },
      commit: () => {
        leaving.forEach((m) => { F.S.remove(m.o); m.gone = true; });
        B.on = B.on.filter((m) => !m.gone).concat(entering); B.side = next;
        if (entering.length) { this.flClick(0.45); this.buzz('light'); }
      },
      cancel: () => {
        entering.forEach((m) => { F.S.remove(m.o); });
        leaving.forEach((m) => { m.manual = false; m.o.position.x = m.x; m.o.position.y = B.y; m.o.scale.setScalar(1); });
      }
    };
    return S;
  }
  // place a proxy so that, seen from camNow, it looks exactly like its own scene seen from camR shifted by offPx on screen (+ = below)
  flProxyAt(proxy, camNow, camR, upR, wppR, offPx) {
    const T = this.THREE, cp = this.flTmpCam || (this.flTmpCam = new T.PerspectiveCamera());
    cp.position.copy(camR.position).addScaledVector(upR, offPx * wppR); cp.quaternion.copy(camR.quaternion); cp.updateMatrixWorld(true);
    camNow.updateMatrixWorld(true);
    proxy.matrix.copy(camNow.matrixWorld).multiply(new T.Matrix4().copy(cp.matrixWorld).invert()); proxy.matrixWorldNeedsUpdate = true;
  }
  // on the first set, dragging down pans back up to the kit, laid out just as you left it
  flSetsKitDrag(orb) {
    const F = this.FL, T = this.THREE, H = F.L.clientHeight || 844;
    const rest = new T.PerspectiveCamera(40, 1, 0.1, 100); rest.position.set(2.45, 1.25, 1.75); rest.lookAt(0.78, 0.8, -0.08); rest.updateMatrixWorld(true);
    const up = new T.Vector3(0, 1, 0).applyQuaternion(rest.quaternion), dist = rest.position.distanceTo(new T.Vector3(0.78, 0.8, -0.08)), wpp = 2 * dist * Math.tan(20 * Math.PI / 180) / H;
    if (!this.flSetsProxy || !this.flSetsProxy.parent) {
      const camK = new T.PerspectiveCamera(35, 1, 0.1, 100); camK.position.set(0, 6.3, 5.57); camK.lookAt(0, -1.3, -0.3); camK.updateMatrixWorld(true);
      const upK = new T.Vector3(0, 1, 0).applyQuaternion(camK.quaternion), wppK = 2 * camK.position.distanceTo(new T.Vector3(0, -1.3, -0.3)) * Math.tan(17.5 * Math.PI / 180) / H;
      const proxy = new T.Group(); proxy.matrixAutoUpdate = false; proxy.visible = false; proxy.userData = { camK, upK, wppK, H };
      this.flKitLayout(this.plan.kit, this.specs()).forEach((pl) => { const g = this.plate(pl.s); g.position.set(pl.x, pl.s.t / 2 + 0.002, pl.z); g.rotation.y = pl.yaw; proxy.add(g); });
      this.flAdd(proxy); this.flSetsProxy = proxy;
    }
    orb.ty = 0; orb.tp = 0;
    const set = (px) => { this.flSetsPan = { up, wpp, px }; this.flFov = 40 - 5 * Math.min(1, px / H); this.flPanSet(-px); this.flGridY = px; this.flApplyStyle(); };
    let px = 0;
    return {
      move: (dy) => { px = Math.max(0, dy); set(px); },
      up: () => {
        const p0 = px;
        if (p0 > 110) {
          F.hit = null;
          this.flAnim((u) => set(p0 + (H - p0) * (1 - Math.pow(1 - u, 2))), 0.3, () => { this.flSetsPan = null; this.flPanSet(0); this.flGridY = 0; this.flCheckSound(); this.buzz('light'); this.flKitPlaced = true; this.flGo('kit'); });
        } else this.flAnim((u) => set(p0 * Math.pow(1 - u, 3)), 0.28, () => { this.flSetsPan = null; this.flPanSet(0); this.flGridY = 0; this.flApplyStyle(); });
      }
    };
  }
  flSets() {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flStep = 'sets'; this.flSetsPan = null; this.flSetsProxy = null;
    this.flCam([2.45, 1.25, 1.75], [0.78, 0.8, -0.08], 40);
    const rest = { P: new T.Vector3(2.45, 1.25, 1.75), T: new T.Vector3(0.78, 0.8, -0.08) };
    const bar = this.flBarGroup(); this.flAdd(bar);
    this.flBar = { bar, on: [], side: [], y: 0.9 };
    const orb = this.flOrb = { yaw: 0, pitch: 0, ty: 0, tp: 0, drag: false };
    const off0 = rest.P.clone().sub(rest.T), sph = new T.Spherical().setFromVector3(off0);
    F.tick = (dt) => {
      const B = this.flBar; if (!B) return;
      if (!orb.drag) { orb.ty *= Math.exp(-dt * 2.5); orb.tp *= Math.exp(-dt * 2.5); }
      orb.yaw += (orb.ty - orb.yaw) * (1 - Math.exp(-dt * 10)); orb.pitch += (orb.tp - orb.pitch) * (1 - Math.exp(-dt * 10));
      const s2 = new T.Spherical(sph.radius, Math.max(0.35, Math.min(Math.PI - 0.35, sph.phi - orb.pitch)), sph.theta + orb.yaw);
      F.cam.position.copy(rest.T).add(new T.Vector3().setFromSpherical(s2)); F.cam.lookAt(rest.T);
      const sp = this.flSetsPan; if (sp && sp.px) F.cam.position.addScaledVector(sp.up, sp.px * sp.wpp);
      const pr = this.flSetsProxy;
      if (pr) { const on = !!(sp && sp.px > 0.5); pr.visible = on; if (on) { const U = pr.userData; this.flProxyAt(pr, F.cam, U.camK, U.upK, U.wppK, -(U.H - sp.px)); } }
      B.on.forEach((m) => {
        m.t += dt; if (m.manual) return;
        if (m.out) { const q = Math.min(1, m.t / 0.3); m.o.position.x = m.x + m.sg * 0.9 * q * q; m.o.position.y = B.y - 0.8 * Math.max(0, q - 0.5); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.6) / 0.4)); if (q >= 1) { F.S.remove(m.o); m.gone = true; } return; }
        const q = Math.min(1, Math.max(0, (m.t - m.dl) / 0.34)); m.o.visible = m.t >= m.dl;
        m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * this.outCubic(q); m.o.position.y = B.y;
        if (q >= 1 && !m.seat) { m.seat = true; this.flClick(0.45); this.buzz('light'); }
      });
      B.on = B.on.filter((m) => !m.gone);
    };
    // sideways drag orbits; a vertical drag moves between sets (or, from the first set, back up to the kit); a tap moves on
    F.hit = (e) => {
      if (e.target.closest && e.target.closest('button')) return null;
      const sx = e.clientX, sy = e.clientY; let lx = sx, ly = sy, mode = null, G = null, lt = performance.now(), vy = 0;
      return {
        move: (ev) => {
          const dx = ev.clientX - sx, dy = ev.clientY - sy, now = performance.now();
          vy = (ev.clientY - ly) / Math.max(1, now - lt); lt = now;
          if (!mode) {
            if (Math.hypot(dx, dy) < 10) { lx = ev.clientX; ly = ev.clientY; return; }
            if (Math.abs(dx) > Math.abs(dy) * 0.9) { mode = 'orbit'; orb.drag = true; }
            else if (dy > 0 && this.setIdx === 0) { mode = 'kit'; G = this.flSetsKitDrag(orb); }
            else { mode = 'card'; G = this.flCardDrag(); if (!G) mode = 'none'; }
          }
          if (mode === 'orbit') { const ddx = ev.clientX - lx, ddy = ev.clientY - ly; orb.ty = Math.max(-0.7, Math.min(0.7, orb.ty - ddx * 0.006)); orb.tp = Math.max(-0.25, Math.min(0.25, orb.tp + ddy * 0.003)); }
          if (mode === 'kit' || mode === 'card') G.move(dy);
          lx = ev.clientX; ly = ev.clientY;
        },
        up: (ev, tap) => {
          orb.drag = false;
          if (tap && !mode) { this.flSetGo(1, true); return; }
          if (mode === 'kit') G.up(); else if (mode === 'card') G.up(vy);
        }
      };
    };
    F.swipe = false; F.onSwipe = null; F.onTap = null;
    this.flLoad(this.setIdx);
    this.flSetCard(0);
  }

  // ---------- PRs in the onboarding: the notebook opens with a pencil beside it — tap the pencil to type, the notebook to upload ----------
  flPRs() {
    const F = this.FL, T = this.THREE;
    this.flCam([0, 0.5, 6.6], [0, 0.02, 0], 35);
    const nb = this.notebookModel2('MY PRs'); nb.rotation.set(-0.28, 0.18, 0.06); nb.visible = false; this.flAdd(nb);
    const sh = this.softShadow(0.6); sh.position.set(0, -0.95, 0); sh.scale.set(1, 0.5, 1); sh.visible = false; this.flAdd(sh);
    const pen = this.penModel(); pen.position.set(0.55, -0.44, 0.34); pen.rotation.set(0.5, 0, -0.95); pen.scale.setScalar(0.0001); this.flAdd(pen);
    const rows = () => this.d.prs.filter((q) => q[1] != null).map((q) => q[0] + '  ' + this.fmt(q[1]) + ' ' + this.d.unit);
    if (this.d.prs.some((q) => q[1] != null)) nb.userData.drawPage(rows());
    let open = 0, ready = false, busy = false;
    const hinge = nb.userData.hinge;
    const pose = (k) => { open = k; hinge.rotation.y = -2.95 * k; nb.rotation.set(-0.28 + 0.18 * k, 0.18 * (1 - k), 0.06 * (1 - k)); nb.scale.setScalar(1 - 0.3 * k); nb.position.x = 0.37 * k; };
    this.flAfter('Alright. And what are your PRs?', () => {
      nb.visible = true; sh.visible = true; this.popIn(nb, 0); this.popIn(sh, 0);
      this.flLater(() => {
        this.flClick(0.5);
        this.flAnim((u) => pose(u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2), 0.7, () => { ready = true; });
        this.flLater(() => { this.flAnim((u) => pen.scale.setScalar(Math.max(0.0001, this.outBack(u, 1.4))), 0.45); this.flClick(1.4); }, 450);
      }, 550);
    });
    F.tick = (dt, t) => { nb.position.y = 0.06 * Math.sin(t * 1.4); pen.position.y = -0.44 + 0.04 * Math.sin(t * 1.4 + 0.6); this.flSpkTick(dt); };
    const leave = () => {
      // close, shine, and down to the workout
      busy = true; this.flAnim((u) => { pose(1 - (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2)); pen.scale.setScalar(Math.max(0.0001, 1 - u)); }, 0.6, () => {
        this.flShine([nb], 0.8); this.flSparkles(new T.Vector3(0, 0.2, 0.5), 7, 1.3); this.flLater(() => { this.flCheckSound(); this.flPanTo('wod'); }, 1000);
      });
    };
    const hit = (e, o) => this.flRay(e).intersectObject(o, true).length > 0;
    F.hit = (e) => {
      if (!ready || busy) return null;
      if (!hit(e, pen) && !hit(e, nb)) return null;
      return { up: (ev, tap) => {
        if (!tap || busy) return; this.buzz('light'); this.flCheckSound();
        if (hit(ev, pen)) { busy = true; this.flPrRet = 'wod'; this.flPanTo('prDial'); return; }
        if (hit(ev, nb)) this.flPickPhoto(() => { busy = true; this.reading('Reading your PRs…', () => { this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); nb.userData.drawPage(rows()); this.flShine([nb], 0.6); this.flLater(leave, 900); }); });
      } };
    };
  }
