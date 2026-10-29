
  // ===================== FLOW, round 10: the gym room, several gyms =====================
  flGymSnap() { const d = this.d, cl = (o) => JSON.parse(JSON.stringify(o || {})); return { name: d.name, unit: d.unit, own: cl(d.own), bar: cl(d.bar) }; }
  flGymLoad(g) { const cl = (o) => JSON.parse(JSON.stringify(o || {})); this.d.name = g.name; this.setUnit(g.unit); this.d.own = cl(g.own); this.d.bar = cl(g.bar); }
  flGymList() {
    if (!this.flGyms) { this.flGyms = [this.flGymSnap()]; this.flGymIdx = 0; }
    this.flGyms[this.flGymIdx] = this.flGymSnap();
    return this.flGyms;
  }
  // an iOS-style alert, drawn in the page so it works everywhere the prototype runs
  flAlert(title, msg, buttons) {
    const F = this.FL, host = F.L;
    const ov = this.fh('div', { position: 'absolute', inset: 0, zIndex: 90, background: 'rgba(0,0,0,0.32)', display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'auto' }, host);
    ov.setAttribute('role', 'alertdialog'); ov.setAttribute('aria-label', title);
    const box = this.fh('div', { width: '270px', borderRadius: '14px', background: 'rgba(242,242,247,0.96)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', overflow: 'hidden', fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif', textAlign: 'center', color: '#000' }, ov);
    const head = this.fh('div', { padding: '19px 16px 18px' }, box);
    this.fh('div', { fontSize: '17px', fontWeight: 600, lineHeight: 1.3 }, head, title);
    if (msg) this.fh('div', { fontSize: '13px', lineHeight: 1.35, marginTop: '3px' }, head, msg);
    const row = this.fh('div', { display: 'flex', borderTop: '0.5px solid rgba(60,60,67,0.36)' }, box);
    const close = () => { ov.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 160 }).onfinish = () => ov.remove(); };
    buttons.forEach((b, i) => {
      const bt = this.fh('button', { flex: 1, height: '44px', border: 0, borderLeft: i ? '0.5px solid rgba(60,60,67,0.36)' : 0, background: 'transparent', fontFamily: 'inherit', fontSize: '17px', fontWeight: b.bold ? 600 : 400, color: b.destructive ? '#FF3B30' : '#007AFF', cursor: 'pointer' }, row, b.label);
      bt.onclick = (e) => { e.stopPropagation(); close(); if (b.fn) b.fn(); };
    });
    ov.addEventListener('pointerdown', (e) => e.stopPropagation()); ov.addEventListener('pointerup', (e) => e.stopPropagation());
    ov.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 160 }); box.animate([{ transform: 'scale(1.15)' }, { transform: 'scale(1)' }], { duration: 220, easing: 'cubic-bezier(.2,.9,.25,1)' });
  }
  // a box whose lid, front and side fold away to leave a tiny gym: floor, the flag on the back wall,
  // three bars racked on the side wall, the plates piled under the flag and a kettlebell in front
  gymRoomModel(name, gym) {
    const T = this.THREE, g = new T.Group(), S = 1.15, th = 0.04, ink = this.pal.boxDark;
    gym = gym || { unit: this.d.unit, own: this.d.own };
    const FONT = "'Space Grotesk', Arial, sans-serif";
    const mat = () => { const m = this.toon(this.pal.boxLight); m.transparent = true; return m; };
    const edge = (mesh) => { const e = new T.LineSegments(new T.EdgesGeometry(mesh.geometry), new T.LineBasicMaterial({ color: ink, transparent: true })); mesh.add(e); return e; };
    const slab = (w, h, d) => { const m = new T.Mesh(new T.BoxGeometry(w, h, d), mat()); m.castShadow = true; m.receiveShadow = true; edge(m); return m; };
    const floor = slab(S, th, S); floor.position.y = th / 2; g.add(floor);
    const back = slab(S, S, th); back.position.set(0, S / 2, -S / 2 + th / 2); g.add(back);
    const left = slab(th, S, S); left.position.set(-S / 2 + th / 2, S / 2, 0); g.add(left);
    // the parts that open: the lid lifts off, the front and the right side fall outward
    const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d');
    x.fillStyle = this.pal.boxLight; x.fillRect(0, 0, 256, 256); x.fillStyle = ink; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '700 84px ' + FONT; x.fillText(name || '', 128, 134);
    const tx = new T.CanvasTexture(c); tx.colorSpace = T.SRGBColorSpace;
    const fm = mat(), frontFace = this.toon('#FFFFFF'); frontFace.map = tx; frontFace.transparent = true;
    const frontPivot = new T.Group(); frontPivot.position.set(0, 0, S / 2); g.add(frontPivot);
    const front = new T.Mesh(new T.BoxGeometry(S, S, th), [fm, fm, fm, fm, frontFace, fm]); front.position.set(0, S / 2, -th / 2); front.castShadow = true; edge(front); frontPivot.add(front);
    const rightPivot = new T.Group(); rightPivot.position.set(S / 2, 0, 0); g.add(rightPivot);
    const right = slab(th, S, S); right.position.set(-th / 2, S / 2, 0); rightPivot.add(right);
    const lid = slab(S, th, S); lid.position.set(0, S - th / 2, 0); g.add(lid);
    const inside = new T.Group(); g.add(inside);
    const items = {}, hitM = new T.MeshBasicMaterial({ visible: false });
    const hitBox = (grp, w, h, d, x, y, z) => { const m = new T.Mesh(new T.BoxGeometry(w, h, d), hitM); m.position.set(x, y, z); grp.add(m); };
    { // the flag, hung from a rod at the top of the back wall
      const fc = document.createElement('canvas'); fc.width = 320; fc.height = 200; const f = fc.getContext('2d');
      f.fillStyle = ink; f.fillRect(0, 0, 320, 200); f.fillStyle = this.pal.boxLight; f.textAlign = 'center'; f.textBaseline = 'middle'; f.font = '700 74px ' + FONT; f.fillText(name || '', 160, 104);
      const ft = new T.CanvasTexture(fc); ft.colorSpace = T.SRGBColorSpace;
      const FW = 0.56, FH = 0.35, geo = new T.PlaneGeometry(FW, FH, 12, 8); geo.translate(0, -FH / 2, 0);
      const flag = new T.Mesh(geo, new T.MeshBasicMaterial({ map: ft, side: T.DoubleSide, transparent: true }));
      flag.userData.p0 = geo.attributes.position.array.slice(); flag.userData.FH = FH;
      const grp = new T.Group(); grp.add(flag);
      hitBox(grp, FW + 0.16, FH + 0.18, 0.14, 0, -FH / 2, 0.05);
      grp.position.set(0.1, 0.98, -S / 2 + th + 0.035); inside.add(grp); items.flag = grp; items.flagMesh = flag;
    }
    { // three bars racked on the side wall
      const grp = new T.Group(), K = this.toon('#2B2B2B');
      [0.42, 0.6, 0.78].forEach((y) => {
        const bar = this.flBarGroup(); bar.position.set(0, y, 0); bar.scale.setScalar(0.4); bar.rotation.y = Math.PI / 2; grp.add(bar);
        [-0.25, 0.25].forEach((hz) => { const h = new T.Mesh(new T.BoxGeometry(0.09, 0.03, 0.04), K); h.position.set(-0.03, y - 0.03, hz); grp.add(h); });
      });
      hitBox(grp, 0.22, 0.62, 1.0, 0.02, 0.6, 0);
      grp.position.set(-S / 2 + th + 0.06, 0, 0.02); inside.add(grp); items.bar = grp;
    }
    { // the plates, sorted into tall piles under the flag
      const grp = new T.Group(), own = (gym.own && gym.own[gym.unit]) || [], spAll = this.specsFor(gym.unit);
      const sp = spAll.filter((s) => !own.length || own.indexOf(s.kg) >= 0).slice(0, 6), sc = 0.52;
      const spots = [[-0.16, -0.34], [0.15, -0.34], [0.43, -0.34], [-0.02, -0.06], [0.27, -0.06], [0.48, -0.06]];
      sp.forEach((s, i) => {
        const [cx, cz] = spots[i], cnt = s.d > 0.4 ? 6 : 5;
        for (let j = 0; j < cnt; j++) { const p = this.plate(s); p.scale.setScalar(sc); p.rotation.y = j * 0.7; p.position.set(cx, 0.004 + j * s.t * sc + s.t * sc / 2, cz); p.traverse((m) => { if (m.isMesh) m.castShadow = true; }); grp.add(p); }
      });
      hitBox(grp, 0.95, 0.4, 0.62, 0.16, 0.18, -0.2);
      grp.position.set(0, th, 0); inside.add(grp); items.plates = grp;
    }
    { // a kettlebell out front, facing the camera
      const kb = this.kettlebell(String(gym.unit || 'kg').toUpperCase()), grp = new T.Group(); kb.scale.setScalar(0.26); kb.rotation.y = 0.65; grp.add(kb);
      hitBox(grp, 0.36, 0.42, 0.36, 0, 0.2, 0);
      grp.position.set(-0.32, th, 0.3); inside.add(grp); items.bell = grp;
    }
    const fade = [front, right, lid];
    const setOp = (m, o) => m.traverse((q) => { if (q.material) (Array.isArray(q.material) ? q.material : [q.material]).forEach((mt) => { mt.opacity = o; mt.transparent = o < 1; mt.depthWrite = o > 0.5; }); });
    g.userData = {
      items, S,
      open: (k) => {
        const e = Math.min(1, Math.max(0, k)), a = Math.min(1, e / 0.7), fall = a * a * (3 - 2 * a);
        frontPivot.rotation.x = fall * Math.PI / 2; rightPivot.rotation.z = -fall * Math.PI / 2;
        lid.position.y = S - th / 2 + fall * 0.9; lid.rotation.z = fall * 0.4;
        const fo = Math.max(0, 1 - Math.max(0, (e - 0.35) / 0.4));
        fade.forEach((m) => { setOp(m, fo); m.visible = fo > 0.01; });
        ['flag', 'bar', 'plates', 'bell'].forEach((key, i) => { const q = Math.min(1, Math.max(0, (e - 0.45 - i * 0.08) / 0.35)); items[key].scale.setScalar(Math.max(0.0001, this.outBack(q, 1.6))); });
      },
      // hung from the top: the free bottom edge moves most, ripples run across
      wave: (t) => {
        const m = items.flagMesh, p = m.geometry.attributes.position, a = p.array, p0 = m.userData.p0, FH = m.userData.FH;
        for (let i = 0; i < a.length; i += 3) { const xx = p0[i], dn = -p0[i + 1] / FH; a[i + 2] = (Math.sin(t * 2.6 + xx * 9 - dn * 2) * 0.028 + Math.sin(t * 1.3 + xx * 4) * 0.012) * dn; a[i] = p0[i] + Math.sin(t * 2.6 + xx * 9) * 0.006 * dn; }
        p.needsUpdate = true;
      }
    };
    g.userData.open(0);
    return g;
  }
  // the last slot in the gym row: an empty, dashed box with a plus — tap it to set up another gym
  gymAddModel() {
    const T = this.THREE, g = new T.Group(), S = 1.15, h = S / 2, mat = new T.MeshBasicMaterial({ color: this.pal.boxDark });
    // twelve dashed edges, each dash a thin stroke
    const C = [[-h, 0, -h], [h, 0, -h], [h, 0, h], [-h, 0, h], [-h, S, -h], [h, S, -h], [h, S, h], [-h, S, h]].map((p) => new T.Vector3(...p));
    const E = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
    const dash = 0.07, gap = 0.05, geo = new T.CylinderGeometry(0.007, 0.007, dash, 6), Y = new T.Vector3(0, 1, 0);
    E.forEach(([i, j]) => {
      const a = C[i], b = C[j], dir = b.clone().sub(a), L = dir.length(); dir.normalize();
      const n = Math.floor((L + gap) / (dash + gap)), off = (L - (n * dash + (n - 1) * gap)) / 2, q = new T.Quaternion().setFromUnitVectors(Y, dir);
      for (let k = 0; k < n; k++) { const m = new T.Mesh(geo, mat); m.quaternion.copy(q); m.position.copy(a).addScaledVector(dir, off + k * (dash + gap) + dash / 2); g.add(m); }
    });
    const hit = new T.Mesh(new T.BoxGeometry(S, S, S), new T.MeshBasicMaterial({ visible: false })); hit.position.y = S / 2; g.add(hit);
    g.userData = { add: true, items: {}, open: () => {}, wave: () => {} };
    return g;
  }
