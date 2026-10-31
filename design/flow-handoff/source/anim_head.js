// ===================== the UI Animation Lab's two scenes, as a layer over the phone =====================
// 'open': the app opening (title + floating plates) · 'done': the session's plates fall onto a scale.
// Settings follow the UI Animation Lab (saved in this browser), the palette follows the Layout Lab.
class AnimLayer {
  constructor(el, scene, opts) {
    this.stage = el; this.opts = opts || {}; this.state = { scene };
    let art = null; try { art = JSON.parse(localStorage.getItem('dz-art') || 'null'); } catch (e) {}
    this.pal = Object.assign({ boxLight: '#EFE3CF', boxDark: '#4A3426', bgColor: '#E8742C' }, art || {});
    this.FONTS = [
      ['Playfair Display', 900, 'Georgia, serif'], ['Fraunces', 900, 'Georgia, serif'], ['DM Serif Display', 400, 'Georgia, serif'],
      ['Archivo Black', 400, 'Arial, sans-serif'], ['Bebas Neue', 400, 'Arial, sans-serif'], ['Anton', 400, 'Arial, sans-serif'],
      ['Space Grotesk', 700, 'Arial, sans-serif'], ['Permanent Marker', 400, 'cursive']
    ];
    this.DEF = __ANIM_DEF__;
    this.SPECS = [
      { kg: 25, label: '25', color: '#D3262E', ink: '#FFFFFF', d: 0.450, t: 0.056, kind: 'bumper' },
      { kg: 20, label: '20', color: '#1E5BC6', ink: '#FFFFFF', d: 0.450, t: 0.046, kind: 'bumper' },
      { kg: 15, label: '15', color: '#F3C318', ink: '#1A1A1A', d: 0.450, t: 0.036, kind: 'bumper' },
      { kg: 10, label: '10', color: '#2E8A4B', ink: '#FFFFFF', d: 0.450, t: 0.027, kind: 'bumper' },
      { kg: 5, label: '5', color: '#F2F2EE', ink: '#1A1A1A', d: 0.230, t: 0.024, kind: 'change' },
      { kg: 2.5, label: '2.5', color: '#D3262E', ink: '#FFFFFF', d: 0.190, t: 0.019, kind: 'change' },
      { kg: 2, label: '2', color: '#1E5BC6', ink: '#FFFFFF', d: 0.175, t: 0.017, kind: 'change' },
      { kg: 1.5, label: '1.5', color: '#F3C318', ink: '#1A1A1A', d: 0.160, t: 0.015, kind: 'change' },
      { kg: 1, label: '1', color: '#2E8A4B', ink: '#FFFFFF', d: 0.150, t: 0.013, kind: 'change' }
    ];
    this.SPECS.forEach((sp) => { sp.unit = 'KG'; });
    this.cache = {};
    let saved = null; try { saved = JSON.parse(localStorage.getItem('ui-anim-open') || 'null'); } catch (e) {}
    this.o = Object.assign({}, this.DEF, saved || {});
    if (!this.o.title) this.o.title = this.DEF.title;
    if (this.opts.label) this.o.dLabel = this.opts.label;
    this.ANIMALS = [[4.5, 'a house cat'], [10, 'a beagle'], [30, 'a golden retriever'], [45, 'a wolf'], [85, 'a kangaroo'], [110, 'a giant panda'], [180, 'a lion'], [210, 'a gorilla'],
      [300, 'a grizzly bear'], [450, 'a polar bear'], [550, 'a horse'], [650, 'a moose'], [900, 'a bison'], [1200, 'a giraffe'], [1800, 'a hippo'], [2300, 'a rhino'], [6000, 'an elephant'], [8000, 'a T. rex'], [30000, 'a humpback whale'], [150000, 'a blue whale']];
    this.running = []; this.timers = []; this.plates = []; this.H = {};
    el.style.touchAction = 'none';
    this.bindDrag(el);
    this.play();
  }
  ready() { return this.state.scene !== 'done' || !!(this.D && this.D.msgShown); }
  destroy() {
    this.dead = true;
    this.timers.forEach(clearTimeout); cancelAnimationFrame(this.raf);
    this.running.forEach((a) => { try { a.cancel(); } catch (e) {} });
    if (this.T3 && this.T3.renderer) this.T3.renderer.dispose();
  }
  donePlates(o) { return o.d25 * 25 + o.d20 * 20 + o.d15 * 15 + o.d10 * 10 + o.d5 * 5 + o.d2 * 2.5; }
  doneLoad(o) { return this.donePlates(o) + (o.dBar ? 20 : 0); }
  // the prototype hands in the real session: its volume and the plates of its kit
  doneTotal(o) { if (this.opts.total != null) return this.opts.total; return o.dMode === 'volume' ? this.doneLoad(o) * o.dSets * o.dReps : this.doneLoad(o); }
  fmtKg(v) { return (Math.round(v * 10) / 10).toLocaleString('en-US'); }
