
  // ===================== FLOW, round 11 =====================
  // scrubbing a whiteboard clean: wherever the finger goes, the marker comes off; enough of it and the board is clean
  flBoardWiper(wb, onClean) {
    const T = this.THREE, bc = wb.userData.c, bx = bc.getContext('2d'), clean = document.createElement('canvas'); clean.width = bc.width; clean.height = bc.height;
    { const tmp = this.whiteboardModel(); this.flDrawBoard(tmp, null); clean.getContext('2d').drawImage(tmp.userData.c, 0, 0); }
    const cells = new Set(), CW = 10, CH = 5; let done = false;
    return {
      reset: () => { cells.clear(); done = false; },
      wipeAt: (e) => {
        if (done) return;
        const hit = this.flRay(e).intersectObject(wb.userData.board, false)[0]; if (!hit || !hit.uv) return;
        const x = hit.uv.x * bc.width, y = (1 - hit.uv.y) * bc.height, r = 92;
        bx.save(); bx.beginPath(); bx.arc(x, y, r, 0, Math.PI * 2); bx.clip(); bx.drawImage(clean, 0, 0); bx.restore(); wb.userData.tex.needsUpdate = true;
        if (y > 150) { for (let ox = -1; ox <= 1; ox++) for (let oy = -1; oy <= 1; oy++) { const cx = Math.floor((x + ox * r * 0.6) / bc.width * CW), cyy = Math.floor((y + oy * r * 0.6 - 150) / (bc.height - 150) * CH); if (cx >= 0 && cx < CW && cyy >= 0 && cyy < CH) cells.add(cx + ',' + cyy); } }
        if (cells.size >= CW * CH * 0.45) {
          done = true; bx.drawImage(clean, 0, 0); wb.userData.tex.needsUpdate = true;
          this.buzz('success'); this.flCheckSound(); this.flSparkles(wb.localToWorld(new T.Vector3(0, 1.45, 0.3)), 5, 0.9);
          onClean();
        }
      }
    };
  }
  // the session's over: the scale gets the rough, hand-drawn edges by default
  flFinish() {
    const F = this.FL; F.ui.innerHTML = ''; F.swipe = false; F.onSwipe = null; F.onTap = null; F.sw.style.display = 'none'; F.sw.style.bottom = '34px';
    this.flLater(() => { this.flStep = 'done'; this.flApplyStyle(); this.showSessionOver(); }, 500);
  }
