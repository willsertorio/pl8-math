
  // ===================== FLOW, round 7: a real pan down between questions =====================
  // the camera remembers what it looks at, so a pan can slide it exactly one screen along its own "up"
  flCam(P, T, fov) {
    const c = this.FL.cam; c.position.set(P[0], P[1], P[2]); c.fov = fov || 35; this.flFov = c.fov; c.updateProjectionMatrix(); c.lookAt(T[0], T[1], T[2]);
    this.flCamT = new this.THREE.Vector3(T[0], T[1], T[2]);
  }
  // tweens that survive a scene change made from inside a tween's own callback
  flTween(dt) {
    const F = this.FL; if (!F.tw || !F.tw.length) return;
    const list = F.tw, mark = F.tw = [];
    const keep = list.filter((a) => { a.t += dt; const u = Math.min(1, a.t / a.d); a.fn(u); if (u >= 1) { if (a.done) a.done(); return false; } return true; });
    if (F.tw === mark) F.tw = keep.concat(F.tw);
  }
  // how far (world units along the camera's up) one screen-pixel is, at the depth the camera is looking at
  flPanGeo() {
    const F = this.FL, c = F.cam, T = this.THREE, H = F.L.clientHeight || 844;
    const up = new T.Vector3(0, 1, 0).applyQuaternion(c.quaternion);
    const dist = this.flCamT ? c.position.distanceTo(this.flCamT) : 8;
    return { up, H, wpp: 2 * dist * Math.tan(c.fov * Math.PI / 360) / H };
  }
  flPanSet(px) { // px > 0: the world has moved up by px on screen
    const F = this.FL, tf = px ? 'translateY(' + (-px).toFixed(1) + 'px)' : '';
    F.q.style.transform = tf; F.ui.style.transform = tf;
  }
  // leaving a question: nothing grows or shrinks — the camera just travels down one screen; the question and
  // the toy stay where they are in the world and slide up and away together, and the next question is waiting below
  flPanTo(step) {
    if (this.flPanning) return;
    // an edit opened from the menu changes one thing, then goes straight back to the menu
    if (this.flEditOne && step !== 'menu' && this.flStep !== 'prDial' && this.flStep !== 'menu') { step = 'menu'; this.flMode = 'menu'; }
    if (this.flDirect) { this.flDirect = false; this.flGo(step); return; }
    this.flPanning = true;
    const F = this.FL, c = F.cam, G = this.flPanGeo(), P0 = c.position.clone(), g0 = this.flGridY || 0;
    F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null; F.drag = null; F.grab = null;
    F.q.getAnimations().forEach((a) => a.cancel()); F.q.style.opacity = '1';
    [...F.ui.children].forEach((el) => { el.style.pointerEvents = 'none'; });
    // ease-in on the way out, ease-out on the way in, with matching speed where they meet: one continuous move
    const t1 = 0.3;
    this.flAnim((u) => {
      const px = G.H * u * u; c.position.copy(P0).addScaledVector(G.up, -px * G.wpp);
      this.flPanSet(px); this.flGridY = g0 - px; this.flApplyStyle();
    }, t1, () => { this.flPanning = false; this.flPanIn = { g0: g0 - G.H }; this.flGo(step); });
  }
  flGo(step) {
    this.flClear(); this.flPanning = false; this.flStep = step; this.flPanSet(0); this.flApplyStyle();
    ({ name: () => this.flName(), unit: () => this.flUnit(), plates: () => this.flPlates(), bar: () => this.flBarQ(), prs: () => this.flPRs(), prDial: () => this.flPRDial(0),
      wod: () => this.flWod(), kit: () => this.flKit(), sets: () => this.flSets(), menu: () => this.flMenu() })[step]();
    this.flFromMenu = false; this.flFromKit = false;
    const F = this.FL;
    if ((this.flMode === 'menu' || this.flMode === 'gym') && ['wod', 'prs', 'name', 'unit', 'plates', 'bar'].indexOf(step) >= 0) {
      F.panBack = true;
    } else F.panBack = false;
    this.flPanBackBind();
    // arriving from a pan: the new scene starts one screen below and the camera settles onto it
    if (this.flPanIn) {
      const pin = this.flPanIn; this.flPanIn = false;
      const c = F.cam, G = this.flPanGeo(), P1 = c.position.clone(), t2 = 0.45;
      const at = (u) => { const r = Math.pow(1 - u, 3), px = -G.H * r; c.position.copy(P1).addScaledVector(G.up, -px * G.wpp); this.flPanSet(px); this.flGridY = pin.g0 - G.H * (1 - r); this.flApplyStyle(); };
      at(0);
      this.flAnim(at, t2, () => { this.flPanSet(0); this.flGridY = ((this.flGridY || 0) % 26 + 26) % 26; this.flApplyStyle(); });
    }
  }
