// Will's palette and layout, for browsers that have none saved
;(function(){ try { var S = {"layoutlab-v4": "{\"v\": 1, \"room\": {\"cols\": 9, \"rows\": 7}, \"objects\": {\"platform\": {\"p\": [0.66, 0, -1.86], \"r\": 0, \"s\": 1}, \"rack\": {\"p\": [0.61, 0, -2.31], \"r\": 0, \"s\": 1}, \"bench\": {\"p\": [0.95, 0, 0.63], \"r\": 180, \"s\": 1}, \"bottle\": {\"p\": [0.56, 0.1, -0.26], \"r\": 0, \"s\": 1, \"removed\": true}, \"board\": {\"p\": [-2.16, 0, -3.07], \"r\": 25, \"s\": 1}, \"shelf\": {\"p\": [0.06, 0.3, 2.32], \"r\": 0, \"s\": 1}, \"flag\": {\"p\": [3.2, 1.95, -3.99], \"r\": 0, \"s\": 1}, \"pr\": {\"p\": [-3.97, 1.15, -2.76], \"r\": 90, \"s\": 1}, \"bell\": {\"p\": [3.65, 1.75, -3.95], \"r\": 0, \"s\": 1, \"removed\": true}, \"window\": {\"p\": [0, -0.25, 0.65], \"r\": 0, \"s\": 1, \"removed\": true}, \"clip\": {\"p\": [3.94, 1.3, -3], \"r\": -90, \"s\": 1, \"removed\": true}}, \"added\": [{\"kind\": \"kitplates\", \"p\": [3.45, 0, -1.85], \"r\": 0, \"s\": 1}, {\"kind\": \"wallfan\", \"p\": [4.94, 2, -2.75], \"r\": -90, \"s\": 1}, {\"kind\": \"barholder\", \"p\": [5, 0, -0.45], \"r\": -90, \"s\": 1}, {\"kind\": \"wallwindow\", \"p\": [5, -0.15, 1.2], \"r\": -90, \"s\": 1}], \"shots\": {\"overview\": {\"T\": [0.44, 1.33, -0.89], \"P\": [13.28, 10.8, 14.36], \"fov\": 50}, \"corner\": {\"T\": [-4.31, 0.69, -0.22], \"P\": [1.27, 2.01, 3.24], \"fov\": 50}, \"flag\": {\"T\": [3.03, 0.98, -2.31], \"P\": [-0.45, 6.06, 1.46], \"fov\": 50}, \"pr\": {\"T\": [-3.93, 1.18, -2.72], \"P\": [-0.81, 1.77, -0.02], \"fov\": 50}, \"board\": {\"T\": [-0.93, 1.97, 2.15], \"P\": [-0.65, 2.21, 3.29], \"fov\": 40}, \"kit\": {\"T\": [2.59, 1.44, -1.05], \"P\": [-0.31, 5.35, 4.42], \"fov\": 50}, \"setv\": {\"T\": [2.38, 1.54, -1.86], \"P\": [3.04, 1.75, -0.89], \"fov\": 50}}, \"palette\": {\"light\": \"#F0E2F3\", \"dark\": \"#6C3713\", \"bg\": \"#FF6200\", \"bgStyle\": \"flat\"}}", "dz-art": "{\"boxLight\": \"#F0E2F3\", \"boxDark\": \"#6C3713\", \"bgColor\": \"#FF6200\", \"bgMode\": \"colour\", \"cloudReal\": 1, \"flagFont\": \"playfair\"}"}; for (var k in S) if (localStorage.getItem(k) == null) localStorage.setItem(k, S[k]); } catch (e) {} })();
// ===================== GLFX: the boards' SVG looks (duotone, posterize, sketch line) as one WebGL pass =====================
// one pipeline everywhere: WebKit (iPhone) drops CSS filter:url(#svg) on canvases, so the look is drawn in a shader
class GLFX {
  static on = true;
  static per = new WeakMap();
  static hex(h) { h = String(h || '#000000'); if (h[0] !== '#') h = '#000000'; if (h.length === 4) h = '#' + h[1] + h[1] + h[2] + h[2] + h[3] + h[3]; const c = parseInt(h.slice(1, 7), 16); return [(c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255]; }
  static get(R) {
    let S = this.per.get(R); if (S) return S;
    const T = window.__THREE || (window.PlateKit && window.PlateKit.THREE); if (!T) return null;
    const rt = new T.WebGLRenderTarget(4, 4, { samples: 4, depthBuffer: true, stencilBuffer: false });
    const mat = new T.ShaderMaterial({
      uniforms: {
        tSrc: { value: rt.texture }, uRes: { value: new T.Vector2(1, 1) }, uPx: { value: 1 },
        uCon: { value: 1 }, uBri: { value: 1 }, uSat: { value: 1 }, uHue: { value: 0 },
        uPost: { value: 0 }, uDuo: { value: 0 }, uDk: { value: new T.Vector3() }, uLt: { value: new T.Vector3() },
        uSk: { value: 0 }, uSkCol: { value: new T.Vector3() }, uW: { value: 2.5 }, uRough: { value: 6 }, uFq: { value: 0.03 },
        uGrain: { value: 0.45 }, uDouble: { value: 1 }, uWarp: { value: 0.35 }, uSeed: { value: 0 }
      },
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: `
precision highp float;
varying vec2 vUv;
uniform sampler2D tSrc; uniform vec2 uRes; uniform float uPx;
uniform float uCon, uBri, uSat, uHue, uPost, uDuo, uSk, uW, uRough, uFq, uGrain, uDouble, uWarp, uSeed;
uniform vec3 uDk, uLt, uSkCol;
float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
// fractal noise, two octaves, roughly feTurbulence's 0..1 spread around 0.5
float fb(vec2 p){ return 0.5 + ((vn(p) - 0.5) * 0.66 + (vn(p * 2.0 + 17.3) - 0.5) * 0.33) * 1.35; }
vec2 n2(vec2 p, float s){ return vec2(fb(p + vec2(s, 3.1 * s)), fb(p + vec2(41.7 + s, 9.2 - s))); }
vec3 toS(vec3 c){ return mix(c * 12.92, 1.055 * pow(max(c, 0.0), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
vec4 px(vec2 cssP){ vec4 t = texture2D(tSrc, cssP / uRes); return t; }
// the colour chain, on straight (not premultiplied) sRGB
vec3 grade(vec3 c){
  c = (c - 0.5) * uCon + 0.5; c = c * uBri;
  float l = dot(c, vec3(0.2126, 0.7152, 0.0722)); c = mix(vec3(l), c, uSat);
  if (abs(uHue) > 0.01) { float a = radians(uHue), cs = cos(a), sn = sin(a);
    mat3 m = mat3(0.213 + cs * 0.787 - sn * 0.213, 0.213 - cs * 0.213 + sn * 0.143, 0.213 - cs * 0.213 - sn * 0.787,
                  0.715 - cs * 0.715 - sn * 0.715, 0.715 + cs * 0.285 + sn * 0.140, 0.715 - cs * 0.715 + sn * 0.715,
                  0.072 - cs * 0.072 + sn * 0.928, 0.072 - cs * 0.072 - sn * 0.283, 0.072 + cs * 0.928 + sn * 0.072);
    c = m * c; }
  c = clamp(c, 0.0, 1.0);
  if (uDuo > 0.5) c = vec3(dot(c, vec3(0.299, 0.587, 0.114)));
  if (uPost >= 2.0) { float n = uPost; c = min(floor(c * n), n - 1.0) / (n - 1.0); }
  if (uDuo > 0.5) c = mix(uDk, uLt, c.r);
  return c;
}
vec4 fill(vec2 p){ vec4 t = px(p); if (t.a < 0.002) return vec4(0.0); vec3 c = toS(t.rgb / t.a); return vec4(grade(c), t.a); }
float alphaAt(vec2 p){ return px(p).a; }
// feMorphology dilate, then 'out' the shape: a band around the silhouettes
float ring(vec2 p, float w){
  float m = alphaAt(p);
  for (int i = 0; i < 12; i++) { float a = float(i) * 0.5235988; vec2 d = vec2(cos(a), sin(a));
    m = max(m, alphaAt(p + d * w)); m = max(m, alphaAt(p + d * w * 0.5)); }
  return m * (1.0 - alphaAt(p));
}
void main(){
  vec2 p = vUv * uRes;                       // CSS px
  vec4 base;
  if (uSk > 0.5) {
    vec2 a = n2(p * uFq, uSeed), b = n2(p * uFq, uSeed + 7.7);
    base = fill(p + uRough * uWarp * (a - 0.5));
    float g = clamp(4.0 * uGrain * vn(p * 0.85 + 5.0) + (1.0 - 2.2 * uGrain), 0.0, 1.0);
    float l1 = ring(p + uRough * (a - 0.5), uW) * g;
    vec4 o = vec4(base.rgb * base.a, base.a);
    o = vec4(uSkCol * l1, l1) + o * (1.0 - l1);
    if (uDouble > 0.5) { float l2 = ring(p + uRough * (b - 0.5), max(0.5, uW * 0.7)) * g; o = vec4(uSkCol * l2, l2) + o * (1.0 - l2); }
    gl_FragColor = o;
  } else {
    base = fill(p);
    gl_FragColor = vec4(base.rgb * base.a, base.a);
  }
}`,
      depthTest: false, depthWrite: false, transparent: false
    });
    const scene = new T.Scene(), cam = new T.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    const quad = new T.Mesh(new T.PlaneGeometry(2, 2), mat); quad.frustumCulled = false; scene.add(quad);
    S = { T, rt, mat, scene, cam, v: new T.Vector2() };
    this.per.set(R, S); return S;
  }
  static begin(R) {
    const S = this.get(R); if (!S) return false;
    R.getDrawingBufferSize(S.v);
    if (S.rt.width !== S.v.x || S.rt.height !== S.v.y) S.rt.setSize(S.v.x, S.v.y);
    S.rt.texture.colorSpace = S.T.NoColorSpace;
    R.setRenderTarget(S.rt); return true;
  }
  static end(R, P) {
    const S = this.get(R); if (!S) return;
    R.setRenderTarget(null);
    const u = S.mat.uniforms, pr = R.getPixelRatio();
    u.uRes.value.set(S.v.x / pr, S.v.y / pr); u.uPx.value = pr;
    u.uCon.value = P.contrast != null ? P.contrast : 1; u.uBri.value = P.bright != null ? P.bright : 1;
    u.uSat.value = P.saturate != null ? P.saturate : 1; u.uHue.value = P.hue || 0;
    u.uPost.value = P.posterize >= 2 ? Math.round(P.posterize) : 0; u.uDuo.value = P.duotone ? 1 : 0;
    u.uDk.value.fromArray(this.hex(P.dk)); u.uLt.value.fromArray(this.hex(P.lt));
    u.uSk.value = P.sketch ? 1 : 0; u.uSkCol.value.fromArray(this.hex(P.skCol));
    u.uW.value = P.skWidth != null ? P.skWidth : 2.5; u.uRough.value = P.skRough != null ? P.skRough : 6;
    u.uFq.value = P.skScale != null ? P.skScale : 0.03; u.uGrain.value = P.skGrain != null ? P.skGrain : 0.45;
    u.uDouble.value = P.skDouble === false ? 0 : 1; u.uWarp.value = P.skWarp != null ? P.skWarp : 0.35; u.uSeed.value = P.seed || 0;
    const ac = R.autoClear; R.autoClear = true;
    R.render(S.scene, S.cam);
    R.autoClear = ac;
  }
  static draw(R, scene, cam, P) {
    if (!P || !(P.duotone || P.sketch || P.posterize >= 2 || P.contrast !== 1 || P.bright !== 1)) { R.render(scene, cam); return; }
    if (!this.begin(R)) { R.render(scene, cam); return; }
    R.render(scene, cam); this.end(R, P);
  }
  // CSS filters left on the canvas: only the ones WebKit handles (no url(), the shader does colour)
  static cssLeft(parts) { return parts.filter((p) => /^(blur|drop-shadow)/.test(p)); }
  static boilSeed(rate) { if (!rate) return 0; const now = performance.now(); return Math.floor(now / (1000 / rate)) * 13.7 % 1000; }
}

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
    this.DEF = {"d25": 3, "d20": 0, "d15": 0, "d10": 0, "d5": 0, "d2": 0, "dMode": "volume", "dSets": 5, "dReps": 5, "dBar": true, "dBarDelay": 450, "dBarYaw": 30, "dInterval": 380, "dHeight": 3, "dTilt": 0.6, "dBounce": 0.5, "dMess": 0.4, "dDip": 0.5, "dShake": 0.3, "dSpeed": 1, "dStart": 500, "dScaleCol": "brown", "dTopCol": "cream", "dScaleSize": 1, "dHead": true, "dAz": 45, "dEl": 32, "dZoom": 3.5, "dCamY": 0.3, "dScaleY": 0.5, "dFont": "Space Grotesk", "dWeight": 900, "dNumSize": 96, "dNumY": 0.13, "dUnit": "kg", "dLabel": "Session total", "dShowLabel": true, "dNumCol": "cream", "dCount": true, "dMsg": "You lifted {animal}.", "dMsgFont": "title", "dMsgSize": 24, "dMsgY": 0.745, "dMsgIn": "words", "dWordGap": 260, "dSub": false, "dShowNum": false, "dDrag": true, "dV": 4, "font": "Space Grotesk", "weight": 900, "italic": false, "title": "pl8(math)", "upper": false, "textColor": "cream", "words": true, "align": "center", "size": 39, "scaleX": 1, "scaleY": 1, "lineH": 0.83, "spacing": 0.11, "textX": 0.5, "textY": 0.5, "rotate": 0, "skew": 0, "width": 0.83, "fill": "solid", "strokeW": 1, "textOpacity": 1, "textBlend": "normal", "behind": true, "shadowCol": "none", "shadowX": -8, "shadowY": 6, "shadowBlur": 0, "echoes": 0, "echoX": -40, "echoY": 40, "echoFade": 0, "echoCol": "brown", "jitterR": 0, "jitterY": 0, "waveSize": 0, "seed": 1, "idle": "none", "idleAmt": 0.5, "idleSpeed": 1, "showTag": false, "tagline": "Load it right", "tagFont": "sans", "tagSize": 14, "tagSpacing": 0.14, "tagGap": 14, "showFlag": false, "textIn": "none", "stagger": 60, "textDelay": 700, "textDur": 600, "plateKind": "real", "realMix": "all", "blend": "normal", "realOpacity": 1, "tint": 0, "saturate": 0, "spacing3d": 1.5, "surface": "toon", "tintMode": "multiply", "tintColor": "bg", "contrast": 0.71, "bright": 0.68, "hue": 0, "posterize": 2, "duotone": true, "duoLight": "cream", "pixel": 1, "outline": false, "ambient": 2.7, "sunI": 1.5, "sunA": 60, "shadow": 0, "grain": 0, "blur": 0, "style": "bumper", "count": 24, "size2": 2, "thick": 0.26, "hub": 0.29, "hole": 0.11, "rings": 0, "lineW": 0.5, "lineColor": "brown", "solid": false, "depthFade": 0, "sides": 14, "tri": false, "meridians": true, "drift": 42, "spin": 0.08, "tumble": 1, "bob": 0, "platesIn": "rise", "platesDur": 5000, "lane": 0.4, "riseHead": 0.25, "sketch": true, "skWidth": 2.5, "skRough": 6, "skScale": 0.03, "skBoil": 0, "skGrain": 0.45, "skDouble": true, "skInner": true, "skWarp": 0.35, "skCol": "brown", "orbit": true, "orbitAmt": 0.5, "orbitBack": true};
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
  animalFor(kg) {
    if (kg <= 0) return [0, 'a feather'];
    let best = this.ANIMALS[0], bd = 1e9;
    this.ANIMALS.forEach((a) => { const d = Math.abs(Math.log(kg / a[0])); if (d < bd) { bd = d; best = a; } });
    return best;
  }
  inkOn() { const o = this.o; return !!(o.outline || (o.sketch && o.skInner)); }
  inkColour() { const o = this.o; return o.sketch ? this.colour(o.skCol) : this.colour(o.lineColor); }
  colour(k) { return k === 'cream' ? this.pal.boxLight : k === 'dark' ? '#2B1E16' : k === 'bg' ? this.pal.bgColor : k === 'white' ? '#FFFFFF' : this.pal.boxDark; }
  play() {
    if (!this.stage) return;
    this.running.forEach((a) => { try { a.cancel(); } catch (e) {} }); this.running = [];
    this.timers.forEach(clearTimeout); this.timers = [];
    cancelAnimationFrame(this.raf);
    if (this.T3 && this.T3.renderer) this.T3.renderer.dispose();
    this.T3 = null; this.cache = {};
    const S = this.stage; S.innerHTML = ''; S.style.background = this.pal.bgColor;
    this.W = S.clientWidth || 390; this.Hh = S.clientHeight || 844;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const cv = document.createElement('canvas');
    cv.width = Math.round(this.W * dpr); cv.height = Math.round(this.Hh * dpr);
    Object.assign(cv.style, { position: 'absolute', left: 0, top: 0, width: this.W + 'px', height: this.Hh + 'px', zIndex: 1 });
    S.appendChild(cv); this.cv = cv; this.g = cv.getContext('2d'); this.dpr = dpr;
    // film grain: a noise tile over the plates, under the type
    const nc = document.createElement('canvas'); nc.width = nc.height = 256; const nx = nc.getContext('2d'), id = nx.createImageData(256, 256);
    for (let i = 0; i < id.data.length; i += 4) { const v = Math.random() * 255; id.data[i] = id.data[i + 1] = id.data[i + 2] = v; id.data[i + 3] = 255; }
    nx.putImageData(id, 0, 0);
    this.grainEl = document.createElement('div');
    Object.assign(this.grainEl.style, { position: 'absolute', inset: 0, pointerEvents: 'none', backgroundImage: 'url(' + nc.toDataURL() + ')', mixBlendMode: 'overlay', opacity: 0, display: 'none', zIndex: 2 });
    S.appendChild(this.grainEl);
    this.fxSvg = null; this.fxKey = null;
    this.textLayer = document.createElement('div');
    Object.assign(this.textLayer.style, { position: 'absolute', inset: 0, pointerEvents: 'none' });
    S.appendChild(this.textLayer);
    const done = this.state.scene === 'done';
    if (done) this.buildDone(); else { this.makePlates(false, true); this.buildText(); }
    this.last = performance.now(); this.t = 0;
    const loop = (now) => {
      if (this.dead) return;
      const dt = Math.min(0.05, (now - this.last) / 1000); this.last = now; this.t += dt;
      if (done) this.stepDone(dt, now); else { this.step(dt); this.draw(now); }
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);
  }
  go(e, kf, o) { const a = e.animate(kf, { duration: o.d || 400, delay: o.delay || 0, easing: o.easing || 'cubic-bezier(.3,1.45,.45,1)', fill: o.fill || 'both' }); this.running.push(a); return a; }
  el(tag, css, parent, html) { const e = document.createElement(tag); Object.assign(e.style, css || {}); if (html != null) e.innerHTML = html; parent.appendChild(e); return e; }
  buildText() {
    if (!this.textLayer) return;
    this.running.forEach((a) => { try { a.cancel(); } catch (e) {} }); this.running = [];
    const o = this.o, L = this.textLayer; L.innerHTML = '';
    const F = this.FONTS.find((f) => f[0] === o.font) || this.FONTS[0], ff = "'" + F[0] + "', " + F[2], col = this.colour(o.textColor), wt = o.weight || F[1];
    const d0 = o.textDelay, st = o.stagger, dur = o.textDur, mode = o.textIn, sp = 1 / Math.max(0.05, o.idleSpeed), amt = o.idleAmt;
    // a seeded random so the chaos sliders give the same layout until "Shuffle" moves
    let sd = o.seed * 9301 + 49297; const rnd = () => { sd = (sd * 9301 + 49297) % 233280; return sd / 233280; };
    // the box sits on its own z-layer so it can go in front of or behind the plates and blend with them
    const box = this.el('div', { position: 'absolute', left: (o.textX * 100) + '%', top: (o.textY * 100) + '%', width: Math.round(o.width * this.W) + 'px',
      transform: 'translate(-50%,-50%) rotate(' + o.rotate + 'deg) skewX(' + (-o.skew) + 'deg) scale(' + o.scaleX + ',' + o.scaleY + ')',
      zIndex: o.behind ? 0 : 3, opacity: o.textOpacity, mixBlendMode: o.textBlend, pointerEvents: 'none' }, L);
    const idleBox = this.el('div', { display: 'flex', flexDirection: 'column', alignItems: o.align === 'left' ? 'flex-start' : o.align === 'right' ? 'flex-end' : 'center', gap: o.tagGap + 'px', textAlign: o.align }, box);
    const loop = (e, kf, d, delay) => { const a = e.animate(kf, { duration: d, delay: delay || 0, iterations: Infinity, direction: 'alternate', easing: 'ease-in-out' }); this.running.push(a); };
    const iD = 1400 * sp;
    if (o.idle === 'float') loop(idleBox, [{ transform: 'translateY(0)' }, { transform: 'translateY(' + (-amt * 40) + 'px)' }], iD, d0);
    else if (o.idle === 'breathe') loop(idleBox, [{ transform: 'scale(1)' }, { transform: 'scale(' + (1 + amt * 0.2) + ')' }], iD, d0);
    else if (o.idle === 'sway') loop(idleBox, [{ transform: 'rotate(' + (-amt * 10) + 'deg)' }, { transform: 'rotate(' + (amt * 10) + 'deg)' }], iD * 1.3, d0);
    else if (o.idle === 'jelly') loop(idleBox, [{ transform: 'scale(1,1)' }, { transform: 'scale(' + (1 + amt * 0.18) + ',' + (1 - amt * 0.14) + ')' }], iD * 0.5, d0);
    if (o.showFlag) {
      const fw = this.el('div', { position: 'relative', width: '160px', height: '108px', flex: 'none' }, idleBox);
      const rod = this.el('div', { position: 'absolute', left: 0, top: 0, width: '160px', height: '6px', borderRadius: '3px', background: this.pal.boxDark }, fw);
      const flag = this.el('div', { position: 'absolute', left: '12px', top: '4px', width: '136px', height: '100px', background: this.pal.boxDark, transformOrigin: 'top center', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Playfair Display', Georgia, serif", fontWeight: 900, fontSize: '58px', color: this.pal.boxLight, boxShadow: '0 10px 24px rgba(0,0,0,0.18)' }, fw, '79');
      if (mode !== 'none') {
        const fd = Math.max(0, d0 - 450);
        this.go(rod, [{ transform: 'scaleX(0)' }, { transform: 'scaleX(1)' }], { d: 380, delay: fd });
        this.go(flag, [{ transform: 'scaleY(0)' }, { transform: 'scaleY(1)' }], { d: 650, delay: fd + 260 });
      }
    }
    const title = o.upper ? o.title.toUpperCase() : o.title;
    // per-letter chaos, fixed for this seed so every echo matches the main title
    const chars = title.split(''), chaos = chars.map((ch, i) => ({ r: (rnd() * 2 - 1) * o.jitterR, y: (rnd() * 2 - 1) * o.jitterY, s: 1 + o.waveSize * Math.sin(i * 1.1 + o.seed) }));
    const tw = this.el('div', { position: 'relative', width: '100%' }, idleBox);
    tw.setAttribute('aria-label', title);
    const stroke = (c) => (o.fill === 'outline' ? o.strokeW + 'px ' + c : o.fill === 'both' ? o.strokeW + 'px ' + (o.textColor === 'cream' || o.textColor === 'white' ? this.pal.boxDark : this.pal.boxLight) : '');
    const shadow = o.shadowCol === 'none' ? 'none' : o.shadowX + 'px ' + o.shadowY + 'px ' + o.shadowBlur + 'px ' + this.colour(o.shadowCol);
    const layer = (c, isEcho, k) => {
      const word = this.el('div', { display: 'flex', flexWrap: 'wrap', flexDirection: o.words ? 'column' : 'row', alignItems: o.align === 'left' ? 'flex-start' : o.align === 'right' ? 'flex-end' : 'center',
        justifyContent: o.align === 'left' ? 'flex-start' : o.align === 'right' ? 'flex-end' : 'center', fontFamily: ff, fontWeight: wt, fontStyle: o.italic ? 'italic' : 'normal',
        fontSize: o.size + 'px', lineHeight: o.lineH, letterSpacing: o.spacing + 'em', color: o.fill === 'outline' ? 'transparent' : c,
        webkitTextStroke: stroke(c), textShadow: isEcho ? 'none' : shadow }, tw);
      if (isEcho) Object.assign(word.style, { position: 'absolute', left: 0, top: 0, width: '100%', transform: 'translate(' + k * o.echoX + 'px,' + k * o.echoY + 'px)', opacity: String(Math.max(0, 1 - o.echoFade * k / (o.echoes + 1))) });
      if (isEcho) word.setAttribute('aria-hidden', 'true');
      let wb = null;
      chars.forEach((ch, i) => {
        if (ch === ' ' || !wb) { wb = this.el('span', { display: 'inline-block', whiteSpace: 'nowrap' }, word); if (ch === ' ' && o.words) return; }
        const cz = chaos[i];
        // outer span: the chaos (fixed) · middle: idle wave · inner: the entrance
        const outer = this.el('span', { display: 'inline-block', fontSize: cz.s + 'em', transform: 'translateY(' + cz.y + 'px) rotate(' + cz.r + 'deg)' }, wb);
        const mid = this.el('span', { display: 'inline-block' }, outer);
        const s = this.el('span', { display: 'inline-block', whiteSpace: 'pre' }, mid, ch === ' ' ? '&nbsp;' : ch.replace(/&/g, '&amp;').replace(/</g, '&lt;'));
        if (o.idle === 'wave') loop(mid, [{ transform: 'translateY(0)' }, { transform: 'translateY(' + (-amt * 0.35) + 'em)' }], iD * 0.6, d0 + i * 110 * sp);
        const dl = d0 + i * st + (isEcho ? k * 45 : 0);
        if (mode === 'rise') this.go(s, [{ transform: 'translateY(0.55em)', opacity: 0 }, { transform: 'none', opacity: 1 }], { d: dur, delay: dl });
        else if (mode === 'fade') this.go(s, [{ opacity: 0 }, { opacity: 1 }], { d: dur, delay: dl, easing: 'ease-out' });
        else if (mode === 'blur') this.go(s, [{ opacity: 0, filter: 'blur(12px)', transform: 'scale(1.15)' }, { opacity: 1, filter: 'blur(0px)', transform: 'none' }], { d: dur, delay: dl, easing: 'cubic-bezier(.2,.7,.3,1)' });
        else if (mode === 'pop') this.go(s, [{ opacity: 0, transform: 'scale(0.2)' }, { opacity: 1, transform: 'none' }], { d: dur, delay: dl });
        else if (mode === 'drop') this.go(s, [{ opacity: 0, transform: 'translateY(-1.2em) rotate(' + ((i % 2 ? 1 : -1) * 25) + 'deg)' }, { opacity: 1, transform: 'none' }], { d: dur, delay: dl, easing: 'cubic-bezier(.3,1.6,.5,1)' });
        else if (mode === 'spin') this.go(s, [{ opacity: 0, transform: 'rotateY(90deg) scale(0.6)' }, { opacity: 1, transform: 'none' }], { d: dur, delay: dl });
      });
    };
    for (let k = Math.round(o.echoes); k >= 1; k--) layer(this.colour(o.echoCol), true, k);
    layer(col, false, 0);
    if (o.showTag && o.tagline) {
      const tf = o.tagFont === 'mono' ? "'Space Mono', monospace" : o.tagFont === 'title' ? ff : 'Helvetica, Arial, sans-serif';
      const tag = this.el('div', { fontFamily: tf, fontWeight: o.tagFont === 'title' ? wt : 700, fontStyle: o.italic && o.tagFont === 'title' ? 'italic' : 'normal', fontSize: o.tagSize + 'px', letterSpacing: o.tagSpacing + 'em', textTransform: 'uppercase', color: col, opacity: 0.85, textAlign: o.align }, idleBox);
      tag.textContent = o.tagline;
      if (mode !== 'none') this.go(tag, [{ opacity: 0, transform: 'translateY(8px)' }, { opacity: 0.85, transform: 'none' }], { d: Math.max(300, dur), delay: d0 + title.length * st + dur * 0.4, easing: 'ease-out' });
    }
  }
  stepOrbit(f, hw, hh) {
    const o = this.o, O = this.orb || (this.orb = { yaw: 0, pitch: 0, ty: 0, tp: 0, drag: null });
    if (!O.drag && o.orbitBack !== false) { O.ty = 0; O.tp = 0; }
    const k = 1 - Math.exp(-(O.drag ? 14 : 3.2) * (1 / 60));
    O.yaw += (O.ty - O.yaw) * k; O.pitch += (O.tp - O.pitch) * k;
    // pivot: the title, sitting a little behind the screen plane
    const zP = 1.3;
    O.P = [(o.textX * 2 - 1) * hw * zP, (o.textY * 2 - 1) * hh * zP, zP * f];
    O.cy = Math.cos(O.yaw); O.sy = Math.sin(O.yaw); O.cp = Math.cos(O.pitch); O.sp = Math.sin(O.pitch);
    // the title turns with the scene (css 3d, around its own centre)
    if (this.textLayer) {
      const t = Math.abs(O.yaw) + Math.abs(O.pitch) > 0.0005 ? 'perspective(' + Math.round(f * 1.3) + 'px) rotateX(' + (-O.pitch).toFixed(4) + 'rad) rotateY(' + (-O.yaw).toFixed(4) + 'rad)' : '';
      if (this.textLayer.style.transform !== t) { this.textLayer.style.transformOrigin = (o.textX * 100) + '% ' + (o.textY * 100) + '%'; this.textLayer.style.transform = t; }
    }
  }
  orbitVec(x, y, z) {
    const O = this.orb; if (!O || !O.cy) return [x, y, z];
    const x1 = x * O.cy + z * O.sy, z1 = -x * O.sy + z * O.cy;            // turn about the vertical
    return [x1, y * O.cp - z1 * O.sp, y * O.sp + z1 * O.cp];                 // then tip about the horizontal
  }
  orbitPt(x, y, z) {
    const O = this.orb; if (!O || !O.P) return [x, y, z];
    const P = O.P, v = this.orbitVec(x - P[0], y - P[1], z - P[2]);
    return [v[0] + P[0], v[1] + P[1], v[2] + P[2]];
  }
  makePlates(keep, entrance) {
    const n = Math.round(this.o.count), rnd = (a, b) => a + Math.random() * (b - a);
    const fresh = () => ({
      u: rnd(-1.15, 1.15), v: rnd(-1.15, 1.15), z: rnd(0.75, 2.4), r0: rnd(38, 92),
      rx: rnd(0, 6.28), ry: rnd(0, 6.28), rz: rnd(0, 6.28),
      wx: rnd(-1, 1), wy: rnd(-1, 1), wz: rnd(0.4, 1) * (Math.random() < 0.5 ? -1 : 1),
      dir: rnd(0, 6.28), sp: rnd(0.5, 1.2), ph: rnd(0, 6.28), bw: rnd(0.4, 0.9), born: 0, pick: (this.pickN = (this.pickN || 0) + 1)
    });
    const drop = (p) => { if (p.realG && this.T3 && this.T3.scene) { this.T3.scene.remove(p.realG); this.T3.groups = this.T3.groups.filter((gr) => gr !== p.realG); } };
    if (keep) { while (this.plates.length > n) drop(this.plates.pop()); while (this.plates.length < n) { const p = fresh(); p.born = -1; this.plates.push(p); this.placeFree(p, true); } }
    else {
      this.plates.forEach(drop); this.plates = []; for (let i = 0; i < n; i++) this.plates.push(fresh());
      // place them one by one, each where it is farthest from the others in 3D
      const all = this.plates; this.plates = [];
      all.forEach((q) => { this.plates.push(q); this.placeFree(q, true); });
    }
    // rise: the whole field starts just below the screen and comes up at the normal rise speed,
    // so the first plate peeks in at once and the screen fills from the bottom, never faster than the drift
    if (entrance && !keep && this.o.platesIn === 'rise' && this.plates.length) {
      const hh = this.Hh / 2, top = Math.min(...this.plates.map((q) => q.v - q.r0 * this.o.size2 / (hh * q.z)));
      // head start: how much of the screen (from the bottom) is already filled when the scene opens
      const shift = 1 - top - 2 * (this.o.riseHead || 0);
      this.plates.forEach((q) => { q.v += shift; });
    }
    const now = performance.now();
    this.plates.forEach((p, i) => {
      if (p.born === -1) { p.born = now; p.delay = 0; p.inMode = 'fade'; p.inDur = 900; }
      else if (entrance || !keep) { p.born = now; p.inMode = entrance ? this.o.platesIn : 'fade';
        if (p.inMode === 'rise') { p.delay = 0; p.inDur = 0; p.inMode = null; }   // rise: no animation of its own, see below
        else { p.delay = entrance ? (i / Math.max(1, n)) * this.o.platesDur * 0.45 : 0; p.inDur = entrance ? this.o.platesDur * 0.55 : 600; }
      }
    });
  }
  step(dt) {
    const o = this.o, hh = this.Hh / 2, pulse = Math.min(0.9, o.bob / 24 * 0.9);
    for (const p of this.plates) {
      const R = p.r0 * o.size2;
      // straight up only; speed is screen px/s at the reference depth, so farther plates rise slower (parallax).
      // the pulse eases each plate's speed up and down but never lets it stop or sink
      const k = 1 + pulse * Math.sin(this.t * p.bw + p.ph);
      // with 'keep apart' on, every plate rises at the same speed in 3D, so they never catch up with each other
      p.v -= o.drift * (o.spacing3d > 0 ? 1 : p.sp) * k * dt / (hh * p.z);
      const mv = 1 + R * 1.3 / (hh * p.z);
      if (p.v < -mv) { p.v = mv; p.u = this.laneU(); if (o.spacing3d > 0) this.placeFree(p, false); }
      const s = o.spin;
      p.rx += p.wx * s * o.tumble * dt; p.rz += p.wz * s * dt; p.ry += p.wy * s * o.tumble * dt;
    }
    if (o.spacing3d > 0) {
      // two plates whose bounding spheres overlap slide apart in depth (nearer one comes forward, farther one backs off)
      const f = this.Hh * 0.9, hw = this.W / 2, P = this.plates, rate = Math.min(1, dt * 6);
      for (let i = 0; i < P.length; i++) for (let j = i + 1; j < P.length; j++) {
        const a = P[i], b = P[j], Ra = a.r0 * o.size2, Rb = b.r0 * o.size2, S = (Ra + Rb) * o.spacing3d;
        const dx = a.u * hw * a.z - b.u * hw * b.z, dy = a.v * hh * a.z - b.v * hh * b.z, flat = dx * dx + dy * dy;
        if (flat >= S * S) continue;
        const need = Math.sqrt(S * S - flat), dz = (a.z - b.z) * f;
        if (Math.abs(dz) >= need) continue;
        const sgn = dz === 0 ? (i % 2 ? 1 : -1) : Math.sign(dz), push = (need - Math.abs(dz)) / f * 0.5 * rate;
        // moving a plate in depth scales it with the distance, so its size on screen never changes
        const za = Math.min(4, Math.max(0.45, a.z + sgn * push)), zb = Math.min(4, Math.max(0.45, b.z - sgn * push));
        a.r0 *= za / a.z; b.r0 *= zb / b.z; a.z = za; b.z = zb;
      }
    }
  }
  laneU() {
    const L = Math.min(0.98, this.o.lane || 0);
    if (!L) return Math.random() * 2.1 - 1.05;
    return (Math.random() < 0.5 ? -1 : 1) * (L + Math.random() * (1.15 - L));
  }
  placeFree(p, rollV) {
    const o = this.o, f = this.Hh * 0.9, hw = this.W / 2, hh = this.Hh / 2, rnd = (a, b) => a + Math.random() * (b - a);
    let best = null, bestScore = -1;
    for (let t = 0; t < 40; t++) {
      const c = { u: this.laneU(), v: rollV ? rnd(-1.15, 1.15) : p.v, z: rnd(0.75, 2.4) };
      let score = 1e9;
      for (const q of this.plates) {
        if (q === p) continue;
        const d = Math.hypot(c.u * hw * c.z - q.u * hw * q.z, c.v * hh * c.z - q.v * hh * q.z, (c.z - q.z) * f) / ((p.r0 + q.r0) * o.size2);
        if (d < score) score = d;
      }
      if (score > bestScore) { bestScore = score; best = c; }
      if (score > 1.3) break;
    }
    if (best) { p.u = best.u; p.v = best.v; p.z = best.z; }
  }
  draw(now) {
    const o = this.o, g = this.g, W = this.W, H = this.Hh, f = H * 0.9, hw = W / 2, hh = H / 2, bg = this.pal.bgColor;
    g.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    g.clearRect(0, 0, W, H);
    g.lineJoin = 'round'; g.lineCap = 'round';
    this.stepOrbit(f, hw, hh);
    const lc = this.colour(o.lineColor), real = o.plateKind === 'real' && this.ensureThree();
    if (this.T3) {
      this.applyLook();
    }
    if (this.grainEl) {
      this.grainEl.style.opacity = String(o.grain); this.grainEl.style.display = o.grain > 0 ? 'block' : 'none';
      if (o.grain > 0) this.grainEl.style.backgroundPosition = Math.floor(Math.random() * 256) + 'px ' + Math.floor(Math.random() * 256) + 'px';
    }
    if (this.T3) { this.T3.canvas.style.display = real ? 'block' : 'none'; this.T3.groups.forEach((gr) => { gr.visible = false; }); }
    const list = this.plates.map((p) => {
      let e = 1, zOff = 0, yOff = 0;
      if (p.inMode && p.inMode !== 'none') {
        const u = Math.min(1, Math.max(0, (now - p.born - p.delay) / p.inDur)); e = 1 - Math.pow(1 - u, 3);
        if (p.inMode === 'fly') zOff = (1 - e) * 3.2;
        // rise: the field starts one full screen lower, so plates come in from the bottom first and the top ones arrive last,
        // all at the same gentle speed (a soft ease-out, never a rush)
        if (p.inMode === 'rise') { const q = 1 - Math.pow(1 - u, 2); e = 1; yOff = (1 - q) * (2.3 + 2.2 * p.r0 * o.size2 / (hh * p.z)); }
        if (u >= 1) p.inMode = null;
      }
      const z = p.z + zOff;
      return { p, z, e, yOff };
    }).sort((a, b) => b.z - a.z);
    for (const it of list) {
      const p = it.p, R = p.r0 * o.size2, T = R * o.thick;
      const [Xc, Yc, Zc] = this.orbitPt(p.u * hw * it.z, (p.v + it.yOff) * hh * it.z, it.z * f);
      const fade = 1 - o.depthFade * Math.min(1, Math.max(0, (p.z - 0.75) / 1.65));
      const alpha = fade * (p.inMode === 'fly' ? Math.min(1, it.e * 1.6) : it.e);
      if (alpha <= 0.01) continue;
      const cx = Math.cos(p.rx), sx = Math.sin(p.rx), cy = Math.cos(p.ry), sy = Math.sin(p.ry), cz = Math.cos(p.rz), sz = Math.sin(p.rz);
      // M = Ry * Rx * Rz (spin about the face normal last, so "spin" turns the plate in its own plane)
      const m = (a, b, c) => {
        let x = a * cz - b * sz, y = a * sz + b * cz, zz = c;
        const y2 = y * cx - zz * sx, z2 = y * sx + zz * cx; y = y2; zz = z2;
        const x3 = x * cy + zz * sy, z3 = -x * sy + zz * cy; x = x3; zz = z3;
        return this.orbitVec(x, y, zz);
      };
      if (real) { this.poseReal(p, Xc, Yc, Zc, m, alpha); continue; }
      const proj = (a, b, c) => { const w = m(a, b, c), X = Xc + w[0], Y = Yc + w[1], Z = Zc + w[2]; const k = f / Math.max(10, Z); return [hw + X * k, hh + Y * k]; };
      const nrm = m(0, 0, 1);
      const sF = (nrm[0] * -Xc + nrm[1] * -Yc + nrm[2] * -Zc) > 0 ? 1 : -1;
      const N = Math.max(3, Math.round(o.sides)), path = (pts) => { g.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) g.lineTo(pts[i][0], pts[i][1]); g.closePath(); };
      g.globalAlpha = alpha; g.strokeStyle = lc; g.lineWidth = o.lineW * Math.min(1.4, Math.max(0.5, 1.15 / it.z));
      // the plate is a lathe: a closed cross-section profile [radius, z] spun around the axis in N steps
      const t = T / 2, prof = this.profile(o, R, T), K = prof.length;
      const V = prof.map(([r, zl]) => { const row = []; for (let i = 0; i < N; i++) { const a = i / N * Math.PI * 2; row.push(proj(Math.cos(a) * r, Math.sin(a) * r, zl)); } return row; });
      const seg = (A, B) => { g.moveTo(A[0], A[1]); g.lineTo(B[0], B[1]); };
      const edges = (keep) => {
        g.beginPath();
        for (let k = 0; k < K; k++) {
          const k2 = (k + 1) % K, ring = keep(k), across = keep(k) && keep(k2);
          for (let i = 0; i < N; i++) {
            const i2 = (i + 1) % N;
            if (ring) seg(V[k][i], V[k][i2]);
            if (across && o.meridians) seg(V[k][i], V[k2][i]);
            if (across && o.tri) seg(V[k][i], V[k2][i2]);
          }
        }
        g.stroke();
      };
      if (o.solid) {
        // fill the outline with the background, then the front face, then only the front face's edges
        const oi = prof.findIndex(([r, zl]) => r === R && zl * sF > 0), bi = prof.findIndex(([r, zl]) => r === R && zl * sF < 0);
        g.fillStyle = bg;
        g.beginPath(); path(this.hull(V[oi].concat(V[bi]))); g.fill(); g.stroke();
        g.beginPath(); path(V[oi]); g.fill();
        edges((k) => prof[k][1] * sF > t * 0.5);
        g.beginPath(); path(V[oi]); g.stroke();
      } else {
        edges(() => true);
      }
    }
    g.globalAlpha = 1;
    if (real) GLFX.draw(this.T3.renderer, this.T3.scene, this.T3.camera, this.glfxParams());
  }
  buildDone() {
    const o = this.o;
    if (!this.ensureThree()) return;
    const THREE = this.THREE, T3 = this.T3;
    if (this.textLayer) this.textLayer.innerHTML = '';
    const scene = new THREE.Scene();
    if (window.PlateKit.RoomEnvironment) { const pm = new THREE.PMREMGenerator(T3.renderer); scene.environment = pm.fromScene(new window.PlateKit.RoomEnvironment(), 0.04).texture; scene.environmentIntensity = 0.45; }
    const hemi = new THREE.HemisphereLight('#FFFFFF', '#FFFFFF', 2.7); scene.add(hemi);
    const sun = new THREE.DirectionalLight('#FFFFFF', 1.5); scene.add(sun);
    const cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 100);
    const D = this.D = { scene, cam, hemi, sun, plates: [], total: 0, shown: 0, dipY: 0, dipV: 0, shake: 0, t0: performance.now(), landed: 0, msgShown: false, inks: [] };
    // materials follow the plates' surface choice so the scale and the plates feel like one object
    const mat = (hex) => {
      const sf = o.surface;
      if (sf === 'toon') return new THREE.MeshToonMaterial({ color: hex, gradientMap: this.toonRamp() });
      if (sf === 'clay') return new THREE.MeshLambertMaterial({ color: '#EFE6DA' });
      if (sf === 'textured') return new THREE.MeshStandardMaterial({ color: hex, roughness: 0.75, metalness: 0.05 });
      return new THREE.MeshLambertMaterial({ color: hex });
    };
    const col = (k) => (k === 'bg' ? this.pal.bgColor : this.colour(k));
    const body = mat(col(o.dScaleCol)), top = mat(col(o.dTopCol)), dark = mat('#2B1E16');
    const ink = new THREE.LineBasicMaterial({ color: this.colour(o.lineColor) });
    const add = (geo, m, x, y, z, parent) => {
      const me = new THREE.Mesh(geo, m); me.position.set(x, y, z); parent.add(me);
      const l = new THREE.LineSegments(new THREE.EdgesGeometry(geo, 30), ink); l.position.copy(me.position); parent.add(l); D.inks.push(l);
      return me;
    };
    const k = o.dScaleSize, G = new THREE.Group(); G.scale.setScalar(k); scene.add(G); D.scaleG = G;
    // a low platform floor scale: base, rubber-topped platform that dips, four feet, a column with a digital head
    add(new THREE.BoxGeometry(0.84, 0.07, 0.84), body, 0, 0.055, 0, G);
    [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sz]) => add(new THREE.CylinderGeometry(0.035, 0.045, 0.03, 10), dark, sx * 0.36, 0.015, sz * 0.36, G));
    const P = new THREE.Group(); G.add(P); D.platform = P;
    add(new THREE.BoxGeometry(0.78, 0.04, 0.78), body, 0, 0.11, 0, P);
    add(new THREE.BoxGeometry(0.72, 0.01, 0.72), top, 0, 0.135, 0, P);
    D.platTop = 0.14;
    if (o.dHead) {
      add(new THREE.CylinderGeometry(0.022, 0.022, 0.72, 10), body, 0, 0.45, -0.39, G);
      const head = new THREE.Group(); head.position.set(0, 0.86, -0.39); head.rotation.x = -0.35; G.add(head);
      add(new THREE.BoxGeometry(0.36, 0.19, 0.08), body, 0, 0, 0, head);
      const rc = document.createElement('canvas'); rc.width = 512; rc.height = 224;
      const tex = new THREE.CanvasTexture(rc); tex.colorSpace = THREE.SRGBColorSpace;
      const scr = new THREE.Mesh(new THREE.PlaneGeometry(0.31, 0.135), new THREE.MeshBasicMaterial({ map: tex })); scr.position.set(0, 0, 0.041); head.add(scr);
      D.readout = { c: rc, x: rc.getContext('2d'), tex };
      this.drawReadout(0);
    }
    // the session's plates, heaviest at the bottom of the stack
    const list = this.opts.plates ? this.opts.plates.slice() : [];
    if (!this.opts.plates) [['d25', 0], ['d20', 1], ['d15', 2], ['d10', 3], ['d5', 4], ['d2', 5]].forEach(([key, si]) => { for (let i = 0; i < Math.round(o[key]); i++) list.push(this.SPECS[si]); });
    let h = 0;
    list.forEach((spec, i) => {
      const g = this.plate(spec); scene.add(g);   // plates stay real size whatever the scale's size
      const jit = o.dMess * 0.06;
      const p = { g, spec, y: h + spec.t / 2, x: (Math.random() - 0.5) * 2 * jit, z: (Math.random() - 0.5) * 2 * jit, ry: Math.random() * Math.PI * 2,
        tx: (Math.random() - 0.5) * 2 * o.dTilt * 1.2, tz: (Math.random() - 0.5) * 2 * o.dTilt * 1.2, spin: (Math.random() - 0.5) * 4 * o.dTilt,
        at: o.dStart + i * o.dInterval, landed: false };
      h += spec.t + 0.001;
      g.visible = false; D.plates.push(p);
    });
    D.stackTop = h;
    if (o.dBar) {
      // the barbell: 2.2 m, shaft between two collars and sleeves, along its local x
      const bg = new THREE.Group(), steel = mat('#B9BEC4'), dk = mat('#6E7378');
      const cyl = (r, len, x, m) => {
        const geo = new THREE.CylinderGeometry(r, r, len, 16).rotateZ(Math.PI / 2), me = new THREE.Mesh(geo, m); me.position.x = x; bg.add(me);
        const l = new THREE.LineSegments(new THREE.EdgesGeometry(geo, 40), new THREE.LineBasicMaterial({ color: '#2B1E16' })); l.position.x = x; l.userData.ink = true; bg.add(l);
      };
      cyl(0.014, 1.31, 0, dk);
      [-1, 1].forEach((sg) => { cyl(0.04, 0.03, sg * 0.67, steel); cyl(0.025, 0.445, sg * (0.685 + 0.2225), steel); });
      scene.add(bg); bg.visible = false;
      const last = D.plates.length ? D.plates[D.plates.length - 1].at : o.dStart - o.dInterval;
      // the bar's angle is measured from the camera's line of sight, so it reads the same at any turn
      D.plates.push({ g: bg, spec: { kg: this.opts.bar || 20, t: 0.028, d: 0.05 }, isBar: true, y: h + 0.014, x: 0, z: 0, ry: (o.dAz + 90 + o.dBarYaw) * Math.PI / 180,
        tx: 0, tz: (Math.random() - 0.5) * 0.5 * o.dTilt, spin: 0, at: last + 600 + o.dBarDelay, landed: false });
    }
    D.count = D.plates.length; D.final = this.doneTotal(o); D.read = 0;
    // the type: label + total at the top, the message below the scale
    this.buildDoneText();
    this.placeDoneCam();
  }
  placeDoneCam() {
    const o = this.o, D = this.D; if (!D) return;
    const asp = this.W / this.Hh, V = o.dZoom, az = o.dAz * Math.PI / 180, el = o.dEl * Math.PI / 180;
    // shift the frustum so the scale sits at its chosen height on screen
    const off = (o.dScaleY - 0.5) * V;
    D.cam.left = -V * asp / 2; D.cam.right = V * asp / 2; D.cam.top = V / 2 + off; D.cam.bottom = -V / 2 + off; D.cam.updateProjectionMatrix();
    const tY = o.dCamY * o.dScaleSize;
    D.cam.position.set(Math.sin(az) * Math.cos(el) * 20, tY + Math.sin(el) * 20, Math.cos(az) * Math.cos(el) * 20);
    D.cam.lookAt(0, tY, 0);
    D.camBase = D.cam.position.clone();
  }
  drawReadout(v) {
    const R = this.D && this.D.readout; if (!R) return;
    const x = R.x, w = R.c.width, h = R.c.height;
    x.fillStyle = '#2B1E16'; x.fillRect(0, 0, w, h);
    x.fillStyle = this.pal.boxLight; x.textAlign = 'right'; x.textBaseline = 'middle';
    const txt = this.fmtKg(v); let fs = 120;
    x.font = '700 ' + fs + 'px "Space Mono", ui-monospace, Menlo, monospace';
    const mw = x.measureText(txt).width; if (mw > w - 150) { fs = Math.floor(fs * (w - 150) / mw); x.font = '700 ' + fs + 'px "Space Mono", ui-monospace, Menlo, monospace'; }
    x.fillText(txt, w - 120, h / 2 + 6);
    x.font = '700 54px "Space Mono", ui-monospace, monospace'; x.fillText(this.opts.unit || 'kg', w - 24, h / 2 + 30);
    R.tex.needsUpdate = true;
  }
  buildDoneText() {
    const o = this.o, L = this.textLayer; if (!L) return; L.innerHTML = '';
    const F = this.FONTS.find((f) => f[0] === o.dFont) || this.FONTS[0], ff = "'" + F[0] + "', " + F[2], wt = o.dWeight || F[1], col = this.colour(o.dNumCol);
    const top = this.el('div', { display: o.dShowNum ? 'flex' : 'none', position: 'absolute', left: 0, right: 0, top: (o.dNumY * 100) + '%', transform: 'translateY(-50%)', flexDirection: 'column', alignItems: 'center', gap: '4px', zIndex: 3, padding: '0 16px', textAlign: 'center' }, L);
    if (o.dShowLabel && o.dLabel) {
      const lb = this.el('div', { fontFamily: 'Helvetica, Arial, sans-serif', fontWeight: 700, fontSize: '14px', letterSpacing: '0.16em', textTransform: 'uppercase', color: col, opacity: 0.85 }, top); lb.textContent = o.dLabel;
      this.go(lb, [{ opacity: 0, transform: 'translateY(8px)' }, { opacity: 0.85, transform: 'none' }], { d: 500, delay: 150, easing: 'ease-out' });
    }
    const num = this.el('div', { display: 'flex', alignItems: 'baseline', gap: '0.12em', fontFamily: ff, fontWeight: wt, fontSize: o.dNumSize + 'px', lineHeight: 0.95, letterSpacing: '-0.02em', color: col, fontVariantNumeric: 'tabular-nums', whiteSpace: 'nowrap' }, top);
    const nv = this.el('span', {}, num); nv.textContent = o.dCount ? '0' : this.fmtKg(this.doneTotal(o));
    const un = this.el('span', { fontSize: '0.42em' }, num); un.textContent = o.dUnit;
    this.go(num, [{ opacity: 0, transform: 'scale(0.85)' }, { opacity: 1, transform: 'none' }], { d: 600, delay: 250 });
    this.D.numEl = num; this.D.numV = nv;
    // the message: hidden until the last plate lands
    const total = this.doneTotal(o), an = this.animalFor(total * (this.opts.unit === 'lb' ? 0.4536 : 1));
    const mf = o.dMsgFont === 'title' ? ff : o.dMsgFont === 'mono' ? "'Space Mono', monospace" : o.dMsgFont === 'serif' ? "'Playfair Display', Georgia, serif" : 'Helvetica, Arial, sans-serif';
    const mw = o.dMsgFont === 'title' ? wt : o.dMsgFont === 'serif' ? 900 : 700;
    const box = this.el('div', { position: 'absolute', left: 0, right: 0, top: (o.dMsgY * 100) + '%', transform: 'translateY(-50%)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', zIndex: 3, padding: '0 24px', textAlign: 'center', visibility: 'hidden' }, L);
    const msg = this.el('div', { fontFamily: mf, fontWeight: mw, fontSize: o.dMsgSize + 'px', lineHeight: 1.1, color: col }, box);
    msg.textContent = o.dMsg.replace(/\{animal\}/g, an[1]).replace(/\{kg\}/g, this.fmtKg(total));
    let sub = null;
    if (o.dSub) { sub = this.el('div', { fontFamily: 'Helvetica, Arial, sans-serif', fontWeight: 700, fontSize: '13px', letterSpacing: '0.08em', textTransform: 'uppercase', color: col, opacity: 0.8 }, box); sub.textContent = an[1].replace(/^an? /, '') + ' ≈ ' + this.fmtKg(an[0]) + ' kg'; }
    this.D.msgBox = box; this.D.msgEl = msg; this.D.subEl = sub;
  }
  showDoneMsg() {
    const D = this.D, o = this.o; if (!D || !D.msgBox || D.msgShown) return;
    D.msgShown = true; D.msgBox.style.visibility = 'visible';
    const m = D.msgEl;
    if (o.dMsgIn === 'words') {
      // each word simply appears, one after another, no motion
      const words = m.textContent.split(/\s+/).filter(Boolean); m.textContent = '';
      const spans = words.map((w, i) => { const sp = document.createElement('span'); sp.textContent = w + (i < words.length - 1 ? ' ' : ''); sp.style.visibility = 'hidden'; m.appendChild(sp); return sp; });
      spans.forEach((sp, i) => this.timers.push(setTimeout(() => { if (!this.dead) sp.style.visibility = 'visible'; }, i * o.dWordGap)));
    } else if (o.dMsgIn === 'type') {
      const full = m.textContent; m.textContent = ''; let i = 0;
      const tick = () => { if (this.dead || !m.isConnected) return; i++; m.textContent = full.slice(0, i); if (i < full.length) this.timers.push(setTimeout(tick, 38)); };
      tick();
    } else if (o.dMsgIn === 'fade') this.go(m, [{ opacity: 0 }, { opacity: 1 }], { d: 700, easing: 'ease-out' });
    else if (o.dMsgIn === 'pop') this.go(m, [{ opacity: 0, transform: 'scale(0.6)' }, { opacity: 1, transform: 'none' }], { d: 600 });
    else this.go(m, [{ opacity: 0, transform: 'translateY(24px)' }, { opacity: 1, transform: 'none' }], { d: 700 });
    if (D.subEl) this.go(D.subEl, [{ opacity: 0 }, { opacity: 0.8 }], { d: 600, delay: 450, easing: 'ease-out' });
    if (D.numEl) this.go(D.numEl, [{ transform: 'scale(1)' }, { transform: 'scale(1.12)', offset: 0.35 }, { transform: 'scale(1)' }], { d: 650, easing: 'ease-out' });
  }
  stepDone(dt, now) {
    const D = this.D, o = this.o, T3 = this.T3; if (!D || !T3) return;
    if (this.g) { this.g.setTransform(1, 0, 0, 1, 0, 0); this.g.clearRect(0, 0, this.cv.width, this.cv.height); }
    this.applyLook();
    if (this.grainEl) { this.grainEl.style.opacity = String(o.grain); this.grainEl.style.display = o.grain > 0 ? 'block' : 'none'; if (o.grain > 0) this.grainEl.style.backgroundPosition = Math.floor(Math.random() * 256) + 'px ' + Math.floor(Math.random() * 256) + 'px'; }
    D.hemi.intensity = o.ambient; D.sun.intensity = o.sunI;
    const ang = o.sunA * Math.PI / 180; D.sun.position.set(Math.cos(ang) * 4, Math.sin(ang) * 4 + 3, 3);
    this.placeDoneCam();
    const t = now - D.t0, sp = o.dSpeed, g = 9.8 * sp * sp, k = o.dScaleSize;
    // the platform: a damped spring kicked by each landing
    D.dipV += (-90 * D.dipY - 11 * D.dipV) * dt; D.dipY += D.dipV * dt;
    D.platform.position.y = D.dipY;
    const base = (D.platTop + D.dipY) * k;
    if (!D.world && D.physAt && t > D.physAt && o.dDrag) this.startDonePhysics();
    if (D.world) { this.stepDonePhysics(dt); D.plates.forEach((p) => this.styleGroup(p.g, 1)); }
    else D.plates.forEach((p) => {
      const el = (t - p.at) / 1000;
      if (el < 0) { p.g.visible = false; return; }
      p.g.visible = true;
      const tf = Math.sqrt(2 * o.dHeight / g);              // time to fall the drop height
      let y, tilt = 1, wob = 0;
      if (el < tf) { y = p.y + o.dHeight - 0.5 * g * el * el; }
      else {
        const e = el - tf;
        if (!p.landed) {
          p.landed = true; D.landed++; D.total += p.spec.kg;
          const hit = p.isBar ? 1.6 : p.spec.kg / 25 + 0.25;
          D.dipV -= o.dDip * 1.6 * hit; D.shake = Math.max(D.shake, o.dShake * (p.isBar ? 1.4 : p.spec.kg / 25 + 0.3));
          D.read = D.total; this.drawReadout(D.total);
          if (D.landed === D.count) {
            // session volume: the readout keeps climbing past what is on the scale, then the message
            const spin = o.dMode === 'volume' && D.final > D.total ? 1500 : 0;
            if (spin) D.volT0 = t + 300;
            this.timers.push(setTimeout(() => { if (!this.dead) this.showDoneMsg(); }, 350 + (spin ? 300 + spin : 0)));
            D.physAt = t + 700;
          }
        }
        // a small damped hop, while the tilt settles flat with a wobble
        y = p.y + o.dBounce * 0.07 * Math.abs(Math.sin(e * 16)) * Math.exp(-e * 7);
        tilt = Math.exp(-e * 9); wob = Math.cos(e * 26) * tilt;
      }
      const fall = Math.min(1, el / Math.max(0.01, tf));
      p.g.position.set(p.x, base + y, p.z);
      p.g.rotation.set(p.tx * (el < tf ? 1 : wob), p.ry + p.spin * fall, p.tz * (el < tf ? 1 : wob));
      this.styleGroup(p.g, 1);
    });
    if (!D.count && !D.msgShown && t > o.dStart) this.showDoneMsg();
    D.inks.forEach((l) => { l.visible = this.inkOn(); l.material.color.set(this.inkColour()); });
    if (D.volT0 && !D.touched) {
      const u = Math.min(1, Math.max(0, (t - D.volT0) / 1500)), e = u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2;
      const v = Math.round(D.total + (D.final - D.total) * e);
      if (v !== D.read) { D.read = v; this.drawReadout(v); }
      if (u >= 1) D.volT0 = 0;
    }
    // the number follows the readout
    const target = o.dCount ? D.read : D.final;
    D.shown += (target - D.shown) * Math.min(1, dt * 12);
    if (Math.abs(target - D.shown) < 0.05) D.shown = target;
    if (D.numV) { const txt = this.fmtKg(Math.round(D.shown * 2) / 2); if (D.numV.textContent !== txt) D.numV.textContent = txt; }
    // impact shake
    D.shake *= Math.exp(-dt * 10);
    const sh = D.shake * 0.05 * o.dZoom;
    D.cam.position.set(D.camBase.x + (Math.random() - 0.5) * sh, D.camBase.y + (Math.random() - 0.5) * sh, D.camBase.z + (Math.random() - 0.5) * sh);
    T3.canvas.style.display = 'block';
    GLFX.draw(T3.renderer, D.scene, D.cam, this.glfxParams());
  }
  startDonePhysics() {
    const D = this.D, o = this.o, C = window.PlateKit && window.PlateKit.CANNON; if (!C || !D) return;
    const k = o.dScaleSize;
    const w = new C.World({ gravity: new C.Vec3(0, -9.81, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = 20; w.solver.tolerance = 0.0005;
    const mP = new C.Material('plate'), mG = new C.Material('ground');
    w.addContactMaterial(new C.ContactMaterial(mP, mG, { friction: 0.55, restitution: 0.15 }));
    w.addContactMaterial(new C.ContactMaterial(mP, mP, { friction: 0.4, restitution: 0.1 }));
    const fixed = (shape, x, y, z) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(shape); b.position.set(x, y, z); w.addBody(b); return b; };
    // no floor and no walls: the scale floats in the void, and anything pulled off it falls away
    fixed(new C.Box(new C.Vec3(0.42 * k, 0.07 * k, 0.42 * k)), 0, 0.07 * k, 0);                        // base + platform, top at the platform surface
    if (o.dHead) { fixed(new C.Box(new C.Vec3(0.025 * k, 0.37 * k, 0.025 * k)), 0, 0.45 * k, -0.39 * k); fixed(new C.Box(new C.Vec3(0.18 * k, 0.1 * k, 0.05 * k)), 0, 0.86 * k, -0.39 * k); }
    D.platform.position.y = 0; D.dipY = 0; D.dipV = 0;
    const toX = new C.Quaternion(); toX.setFromAxisAngle(new C.Vec3(0, 0, 1), -Math.PI / 2);
    D.plates.forEach((p) => {
      const sp = p.spec, b = new C.Body({ mass: sp.kg, material: mP, linearDamping: 0.03, angularDamping: 0.06, sleepSpeedLimit: 0.06, sleepTimeLimit: 0.6 });
      if (p.isBar) {
        b.addShape(new C.Cylinder(0.014, 0.014, 1.31, 12), new C.Vec3(0, 0, 0), toX);
        [-1, 1].forEach((sg) => { b.addShape(new C.Cylinder(0.04, 0.04, 0.03, 12), new C.Vec3(sg * 0.67, 0, 0), toX); b.addShape(new C.Cylinder(0.025, 0.025, 0.445, 12), new C.Vec3(sg * 0.9075, 0, 0), toX); });
      } else {
        b.addShape(new C.Cylinder(sp.d / 2, sp.d / 2, sp.t, 20));
        p.g.position.y = Math.max(p.g.position.y, 0.14 * k + sp.t / 2);
      }
      b.position.set(p.g.position.x, p.g.position.y, p.g.position.z);
      b.quaternion.set(p.g.quaternion.x, p.g.quaternion.y, p.g.quaternion.z, p.g.quaternion.w);
      w.addBody(b); p.body = b;
    });
    // drag: a damped spring from the grabbed point to the pointer (same feel as the Onboarding kit)
    const rel = new C.Vec3(), pw = new C.Vec3(), pv = new C.Vec3(), F = new C.Vec3();
    w.addEventListener('preStep', () => {
      const g = D.grab; if (!g) return;
      const b = g.body; b.pointToWorldFrame(g.local, pw); pw.vsub(b.position, rel);
      b.angularVelocity.cross(rel, pv); pv.vadd(b.velocity, pv);
      const m = b.mass, kk = 260, c = 2 * Math.sqrt(kk) * 0.85;
      F.set(m * (kk * (g.target.x - pw.x) - c * pv.x), m * (kk * (g.target.y - pw.y) - c * pv.y - w.gravity.y), m * (kk * (g.target.z - pw.z) - c * pv.z));
      const mx = m * 140, L = F.length(); if (L > mx) F.scale(mx / L, F);
      b.applyForce(F, rel);
    });
    D.world = w; D.onScale = -1;
  }
  stepDonePhysics(dt) {
    const D = this.D, o = this.o, k = o.dScaleSize;
    D.world.step(1 / 60, dt, 5);
    let on = 0;
    D.plates.forEach((p) => {
      const b = p.body; if (!b) return;
      // long gone below the screen: stop simulating it
      if (b.position.y < -30) { if (!(D.grab && D.grab.body === b)) { D.world.removeBody(b); p.body = null; p.g.visible = false; } return; }
      p.g.position.set(b.position.x, b.position.y, b.position.z);
      p.g.quaternion.set(b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w);
      if (Math.abs(b.position.x) < 0.42 * k && Math.abs(b.position.z) < 0.42 * k && b.position.y > 0.14 * k - 0.005 && !(D.grab && D.grab.body === b)) on += p.spec.kg;
    });
    // the readout shows whatever is still on the platform
    if (D.touched && on !== D.onScale) { D.onScale = on; D.read = on; this.drawReadout(on); }
  }
  bindDrag(el) {
    const THREE = () => this.THREE;
    const hit = (e) => {
      const D = this.D; if (!D || !D.world || !THREE()) return null;
      const T = THREE(), r = el.getBoundingClientRect();
      const ray = this._ray || (this._ray = new T.Raycaster());
      ray.setFromCamera(new T.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), D.cam);
      const meshes = []; D.plates.forEach((p) => p.g.children.forEach((c) => { if (c.isMesh) { c.userData.plate = p; meshes.push(c); } }));
      const h = ray.intersectObjects(meshes, false)[0];
      return h ? { p: h.object.userData.plate, point: h.point, ray } : null;
    };
    el.addEventListener('pointerdown', (e) => {
      this.tap0 = { x: e.clientX, y: e.clientY, t: performance.now() };
      if (this.state.scene !== 'done' && this.o.orbit !== false) {
        const O = this.orb || (this.orb = { yaw: 0, pitch: 0, ty: 0, tp: 0, drag: null });
        O.drag = { x: e.clientX, y: e.clientY, y0: O.yaw, p0: O.pitch, id: e.pointerId };
        try { el.setPointerCapture(e.pointerId); } catch (er) {} el.style.cursor = 'grabbing'; e.preventDefault(); return;
      }
      const h = hit(e); if (!h) return;
      const D = this.D, T = THREE(), C = window.PlateKit.CANNON, b = h.p.body; if (!b) return; b.wakeUp(); D.touched = true; D.volT0 = 0;
      const n = new T.Vector3(); D.cam.getWorldDirection(n);
      D.grab = { body: b, local: b.pointToLocalFrame(new C.Vec3(h.point.x, h.point.y, h.point.z)), plane: new T.Plane().setFromNormalAndCoplanarPoint(n, h.point), target: h.point.clone() };
      b.angularDamping = 0.4;
      try { el.setPointerCapture(e.pointerId); } catch (er) {}
      el.style.cursor = 'grabbing'; e.preventDefault();
    });
    el.addEventListener('pointermove', (e) => {
      const O = this.orb;
      if (O && O.drag && this.state.scene !== 'done') {
        // drag right: the front of the scene swings right; drag down: it tips down. Limited to a gentle turn.
        const a = this.o.orbitAmt, lim = 0.15 + 0.6 * a, sens = 0.002 + 0.006 * a;
        O.ty = Math.max(-lim, Math.min(lim, O.drag.y0 - (e.clientX - O.drag.x) * sens));
        O.tp = Math.max(-lim * 0.6, Math.min(lim * 0.6, O.drag.p0 + (e.clientY - O.drag.y) * sens));
        return;
      }
      if (this.state.scene !== 'done' && this.o.orbit !== false && e.pointerType === 'mouse') { el.style.cursor = 'grab'; return; }
      const D = this.D;
      if (D && D.grab) {
        const T = THREE(), r = el.getBoundingClientRect(), ray = this._ray;
        ray.setFromCamera(new T.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), D.cam);
        const hp = new T.Vector3();
        if (ray.ray.intersectPlane(D.grab.plane, hp)) D.grab.target.copy(hp);
        return;
      }
      if (e.pointerType === 'mouse') el.style.cursor = hit(e) ? 'grab' : '';
    });
    const up = (e) => {
      // a tap (no drag) moves the app on
      const tp = this.tap0; this.tap0 = null;
      if (tp && e.type === 'pointerup' && Math.hypot(e.clientX - tp.x, e.clientY - tp.y) < 8 && performance.now() - tp.t < 600 && this.opts.onTap) this.timers.push(setTimeout(() => { if (!this.dead) this.opts.onTap(); }, 0));
      const O = this.orb; if (O && O.drag) { O.drag = null; try { el.releasePointerCapture(e.pointerId); } catch (er) {} el.style.cursor = ''; return; }
      const D = this.D; if (!D || !D.grab) return; D.grab.body.angularDamping = 0.06; D.grab = null; try { el.releasePointerCapture(e.pointerId); } catch (er) {} el.style.cursor = ''; };
    el.addEventListener('pointerup', up); el.addEventListener('pointercancel', up);
  }
  ensureThree() {
    if (this.T3) return this.T3.ok;
    const PK = window.PlateKit; if (!PK || !this.stage) return false;
    const THREE = PK.THREE; this.THREE = THREE;
    const cv = document.createElement('canvas');
    Object.assign(cv.style, { position: 'absolute', left: 0, top: 0, width: this.W + 'px', height: this.Hh + 'px', pointerEvents: 'none', zIndex: 1 });
    this.stage.insertBefore(cv, this.grainEl || this.textLayer || null);
    let renderer;
    try { renderer = new THREE.WebGLRenderer({ canvas: cv, antialias: true, alpha: true }); } catch (e) { this.T3 = { ok: false, canvas: cv, groups: [] }; return false; }
    renderer.setClearColor(0x000000, 0); renderer.setPixelRatio(this.dpr); renderer.setSize(this.W, this.Hh, false);
    renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.NoToneMapping;
    const scene = new THREE.Scene();
    if (PK.RoomEnvironment) { const pm = new THREE.PMREMGenerator(renderer); scene.environment = pm.fromScene(new PK.RoomEnvironment(), 0.04).texture; scene.environmentIntensity = 0.45; }
    const hemi = new THREE.HemisphereLight('#FFFFFF', '#FFFFFF', 2.7); scene.add(hemi);
    const sun = new THREE.DirectionalLight('#FFFFFF', 1.5); sun.position.set(-0.5, 1, 0.7); scene.add(sun);
    const f = this.Hh * 0.9, camera = new THREE.PerspectiveCamera(2 * Math.atan(this.Hh / 2 / f) * 180 / Math.PI, this.W / this.Hh, 1, 200000);
    this.T3 = { ok: true, canvas: cv, renderer, scene, camera, groups: [], f, hemi, sun, px: 0 };
    return true;
  }
  poseReal(p, Xc, Yc, Zc, m, alpha) {
    const T3 = this.T3, THREE = this.THREE, o = this.o;
    const pool = o.realMix === 'all' ? this.SPECS : this.SPECS.slice(0, 4);
    if (!p.realG || p.realMix !== o.realMix || p.surf !== o.surface) {
      if (p.realG) { T3.scene.remove(p.realG); T3.groups = T3.groups.filter((gr) => gr !== p.realG); }
      p.surf = o.surface; p.realMix = o.realMix; p.spec = pool[(p.pick == null ? (p.pick = Math.floor(Math.random() * 1000)) : p.pick) % pool.length];
      p.realG = this.plate(p.spec); p.realG.matrixAutoUpdate = false; T3.scene.add(p.realG); T3.groups.push(p.realG);
    }
    const G = p.realG, s = p.r0 * o.size2 * 2 / 0.45;
    const X = m(1, 0, 0), Y = m(0, 1, 0), Z = m(0, 0, 1);
    // columns: plate x → X, plate y (its axis) → Z, plate z → -Y; then flip y and z for three.js
    G.matrix.set(
      X[0] * s, Z[0] * s, -Y[0] * s, Xc,
      -X[1] * s, -Z[1] * s, Y[1] * s, -Yc,
      -X[2] * s, -Z[2] * s, Y[2] * s, -Zc,
      0, 0, 0, 1);
    G.matrixWorldNeedsUpdate = true; G.visible = true;
    this.styleGroup(G, Math.min(1, alpha));
  }
  styleGroup(G, a) {
    const THREE = this.THREE, o = this.o;
    const tc = o.tintColor === 'brown' ? this.pal.boxDark : o.tintColor === 'cream' ? this.pal.boxLight : o.tintColor === 'black' ? '#141010' : this.pal.bgColor;
    const lcol = this.inkColour(), tk = o.tint.toFixed(3) + tc + o.tintMode + lcol;
    if (G.userData.tk !== tk) {
      G.userData.tk = tk; const tcol = new THREE.Color(tc), s = o.tint;
      G.children.forEach((c) => {
        const m0 = c.material;
        if (c.userData.ink) { m0.color.set(lcol); return; }
        if (!m0.userData.base) m0.userData.base = m0.color.clone();
        if (o.tintMode === 'wash') {
          // wash: fade the plate's own colour out and glow the tint in, so at 100% it is a flat silhouette of the tint
          m0.color.copy(m0.userData.base).multiplyScalar(1 - s);
          if (m0.emissive) m0.emissive.copy(tcol).multiplyScalar(s);
        } else {
          m0.color.copy(m0.userData.base).lerp(tcol.clone().multiply(m0.userData.base), s);
          if (m0.emissive) m0.emissive.set(0x000000);
        }
      });
    }
    G.children.forEach((c) => {
      if (c.userData.ink) c.visible = this.inkOn();
      c.material.opacity = a; c.material.transparent = a < 0.999; c.material.depthWrite = a > 0.5;
    });
  }
  plate(spec) {
    const T = this.THREE, A = this.assets(spec), g = new T.Group(), surf = this.o.surface;
    const make = (mat, role) => {
      if (surf === 'textured') return mat.clone();
      if (surf === 'toon') return new T.MeshToonMaterial({ map: mat.map || null, color: mat.map ? '#FFFFFF' : mat.color, gradientMap: this.toonRamp() });
      if (surf === 'clay') return new T.MeshLambertMaterial({ color: role === 'metal' ? '#C9C2B8' : '#EFE6DA' });
      return new T.MeshLambertMaterial({ color: role === 'metal' ? '#B9BEC4' : spec.color });
    };
    [[A.ringTop, A.face, 'face'], [A.ringBot, A.face, 'face'], [A.side, A.rim, 'rim'], [A.hubTop, A.chrome, 'metal'], [A.hubBot, A.chrome, 'metal'], [A.hubOut, A.chrome, 'metal'], [A.hubIn, A.chromeIn, 'metal']]
      .forEach(([geo, mat, role]) => { const m = make(mat, role); if (mat.side === T.BackSide) m.side = T.BackSide; g.add(new T.Mesh(geo, m)); });
    // ink outline: the hard edges of each part, like the diorama's line style
    [A.ringTop, A.ringBot, A.side, A.hubOut].forEach((geo) => {
      const key = geo.uuid; this.edgeCache = this.edgeCache || {};
      const eg = this.edgeCache[key] || (this.edgeCache[key] = new T.EdgesGeometry(geo, 40));
      const l = new T.LineSegments(eg, new T.LineBasicMaterial({ color: '#4A3426' })); l.userData.ink = true; l.visible = false; g.add(l);
    });
    return g;
  }
  toonRamp() {
    if (this.ramp) return this.ramp;
    const T = this.THREE, d = new Uint8Array([70, 70, 70, 255, 160, 160, 160, 255, 255, 255, 255, 255]);
    const tx = new T.DataTexture(d, 3, 1, T.RGBAFormat); tx.minFilter = tx.magFilter = T.NearestFilter; tx.generateMipmaps = false; tx.needsUpdate = true;
    this.ramp = tx; return tx;
  }
  applyLook() {
    const o = this.o, T3 = this.T3, cs = T3.canvas.style;
    cs.mixBlendMode = o.blend || 'normal'; cs.opacity = String(o.realOpacity);
    const parts = [];
    if (o.contrast !== 1) parts.push('contrast(' + o.contrast + ')');
    if (o.bright !== 1) parts.push('brightness(' + o.bright + ')');
    if (o.saturate !== 1) parts.push('saturate(' + o.saturate + ')');
    if (o.hue) parts.push('hue-rotate(' + o.hue + 'deg)');
    if (o.posterize >= 2 || o.duotone || o.sketch) { this.svgFilter(); parts.push('url(#ua-fx)'); }
    this.boil();
    if (o.blur > 0) parts.push('blur(' + o.blur + 'px)');
    if (o.shadow > 0) parts.push('drop-shadow(0 ' + Math.round(6 + o.shadow * 22) + 'px ' + Math.round(4 + o.shadow * 18) + 'px rgba(43,30,22,' + (o.shadow * 0.55).toFixed(2) + '))');
    const fs = GLFX.cssLeft(parts).join(' ') || 'none'; if (cs.filter !== fs) cs.filter = fs;
    const px = Math.max(1, Math.round(o.pixel));
    if (T3.px !== px) {
      T3.px = px; T3.renderer.setPixelRatio(px <= 1 ? this.dpr : 1 / px); T3.renderer.setSize(this.W, this.Hh, false);
      cs.imageRendering = px > 1 ? 'pixelated' : 'auto'; cs.width = this.W + 'px'; cs.height = this.Hh + 'px';
    }
    T3.hemi.intensity = o.ambient; T3.sun.intensity = o.sunI;
    const ang = o.sunA * Math.PI / 180; T3.sun.position.set(Math.cos(ang), Math.sin(ang), 0.8);
  }
  svgFilter() {
    const o = this.o, key = [o.posterize, o.duotone, o.duoLight, o.sketch, o.skCol, o.skWidth, o.skRough, o.skScale, o.skGrain, o.skDouble, o.skWarp].join('|');
    if (this.fxKey === key && this.fxSvg && this.fxSvg.isConnected) return;
    this.fxKey = key;
    if (!this.fxSvg || !this.fxSvg.isConnected) {
      this.fxSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      this.fxSvg.setAttribute('width', '0'); this.fxSvg.setAttribute('height', '0'); this.fxSvg.setAttribute('aria-hidden', 'true');
      Object.assign(this.fxSvg.style, { position: 'absolute', width: 0, height: 0 });
      this.stage.appendChild(this.fxSvg);
    }
    const hex = (h) => { const c = parseInt(h.slice(1), 16); return [(c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255].map((v) => v.toFixed(3)); };
    // grey first (for duotone), then the colour steps, then map dark→brown and light→highlight,
    // so posterized duotone stays inside the two colours
    let inner = '', post = '';
    if (o.posterize >= 2) {
      const n = Math.round(o.posterize), tv = []; for (let i = 0; i < n; i++) tv.push((i / (n - 1)).toFixed(3));
      const f = '<feFunc% type="discrete" tableValues="' + tv.join(' ') + '"/>';
      post = '<feComponentTransfer>' + f.replace('%', 'R') + f.replace('%', 'G') + f.replace('%', 'B') + '</feComponentTransfer>';
    }
    if (o.duotone) {
      const dk = hex(this.pal.boxDark), lt = hex(o.duoLight === 'bg' ? this.pal.bgColor : o.duoLight === 'white' ? '#FFFFFF' : this.pal.boxLight);
      inner += '<feColorMatrix type="matrix" values="0.299 0.587 0.114 0 0  0.299 0.587 0.114 0 0  0.299 0.587 0.114 0 0  0 0 0 1 0"/>';
      inner += post;
      inner += '<feComponentTransfer><feFuncR type="table" tableValues="' + dk[0] + ' ' + lt[0] + '"/><feFuncG type="table" tableValues="' + dk[1] + ' ' + lt[1] + '"/><feFuncB type="table" tableValues="' + dk[2] + ' ' + lt[2] + '"/></feComponentTransfer>';
    } else inner = post;
    if (o.sketch) {
      // the sketch line: the shapes' outline (alpha grown by the line weight, minus the shapes), wobbled by noise,
      // broken up by a fine grain, optionally drawn twice; the fills can wobble a little too so inner lines look drawn
      const c = hex(this.colour(o.skCol)), g = o.skGrain, A = (4 * g).toFixed(2), B = (1 - 2.2 * g).toFixed(2);
      const fq = o.skScale.toFixed(4), r = o.skRough, w = o.skWidth;
      inner += '<feComponentTransfer result="base"><feFuncA type="identity"/></feComponentTransfer>';
      inner += '<feTurbulence class="sk" type="fractalNoise" baseFrequency="' + fq + '" numOctaves="2" seed="3" result="n1"/>';
      inner += '<feTurbulence class="sk" type="fractalNoise" baseFrequency="' + fq + '" numOctaves="2" seed="11" result="n2"/>';
      inner += '<feTurbulence class="sk" type="fractalNoise" baseFrequency="0.85" numOctaves="1" seed="5" result="gr"/>';
      inner += '<feColorMatrix in="gr" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  ' + A + ' 0 0 0 ' + B + '" result="grain"/>';
      inner += '<feDisplacementMap in="base" in2="n1" scale="' + (r * o.skWarp).toFixed(2) + '" xChannelSelector="R" yChannelSelector="G" result="fill"/>';
      const stroke = (noise, name, wd) => '<feMorphology in="SourceAlpha" operator="dilate" radius="' + wd.toFixed(2) + '" result="' + name + 'd"/>' +
        '<feComposite in="' + name + 'd" in2="SourceAlpha" operator="out" result="' + name + 'r"/>' +
        '<feDisplacementMap in="' + name + 'r" in2="' + noise + '" scale="' + r.toFixed(2) + '" xChannelSelector="R" yChannelSelector="G" result="' + name + 'w"/>' +
        '<feComposite in="' + name + 'w" in2="grain" operator="in" result="' + name + 'g"/>' +
        '<feFlood flood-color="rgb(' + c.map((v) => Math.round(v * 255)).join(',') + ')" result="' + name + 'c"/>' +
        '<feComposite in="' + name + 'c" in2="' + name + 'g" operator="in" result="' + name + '"/>';
      inner += stroke('n1', 'l1', w);
      if (o.skDouble) inner += stroke('n2', 'l2', Math.max(0.5, w * 0.7));
      inner += '<feMerge><feMergeNode in="fill"/><feMergeNode in="l1"/>' + (o.skDouble ? '<feMergeNode in="l2"/>' : '') + '</feMerge>';
    }
    this.fxSvg.innerHTML = '<filter id="ua-fx" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">' + inner + '</filter>';
    this.skTurb = Array.from(this.fxSvg.querySelectorAll('feTurbulence.sk'));
  }
  boil() {
    const o = this.o; if (!o.sketch || !o.skBoil || !this.skTurb) return;
    const now = performance.now(); if (now - (this.boilT || 0) < 1000 / o.skBoil) return;
    this.boilT = now; const s0 = Math.floor(Math.random() * 1000);
    this.skTurb.forEach((t, i) => t.setAttribute('seed', String(s0 + i * 7)));
  }
  faceTexture(spec) {
    const THREE = this.THREE, S = 512, c = document.createElement('canvas');
    c.width = c.height = S;
    const g = c.getContext('2d'), cx = S / 2, r = S / 2;
    const base = new THREE.Color(spec.color);
    const dark = base.clone().offsetHSL(0, 0, -0.08).getStyle(), darker = base.clone().offsetHSL(0, 0, -0.14).getStyle();
    g.fillStyle = spec.color; g.fillRect(0, 0, S, S);
    g.strokeStyle = dark; g.lineWidth = 14;
    g.beginPath(); g.arc(cx, cx, r * 0.955, 0, Math.PI * 2); g.stroke();
    g.strokeStyle = darker; g.globalAlpha = 0.55; g.lineWidth = 3;
    g.beginPath(); g.arc(cx, cx, r * 0.905, 0, Math.PI * 2); g.stroke();
    g.beginPath(); g.arc(cx, cx, r * (spec.kind === 'bumper' ? 0.40 : 0.52), 0, Math.PI * 2); g.stroke();
    g.globalAlpha = 1; g.fillStyle = spec.ink; g.textAlign = 'center'; g.textBaseline = 'middle';
    if (spec.kind === 'bumper') {
      g.font = '700 104px Helvetica, "Helvetica Neue", Arial, sans-serif'; g.fillText(spec.label, cx, cx - r * 0.66);
      g.font = '700 60px Helvetica, "Helvetica Neue", Arial, sans-serif'; g.fillText(spec.unit || 'KG', cx, cx + r * 0.66);
      g.font = '600 26px Helvetica, "Helvetica Neue", Arial, sans-serif';
      g.save(); g.translate(cx - r * 0.66, cx); g.rotate(-Math.PI / 2); g.fillText('COMPETITION', 0, 0); g.restore();
      g.save(); g.translate(cx + r * 0.66, cx); g.rotate(Math.PI / 2); g.fillText('Ø 450 MM', 0, 0); g.restore();
    } else {
      g.font = '700 118px Helvetica, "Helvetica Neue", Arial, sans-serif'; g.fillText(spec.label, cx, cx - r * 0.73);
      g.font = '700 70px Helvetica, "Helvetica Neue", Arial, sans-serif'; g.fillText(spec.unit || 'KG', cx, cx + r * 0.75);
    }
    const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
    return tex;
  }
  assets(spec) {
    const segs = 80, key = (spec.unit || 'KG') + spec.kg;
    if (this.cache[key]) return this.cache[key];
    const THREE = this.THREE, R = spec.d / 2, t = spec.t, holeR = 0.0255, bumper = spec.kind === 'bumper';
    const hubR = bumper ? 0.068 : Math.min(0.046, R * 0.46), hubH = t + 0.005;
    const face = new THREE.MeshStandardMaterial({ map: this.faceTexture(spec), roughness: bumper ? 0.8 : 0.38, metalness: bumper ? 0 : 0.2 });
    // rim: plate colour with softly darkened edges
    const rc = document.createElement('canvas'); rc.width = 4; rc.height = 128;
    const rg = rc.getContext('2d'), base = new THREE.Color(spec.color).offsetHSL(0, 0, -0.05), edge = base.clone().offsetHSL(0, 0, -0.16);
    const grad = rg.createLinearGradient(0, 0, 0, 128);
    grad.addColorStop(0, edge.getStyle()); grad.addColorStop(0.1, base.getStyle()); grad.addColorStop(0.9, base.getStyle()); grad.addColorStop(1, edge.getStyle());
    rg.fillStyle = grad; rg.fillRect(0, 0, 4, 128);
    const rimTex = new THREE.CanvasTexture(rc); rimTex.colorSpace = THREE.SRGBColorSpace;
    const rim = new THREE.MeshStandardMaterial({ map: rimTex, roughness: bumper ? 0.85 : 0.4, metalness: bumper ? 0 : 0.2 });
    const chrome = new THREE.MeshStandardMaterial({ color: '#D8DCE1', metalness: 1, roughness: 0.2 });
    const chromeIn = chrome.clone(); chromeIn.side = THREE.BackSide; chromeIn.color = new THREE.Color('#9AA1AA');
    const hs = Math.max(8, Math.round(segs * 0.6));
    const a = {
      face, rim, chrome, chromeIn,
      ringTop: new THREE.RingGeometry(hubR * 0.98, R, segs, 1).rotateX(-Math.PI / 2).translate(0, t / 2, 0),
      ringBot: new THREE.RingGeometry(hubR * 0.98, R, segs, 1).rotateX(Math.PI / 2).translate(0, -t / 2, 0),
      side: new THREE.CylinderGeometry(R, R, t, segs, 1, true),
      hubTop: new THREE.RingGeometry(holeR, hubR, hs, 1).rotateX(-Math.PI / 2).translate(0, hubH / 2, 0),
      hubBot: new THREE.RingGeometry(holeR, hubR, hs, 1).rotateX(Math.PI / 2).translate(0, -hubH / 2, 0),
      hubOut: new THREE.CylinderGeometry(hubR, hubR, hubH, hs, 1, true),
      hubIn: new THREE.CylinderGeometry(holeR, holeR, hubH, Math.max(6, Math.round(segs * 0.4)), 1, true)
    };
    this.cache[key] = a;
    return a;
  }
  profile(o, R, T) {
    const t = T / 2, hole = o.hole * R, extra = (from, to) => { const a = []; for (let k = 1; k <= o.rings; k++) a.push(from + (to - from) * k / (o.rings + 1)); return a; };
    let side;
    if (o.style === 'iron') {
      const hubR = Math.max(o.hub, o.hole + 0.06) * R, rec = t - T * 0.35;
      side = (s) => [[hole, s * t], [hubR, s * t], [hubR, s * rec]].concat(extra(hubR, 0.86 * R).map((r) => [r, s * rec]), [[0.86 * R, s * rec], [0.86 * R, s * t], [R, s * t]]);
    } else if (o.style === 'disc') {
      side = (s) => [[hole, s * t]].concat(extra(hole, R).map((r) => [r, s * t]), [[R, s * t]]);
    } else {
      const hubR = o.hub * R, pr = t + T * 0.14;
      side = (s) => [[hole, s * pr], [hubR, s * pr], [hubR, s * t]].concat(extra(hubR, R).map((r) => [r, s * t]), [[R, s * t]]);
    }
    return side(1).reverse().concat(side(-1));
  }
  hull(pts) {
    const P = pts.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    const cr = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
    const lo = [], up = [];
    for (const p of P) { while (lo.length >= 2 && cr(lo[lo.length - 2], lo[lo.length - 1], p) <= 0) lo.pop(); lo.push(p); }
    for (let i = P.length - 1; i >= 0; i--) { const p = P[i]; while (up.length >= 2 && cr(up[up.length - 2], up[up.length - 1], p) <= 0) up.pop(); up.push(p); }
    up.pop(); lo.pop(); return lo.concat(up);
  }
  // the look's settings, for the GLFX pass
  glfxParams() {
    const o = this.o;
    return { contrast: o.contrast, bright: o.bright, saturate: o.saturate, hue: o.hue, posterize: o.posterize, duotone: o.duotone,
      dk: this.pal.boxDark, lt: o.duoLight === 'bg' ? this.pal.bgColor : o.duoLight === 'white' ? '#FFFFFF' : this.pal.boxLight,
      sketch: o.sketch && !window.__plNoRough, skCol: this.colour(o.skCol), skWidth: o.skWidth, skRough: o.skRough, skScale: o.skScale, skGrain: o.skGrain,
      skDouble: o.skDouble, skWarp: o.skWarp, seed: GLFX.boilSeed(o.sketch ? o.skBoil : 0) };
  }
}

// ===================== the prototype: opening → box → setup → PRs → workout → kit → sets → session over → home =====================
// The 3D gym is the Onboarding board's (box, furnishing, kit drop, bar loading) laid out and art-directed by the Layout Lab;
// the screens are the Input screens · custom ones; the opening and the session over are the UI Animation Lab's.
class Component extends DCLogic {
  constructor(props) {
    super(props);
    // ---- the gym's plates (colour lives only here) ----
    this.SPECS = [
      { kg: 25,  label: '25',  color: '#D3262E', ink: '#FFFFFF', d: 0.450, t: 0.056, kind: 'bumper' },
      { kg: 20,  label: '20',  color: '#1E5BC6', ink: '#FFFFFF', d: 0.450, t: 0.046, kind: 'bumper' },
      { kg: 15,  label: '15',  color: '#F3C318', ink: '#1A1A1A', d: 0.450, t: 0.036, kind: 'bumper' },
      { kg: 10,  label: '10',  color: '#2E8A4B', ink: '#FFFFFF', d: 0.450, t: 0.027, kind: 'bumper' },
      { kg: 5,   label: '5',   color: '#F2F2EE', ink: '#1A1A1A', d: 0.230, t: 0.024, kind: 'change' },
      { kg: 2.5, label: '2.5', color: '#D3262E', ink: '#FFFFFF', d: 0.190, t: 0.019, kind: 'change' },
      { kg: 2,   label: '2',   color: '#1E5BC6', ink: '#FFFFFF', d: 0.175, t: 0.017, kind: 'change' },
      { kg: 1.5, label: '1.5', color: '#F3C318', ink: '#1A1A1A', d: 0.160, t: 0.015, kind: 'change' },
      { kg: 1,   label: '1',   color: '#2E8A4B', ink: '#FFFFFF', d: 0.150, t: 0.013, kind: 'change' },
      { kg: 0.5, label: '0.5', color: '#F2F2EE', ink: '#1A1A1A', d: 0.135, t: 0.011, kind: 'change' }
    ];
    this.LB_SPECS = [
      { kg: 55,  label: '55',  color: '#D3262E', ink: '#FFFFFF', d: 0.450, t: 0.058, kind: 'bumper', unit: 'LB' },
      { kg: 45,  label: '45',  color: '#1E5BC6', ink: '#FFFFFF', d: 0.450, t: 0.050, kind: 'bumper', unit: 'LB' },
      { kg: 35,  label: '35',  color: '#F3C318', ink: '#1A1A1A', d: 0.450, t: 0.040, kind: 'bumper', unit: 'LB' },
      { kg: 25,  label: '25',  color: '#2E8A4B', ink: '#FFFFFF', d: 0.450, t: 0.030, kind: 'bumper', unit: 'LB' },
      { kg: 15,  label: '15',  color: '#F2F2EE', ink: '#1A1A1A', d: 0.300, t: 0.026, kind: 'change', unit: 'LB' },
      { kg: 10,  label: '10',  color: '#26282C', ink: '#FFFFFF', d: 0.250, t: 0.024, kind: 'change', unit: 'LB' },
      { kg: 5,   label: '5',   color: '#26282C', ink: '#FFFFFF', d: 0.205, t: 0.020, kind: 'change', unit: 'LB' },
      { kg: 2.5, label: '2.5', color: '#26282C', ink: '#FFFFFF', d: 0.165, t: 0.016, kind: 'change', unit: 'LB' }
    ];
    this.SPECS.forEach((sp) => { sp.unit = 'KG'; });
    this.specsFor = (u) => (u === 'lb' ? this.LB_SPECS : this.SPECS);
    this.cache = {};
    this.S = 8; this.H = 2.6; this.CUBE = 8;
    this.FLAG_FONTS = [
      { id: 'helvetica', label: 'Helvetica', css: 'Helvetica, "Helvetica Neue", Arial, sans-serif', weight: 700 },
      { id: 'anton', label: 'Anton', css: '"Anton", Impact, sans-serif', weight: 400 },
      { id: 'bebas', label: 'Bebas Neue', css: '"Bebas Neue", Impact, sans-serif', weight: 400 },
      { id: 'archivo', label: 'Archivo Black', css: '"Archivo Black", Arial Black, sans-serif', weight: 400 },
      { id: 'playfair', label: 'Playfair', css: '"Playfair Display", Georgia, serif', weight: 900 },
      { id: 'dmserif', label: 'DM Serif', css: '"DM Serif Display", Georgia, serif', weight: 400 },
      { id: 'spacemono', label: 'Space Mono', css: '"Space Mono", "Courier New", monospace', weight: 700 },
      { id: 'marker', label: 'Marker', css: '"Permanent Marker", "Comic Sans MS", cursive', weight: 400 }
    ];
    // scene state the gym code reads (art direction + the box)
    this.state = { view: 'overview', outline: true, shadows: true, spin: false, base: true, closed: false, plateSegs: 80,
      boxLight: '#EFE3CF', boxDark: '#4A3426', bgColor: '#00B3FF', bgMode: 'sky', cloudReal: 1, flagFont: 'playfair', media: null, unit: 'kg', scale: 1, framed: false };
    try {
      const saved = JSON.parse(localStorage.getItem('dz-art') || 'null');
      if (saved) ['boxLight', 'boxDark', 'bgColor'].forEach((k) => { if (/^#[0-9A-Fa-f]{6}$/.test(saved[k] || '')) this.state[k] = saved[k]; });
      if (saved && (saved.bgMode === 'sky' || saved.bgMode === 'colour')) this.state.bgMode = saved.bgMode;
      if (saved && this.FLAG_FONTS.some((f) => f.id === saved.flagFont)) this.state.flagFont = saved.flagFont;
      if (saved && isFinite(saved.cloudReal)) this.state.cloudReal = Math.min(1, Math.max(0, +saved.cloudReal));
    } catch (e) {}
    this.pal = { boxLight: this.state.boxLight, boxDark: this.state.boxDark, bgColor: this.state.bgColor };
    // the Layout Lab is the source of truth for the palette: follow it live
    this.onArtStore = (e) => {
      if (this.dead) return;
      if (e.key === 'dz-art' && e.newValue) {
        let a = null; try { a = JSON.parse(e.newValue); } catch (er) { return; }
        ['boxLight', 'boxDark', 'bgColor'].forEach((k) => { if (/^#[0-9A-Fa-f]{6}$/.test(a[k] || '')) { this.state[k] = a[k]; this.pal[k] = a[k]; } });
        if (a.bgMode === 'sky' || a.bgMode === 'colour') this.state.bgMode = a.bgMode;
        this.applyUILook(); this.setState({ palRev: (this.state.palRev || 0) + 1 });
      }
      if (e.key === 'input-custom-look' && e.newValue) { try { this.look = Object.assign({}, this.LOOK_DEF, JSON.parse(e.newValue)); this.applyUILook(); } catch (er) {} }
      if (e.key === 'layoutlab-look' && e.newValue) { try { this.slook = Object.assign({}, this.SLOOK_DEF, JSON.parse(e.newValue)); this.state.bgMode = this.slook.bg === 'sky' ? 'sky' : 'colour'; this.slookKey = null; } catch (er) {} }
    };
    window.addEventListener('storage', this.onArtStore);

    // ---- the Layout Lab's art direction for the 3D (its Look tab, saved in this browser) ----
    this.SLOOK_DEF = { duotone: false, duoDark: 'brown', duoLight: 'cream', posterize: 0, contrast: 1, bright: 1, saturate: 1, hue: 0,
      pixel: 1, blur: 0, grain: 0, halftone: 0, dotSize: 6, scan: 0, paper: 0, vignette: 0, ambient: 2.7, sunI: 1.5, bg: 'flat',
      sketch: true, skCol: 'brown', skWidth: 2.5, skRough: 6, skScale: 0.03, skBoil: 0, skGrain: 0.45, skDouble: true, skInner: true, skWarp: 0.35 };
    let sl = null; try { sl = JSON.parse(localStorage.getItem('layoutlab-look') || 'null'); } catch (e) {}
    this.slook = Object.assign({}, this.SLOOK_DEF, sl || {});
    if (sl && !sl.v2) this.slook.duotone = false;
    { const b = this.slook.bg, named = { orange: '#E8742C', cream: '#EFE3CF', brown: '#4A3426' };
      if (named[b]) { this.state.bgColor = named[b]; this.slook.bg = 'flat'; }
      this.state.bgMode = this.slook.bg === 'sky' ? 'sky' : 'colour'; }

    // ---- the screens' look: Input screens · custom (saved in this browser), with Will's black-and-white default ----
    this.UFONTS = {
      grotesk: ["'Space Grotesk', Helvetica, sans-serif", 700, 'Space Grotesk'], mono: ["'Space Mono', ui-monospace, monospace", 700, 'Space Mono'],
      archivo: ["'Archivo Black', Helvetica, sans-serif", 400, 'Archivo Black'], bebas: ["'Bebas Neue', Impact, sans-serif", 400, 'Bebas Neue'],
      anton: ["Anton, Impact, sans-serif", 400, 'Anton'], playfair: ["'Playfair Display', Georgia, serif", 900, 'Playfair'],
      dmsans: ["'DM Sans', Helvetica, sans-serif", 700, 'DM Sans'], helvetica: ["Helvetica, Arial, sans-serif", 700, 'Helvetica']
    };
    this.LOOK_DEF = {
      accent: '#000000', text: '#000000', ink: '#FFFFFF', surface: '#FFFFFF', card: '#FFFFFF', bg: '#FFFFFF', frC: null,
      fd: 'grotesk', ft: 'grotesk', tSize: 1, tW: 600, tTrack: 0, tSub: 0.48,
      hSize: 25, hTrack: -0.01, hLine: 1, caps: 'off',
      fStyle: 'outline', fH: 56, fR: 14, fSize: 24,
      dR: 0, dBw: 2, dBc: 'none', dSh: 'none', dGrab: 'off', dFit: 'fit', dMax: 62, dFix: 52,
      cR: 0, cBw: 0, cSh: 'none',
      bFill: 'solid', bR: 0, bH: 40, bBw: 0, bSh: 'none', bCase: 'off',
      frStyle: 'none', frW: 8, frR: 0, frTop: 'frame', frLine: 'off',
      rough: 4.5, grain: 0.039, boil: 'off', rkDrawer: 'on', rkCard: 'off', rkButton: 'on', rkField: 'off', rkControl: 'off', rkFrame: 'off'
    };
    let lk = null; try { lk = JSON.parse(localStorage.getItem('input-custom-look') || 'null'); } catch (e) {}
    this.look = Object.assign({}, this.LOOK_DEF, lk || {});

    // ---- the athlete's data: fresh for every run of the prototype ----
    this.BARS = { kg: [[20, 'Olympic bar'], [15, 'Women’s Olympic bar'], [10, 'Technique bar']], lb: [[45, 'Olympic bar'], [35, 'Women’s Olympic bar'], [15, 'Technique bar']] };
    this.DEMO_PRS = { 'Back squat': 140, 'Front squat': 115, 'Deadlift': 180, 'Clean': 100, 'Snatch': 80, 'Bench press': 100 };
    this.DEF = { name: '', unit: 'kg', own: { kg: [25, 20, 15, 10, 5, 2.5, 2, 1.5, 1, 0.5], lb: [55, 45, 35, 25, 15, 10, 5, 2.5] }, bar: { kg: 20, lb: 45 },
      prs: [['Back squat', null], ['Front squat', null], ['Deadlift', null], ['Clean', null], ['Snatch', null], ['Bench press', null]],
      wod: [{ lift: 'Back squat', sets: 5, reps: 5, pct: 75 }, { lift: 'Deadlift', sets: 3, reps: 3, pct: 80 }], kitGot: {} };
    this.d = JSON.parse(JSON.stringify(this.DEF));
    this.setIdx = 0; this.doneSets = [];

    // ---- the phone frame: 390 × 844, scaled to fit the board ----
    this.setOuter = (el) => {
      if (!el || this.outerEl) return;
      this.outerEl = el;
      const fit = () => {
        const w = el.clientWidth, h = el.clientHeight, framed = w > 430 || h > 900;
        const sc = Math.max(0.3, Math.min(framed ? 1.25 : 1, (h - (framed ? 32 : 0)) / 844, (w - (framed ? 32 : 0)) / 390));
        if (framed !== this.state.framed || Math.abs(sc - this.state.scale) > 0.004) this.setState({ framed, scale: sc });
      };
      this.outerRO = new ResizeObserver(fit); this.outerRO.observe(el); fit();
    };
    this.setPhone = (el) => { if (el && !this.phone) { this.phone = el; this.buildPhone(); } };
  }

  renderVals() {
    const st = this.state;
    return { setOuter: this.setOuter, setPhone: this.setPhone, palBg: this.uiBg || '#FFFFFF', scale: st.scale || 1,
      radius: st.framed ? '44px' : '0', shadow: st.framed ? '0 30px 60px rgba(43,30,22,0.28)' : 'none' };
  }

  // ---------------- data helpers ----------------
  specs() { return this.specsFor(this.d.unit); }
  own() { return this.d.own[this.d.unit] || []; }
  barW() { return (this.d.bar && this.d.bar[this.d.unit]) || (this.d.unit === 'kg' ? 20 : 45); }
  haveList(u) { return this.d.own[u] || []; }
  barOf(u) { return (this.d.bar && this.d.bar[u]) || (u === 'kg' ? 20 : 45); }
  demoPR(q) { const v = this.DEMO_PRS[q[0]] || 0; return this.d.unit === 'lb' ? Math.round(v * 2.2046 / 5) * 5 : v; }
  prOf(lift) { const r = this.d.prs.find((q) => q[0] === lift); return r && r[1] != null && r[1] > 0 ? r[1] : this.demoPR([lift]); }
  fmt(v) { return v == null ? '—' : (Math.round(v * 100) / 100).toLocaleString('en-US'); }
  setUnit(u) { this.d.unit = u; this.state.unit = u; }
  prData() { const prs = this.d.prs.filter((q) => q[1] != null && q[1] > 0).map((q) => ({ lift: q[0], value: this.fmt(q[1]) })); return prs.length ? { prs } : null; }

  // today's plan from the workout: every set's load from the plates the gym has, a warm-up before the first lift,
  // and the kit (per plate size, the most any one set needs on a side, times two)
  workoutPlan() {
    const u = this.d.unit, bar = this.barW(), denoms = this.own().slice().sort((a, b) => b - a);
    const solve = denoms.length ? this.solver(denoms) : null;
    const loadAt = (lo, hi, plus) => (solve ? this.loadable(lo, hi, plus, bar, denoms, solve) : { total: bar, side: [] });
    const groups = this.d.wod.map((e) => {
      const pr = this.prOf(e.lift), sets = [];
      for (let i = 0; i < e.sets; i++) { const c = loadAt(pr * e.pct / 100, null, false); sets.push({ label: 'Set ' + (i + 1), n: i + 1, of: e.sets, reps: e.reps, pct: e.pct + '%', total: c.total, side: c.side }); }
      return { name: e.lift, format: e.sets + ' × ' + e.reps + ' @ ' + e.pct + '%', pr, sets };
    }).filter((g) => g.sets.length);
    if (!groups.length) return null;
    const g0 = groups[0], first = g0.sets[0], warm = []; let last = -1;
    [[0.5, 5], [0.7, 3], [0.85, Math.max(1, first.reps)]].forEach(([f, r]) => {
      const c = loadAt(first.total * f, null, false);
      if (c.total <= last || c.total >= first.total) return; last = c.total;
      warm.push({ label: 'Round ' + (warm.length + 1), reps: r, pct: '≈' + Math.round(c.total / g0.pr * 100) + '%', total: c.total, side: c.side });
    });
    if (!warm.length) warm.push({ label: 'Round 1', reps: 5, pct: 'Empty bar', total: bar, side: [] });
    warm.forEach((w, i) => { w.n = i + 1; w.of = warm.length; });
    groups.unshift({ name: 'Warm-up', warm: true, sets: warm });
    const maxPer = {};
    groups.forEach((g) => g.sets.forEach((x) => { const n = {}; x.side.forEach((w) => { n[w] = (n[w] || 0) + 1; }); Object.keys(n).forEach((w) => { maxPer[w] = Math.max(maxPer[w] || 0, n[w]); }); }));
    const kit = Object.keys(maxPer).map(Number).sort((a, b) => b - a).map((w) => ({ w, qty: maxPer[w] * 2 }));
    const flat = []; groups.forEach((g, gi) => g.sets.forEach((x) => flat.push(Object.assign({ gi, group: g.warm ? 'Warm-up · ' + groups[1].name : g.name }, x))));
    return { groups, kit, flat, bar, unit: u };
  }

  // ---------------- the phone ----------------
  buildPhone() {
    const P = this.phone;
    // anything that breaks shows up on the phone, so it can be reported
    this.onWinErr = (e) => { if (!this.dead) this.reportError((e && e.error) || (e && e.message) || e); };
    window.addEventListener('error', this.onWinErr);
    P.classList.add('ios');
    // the 3D stage (the gym), then the frame and rough filters, then our UI layer, then the system chrome
    const stage = document.createElement('div'); Object.assign(stage.style, { position: 'absolute', inset: 0 }); P.appendChild(stage); this.stageEl = stage;
    const cv = document.createElement('canvas'); cv.setAttribute('aria-label', 'Your gym, in 3D'); Object.assign(cv.style, { display: 'block', width: '100%', height: '100%', touchAction: 'none' }); stage.appendChild(cv);
    this.frameEl = this.h('div', { position: 'absolute', inset: 0, pointerEvents: 'none', overflow: 'hidden', zIndex: 0, display: 'none' }, P);
    this.frameHole = this.h('div', { position: 'absolute' }, this.frameEl);
    const fx = document.createElement('div'); fx.setAttribute('aria-hidden', 'true'); Object.assign(fx.style, { position: 'absolute', width: 0, height: 0, overflow: 'hidden' });
    fx.innerHTML = '<svg width="0" height="0"><filter id="cu-rough" x="-25%" y="-25%" width="150%" height="150%"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="1" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0" xChannelSelector="R" yChannelSelector="G"/></filter>'
      + '<filter id="cu-rough-frame" filterUnits="userSpaceOnUse" x="-650" y="-650" width="1700" height="2150"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="1" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0" xChannelSelector="R" yChannelSelector="G"/></filter></svg>';
    P.appendChild(fx);
    this.turb = [...fx.querySelectorAll('feTurbulence')]; this.disp = [...fx.querySelectorAll('feDisplacementMap')];
    this.ui = this.h('div', { position: 'absolute', inset: 0, zIndex: 5 }, P); this.ui.classList.add('cu'); this.applyUILook();
    // every button gives under the finger: it sinks quickly and springs back with an ease-out
    { const SEL = 'button, .tap, [role=radio], [role=checkbox], [role=button], [role=switch]';
      let cur = null;
      const up = () => {
        const el = cur; cur = null; if (!el) return;
        const s0 = el.__ps || 0.95;
        if (el.__pa) { try { el.__pa.cancel(); } catch (e) {} el.__pa = null; }
        el.animate([{ transform: 'scale(' + s0 + ')' }, { transform: 'scale(1)' }], { duration: 280, easing: 'cubic-bezier(.2,.8,.25,1)' });
      };
      P.addEventListener('pointerdown', (e) => {
        const el = e.target && e.target.closest ? e.target.closest(SEL) : null;
        if (!el || !P.contains(el) || el.closest('[data-nopress]')) return;
        up(); cur = el;
        const s0 = el.__ps = 1 - Math.min(0.06, 10 / Math.max(40, el.offsetWidth || 40));
        el.__pa = el.animate([{ transform: 'scale(1)' }, { transform: 'scale(' + s0 + ')' }], { duration: 110, easing: 'cubic-bezier(.2,.8,.25,1)', fill: 'forwards' });
      }, true);
      ['pointerup', 'pointercancel'].forEach((ev) => window.addEventListener(ev, up, true));
      P.addEventListener('pointerleave', up); }
    this.raw = true;
    const sb = this.h('div', { position: 'absolute', left: 0, right: 0, top: 0, height: '54px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 30px 0 44px', boxSizing: 'border-box', pointerEvents: 'none', zIndex: 40, fontSize: '17px', fontWeight: 600, color: '#000' }, P);
    this.h('span', {}, sb, '9:41');
    this.h('span', { display: 'flex', gap: '6px', alignItems: 'center' }, sb).innerHTML = '<svg width="18" height="12" viewBox="0 0 18 12" aria-hidden="true" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg><svg width="26" height="12" viewBox="0 0 26 12" aria-hidden="true" fill="currentColor"><rect x="0.5" y="0.5" width="22" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="17" height="8" rx="2"/><rect x="23.5" y="4" width="1.8" height="4" rx="1" opacity=".4"/></svg>';
    this.statusBar = sb;
    this.h('div', { position: 'absolute', left: '50%', top: '11px', width: '126px', height: '37px', marginLeft: '-63px', borderRadius: '19px', background: '#000', zIndex: 45, pointerEvents: 'none' }, P);
    this.h('div', { position: 'absolute', left: '50%', bottom: '8px', width: '134px', height: '5px', marginLeft: '-67px', borderRadius: '3px', background: '#000', zIndex: 60, pointerEvents: 'none' }, P);
    this.haptic = this.h('div', { position: 'absolute', left: '12px', top: '58px', padding: '5px 10px', borderRadius: '12px', background: 'rgba(0,0,0,0.72)', color: '#FFF', fontSize: '12px', fontWeight: 600, zIndex: 55, opacity: 0, transition: 'opacity .2s', pointerEvents: 'none' }, P);
    this.raw = false;
    // 1 · the app opening, over everything until it is tapped
    this.showOpening();
    this.boot();
  }
  h(tag, css, parent, text) { const e = document.createElement(tag); if (css) { Object.assign(e.style, this.raw ? css : this.themeCss(css)); if (!this.raw) this.markRough(e, css); } if (this.raw && parent === this.ui) e.classList.add('sys'); if (text != null) e.textContent = text; if (parent) parent.appendChild(e); return e; }
  sys(fn) { const was = this.raw; this.raw = true; try { return fn(); } finally { this.raw = was; } }
  buzz(kind) { if (!this.haptic) return; this.haptic.textContent = '◉ Haptic · ' + kind; this.haptic.style.opacity = '1'; clearTimeout(this.hT); this.hT = setTimeout(() => { if (this.haptic) this.haptic.style.opacity = '0'; }, 900); }
  clearUI() { this.closeKeyboard(true); if (this.ui) this.ui.innerHTML = ''; this.sheetEl = null; this.cardEl = null; if (this.statusBar) this.statusBar.style.color = '#000'; }

  // ---------------- the two animation scenes ----------------
  // the layer's own element listens for taps too, so a tap always moves the app on even if the animation could not start
  animLayer(scene, opts) {
    const el = document.createElement('div'); el.setAttribute('data-nopress', '');
    Object.assign(el.style, { position: 'absolute', inset: 0, zIndex: 38, overflow: 'hidden', transition: 'opacity .55s ease', cursor: 'pointer', background: (this.pal && this.pal.bgColor) || '#E8742C' });
    this.phone.appendChild(el);
    let down = null;
    el.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY, t: Date.now() }; }, true);
    el.addEventListener('click', (e) => {
      const d = down; down = null;
      if (d && (Math.hypot(e.clientX - d.x, e.clientY - d.y) > 10 || Date.now() - d.t > 900)) return;   // a drag, not a tap
      if (opts.onTap) opts.onTap();
    });
    let L = null;
    try { L = new AnimLayer(el, scene, Object.assign({}, opts, { onTap: null })); }
    catch (err) { this.reportError(err); L = { destroy() {}, ready: () => true, D: null }; }
    L.el = el; return L;
  }
  reportError(err) {
    try { console.error(err); } catch (e) {}
    if (!this.phone) return;
    const p = this.errEl || (this.errEl = this.sys(() => this.h('div', { position: 'absolute', left: '12px', right: '12px', bottom: '40px', padding: '8px 10px', borderRadius: '10px', background: 'rgba(160,20,20,0.9)', color: '#FFF', fontSize: '11px', fontFamily: 'ui-monospace, Menlo, monospace', zIndex: 70, pointerEvents: 'none', whiteSpace: 'pre-wrap' }, this.phone)));
    p.textContent = String(err && err.message || err).slice(0, 240);
  }
  dropLayer(L, then) {
    if (!L || L.gone) return; L.gone = true;
    L.el.style.opacity = '0'; L.el.style.pointerEvents = 'none';
    setTimeout(() => { L.destroy(); L.el.remove(); if (then) then(); }, 560);
  }
  showOpening() {
    this.paused = true;
    try {
      this.openL = this.animLayer('open', { onTap: () => this.closeOpening() });
      this.openL.el.setAttribute('role', 'button'); this.openL.el.setAttribute('aria-label', 'pl8(math). Tap to start');
    } catch (err) { this.reportError(err); this.paused = false; }
  }
  // where the cube will sit on screen, and how tall it is there (phone px)
  cubeTarget() {
    const T = this.THREE, g = this.popG, cam = this.camera; if (!T || !g || !cam) return null;
    const s = g.scale.x, v = g.visible; g.scale.setScalar(1); g.visible = true; g.updateMatrixWorld(true);
    const b = new T.Box3().setFromObject(g); g.scale.setScalar(s); g.visible = v; g.updateMatrixWorld(true);
    if (b.isEmpty()) return null;
    const c = b.getCenter(new T.Vector3()), W = this.phone.clientWidth || 390, H = this.phone.clientHeight || 844;
    const pr = (x, y, z) => { const q = new T.Vector3(x, y, z).project(cam); return { x: (q.x + 1) / 2 * W, y: (1 - q.y) / 2 * H }; };
    const m = pr(c.x, c.y, c.z), top = pr(c.x, b.max.y, c.z), bot = pr(c.x, b.min.y, c.z);
    return { x: m.x, y: m.y, h: Math.abs(bot.y - top.y) };
  }
  closeOpening() {
    this.paused = false;            // 2 · the box pops in under the fading title, and waits for a tap
    const L = this.openL; this.openL = null;
    if (!L || L.gone) return;
    this.buzz('light');
    this.dropLayer(L);
  }

  // ---------------- camera helpers for the screens ----------------
  camTo(name, dur) {
    const S = this.SHOTS && this.SHOTS[name]; if (!S || !this.camera) return;
    let T = S.T, P = S.P;
    // pulls start on the floor: aim the set view lower
    if (name === 'setv' && this.plan && this.liftOnFloor(this.setIdx)) {
      const R = this.RACK || [0, 0], PZ = this.PLAT ? this.PLAT[1] : R[1], ex = R[0] + 1.1 * (this.barSX || 1);
      T = [ex - 0.35, 0.3, PZ]; P = [ex + 1.55, 1.7, PZ + 2.0];
    }
    this.flyTo(T, P, dur || 1.15); this.fovGoal = S.fov || 50;
  }
  // how much of the screen the open drawer or floating card covers, from the bottom (0..1)
  coverFrac() {
    const el = this.sheetEl && this.sheetEl.isConnected ? this.sheetEl : this.cardEl && this.cardEl.isConnected ? this.cardEl : null;
    if (!el) return 0;
    const H = 844; return Math.min(0.9, Math.max(0, (H - el.offsetTop) / H));
  }
  bigQ(body, q) {
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', padding: '6px 4px 8px' }, body, q);
    this.h('div', { height: '10px' }, body);
  }
  secondary(parent, label, fn) {
    const b = this.h('button', { height: 'var(--b-h)', border: 'var(--bd)', borderRadius: 'var(--r-btn)', background: 'var(--c-soft)', color: '#000', fontSize: '17px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--b-tt)', cursor: 'pointer' }, parent, label);
    b.className = 'tap'; b.classList.replace('k-card', 'k-button'); b.onclick = fn; return b;
  }

  // ---------------- 3 · gym setup: one question at a time (name → units → plates → bar), each one building the gym ----------------
  showGym() {
    this.clearUI();
    const step = this.gymStep = Math.max(0, Math.min(3, this.gymStep || 0)), edit = this.gymMode === 'edit';
    const go = (s) => { this.gymStep = s; this.showGym(); };
    const back = step > 0 ? () => go(step - 1) : edit ? () => this.showHome() : null;
    const nextStep = () => { this.closeKeyboard(true); if (step < 3) go(step + 1); else this.finishSetup(); };
    const cont = (body, label, enabled) => {
      const b = this.bigButton(body, label || 'Continue', () => { if (b.dataset.on === '1') { this.buzz('light'); nextStep(); } });
      const set = (on) => { b.dataset.on = on ? '1' : '0'; b.style.opacity = on ? '1' : '0.35'; b.style.cursor = on ? 'pointer' : 'default'; };
      set(enabled !== false); b.style.marginTop = '16px'; return set;
    };
    const opts = { title: '', left: back ? 'Back' : '', onLeft: back };
    if (step === 0) {
      // name: the keyboard is already up; with the first letter the flag pops onto the back wall and unrolls with the name
      this.camTo('nameFlag');
      const { body } = this.sheet(Object.assign(opts, { height: 560 }));
      this.bigQ(body, 'Where are you training now?');
      const f = this.h('div', { display: 'flex', alignItems: 'center', height: 'var(--f-h)', padding: 'var(--f-pad)', borderRadius: 'var(--f-r)', background: 'var(--f-bg)', border: 'var(--f-bd)', borderBottom: 'var(--f-bdb)', boxShadow: 'var(--f-sh)', fontSize: 'var(--f-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)' }, body);
      const val = this.h('span', {}, f, this.d.name || '');
      this.h('span', { width: '2px', height: '26px', background: this.tint, animation: 'is-blink 1s infinite', marginLeft: '1px' }, f);
      const ph = this.h('span', { color: 'rgba(60,60,67,0.3)' }, f, this.d.name ? '' : 'e.g. 79');
      const setBtn = cont(body, 'Continue', !!this.d.name);
      this.openKeyboard('text', (k) => {
        if (k === 'done') { if (this.d.name) { this.buzz('light'); nextStep(); } return; }
        let v = this.d.name || '';
        v = k === 'del' ? v.slice(0, -1) : (v + k).slice(0, 8);
        this.d.name = v.toUpperCase(); val.textContent = this.d.name; ph.textContent = this.d.name ? '' : 'e.g. 79';
        setBtn(!!this.d.name); this.nameToFlag();
      }, true);
    } else if (step === 1) {
      // units: a checkmark list; the plate shelf swaps to the other plates
      this.camTo('corner'); this.setPiles(true);
      const { body } = this.sheet(opts);
      this.bigQ(body, 'Is the gym kilos or pounds?');
      const g = this.section(body), rows = [];
      [['kg', 'Kilograms'], ['lb', 'Pounds']].forEach(([v, l]) => {
        const rr = this.row(g, { label: l });
        const ck = this.h('span', { width: '20px', textAlign: 'right', color: this.tint, fontSize: '19px', fontWeight: 600 }, rr.r, this.d.unit === v ? '✓' : '');
        rows.push({ v, ck });
        rr.r.classList.add('tap'); rr.r.setAttribute('role', 'radio'); rr.r.setAttribute('aria-checked', this.d.unit === v ? 'true' : 'false');
        rr.r.onclick = () => { if (this.d.unit === v) return; this.setUnit(v); this.buzz('selection'); rows.forEach((q) => { q.ck.textContent = q.v === v ? '✓' : ''; q.ck.parentNode.setAttribute('aria-checked', q.v === v ? 'true' : 'false'); }); this.setPiles(true); this.setBarModel(); };
      });
      cont(body);
    } else if (step === 2) {
      // plates: chips; each one pops its pile on or off its peg
      this.camTo('corner'); this.setPiles(false);
      const { body } = this.sheet(opts);
      this.bigQ(body, 'Which plates does your gym have?');
      const wrap = this.chipWrap(body); wrap.setAttribute('aria-label', 'Plates');
      const own = this.own();
      this.specs().forEach((sp) => {
        this.chip(wrap, { label: this.fmt(sp.kg) + ' ' + this.d.unit, dot: sp.color, size: Math.round(10 + sp.d * 14), on: own.indexOf(sp.kg) >= 0, onToggle: (on) => {
          const a = this.own(), i = a.indexOf(sp.kg);
          if (on && i < 0) a.push(sp.kg); if (!on && i >= 0) a.splice(i, 1);
          this.buzz('light'); this.pilePop(sp.kg, on);
        } });
      });
      cont(body);
    } else {
      // the bar: the one on the rack changes to match (shorter sleeves, thinner grip for the lighter bars)
      this.camTo('bar'); this.setBarModel();
      const { body } = this.sheet(opts);
      this.bigQ(body, 'Which bar do you use?');
      const g = this.section(body), rows = [];
      this.BARS[this.d.unit].forEach(([w, l]) => {
        const rr = this.row(g, { label: '' }); rr.lab.remove();
        const tx = this.h('div', { flex: 1, minWidth: 0, padding: '12px 0' }, rr.r);
        this.h('div', { fontSize: '17px' }, tx, this.fmt(w) + ' ' + this.d.unit + ' · ' + l);
        const ck = this.h('span', { width: '20px', textAlign: 'right', color: this.tint, fontSize: '19px', fontWeight: 600 }, rr.r, this.barW() === w ? '✓' : '');
        rows.push({ w, ck });
        rr.r.classList.add('tap'); rr.r.setAttribute('role', 'radio');
        rr.r.onclick = () => { this.d.bar[this.d.unit] = w; this.buzz('selection'); rows.forEach((q) => { q.ck.textContent = q.w === w ? '✓' : ''; }); this.setBarModel(true); };
      });
      cont(body, 'Done');
    }
  }
  // the flag follows the name as it is typed
  nameToFlag() {
    const name = this.d.name || '';
    if (!name) { this.flagAnim = null; return; }
    this.FLAG_TEXT = name;
    const ff = this.FLAG_FONTS.find((q) => q.id === this.state.flagFont) || this.FLAG_FONTS[0];
    this.drawFlag(ff);
    if (!this.flagAnim) this.flagAnim = { t0: this.onb ? this.onb.t : 0 };
  }
  // the plate shelf: one pile per plate size; switched-on sizes pop onto their pegs
  setPiles(animate) {
    if (this.pileUnit !== this.d.unit) { this.buildPlatePiles(this.d.unit); this.pileAnim = {}; }
    const now = this.onb ? this.onb.t : 0, own = this.own();
    this.pileAnim = this.pileAnim || {};
    const seen = {};
    this.plateItems.forEach((pi) => {
      if (seen[pi.k]) return; seen[pi.k] = 1;
      const on = own.indexOf(pi.kg) >= 0, cur = this.pileAnim[pi.k];
      if (!cur || cur.on !== on) this.pileAnim[pi.k] = { on, t0: animate ? now + 0.25 + pi.k * 0.08 : now - 10 };
    });
  }
  pilePop(kg, on) {
    const now = this.onb ? this.onb.t : 0;
    this.plateItems.forEach((pi) => { if (pi.kg === kg) this.pileAnim[pi.k] = { on, t0: now }; });
  }
  // per frame while the gym is being set up: the flag and the piles follow the answers
  runSetup(dt, t) {
    const cl = (x) => Math.min(1, Math.max(0, x));
    const outBack = (x, k = 1.8) => { x = cl(x); const c = k + 1; return 1 + c * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); };
    const outCubic = (x) => 1 - Math.pow(1 - cl(x), 3);
    [this.ghostG, this.ghostFlagG].forEach((g) => { if (g) g.visible = false; });
    const F = this.flagAnim;
    if (F) {
      const rt = t - F.t0, rx = rt / 0.35, ux = (rt - 0.2) / 0.85;
      this.flagG.visible = true;
      this.flagG.scale.set(Math.max(0.0001, outBack(rx, 2.0)), 1, 1);
      const sy = Math.max(0.0001, outCubic(ux)), FH = this.flag.H;
      this.flagCloth.scale.y = sy; this.flagCloth.position.y = -FH / 2 * sy;
      const sf = rt - 0.2, e = sf < 0 ? 0 : sf < 0.85 ? 0.6 + 0.4 * Math.sin((sf / 0.85) * Math.PI / 2) : Math.exp(-(sf - 0.85) * 1.2);
      if (rt < 3.5) this.poseFlag(e, t);
    } else this.flagG.visible = false;
    // plates slide along their peg like they would by hand: on, innermost first; off, outermost first. No popping.
    const A = this.pileAnim || {};
    (this.plateItems || []).forEach((pi) => {
      const a = A[pi.k]; if (!a) { pi.o.visible = false; return; }
      this.posePlate(pi); pi.o.scale.setScalar(1);
      const off = 0.32 + (pi.n - pi.i) * (pi.t + 0.003);
      if (a.on) {
        const q = (t - a.t0 - pi.i * 0.07) / 0.34;
        if (q <= 0) { pi.o.visible = false; return; }
        const e = outCubic(q); pi.o.visible = true; pi.o.position.x = pi.bx + off * (1 - e);
      } else {
        const q = (t - a.t0 - (pi.n - 1 - pi.i) * 0.05) / 0.26;
        if (q >= 1 || a.t0 < t - 5) { pi.o.visible = false; return; }
        const c = cl(q); pi.o.visible = true; pi.o.position.x = pi.bx + off * c * c;
      }
    });
  }
  // the bar on the rack takes the chosen bar's length and grip
  setBarModel(kick) {
    if (!this.barG) return;
    const w = this.barW(), u = this.d.unit, list = this.BARS[u].map((b) => b[0]), i = Math.max(0, list.indexOf(w));
    const L = [1, 0.914, 0.8][i], th = [1, 0.88, 0.8][i];
    this.barSX = L; this.barG.scale.set(L, th, th);
    if (kick) this.shakeKick(0.05);
  }
  finishSetup() {
    const O = this.onb, own = this.own();
    this.clearUI();
    // the gym is set: piles and flag stay as they are, the rest of the onboarding takes over from here
    if (this.pileUnit !== this.d.unit) this.buildPlatePiles(this.d.unit);
    const order = []; this.plateItems.forEach((pi) => { if (pi.i === 0 && own.indexOf(pi.kg) >= 0) order.push(pi.k); });
    O.rank = {}; order.forEach((k, i) => { O.rank[k] = i; }); O.have = own.slice();
    O.flagAt = -100; O.rt0 = O.t - 200;
    if (!this.d.name) { this.d.name = '79'; this.nameToFlag(); }
    this.flagAnim = null;
    this.flagG.visible = true; this.flagG.scale.set(1, 1, 1); this.flagCloth.scale.y = 1; this.flagCloth.position.y = -this.flag.H / 2;
    if (this.gymMode === 'edit') { this.drawPR(this.prData()); this.showHome(); return; }
    // 4 · on to the PR board
    O.phase = 'toPR'; O.pt = 0; this.camTo('pr', 1.5);
  }

  // ---------------- 4 · PRs: upload, scan or type ----------------
  showPRs(mode) {
    this.clearUI(); this.prMode = mode || 'first';
    this.camTo('pr');
    const home = this.prMode === 'home';
    const toList = (src) => {
      if (src !== 'typed') this.d.prs.forEach((q) => { q[1] = this.demoPR(q); });
      this.drawPR(this.prData()); this.prList(src);
    };
    this.chooser({ left: home ? 'Back' : '', onLeft: home ? () => this.showHome() : null,
      q: 'Add your PRs',
      options: [
        { icon: 'photo', label: 'Upload a screenshot', tag: 'Fastest', fn: () => this.photoPicker('pr', () => { this.closeSheet(); this.reading('Reading your PRs…', () => toList('upload')); }, () => this.showPRs(this.prMode)) },
        { icon: 'camera', label: 'Scan with the camera', fn: () => { this.closeSheet(); this.scanner({ title: 'Scan your PRs', onCancel: () => this.showPRs(this.prMode), onCapture: () => toList('scan'), draw: (x) => {
          x.fillStyle = '#F4EFE2'; x.fillRect(0, 0, 780, 1000);
          x.strokeStyle = 'rgba(60,90,160,0.25)'; x.lineWidth = 2; for (let y = 120; y < 1000; y += 70) { x.beginPath(); x.moveTo(0, y); x.lineTo(780, y); x.stroke(); }
          x.fillStyle = '#222'; x.font = '58px "Permanent Marker", cursive'; x.fillText('PRs', 60, 100);
          x.font = '46px "Permanent Marker", cursive';
          this.d.prs.forEach((q, i) => x.fillText(q[0] + ' ' + this.fmt(this.demoPR(q)), 60, 245 + i * 140));
          return { count: this.d.prs.length, top: 19.5, gap: 14, h: 6, widths: this.d.prs.map((q) => Math.min(88, 18 + (q[0].length + 4) * 3.4)) };
        } }); } },
        { icon: 'keys', label: 'Type them in', fn: () => this.prList('typed') }
      ] });
  }
  prList(src) {
    this.clearUI(); this.camTo('pr');
    const home = this.prMode === 'home';
    const { body } = this.sheet({ title: '', left: 'Back', onLeft: () => (home ? this.showHome() : this.showPRs(this.prMode)), right: home ? 'Done' : 'Next', onRight: () => {
      this.closeKeyboard(true); this.closeSheet();
      if (home) { this.drawPR(this.prData()); this.showHome(); return; }
      this.finishPR(this.prData());
    } });
    const g = this.section(body), rows = [];
    this.d.prs.forEach((q, i) => {
      const rr = this.row(g, { label: q[0] });
      const v = this.h('span', { color: q[1] == null ? 'rgba(60,60,67,0.3)' : 'rgba(60,60,67,0.6)', fontVariantNumeric: 'tabular-nums' }, rr.r, q[1] == null ? 'Add' : this.fmt(q[1]) + ' ' + this.d.unit);
      this.h('span', { color: 'rgba(60,60,67,0.3)', fontSize: '15px' }, rr.r, '›');
      rows.push({ rr, v });
      rr.r.classList.add('tap');
      rr.r.onclick = () => {
        rows.forEach((x, j) => { x.rr.r.style.background = j === i ? 'var(--c-sel)' : 'transparent'; x.v.style.color = j === i ? this.tint : 'var(--c-ink2)'; });
        let buf = '';
        rr.r.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        this.openKeyboard('num', (k) => {
          if (k === 'done') { rows.forEach((x) => { x.rr.r.style.background = 'transparent'; x.v.style.color = 'var(--c-ink2)'; }); this.closeKeyboard(); this.buzz('light'); return; }
          if (k === 'del') buf = buf.slice(0, -1); else if (!(k === '.' && buf.indexOf('.') >= 0) && buf.length < 6) buf += k;
          const n = parseFloat(buf); q[1] = isFinite(n) ? n : null;
          v.textContent = (buf || '0') + ' ' + this.d.unit; v.style.color = this.tint; this.drawPR(this.prData());
        });
      };
    });
  }

  // ---------------- 5 · today's workout: scan, upload or type ----------------
  showWod(mode) {
    this.clearUI(); this.wodMode = mode || 'first';
    this.camTo('board');
    const home = this.wodMode === 'home';
    this.chooser({ left: home ? 'Back' : '', onLeft: home ? () => { this.onb.phase = 'home'; this.showHome(); } : null,
      q: "Add today's workout",
      options: [
        { icon: 'camera', label: 'Scan the whiteboard', fn: () => { this.closeSheet(); this.scanner({ title: 'Scan the workout', onCancel: () => this.showWod(this.wodMode), onCapture: () => this.wodReady('scan'), draw: (x) => {
          const gr = x.createLinearGradient(0, 0, 780, 1000); gr.addColorStop(0, '#E9E6DF'); gr.addColorStop(1, '#CFCAC0'); x.fillStyle = gr; x.fillRect(0, 0, 780, 1000);
          x.fillStyle = '#B9B3A8'; x.fillRect(0, 0, 780, 30); x.fillRect(0, 970, 780, 30);
          x.fillStyle = '#1F3A73'; x.font = '64px "Permanent Marker", cursive'; x.fillText('WOD 10/08', 60, 150);
          x.font = '52px "Permanent Marker", cursive';
          const lines = this.d.wod.map((e) => e.lift + '  ' + e.sets + 'x' + e.reps + ' @' + e.pct + '%');
          lines.forEach((t, i) => x.fillText(t, 60, 290 + i * 110));
          x.fillStyle = '#9C2C2C'; x.font = '44px "Permanent Marker", cursive'; x.fillText('rest 1:30 btw sets', 60, 290 + lines.length * 110 + 40);
          return { count: lines.length, top: 23, gap: 11, h: 6, widths: lines.map((t) => Math.min(88, 14 + t.length * 3.3)) };
        } }); } },
        { icon: 'photo', label: 'Upload a screenshot', fn: () => this.photoPicker('wod', () => { this.closeSheet(); this.reading('Reading the workout…', () => this.wodReady('upload')); }, () => this.showWod(this.wodMode)) },
        { icon: 'keys', label: 'Type it in', fn: () => { this.closeSheet(); this.review('typed'); } }
      ] });
  }
  // what was read is written on the whiteboard; one tap to start, or edit / cancel
  wodReady(src) {
    this.clearUI(); this.camTo('board');
    this.plan = this.workoutPlan(); this.drawWB(this.plan); this.buzz('success');
    const { body } = this.sheet({ title: '' });
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', padding: '2px 4px 16px' }, body, 'Ready to lift?');
    this.bigButton(body, 'Start training', () => { this.closeSheet(); const p = this.workoutPlan(); if (p) this.beginWorkout(p); });
    const row = this.h('div', { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '10px' }, body);
    this.secondary(row, 'Edit', () => this.review(src));
    this.secondary(row, 'Cancel', () => { this.plan = null; this.drawWB(null); this.showWod(this.wodMode); });
  }
  review(src) {
    this.clearUI(); this.camTo('board');
    const { body } = this.sheet({ detent: 'large', title: '', left: 'Cancel', onLeft: () => (src === 'typed' ? this.showWod(this.wodMode) : this.wodReady(src)), right: 'Done', onRight: () => {
      if (!this.d.wod.length) return;
      this.closeSheet(); this.wodReady(src);
    } });
    const host = this.h('div', {}, body);
    const draw = () => {
      host.innerHTML = '';
      this.d.wod.forEach((e, i) => {
        const g = this.section(host);
        if (i > 0) g.style.marginTop = '20px';
        const r1 = this.row(g, { label: 'Lift' });
        const sel = this.h('select', { border: 0, background: 'none', fontSize: '17px', color: 'rgba(60,60,67,0.6)', textAlign: 'right', fontFamily: 'inherit', cursor: 'pointer', appearance: 'none' }, r1.r);
        this.d.prs.forEach((q) => { const op = this.h('option', null, sel, q[0]); if (q[0] === e.lift) op.selected = true; });
        sel.onchange = () => { e.lift = sel.value; };
        this.h('span', { color: 'rgba(60,60,67,0.3)', fontSize: '13px' }, r1.r, '⌃⌄');
        const num = (label, key, unit, step, lo, hi) => {
          const rr = this.row(g, { label });
          const v = this.h('span', { fontVariantNumeric: 'tabular-nums', color: 'rgba(60,60,67,0.6)', minWidth: '44px', textAlign: 'right' }, rr.r, e[key] + unit);
          rr.r.appendChild(this.stepper(() => { e[key] = Math.max(lo, e[key] - step); v.textContent = e[key] + unit; this.buzz('selection'); }, () => { e[key] = Math.min(hi, e[key] + step); v.textContent = e[key] + unit; this.buzz('selection'); }));
        };
        num('Sets', 'sets', '', 1, 1, 12); num('Reps', 'reps', '', 1, 1, 30); num('Of your PR', 'pct', '%', 2.5, 30, 110);
        this.row(g, { label: 'Remove', labelColor: '#FF3B30', onClick: () => { this.d.wod.splice(i, 1); draw(); } });
      });
      const ga = this.section(host);
      ga.style.marginTop = '20px';
      this.row(ga, { label: '+  Add exercise', labelColor: this.tint, onClick: () => { this.d.wod.push({ lift: this.d.prs[0][0], sets: 3, reps: 5, pct: 70 }); draw(); } });
    };
    draw();
  }

  // ---------------- 6 · plate kit: the session's plates drop onto the floor; chips to keep track ----------------
  showKit() {
    this.clearUI();
    const P = this.plan; if (!P) return;
    const mid = !!this.inSession, U = this.d.unit.toUpperCase(), got = this.d.kitGot || (this.d.kitGot = {});
    const bar = this.h('div', { position: 'absolute', left: '10px', right: '12px', bottom: '24px', padding: '12px', borderRadius: 'var(--r-float)', background: 'rgba(249,249,249,0.78)', backdropFilter: 'blur(20px) saturate(1.8)', WebkitBackdropFilter: 'blur(20px) saturate(1.8)', border: 'var(--bd)', boxShadow: 'var(--sh-float)', zIndex: 20 }, this.ui);
    this.cardEl = bar;
    if (!P.kit.length) this.h('div', { textAlign: 'center', fontSize: '15px', fontWeight: '600', color: '#3c3c43', padding: '4px 8px 12px' }, bar, 'Just the bar');
    else {
      const wrap = this.chipWrap(bar); wrap.style.margin = '0 0 12px'; wrap.setAttribute('aria-label', 'Plates to grab');
      P.kit.forEach((k) => {
        const sp = this.specs().find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
        this.chip(wrap, { label: k.qty + ' × ' + this.fmt(k.w) + ' ' + U, dot: sp.color, size: Math.round(10 + sp.d * 14), on: !!got[k.w], check: true, onToggle: (v) => { if (v) got[k.w] = true; else delete got[k.w]; if (v) this.buzz('light'); } });
      });
    }
    this.bigButton(bar, mid ? 'Back to the set' : 'Start session', () => { this.inSession = true; this.goTab('sets'); }, { height: '56px', fontSize: '19px' });
  }

  // ---------------- 7 · set by set: the set, its load, one Done ----------------
  showSetCard() {
    this.clearUI();
    const P = this.plan; if (!P) return;
    const i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    const bar = this.h('div', { position: 'absolute', left: '10px', right: '12px', bottom: '24px', padding: '14px 16px 16px', borderRadius: 'var(--r-float)', background: 'rgba(249,249,249,0.78)', backdropFilter: 'blur(20px) saturate(1.8)', WebkitBackdropFilter: 'blur(20px) saturate(1.8)', border: 'var(--bd)', boxShadow: 'var(--sh-float)', display: 'flex', flexDirection: 'column', gap: '12px', zIndex: 20 }, this.ui);
    this.cardEl = bar;
    const info = this.h('div', { display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: '10px' }, bar);
    const il = this.h('div', { minWidth: 0 }, info);
    this.h('div', { fontSize: '13px', fontWeight: 700, color: 'rgba(60,60,67,0.6)', textTransform: 'uppercase', letterSpacing: '0.08em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }, il, x.group);
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', whiteSpace: 'nowrap' }, il, x.label + ' of ' + x.of);
    this.h('div', { flex: 'none', textAlign: 'right', fontSize: '17px', fontWeight: 600, fontVariantNumeric: 'tabular-nums' }, info, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + this.d.unit);
    const dots = this.h('div', { display: 'flex', gap: '6px' }, bar);
    const base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.h('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? '#1C1C1E' : 'rgba(0,0,0,0.12)' }, dots); });
    this.bigButton(bar, 'Done', () => this.checkSet(), { height: '56px', fontSize: '19px' });
    // a quiet way back to the plate kit, keeping the place in the session
    const pl = this.h('button', { position: 'absolute', right: '16px', top: '104px', zIndex: 20, display: 'flex', alignItems: 'center', gap: '6px', height: '36px', padding: '0 14px', border: 'var(--bd)', borderRadius: 'var(--r-btn)', background: 'rgba(249,249,249,0.78)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', boxShadow: 'var(--sh)', fontSize: '15px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', color: 'var(--c-ink)', cursor: 'pointer' }, this.ui);
    pl.classList.replace('k-card', 'k-button'); pl.classList.add('tap');
    pl.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></svg>Plates';
    pl.setAttribute('aria-label', 'See the plate kit'); pl.onclick = () => this.goTab('kit');
  }
  checkSet() {
    const P = this.plan; if (!P || this.finishing) return;
    const n = P.flat.length, i = this.setIdx;
    this.doneSets[i] = true; this.buzz('success');
    if (this.doneSets.filter(Boolean).length >= n) { this.finishWorkout(); return; }
    let j = i + 1; while (j < n && this.doneSets[j]) j++;
    if (j >= n) { j = 0; while (j < n && this.doneSets[j]) j++; }
    this.setIdx = j; this.showSetCard();
    setTimeout(() => { if (!this.dead && this.plan) this.showSet(j, null, { next: true }); }, 350);
  }

  // ---------------- 8 · session over: the UI Animation Lab's scale, with this session's plates and volume ----------------
  showSessionOver() {
    // the scale weighs the heaviest set of the session: its bar and plates, both sides
    const P = this.plan, u = this.d.unit, sp = this.specs(), plates = [];
    const top = P && P.flat.length ? P.flat.reduce((a, x) => (x.total > a.total ? x : a), P.flat[0]) : null;
    (top ? top.side : []).forEach((w) => { const s = sp.find((q) => q.kg === w); if (s) plates.push(s, s); });
    plates.sort((a, b) => b.kg - a.kg);
    this.doneL = this.animLayer('done', { plates: plates.slice(0, 16), total: top ? Math.round(top.total * 10) / 10 : 0, unit: u, bar: P ? P.bar : 20, label: 'Heaviest set',
      onTap: () => { if (this.doneL && (this.doneL.ready() || Date.now() - this.doneT > 6000)) this.closeSessionOver(); } });
    this.doneT = Date.now();
    this.doneL.el.setAttribute('role', 'button'); this.doneL.el.setAttribute('aria-label', 'Session over. Tap to go back to your gym');
  }
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light');
    this.dropLayer(L);
    // 9 · back home: the kit is put away, the gym in overview, a tab bar below
    const O = this.onb;
    if (this.kitItems) this.kitOutT = O.t;
    (this.onBar || []).forEach((m) => { if (!m.out) { m.out = true; m.outT = O.t + 0.6 + (m.k || 0) * 0.08; } });
    this.barSide = [];
    this.plan = null; this.inSession = false; this.d.kitGot = {}; this.finishing = false;
    this.drawWB(null);
    O.phase = 'home';
    this.camTo('overview', 1.8);
    this.showHome();
  }
  showHome() {
    this.clearUI();
    const O = this.onb; if (O && O.phase !== 'home') O.phase = 'home';
    this.controls.enabled = true;
    if (this.camera && this.SHOTS) this.camTo('overview', 1.6);
    const nav = this.h('nav', { position: 'absolute', left: 0, right: 0, bottom: 0, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', padding: '8px 12px 30px', background: 'var(--c-sheet)', border: 'var(--d-bd)', borderBottom: '0', boxShadow: 'var(--sh-sheet)', zIndex: 20 }, this.ui);
    nav.setAttribute('aria-label', 'Main');
    this.cardEl = nav;
    const items = [
      ['train', 'Train', '<path d="M2 12h20M5 8v8M8 6v12M16 6v12M19 8v8"/>'],
      ['prs', 'PRs', '<path d="M8 4h8v5a4 4 0 0 1-8 0V4zM8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M8 20h8"/>'],
      ['gym', 'Gym', '<path d="M3 21V9l9-5 9 5v12M9 21v-6h6v6"/>']
    ];
    items.forEach(([id, label, icon]) => {
      const b = this.h('button', { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', height: '54px', border: 0, background: 'none', color: '#000', fontSize: '13px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--b-tt)', cursor: 'pointer', padding: '6px 0 0' }, nav);
      b.className = 'tap'; b.setAttribute('aria-label', label);
      b.innerHTML = '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + icon + '</svg><span>' + label + '</span>';
      b.onclick = () => this.pickTab(id);
    });
  }
  pickTab(id) {
    this.buzz('selection'); this.controls.enabled = false;
    if (id === 'train') { this.trainAgain(); return; }
    if (id === 'prs') { this.prMode = 'home'; this.prList('home'); return; }
    if (id === 'gym') { this.flagAnim = this.d.name ? { t0: this.onb.t - 10 } : null; this.showGymHome(); }
  }

  // ---------------- the gym's layout, from the Layout Lab (saved in this browser, or the layout Will settled on) ----------------
  static get LAYOUT_DEFAULT() { return {"v":1,"room":{"cols":9,"rows":7},"objects":{"platform":{"p":[0.66,0,-1.86],"r":0,"s":1},"rack":{"p":[0.61,0,-2.31],"r":0,"s":1},"bench":{"p":[0.95,0,0.63],"r":180,"s":1},"bottle":{"p":[0.56,0.1,-0.26],"r":0,"s":1,"removed":true},"board":{"p":[-2.16,0,-3.07],"r":25,"s":1},"shelf":{"p":[0.06,0.3,2.32],"r":0,"s":1},"flag":{"p":[3.2,1.95,-3.99],"r":0,"s":1},"pr":{"p":[-3.97,1.15,-2.76],"r":90,"s":1},"bell":{"p":[3.65,1.75,-3.95],"r":0,"s":1,"removed":true},"window":{"p":[0,-0.25,0.65],"r":0,"s":1,"removed":true},"clip":{"p":[3.94,1.3,-3],"r":-90,"s":1,"removed":true}},"added":[{"kind":"kitplates","p":[3.45,0,-1.85],"r":0,"s":1},{"kind":"wallfan","p":[4.94,2,-2.75],"r":-90,"s":1},{"kind":"barholder","p":[5,0,-0.45],"r":-90,"s":1},{"kind":"wallwindow","p":[5,-0.15,1.2],"r":-90,"s":1}],"shots":{"overview":{"T":[0.44,1.33,-0.89],"P":[13.28,10.8,14.36],"fov":50},"corner":{"T":[-4.31,0.69,-0.22],"P":[1.27,2.01,3.24],"fov":50},"flag":{"T":[3.03,0.98,-2.31],"P":[-0.45,6.06,1.46],"fov":50},"pr":{"T":[-3.93,1.18,-2.72],"P":[-0.81,1.77,-0.02],"fov":50},"board":{"T":[-0.93,1.97,2.15],"P":[-0.65,2.21,3.29],"fov":40},"kit":{"T":[2.39,0.91,-0.87],"P":[-0.48,2.71,3.82],"fov":50},"setv":{"T":[2.38,1.54,-1.86],"P":[3.04,1.75,-0.89],"fov":50}}}; }
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

  // ---------------- the screens' building blocks (from Input screens · custom) ----------------
  mix(a, b, t) { const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)); const x = p(a), y = p(b); return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('').toUpperCase(); }
  alpha(h, a) { const c = parseInt(h.slice(1), 16); return 'rgba(' + (c >> 16 & 255) + ',' + (c >> 8 & 255) + ',' + (c & 255) + ',' + a + ')'; }
  lum(h) { const c = parseInt(h.slice(1), 16); const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c >> 16 & 255) + 0.7152 * f(c >> 8 & 255) + 0.0722 * f(c & 255); }
  contrast(a, b) { const x = this.lum(a), y = this.lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  cols() {
    const L = this.look, P = this.pal, ink = L.ink || P.boxDark, surface = L.surface || P.boxLight;
    return { accent: L.accent || P.bgColor, text: L.text || ink, ink, surface, card: L.card || this.mix(P.boxLight, '#FFFFFF', 0.62), bg: L.bg || P.bgColor, frC: L.frC || surface };
  }
  applyUILook() {
    const U = this.ui; if (!U) return;   // on our own layer: the board template owns the phone's style attribute
    const c = this.cols(), L = this.look, px = (n) => n + 'px';
    const on = this.lum(c.accent) > 0.45 ? c.text : '#FFFFFF';
    const line = (w, col) => (w > 0 ? w + 'px solid ' + col : '0 solid transparent');
    const fd = this.UFONTS[L.fd] || this.UFONTS.grotesk, ft = this.UFONTS[L.ft] || this.UFONTS.grotesk;
    const shCard = { none: 'none', soft: '0 4px 14px rgba(0,0,0,0.12)', sticker: '3px 3px 0 ' + c.ink }[L.cSh] || 'none';
    const shFloat = { none: 'none', soft: '0 8px 30px rgba(0,0,0,0.18)', sticker: '4px 5px 0 ' + c.ink }[L.cSh] || 'none';
    const bw = L.cBw, bwIn = Math.min(bw, 1.5);
    const fl = L.bFill;
    const bBd = fl === 'outline' ? line(Math.max(L.bBw, 1.5), fl === 'outline' ? c.accent : c.ink) : line(L.bBw, c.ink);
    const fBd = L.fStyle === 'outline' ? line(Math.max(bw, 1.5), c.ink) : line(0);
    const v = {
      '--c-accent': c.accent, '--c-on': on, '--c-link': this.contrast(c.accent, c.surface) < 1.8 ? c.text : c.accent, '--c-chip': this.contrast(c.accent, c.surface) < 1.8 ? c.text : c.accent, '--c-chip-on': this.contrast(c.accent, c.surface) < 1.8 ? c.card : on, '--c-soft': this.alpha(c.text, 0.07), '--c-ink': c.text, '--c-ink2': this.alpha(c.text, L.tSub), '--c-ink3': this.alpha(c.text, Math.max(0.2, L.tSub * 0.55)),
      '--c-line': this.alpha(c.ink, 0.22), '--c-fill': this.alpha(c.ink, 0.09), '--c-sel': this.alpha(c.accent, 0.16),
      '--c-sheet': c.surface, '--c-card': c.card, '--c-float': this.alpha(c.surface, 0.94), '--c-good': c.accent,
      '--f-display': fd[0], '--w-display': String(fd[1]), '--f-text': ft[0], '--tt': L.caps === 'on' ? 'uppercase' : 'none',
      '--ts': String(L.tSize), '--t-w': String(L.tW), '--t-track': L.tTrack + 'em',
      '--h-size': px(L.hSize), '--h-track': L.hTrack + 'em', '--h-line': String(L.hLine),
      '--r-sheet': px(L.dR), '--r-card': px(L.cR), '--r-float': px(L.cR + 10), '--r-ctl': px(Math.min(L.cR, 12)), '--r-btn': L.bR >= 32 ? '999px' : px(L.bR),
      '--bd': line(bw, c.ink), '--bdw': px(bw), '--bd-in': line(bwIn, c.ink), '--bdw-in': px(bwIn),
      '--sh': shCard, '--sh-float': shFloat,
      '--d-bd': L.dBc === 'none' ? line(0) : line(L.dBw, L.dBc === 'accent' ? c.accent : c.ink), '--d-bw': px(L.dBc === 'none' ? 0 : L.dBw),
      '--d-max': L.dMax + '%', '--d-fix': L.dFix + '%',
      '--sh-sheet': { none: 'none', soft: '0 -6px 30px rgba(0,0,0,0.18)', sticker: '0 -5px 0 ' + c.ink }[L.dSh] || 'none', '--grab': L.dGrab === 'on' ? 'block' : 'none',
      '--b-bg': fl === 'solid' ? c.accent : fl === 'soft' ? this.alpha(c.accent, 0.18) : 'transparent', '--b-fg': fl === 'solid' ? on : c.accent,
      '--b-bd': bBd, '--b-bw': px(fl === 'outline' ? Math.max(L.bBw, 1.5) : L.bBw), '--b-h': px(L.bH), '--b-tt': L.bCase === 'on' ? 'uppercase' : 'none',
      '--b-sh': { none: 'none', drop: '0 6px 16px ' + this.alpha(c.accent, 0.38), sticker: '0 4px 0 ' + c.ink }[L.bSh] || 'none',
      '--f-bg': L.fStyle === 'filled' ? this.alpha(c.ink, 0.09) : L.fStyle === 'underline' ? 'transparent' : c.card,
      '--f-bd': fBd, '--f-bdb': L.fStyle === 'underline' ? line(Math.max(bw, 2), c.ink) : fBd, '--f-bw': px(L.fStyle === 'outline' ? Math.max(bw, 1.5) : 0),
      '--f-r': L.fStyle === 'underline' ? '0px' : px(L.fR), '--f-h': px(L.fH), '--f-size': px(L.fSize),
      '--f-sh': L.fStyle === 'outline' ? shCard : 'none', '--f-pad': L.fStyle === 'underline' ? '0 2px' : '0 16px'
    };
    Object.keys(v).forEach((k) => U.style.setProperty(k, v[k]));
    U.classList.toggle('rough', L.rough > 0);
    [['drawer', 'rkDrawer'], ['card', 'rkCard'], ['button', 'rkButton'], ['field', 'rkField'], ['control', 'rkControl']].forEach(([k, key]) => U.classList.toggle('rk-' + k, L[key] === 'on'));
    this.sizeSheet();
    // the rough filter
    if (this.turb) {
      this.turb.forEach((t) => t.setAttribute('baseFrequency', String(L.grain)));
      this.disp.forEach((d) => d.setAttribute('scale', String(L.rough)));
    }
    clearInterval(this.boilT); this.boilT = null;
    if (L.boil === 'on' && L.rough > 0 && this.turb) { let sd = 1; this.boilT = setInterval(() => { if (this.dead) return; sd = sd % 5 + 1; this.turb.forEach((t) => t.setAttribute('seed', String(sd))); }, 140); }
    // a frame around the 3D view
    const F = this.frameEl, H = this.frameHole;
    if (F) {
      const st = L.frStyle, W = L.frW;
      if (st === 'none') F.style.display = 'none';
      else {
        F.style.display = 'block';
        const top = L.frTop === 'frame' && st !== 'border' ? Math.max(W, 50 + W * 0.5) : W;
        const bot = st === 'polaroid' ? W * 3 + 40 : W;
        const R = st === 'border' ? 0 : st === 'polaroid' ? Math.min(L.frR, 10) : L.frR;
        Object.assign(H.style, { left: px(W), right: px(W), top: px(top), bottom: px(bot), borderRadius: px(R),
          boxShadow: '0 0 0 600px ' + c.frC + (L.frLine === 'on' ? ', inset 0 0 0 2.5px ' + c.ink : ''), filter: L.rough > 0 && L.rkFrame === 'on' ? 'url(#cu-rough-frame)' : 'none' });
      }
    }
  }
  themeCss(css) {
    const M = this.CMAP || (this.CMAP = {
      background: { '#FFF': 'var(--c-card)', '#FFFFFF': 'var(--c-card)', '#F2F2F7': 'var(--c-sheet)', '#E5E5EA': 'var(--c-sel)', 'rgba(120,120,128,0.16)': 'var(--c-fill)', 'rgba(118,118,128,0.12)': 'var(--c-fill)',
        'rgba(249,249,249,0.78)': 'var(--c-float)', 'rgba(249,249,249,0.92)': 'var(--c-float)', 'rgba(60,60,67,0.29)': 'var(--c-line)', 'rgba(60,60,67,0.18)': 'var(--c-line)', 'rgba(60,60,67,0.3)': 'var(--c-line)',
        '#34C759': 'var(--c-good)', '#1C1C1E': 'var(--c-ink)', '#C7C7CC': 'var(--c-ink3)', 'rgba(255,255,255,0.72)': 'var(--c-card)', 'rgba(0,0,0,0.15)': 'rgba(0,0,0,0.25)' },
      color: { '#000': 'var(--c-ink)', '#3c3c43': 'var(--c-ink)', '#FFF': 'var(--c-on)', '#FFFFFF': 'var(--c-on)', 'rgba(60,60,67,0.6)': 'var(--c-ink2)', 'rgba(60,60,67,0.3)': 'var(--c-ink3)', 'rgba(60,60,67,0.45)': 'var(--c-ink3)' },
      borderTop: { '0.5px solid rgba(60,60,67,0.18)': '1px solid var(--c-line)' }
    });
    const o = {};
    Object.keys(css).forEach((k) => {
      const v = css[k], m = M[k];
      if (k === 'fontSize' && typeof v === 'string' && /^\d+(\.\d+)?px$/.test(v)) o[k] = 'calc(' + v + ' * var(--ts))';
      else o[k] = m && typeof v === 'string' && m[v] ? m[v] : v;
    });
    return o;
  }
  markRough(e, css) {
    const BW = { 'var(--bd)': 'var(--bdw)', 'var(--bd-in)': 'var(--bdw-in)', 'var(--b-bd)': 'var(--b-bw)', 'var(--f-bd)': 'var(--f-bw)', 'var(--d-bd)': 'var(--d-bw)' };
    if (!BW[css.border]) return;
    const m = this.themeCss(css);
    e.classList.add('rb', 'k-' + ({ 'var(--d-bd)': 'drawer', 'var(--bd)': 'card', 'var(--b-bd)': 'button', 'var(--f-bd)': 'field', 'var(--bd-in)': 'control' }[css.border]));
    e.style.setProperty('--rb-bg', m.background || 'transparent'); e.style.setProperty('--rb-sh', m.boxShadow || 'none');
    e.style.setProperty('--rb-bd', css.border); e.style.setProperty('--rb-bdb', css.borderBottom != null ? String(css.borderBottom) : css.border); e.style.setProperty('--rb-bw', BW[css.border]);
  }
  get tint() { return this.raw ? '#007AFF' : 'var(--c-link)'; }
  sheet(o) {
    const S = this.h('div', { position: 'absolute', left: 0, right: 0, bottom: 0, height: o.height ? o.height + 'px' : (o.detent === 'large' ? 92 : 52) + '%', background: '#F2F2F7', borderRadius: this.raw ? '12px 12px 0 0' : 'var(--r-sheet) var(--r-sheet) 0 0', boxShadow: this.raw ? '0 -6px 30px rgba(0,0,0,0.18)' : 'var(--sh-sheet)', border: this.raw ? 'none' : 'var(--d-bd)', borderBottom: this.raw ? 'none' : '0', display: 'flex', flexDirection: 'column', transform: 'translateY(100%)', transition: 'transform .45s cubic-bezier(.2,.9,.25,1), height .4s cubic-bezier(.2,.9,.25,1)', zIndex: 20 }, this.ui);
    S.setAttribute('role', 'dialog'); S.setAttribute('aria-label', o.title);
    this.h('div', { width: '36px', height: '5px', borderRadius: '3px', background: '#C7C7CC', margin: '5px auto 0', flex: 'none', display: this.raw ? 'block' : 'var(--grab)' }, S);
    const nav = this.h('div', { flex: 'none', display: 'grid', gridTemplateColumns: '1fr auto 1fr', alignItems: 'center', height: '44px', padding: '0 16px' }, S);
    // our sheets: no titles or step counters in the bar, and Back is an arrow
    const arrow = !this.raw && o.left === 'Back';
    const l = this.h('button', arrow ? { justifySelf: 'start', display: 'flex', alignItems: 'center', justifyContent: 'center', width: '40px', height: '40px', marginLeft: '-8px', border: 0, background: 'none', padding: 0, color: 'var(--c-ink)' } : { justifySelf: 'start', border: 0, background: 'none', padding: 0, fontSize: '17px', color: this.tint }, nav, arrow ? null : (o.left || '')); l.className = 'tap';
    if (arrow) { l.setAttribute('aria-label', 'Back'); l.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 12H4.5M10.5 5.5L4 12l6.5 6.5"/></svg>'; }
    if (o.onLeft) l.onclick = o.onLeft; else l.style.visibility = 'hidden';
    const tt = this.h('div', { textAlign: 'center', lineHeight: 1.15 }, nav);
    if (!this.raw) { o = Object.assign({}, o, { title: '', sub: '' }); tt.setAttribute('aria-hidden', 'true'); }
    this.h('div', this.raw ? { fontSize: '17px', fontWeight: 600 } : { fontSize: '17px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)' }, tt, o.title);
    if (o.sub) this.h('div', { fontSize: '12px', color: 'rgba(60,60,67,0.6)' }, tt, o.sub);
    const r = this.h('button', { justifySelf: 'end', border: 0, background: 'none', padding: 0, fontSize: '17px', fontWeight: 600, color: this.tint }, nav, o.right || ''); r.className = 'tap';
    if (o.onRight) r.onclick = o.onRight; else r.style.visibility = 'hidden';
    const body = this.h('div', { flex: this.raw ? 1 : '0 1 auto', minHeight: 0, overflowY: 'auto', padding: '6px 16px 40px' }, S);
    this.sheetBody = body;
    requestAnimationFrame(() => requestAnimationFrame(() => { S.style.transform = 'translateY(0)'; }));
    this.sheetEl = S; this.sheetDetent = o.detent || 'medium';
    if (!this.raw) { S.dataset.kb = o.height ? '1' : ''; this.sizeSheet(); }
    return { S, body };
  }
  detent(d) { if (!this.sheetEl) return; this.sheetDetent = d; if (this.sheetEl.classList.contains('sys')) { this.sheetEl.style.height = (d === 'large' ? 92 : 52) + '%'; return; } this.sizeSheet(); }
  sizeSheet() {
    const S = this.sheetEl; if (!S || S.classList.contains('sys')) return;
    const kbTall = this.sheetDetent === 'large' && this.kbd && !S.dataset.kb;
    if (kbTall) { S.style.height = '92%'; S.style.maxHeight = 'none'; }
    else if (S.dataset.kb) { S.style.height = 'auto'; S.style.maxHeight = 'none'; }
    else if (this.look.dFit === 'fixed') { S.style.height = 'var(--d-fix)'; S.style.maxHeight = 'none'; }
    else { S.style.height = 'auto'; S.style.maxHeight = 'var(--d-max)'; }
  }
  section(parent, header, footer) {
    if (this.raw && header) this.h('div', { fontSize: '13px', textTransform: 'uppercase', letterSpacing: this.raw ? '0' : '0.06em', fontWeight: this.raw ? 400 : 700, color: 'rgba(60,60,67,0.6)', padding: '14px 16px 6px' }, parent, header);
    const g = this.h('div', this.raw ? { background: '#FFF', borderRadius: '10px', overflow: 'hidden' } : { background: '#FFF', borderRadius: 'var(--r-card)', overflow: 'hidden', border: 'var(--bd)', boxShadow: 'var(--sh)' }, parent);
    if (this.raw && footer) this.h('div', { fontSize: '13px', color: 'rgba(60,60,67,0.6)', padding: '6px 16px 0', lineHeight: 1.35 }, parent, footer);
    return g;
  }
  row(g, opts) {
    const r = this.h('div', { position: 'relative', display: 'flex', alignItems: 'center', gap: '12px', minHeight: '44px', padding: '0 16px', fontSize: '17px', background: opts.bg || (this.raw ? '#FFF' : 'transparent') }, g);
    if (g.childElementCount > 1) this.h('div', { position: 'absolute', left: opts.indent || '16px', right: 0, top: 0, height: '0.5px', background: 'rgba(60,60,67,0.29)' }, r);
    if (opts.dot) this.h('span', { flex: 'none', width: '22px', height: '22px', borderRadius: '11px', background: opts.dot, boxShadow: 'inset 0 0 0 5px rgba(255,255,255,0.35), inset 0 0 0 1px rgba(0,0,0,0.12)' }, r);
    const lab = this.h('span', { flex: 1, minWidth: 0, color: opts.labelColor || '#000' }, r, opts.label);
    if (opts.onClick) { r.classList.add('tap'); r.onclick = opts.onClick; r.setAttribute('role', 'button'); r.tabIndex = 0; }
    return { r, lab };
  }
  toggle(on, cb) {
    const t = this.h('button', { position: 'relative', flex: 'none', width: '51px', height: '31px', borderRadius: '16px', border: 0, padding: 0, background: on ? '#34C759' : 'rgba(120,120,128,0.16)', transition: 'background .2s', cursor: 'pointer', boxShadow: 'inset 0 0 0 0 transparent' }); t.style.border = 'var(--bd-in)'; t.style.boxSizing = 'border-box'; this.markRough(t, { border: 'var(--bd-in)', background: on ? '#34C759' : 'rgba(120,120,128,0.16)' });
    t.setAttribute('role', 'switch'); t.setAttribute('aria-checked', on ? 'true' : 'false');
    const k = this.h('span', { position: 'absolute', top: 'calc(2px - var(--bdw-in))', left: 'calc(2px - var(--bdw-in))', width: '27px', height: '27px', borderRadius: '14px', background: '#FFF', boxShadow: 'none', border: 'var(--bd-in)', boxSizing: 'border-box', transform: on ? 'translateX(20px)' : 'none', transition: 'transform .25s cubic-bezier(.3,1.4,.5,1)' }, t);
    t.onclick = (e) => { e.stopPropagation(); on = !on; t.style.background = on ? 'var(--c-good)' : 'var(--c-fill)'; t.style.setProperty('--rb-bg', t.style.background); k.style.transform = on ? 'translateX(20px)' : 'none'; t.setAttribute('aria-checked', on ? 'true' : 'false'); cb(on); };
    return t;
  }
  segmented(opts, val, cb, parent) {
    const s = this.h('div', { display: 'flex', padding: '2px', borderRadius: this.raw ? '9px' : 'var(--r-ctl)', background: 'rgba(118,118,128,0.12)', height: '32px', boxSizing: 'border-box' }, parent);
    s.setAttribute('role', 'radiogroup');
    const draw = () => { s.innerHTML = ''; opts.forEach(([v, l]) => { const on = v === val, b = this.h('button', { flex: 1, border: 0, borderRadius: '7px', background: on ? '#FFF' : 'transparent', boxShadow: on ? '0 3px 8px rgba(0,0,0,0.12), 0 3px 1px rgba(0,0,0,0.04)' : 'none', fontSize: '13px', fontWeight: on ? 600 : 500, color: '#000', cursor: 'pointer', padding: '0 10px' }, s, l); b.setAttribute('role', 'radio'); b.setAttribute('aria-checked', on ? 'true' : 'false'); b.onclick = () => { val = v; draw(); cb(v); }; }); };
    draw(); return s;
  }
  stepper(onMinus, onPlus) {
    const s = this.h('div', { flex: 'none', display: 'flex', alignItems: 'center', height: '32px', borderRadius: 'var(--r-ctl)', background: 'rgba(118,118,128,0.12)', border: 'var(--bd-in)', overflow: 'hidden' });
    const b = (txt, fn, label) => { const x = this.h('button', { width: '47px', height: '32px', border: 0, background: 'none', fontSize: '22px', fontWeight: 300, color: '#000', cursor: 'pointer', lineHeight: '30px' }, s, txt); x.setAttribute('aria-label', label); x.onclick = (e) => { e.stopPropagation(); fn(); }; return x; };
    b('−', onMinus, 'Decrease'); this.h('span', { width: '0.5px', height: '18px', background: 'rgba(60,60,67,0.3)' }, s); b('+', onPlus, 'Increase');
    return s;
  }
  chip(parent, o) {
    const c = this.h('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', border: 'var(--bd-in)', borderRadius: '999px', background: '#FFF', color: '#000', fontSize: '16px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', fontVariantNumeric: 'tabular-nums', cursor: 'pointer', transition: 'background .15s, color .15s', whiteSpace: 'nowrap' }, parent);
    c.className = 'tap'; c.classList.add('rb', 'k-control'); c.setAttribute('role', 'checkbox');
    const dot = this.h('span', { flex: 'none', width: o.size + 'px', height: o.size + 'px', borderRadius: '50%', background: o.dot, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.18)' }, c);
    const ck = this.h('span', { display: 'none', fontSize: '14px' }, c, '✓');
    this.h('span', {}, c, o.label);
    const paint = (v) => { c.setAttribute('aria-checked', String(v)); c.style.background = v ? 'var(--c-chip)' : 'var(--c-soft)'; c.style.color = v ? 'var(--c-chip-on)' : 'var(--c-ink)'; c.style.setProperty('--rb-bg', c.style.background); dot.style.boxShadow = v ? '0 0 0 2px var(--c-chip-on)' : 'inset 0 0 0 1px rgba(0,0,0,0.18)'; ck.style.display = v && o.check ? 'inline' : 'none'; };
    let on = !!o.on; paint(on);
    c.onclick = () => { on = !on; paint(on); o.onToggle(on); };
    return c;
  }
  chipWrap(parent) { return this.h('div', { display: 'flex', flexWrap: 'wrap', gap: '8px' }, parent); }
  bigButton(parent, label, fn, css) {
    if (!this.raw && css) { css = Object.assign({}, css); delete css.height; delete css.fontSize; }
    const b = this.h('button', Object.assign(this.raw ? { width: '100%', height: '50px', border: 0, borderRadius: '14px', background: this.tint, color: '#FFF', fontSize: '17px', fontWeight: 600, cursor: 'pointer' } : { width: '100%', height: 'var(--b-h)', border: 'var(--b-bd)', borderRadius: 'var(--r-btn)', background: 'var(--b-bg)', color: 'var(--b-fg)', boxShadow: 'var(--b-sh)', fontSize: '18px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--b-tt)', letterSpacing: '0.01em', cursor: 'pointer' }, css || {}), parent, label);
    b.className = 'tap'; b.onclick = fn; return b;
  }
  openKeyboard(kind, onKey, keepDetent) {
    this.closeKeyboard(true);
    const K = this.sys(() => this.h('div', { position: 'absolute', left: 0, right: 0, bottom: 0, background: '#D1D3D9', zIndex: 30, transform: 'translateY(100%)', transition: 'transform .35s cubic-bezier(.2,.9,.25,1)', paddingBottom: '30px' }, this.ui));
    K.setAttribute('aria-label', kind === 'num' ? 'Number keypad' : 'Keyboard');
    if (kind === 'num') {   // the text keyboard has no Done bar: Return continues
      const bar = this.h('div', { display: 'flex', justifyContent: 'flex-end', alignItems: 'center', height: '44px', padding: '0 16px', background: '#F2F2F7', borderTop: '0.5px solid rgba(0,0,0,0.15)' }, K);
      const dn = this.h('button', { border: 0, background: 'none', fontSize: '17px', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', color: this.tint, cursor: 'pointer' }, bar, 'Done'); bar.style.borderTop = 'var(--bd)'; bar.style.fontFamily = 'var(--f-text)'; dn.className = 'tap'; dn.onclick = () => onKey('done');
    }
    const key = (parent, label, val, css) => this.sys(() => { const k = this.h('button', Object.assign({ height: kind === 'num' ? '46px' : '42px', border: 0, borderRadius: '5px', background: '#FFF', boxShadow: '0 1px 0 rgba(0,0,0,0.3)', fontSize: kind === 'num' ? '25px' : '22px', color: '#000', cursor: 'pointer' }, css || {}), parent); k.innerHTML = label; k.onclick = () => onKey(val); return k; });
    if (kind === 'num') {
      const g = this.h('div', { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '7px', padding: '7px 6px' }, K);
      const L = ['', 'ABC', 'DEF', 'GHI', 'JKL', 'MNO', 'PQRS', 'TUV', 'WXYZ'];
      for (let i = 1; i <= 9; i++) key(g, '<div style="line-height:1">' + i + '</div><div style="font-size:10px;font-weight:600;letter-spacing:2px;line-height:1.2">' + L[i - 1] + '</div>', String(i));
      key(g, '.', '.', { background: 'transparent', boxShadow: 'none' }); key(g, '0', '0'); key(g, '⌫', 'del', { background: 'transparent', boxShadow: 'none', fontSize: '22px' });
    } else {
      const rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
      rows.forEach((rw, ri) => {
        const r = this.h('div', { display: 'flex', justifyContent: 'center', gap: '6px', padding: '6px 3px 0' }, K);
        if (ri === 2) key(r, '⇧', '', { width: '42px', background: '#ADB3BC', fontSize: '18px' });
        rw.split('').forEach((ch) => key(r, ch, ch, { width: '32px' }));
        if (ri === 2) key(r, '⌫', 'del', { width: '42px', background: '#ADB3BC', fontSize: '18px' });
      });
      const r = this.h('div', { display: 'flex', gap: '6px', padding: '8px 3px 4px' }, K);
      key(r, '123', '', { width: '86px', background: '#ADB3BC', fontSize: '16px' }); key(r, 'space', ' ', { flex: 1, fontSize: '16px' }); key(r, 'return', 'done', { width: '86px', background: '#ADB3BC', fontSize: '16px' });
    }
    requestAnimationFrame(() => requestAnimationFrame(() => { K.style.transform = 'none'; }));
    this.kbd = K; this.kbdFn = onKey; if (!keepDetent) this.detent('large');
    else if (this.sheetEl && this.sheetEl.dataset.kb && this.sheetBody) {
      const body = this.sheetBody, pad = () => { if (this.kbd === K) body.style.paddingBottom = ((K.offsetHeight || 274) + 14) + 'px'; };
      pad(); requestAnimationFrame(pad);
    }
    this.kbdKeys = (e) => { if (!this.kbdFn) return; if (e.key === 'Backspace') { this.kbdFn('del'); e.preventDefault(); } else if (e.key === 'Enter' || e.key === 'Escape') this.kbdFn('done'); else if (e.key.length === 1 && (kind !== 'num' || /[0-9.]/.test(e.key))) { this.kbdFn(e.key); e.preventDefault(); } };
    window.addEventListener('keydown', this.kbdKeys);
  }
  closeKeyboard(silent) {
    if (this.kbdKeys) window.removeEventListener('keydown', this.kbdKeys);
    this.kbdKeys = null; this.kbdFn = null;
    if (this.kbd) { const K = this.kbd; K.style.transform = 'translateY(100%)'; setTimeout(() => K.remove(), 350); this.kbd = null; if (!silent) this.detent('medium'); }
  }
  icon(kind) {
    const p = {
      photo: '<rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="9" cy="10" r="1.6"/><path d="M4 17l5-4.5 3.5 3 3-2.5L20 17"/>',
      camera: '<path d="M4 8h3l1.6-2.2h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/>',
      keys: '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M6 10h.01M9 10h.01M12 10h.01M15 10h.01M18 10h.01M7.5 14h9"/>'
    }[kind];
    return '<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>';
  }
  chooser(o) {
    const { body } = this.sheet({ title: '', sub: o.step || '', left: o.left || '', onLeft: o.onLeft });
    this.h('div', { fontSize: 'var(--h-size)', fontFamily: 'var(--f-display)', fontWeight: 'var(--w-display)', textTransform: 'var(--tt)', letterSpacing: 'var(--h-track)', lineHeight: 'var(--h-line)', padding: '6px 4px 8px' }, body, o.q);
    this.h('div', { height: '10px' }, body);   // no sub line under the question
    const g = this.section(body);
    o.options.forEach((op) => {
      const rr = this.row(g, { label: '', indent: '60px', onClick: op.fn });
      rr.lab.remove();
      const ic = this.h('span', { flex: 'none', width: '34px', height: '34px', borderRadius: 'var(--r-ctl)', background: op.icon === 'photo' ? 'var(--c-accent)' : op.icon === 'camera' ? 'var(--c-ink)' : 'var(--c-fill)', color: op.icon === 'photo' ? 'var(--c-on)' : op.icon === 'camera' ? 'var(--c-sheet)' : 'var(--c-ink)', border: 'var(--bd-in)', boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center' }, rr.r); ic.innerHTML = this.icon(op.icon);
      const tx = this.h('div', { flex: 1, minWidth: 0, padding: '10px 0' }, rr.r);
      this.h('div', { fontSize: '17px', fontWeight: 700 }, tx, op.label);
      if (op.tag) this.h('span', { flex: 'none', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.06em', padding: '3px 7px', borderRadius: 'var(--r-ctl)', background: 'var(--c-sel)', color: this.tint }, rr.r, op.tag);
      this.h('span', { color: 'rgba(60,60,67,0.3)', fontSize: '17px' }, rr.r, '›');
    });
  }
  drawShot(x, w, h, kind) {
    if (kind === 'pr') {
      x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, w, h);
      x.fillStyle = '#E8A33D'; x.font = '600 ' + (w * 0.05) + 'px -apple-system, Helvetica, Arial'; x.fillText('‹ Notes', w * 0.05, h * 0.07);
      x.fillStyle = '#000'; x.font = '700 ' + (w * 0.085) + 'px -apple-system, Helvetica, Arial'; x.fillText('My PRs 🏋', w * 0.06, h * 0.17);
      x.font = (w * 0.058) + 'px -apple-system, Helvetica, Arial';
      this.d.prs.forEach((q, i) => x.fillText('• ' + q[0] + ' – ' + this.fmt(this.demoPR(q)) + ' ' + this.d.unit, w * 0.07, h * (0.27 + i * 0.075)));
      x.fillStyle = '#8E8E93'; x.font = (w * 0.045) + 'px -apple-system, Helvetica, Arial'; x.fillText('updated after the open', w * 0.07, h * (0.3 + this.d.prs.length * 0.075));
    } else {
      x.fillStyle = '#121212'; x.fillRect(0, 0, w, h);
      x.fillStyle = this.pal.bgColor; x.fillRect(0, h * 0.1, w, h * 0.14);
      x.fillStyle = '#FFF'; x.font = '800 ' + (w * 0.075) + 'px -apple-system, Helvetica, Arial'; x.fillText('WOD · THU 10/08', w * 0.06, h * 0.19);
      x.font = '600 ' + (w * 0.058) + 'px -apple-system, Helvetica, Arial';
      this.d.wod.forEach((e, i) => { x.fillText(e.lift.toUpperCase(), w * 0.06, h * (0.34 + i * 0.13)); x.fillStyle = '#BBB'; x.fillText(e.sets + ' × ' + e.reps + ' @ ' + e.pct + '%', w * 0.06, h * (0.39 + i * 0.13)); x.fillStyle = '#FFF'; });
      x.fillStyle = '#888'; x.font = (w * 0.045) + 'px -apple-system, Helvetica, Arial'; x.fillText('♡ 24   💬 3', w * 0.06, h * 0.93);
    }
  }
  photoPicker(kind, onPick, onCancel) { return this.sys(() => this.photoPicker0(kind, onPick, onCancel)); }
  photoPicker0(kind, onPick, onCancel) {
    let picked = false;
    const { S, body } = this.sheet({ detent: 'large', title: 'Photos', left: 'Cancel', onLeft: onCancel, right: 'Add', onRight: () => { if (picked) onPick(); } });
    const addBtn = S.querySelectorAll('button')[1]; addBtn.style.opacity = '0.35';
    body.style.padding = '0 0 30px';
    const sw = this.segmented([['p', 'Photos'], ['c', 'Collections']], 'p', () => {}, body); sw.style.margin = '4px 16px 10px';
    this.h('div', { fontSize: '13px', color: 'rgba(60,60,67,0.6)', padding: '0 16px 6px' }, body, 'Recent');
    const grid = this.h('div', { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '2px' }, body);
    const tones = [['#C9B8A0', '#7A6650'], ['#9DB7C9', '#2F4A5C'], ['#E0C27A', '#8A5A20'], ['#B7C9A0', '#3E5A30'], ['#D6A0A0', '#6A2A2A'], ['#A0A6D6', '#2A306A'], ['#CCC', '#555'], ['#E8C9A8', '#8A4A20'], ['#A8D6E0', '#20606A'], ['#D0B0E0', '#50306A'], ['#E0E0A0', '#6A6A20']];
    for (let i = 0; i < 12; i++) {
      const t = this.h('button', { position: 'relative', aspectRatio: '1 / 1', border: 0, padding: 0, background: '#DDD', cursor: 'pointer', overflow: 'hidden' }, grid);
      if (i === 0) {
        const c = document.createElement('canvas'); c.width = 240; c.height = 520; Object.assign(c.style, { width: '100%', height: '100%', objectFit: 'cover', objectPosition: 'top', display: 'block' }); t.appendChild(c);
        this.drawShot(c.getContext('2d'), 240, 520, kind);
        this.h('span', { position: 'absolute', left: '4px', bottom: '4px', padding: '1px 5px', borderRadius: '5px', background: 'rgba(0,0,0,0.55)', color: '#FFF', fontSize: '10px', fontWeight: 600 }, t, 'Screenshot');
        t.setAttribute('aria-label', 'Screenshot from today');
        const ck = this.h('span', { position: 'absolute', right: '5px', bottom: '5px', width: '22px', height: '22px', borderRadius: '11px', border: '1.5px solid #FFF', background: 'rgba(0,0,0,0.15)', color: '#FFF', fontSize: '13px', fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', boxSizing: 'border-box' }, t);
        t.onclick = () => { picked = !picked; ck.style.background = picked ? '#007AFF' : 'rgba(0,0,0,0.15)'; ck.textContent = picked ? '✓' : ''; t.style.outline = picked ? '3px solid #007AFF' : 'none'; t.style.outlineOffset = '-3px'; addBtn.style.opacity = picked ? '1' : '0.35'; this.buzz('selection'); };
      } else {
        const tn = tones[(i - 1) % tones.length]; t.style.background = 'linear-gradient(' + (40 + i * 23) + 'deg,' + tn[0] + ',' + tn[1] + ')'; t.disabled = true; t.style.cursor = 'default'; t.setAttribute('aria-hidden', 'true');
      }
    }
  }
  reading(text, then) {
    // a solid white screen with only the spinning plate; the text is for VoiceOver
    const o = this.h('div', { position: 'absolute', inset: 0, zIndex: 35, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,0.8)' }, this.ui);
    o.setAttribute('role', 'status'); o.setAttribute('aria-label', text);
    const card = this.h('div', { display: 'flex', alignItems: 'center', justifyContent: 'center' }, o);
    // the loader: a spinning plate drawn like the UI Animation Lab's (toon, duotone, posterized, sketched outline); a plain spinner until the 3D is up
    if (!this.spinPlate(card)) {
      const sp = this.h('div', { width: '28px', height: '28px', borderRadius: '14px', background: 'conic-gradient(var(--c-accent), transparent)', mask: 'radial-gradient(circle, transparent 9px, #000 10px)', WebkitMask: 'radial-gradient(circle, transparent 9px, #000 10px)' }, card);
      sp.animate([{ transform: 'rotate(0deg)' }, { transform: 'rotate(360deg)' }], { duration: 800, iterations: Infinity });
    }
    setTimeout(() => { if (this.dead) return; o.remove(); this.buzz('success'); then(); }, 3000);
  }
  spinPlate(parent) {
    const T = this.THREE; if (!T || !this.renderer) return false;
    if (this.spin && this.spin.unit !== this.d.unit) { this.spin.r.dispose(); this.spin = null; }
    const S = 168;
    if (!this.spin) {
      const cv = document.createElement('canvas');
      const r = new T.WebGLRenderer({ canvas: cv, antialias: true, alpha: true });
      r.setPixelRatio(Math.min(2, window.devicePixelRatio || 1)); r.setSize(S, S, false); r.outputColorSpace = T.SRGBColorSpace; r.setClearColor(0x000000, 0);
      const sc = new T.Scene(), cam = new T.PerspectiveCamera(30, 1, 0.05, 10); cam.position.set(0, 0, 1.12); cam.lookAt(0, 0, 0);
      const hemi = new T.HemisphereLight('#FFFFFF', '#FFFFFF', 2.7), sun = new T.DirectionalLight('#FFFFFF', 1.5); sun.position.set(0.5, 0.87, 0.8);
      sc.add(hemi, sun);
      // a 25 (kg) or 55 (lb) bumper, re-dressed in toon materials so the light falls in bands
      const spec = this.specs()[0], src = this.plate(spec), grad = new T.DataTexture(new Uint8Array([90, 90, 90, 255, 175, 175, 175, 255, 255, 255, 255, 255]), 3, 1);
      grad.needsUpdate = true; grad.minFilter = grad.magFilter = T.NearestFilter;
      const g = new T.Group();
      src.children.forEach((m) => { const mm = m.material; g.add(new T.Mesh(m.geometry, new T.MeshToonMaterial({ map: mm.map || null, color: mm.map ? '#FFFFFF' : mm.color, gradientMap: grad }))); });
      g.rotation.x = Math.PI / 2;
      const pivot = new T.Group(); pivot.add(g); sc.add(pivot);
      Object.assign(cv.style, { width: S + 'px', height: S + 'px', display: 'block' });
      this.spin = { cv, r, sc, cam, pivot, g, unit: this.d.unit };
    }
    const P = this.spin;
    this.plateFx();
    P.cv.style.filter = 'none';
    parent.appendChild(P.cv);
    const t0 = performance.now();
    const loop = (now) => {
      if (this.dead || !P.cv.isConnected) return;
      const t = (now - t0) / 1000;
      P.pivot.rotation.y = t * 5.2;                                    // the coin spin
      P.g.rotation.x = Math.PI / 2 + 0.38 + Math.sin(t * 2.6) * 0.1;    // tipped toward you, wobbling a little
      GLFX.draw(P.r, P.sc, P.cam, { contrast: 0.71, bright: 0.68, posterize: 2, duotone: true, dk: this.pal.boxDark, lt: this.pal.boxLight, sketch: true, skCol: this.pal.boxDark, skWidth: 2.5, skRough: 6, skScale: 0.03, skGrain: 0.45, skDouble: true, skWarp: 0.35 });
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
    return true;
  }
  plateFx() {
    const key = this.pal.boxDark + this.pal.boxLight;
    if (this.plateFxKey === key && document.getElementById('cu-plate-fx')) return;
    this.plateFxKey = key;
    let svg = this.plateFxSvg;
    if (!svg || !svg.isConnected) {
      svg = this.plateFxSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('width', '0'); svg.setAttribute('height', '0'); svg.setAttribute('aria-hidden', 'true');
      Object.assign(svg.style, { position: 'absolute', width: 0, height: 0 });
      this.phone.appendChild(svg);
    }
    const hex = (h) => { const c = parseInt(h.slice(1), 16); return [(c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255].map((v) => v.toFixed(3)); };
    const dk = hex(this.pal.boxDark), lt = hex(this.pal.boxLight), rgb = 'rgb(' + dk.map((v) => Math.round(v * 255)).join(',') + ')';
    const g = 0.45, A = (4 * g).toFixed(2), B = (1 - 2.2 * g).toFixed(2), r = 6, w = 2.5;
    const stroke = (noise, n, wd) => '<feMorphology in="SourceAlpha" operator="dilate" radius="' + wd + '" result="' + n + 'd"/><feComposite in="' + n + 'd" in2="SourceAlpha" operator="out" result="' + n + 'r"/>'
      + '<feDisplacementMap in="' + n + 'r" in2="' + noise + '" scale="' + r + '" xChannelSelector="R" yChannelSelector="G" result="' + n + 'w"/><feComposite in="' + n + 'w" in2="grain" operator="in" result="' + n + 'g"/>'
      + '<feFlood flood-color="' + rgb + '" result="' + n + 'c"/><feComposite in="' + n + 'c" in2="' + n + 'g" operator="in" result="' + n + '"/>';
    svg.innerHTML = '<filter id="cu-plate-fx" x="-15%" y="-15%" width="130%" height="130%" color-interpolation-filters="sRGB">'
      + '<feColorMatrix type="matrix" values="0.299 0.587 0.114 0 0  0.299 0.587 0.114 0 0  0.299 0.587 0.114 0 0  0 0 0 1 0"/>'
      + '<feComponentTransfer><feFuncR type="discrete" tableValues="0 1"/><feFuncG type="discrete" tableValues="0 1"/><feFuncB type="discrete" tableValues="0 1"/></feComponentTransfer>'
      + '<feComponentTransfer result="base"><feFuncR type="table" tableValues="' + dk[0] + ' ' + lt[0] + '"/><feFuncG type="table" tableValues="' + dk[1] + ' ' + lt[1] + '"/><feFuncB type="table" tableValues="' + dk[2] + ' ' + lt[2] + '"/></feComponentTransfer>'
      + '<feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="2" seed="3" result="n1"/><feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="2" seed="11" result="n2"/>'
      + '<feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="1" seed="5" result="gr"/><feColorMatrix in="gr" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  ' + A + ' 0 0 0 ' + B + '" result="grain"/>'
      + '<feDisplacementMap in="base" in2="n1" scale="' + (r * 0.35).toFixed(2) + '" xChannelSelector="R" yChannelSelector="G" result="fill"/>'
      + stroke('n1', 'l1', w) + stroke('n2', 'l2', (w * 0.7).toFixed(2))
      + '<feMerge><feMergeNode in="fill"/><feMergeNode in="l1"/><feMergeNode in="l2"/></feMerge></filter>';
  }
  scanner(o) { return this.sys(() => this.scanner0(o)); }
  scanner0(o) {
    this.statusBar.style.color = '#FFF';
    const C = this.h('div', { position: 'absolute', inset: 0, background: '#000', zIndex: 15, display: 'flex', flexDirection: 'column' }, this.ui);
    C.setAttribute('aria-label', 'Camera: ' + o.title);
    const view = this.h('div', { position: 'relative', flex: 1, overflow: 'hidden', margin: '100px 0 0' }, C);
    const ph = document.createElement('canvas'); ph.width = 780; ph.height = 1000; Object.assign(ph.style, { position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }); view.appendChild(ph);
    const n = o.draw(ph.getContext('2d'));
    for (let i = 0; i < n.count; i++) this.h('div', { position: 'absolute', left: '6%', top: (n.top + i * n.gap) + '%', width: (n.widths[i] || 70) + '%', height: n.h + '%', borderRadius: '6px', background: 'rgba(255,214,10,0.22)', boxShadow: '0 0 0 2px rgba(255,214,10,0.9)', animation: 'is-pulse 1.6s infinite' }, view);
    ['12%', '88%'].forEach((l) => ['14%', '80%'].forEach((tp) => this.h('div', { position: 'absolute', left: l, top: tp, width: '26px', height: '26px', marginLeft: '-13px', borderColor: '#FFD60A', borderStyle: 'solid', borderWidth: (tp === '14%' ? '4px 0 0 0' : '0 0 4px 0') }, view)));
    this.h('div', { position: 'absolute', left: '50%', top: '86%', transform: 'translateX(-50%)', padding: '6px 12px', borderRadius: '14px', background: 'rgba(0,0,0,0.55)', color: '#FFF', fontSize: '15px', fontWeight: 600, whiteSpace: 'nowrap' }, view, 'Text found · tap the shutter');
    const top = this.h('div', { position: 'absolute', left: 0, right: 0, top: '56px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 16px', color: '#FFF' }, C);
    const close = () => { C.remove(); this.statusBar.style.color = '#000'; };
    const cancel = this.h('button', { border: 0, background: 'none', color: '#FFF', fontSize: '17px', cursor: 'pointer' }, top, 'Cancel'); cancel.className = 'tap'; cancel.onclick = () => { close(); o.onCancel(); };
    this.h('span', { fontSize: '15px', fontWeight: 600 }, top, o.title);
    this.h('span', { width: '50px' }, top);
    const bot = this.h('div', { flex: 'none', height: '150px', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 32px 20px' }, C);
    const sh = this.h('button', { width: '74px', height: '74px', borderRadius: '37px', border: '5px solid #FFF', background: '#FFF', backgroundClip: 'content-box', padding: '4px', cursor: 'pointer' }, bot); sh.setAttribute('aria-label', 'Scan'); sh.className = 'tap';
    sh.onclick = () => {
      const f = this.h('div', { position: 'absolute', inset: 0, background: '#FFF', opacity: 0.9, transition: 'opacity .35s', zIndex: 16 }, this.ui);
      this.buzz('medium');
      setTimeout(() => { f.style.opacity = '0'; C.style.transition = 'opacity .4s'; C.style.opacity = '0'; this.statusBar.style.color = '#000'; }, 60);
      setTimeout(() => { f.remove(); C.remove(); o.onCapture(); }, 450);
    };
  }
  closeSheet() { const S = this.sheetEl; if (!S) return; S.style.transform = 'translateY(100%)'; setTimeout(() => S.remove(), 450); this.sheetEl = null; this.viewGoal = 0; }

  // ---------------- the 3D gym (from the Onboarding board) ----------------
  syncArt() {
    const st = this.state, THREE = this.THREE;
    const key = st.boxLight + st.boxDark;
    if (this.flagArt && st.flagFont !== this.flagFontKey) {
      // wait for the web font before drawing, so the canvas never bakes in the fallback
      this.flagFontKey = st.flagFont;
      const f = this.FLAG_FONTS.find((q) => q.id === st.flagFont) || this.FLAG_FONTS[0], want = st.flagFont;
      const done = () => { if (!this.dead && this.state.flagFont === want) this.drawFlag(f); };
      if (document.fonts && document.fonts.load) document.fonts.load(f.weight + ' 100px ' + f.css, this.FLAG_TEXT).then(done, done); else done();
    }
    if (key !== this.artKey) {
      this.artKey = key;
      this.mats['#FFFFFF'].color.set(st.boxLight);
      this.mats['#111111'].color.set(st.boxDark);
      (this.extraDark || []).forEach((m) => m.color.set(st.boxDark));
      if (this.flagMat) this.flagMat.emissive.set(st.boxDark);
      this.inkMat.color.set(st.boxDark);
      this.puffs.forEach((pf) => { pf.m.material.color.set(st.boxLight); pf.ink.material.color.set(st.boxDark); });
      // boards drawn on canvas: map their black..white pixels onto dark..light
      // canvas pixels are sRGB, so take the picked colours as plain sRGB bytes (THREE.Color would give linear values)
      const rgb = (hx) => { const n = parseInt(hx.slice(1), 16); return { r: (n >> 16) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255 }; };
      const L = rgb(st.boxLight), D = rgb(st.boxDark);
      (this.recolor || []).forEach((r) => {
        const out = r.ctx.createImageData(r.w, r.h), a = r.orig.data, o = out.data;
        for (let i = 0; i < a.length; i += 4) {
          const t = a[i] / 255;
          o[i] = (D.r + (L.r - D.r) * t) * 255; o[i + 1] = (D.g + (L.g - D.g) * t) * 255; o[i + 2] = (D.b + (L.b - D.b) * t) * 255; o[i + 3] = 255;
        }
        r.ctx.putImageData(out, 0, 0); r.tex.needsUpdate = true;
      });
    }
    const mkey = st.media ? st.media.url : '';
    if (mkey !== this.mediaKey) {
      this.mediaKey = mkey;
      if (this.bgEl) { this.bgEl.remove(); this.bgEl = null; }
      if (st.media) {
        const el = document.createElement(st.media.kind === 'video' ? 'video' : 'img');
        el.src = st.media.url; el.setAttribute('aria-hidden', 'true');
        if (st.media.kind === 'video') { el.muted = true; el.loop = true; el.autoplay = true; el.playsInline = true; el.play && el.play().catch(() => {}); }
        el.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;object-fit:cover;pointer-events:none';
        this.stageEl.insertBefore(el, this.stageEl.firstChild);
        this.bgEl = el;
      }
    }
    const sky = !st.media && st.bgMode === 'sky';
    this.sky = sky;
    if (this.skyG) {
      this.skyG.visible = sky;
      this.cloudCasters.forEach((c) => { c.castShadow = sky; });
      this.scene.fog = sky ? this.skyFog : null;
      if (st.cloudReal !== this.cloudKey) {
        this.cloudKey = st.cloudReal;
        const r = st.cloudReal, e = r * r * (3 - 2 * r);
        // faceted clouds fade out as the soft, shaded puffs fade in (the shadow clouds overhead are unaffected)
        this.cloudMat.opacity = 1 - e; this.cloudMat.transparent = e > 0.001; this.cloudMat.depthWrite = e < 0.5;
        this.cloudMat.needsUpdate = true;
        this.cloudMeshes.forEach((m) => { m.visible = e < 0.995; });
        this.puffMats.forEach((m) => { m.opacity = e; });
        this.cloudSprites.forEach((sp) => { sp.visible = e > 0.005; });
      }
    }
    if (st.media) { if (this.scene.background) this.scene.background = null; }
    else {
      if (!this.scene.background) this.scene.background = new THREE.Color();
      this.scene.background.set(sky ? '#CFE6F5' : st.bgColor);
    }
  }
  buildSky() {
    const T = this.THREE;
    const g = new T.Group(); this.scene.add(g); this.skyG = g;
    // gradient dome that follows the camera (so it is always "infinitely" far away)
    const dome = new T.Mesh(new T.SphereGeometry(220, 32, 16), new T.ShaderMaterial({
      side: T.BackSide, depthWrite: false, fog: false,
      uniforms: { top: { value: new T.Color('#4E9BE6') }, mid: { value: new T.Color('#A9D3F2') }, low: { value: new T.Color('#E4F2FB') } },
      vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: 'uniform vec3 top; uniform vec3 mid; uniform vec3 low; varying vec3 vP; void main(){ float h = vP.y; vec3 c = h > 0.0 ? mix(mid, top, pow(clamp(h,0.0,1.0),0.7)) : mix(mid, low, clamp(-h*2.2,0.0,1.0)); gl_FragColor = vec4(c,1.0); }'
    }));
    dome.renderOrder = -10; dome.frustumCulled = false; g.add(dome); this.skyDome = dome;
    this.skyFog = new T.Fog('#CFE6F5', 45, 170);
    // seeded random so the cloudscape is the same on every load
    let seed = 7; const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
    const mat = new T.MeshLambertMaterial({ color: '#E6EFF6', flatShading: true }); this.cloudMat = mat;
    const geo = new T.IcosahedronGeometry(1, 1);
    this.cloudMeshes = []; this.cloudSprites = [];
    let seed2 = 99; const rn2 = () => { seed2 = (seed2 * 16807) % 2147483647; return (seed2 - 1) / 2147483646; };
    // soft puff textures for the realistic look: overlapping radial blobs, lit from above, grey-blue underneath
    const puffTex = (k) => {
      const cv = document.createElement('canvas'); cv.width = cv.height = 256;
      const x = cv.getContext('2d');
      for (let i = 0; i < 22; i++) {
        const a = rn2() * Math.PI * 2, d = rn2() * 52, cx = 128 + Math.cos(a) * d, cy = 136 + Math.sin(a) * d * 0.7, r = 30 + rn2() * 44;
        const gr = x.createRadialGradient(cx, cy, 0, cx, cy, r);
        gr.addColorStop(0, 'rgba(255,255,255,0.8)'); gr.addColorStop(0.55, 'rgba(255,255,255,0.5)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
        x.fillStyle = gr; x.beginPath(); x.arc(cx, cy, r, 0, Math.PI * 2); x.fill();
      }
      x.globalCompositeOperation = 'source-atop';
      const sh = x.createLinearGradient(0, 70, 0, 236);
      sh.addColorStop(0, 'rgba(255,255,255,0)'); sh.addColorStop(0.55, 'rgba(200,215,232,0.25)'); sh.addColorStop(1, 'rgba(118,140,170,0.7)');
      x.fillStyle = sh; x.fillRect(0, 0, 256, 256);
      const tx = new T.CanvasTexture(cv); tx.colorSpace = T.SRGBColorSpace;
      return new T.SpriteMaterial({ map: tx, transparent: true, depthWrite: false, opacity: 0, fog: true });
    };
    this.puffMats = [0, 1, 2, 3].map(puffTex);
    const makeCloud = (size) => {
      const c = new T.Group(), n = 5 + Math.floor(rnd() * 6), len = size * (1.6 + rnd());
      for (let i = 0; i < n; i++) {
        const u = n === 1 ? 0 : i / (n - 1) - 0.5, mid = 1 - Math.abs(u) * 1.3;
        const r = size * (0.45 + 0.5 * mid + rnd() * 0.25);
        const m = new T.Mesh(geo, mat);
        m.position.set(u * len + (rnd() - 0.5) * size * 0.3, r * 0.35 + rnd() * size * 0.2, (rnd() - 0.5) * size * 0.7);
        m.scale.set(r * (1.1 + rnd() * 0.3), r * (0.75 + rnd() * 0.2), r);
        m.rotation.set(rnd() * 3, rnd() * 3, rnd() * 3);
        c.add(m); this.cloudMeshes.push(m);
        for (let j = 0; j < 3; j++) {
          const sp = new T.Sprite(this.puffMats[Math.floor(rn2() * this.puffMats.length)]);
          const k = r * (2.0 + rn2() * 1.0);
          sp.position.set(m.position.x + (rn2() - 0.5) * r * 0.8, m.position.y + (rn2() - 0.3) * r * 0.5, m.position.z + (rn2() - 0.5) * r * 0.8);
          sp.scale.set(k * 1.25, k, 1);
          sp.visible = false;
          c.add(sp); this.cloudSprites.push(sp);
        }
      }
      return c;
    };
    // the cloud field sits in a ring well beyond the camera, mostly below and around the box, so clouds only ever pass behind it
    this.clouds = new T.Group(); g.add(this.clouds);
    for (let i = 0; i < 30; i++) {
      const a = rnd() * Math.PI * 2, R = 48 + rnd() * 75, y = -36 + rnd() * 34;
      const cl = makeCloud(2.2 + rnd() * 4.5);
      cl.position.set(Math.cos(a) * R, y, Math.sin(a) * R);
      cl.rotation.y = rnd() * Math.PI;
      cl.userData = { y, ph: rnd() * 6.28 };
      this.clouds.add(cl);
    }
    // invisible clouds high overhead: they only cast drifting shadows over the box
    const ghost = new T.MeshBasicMaterial({ colorWrite: false, depthWrite: false });
    this.cloudCasters = [];
    this.casters = [];
    for (let i = 0; i < 5; i++) {
      const c = new T.Group();
      const n = 3 + Math.floor(rnd() * 3), sz = 1.8 + rnd() * 1.8;
      for (let k = 0; k < n; k++) {
        const m = new T.Mesh(geo, ghost);
        m.position.set((k - n / 2) * sz * 0.9 + (rnd() - 0.5) * sz, 0, (rnd() - 0.5) * sz * 1.2);
        m.scale.set(sz * (0.9 + rnd() * 0.6), 0.4, sz * (0.8 + rnd() * 0.5));
        m.castShadow = true; m.receiveShadow = false;
        c.add(m); this.cloudCasters.push(m);
      }
      c.position.set(-16 + i * 7.5 + rnd() * 3, 15 + rnd() * 2, -8 + rnd() * 16);
      g.add(c); this.casters.push(c);
    }
  }
  updateSky(dt, t) {
    if (!this.skyG || !this.sky) return;
    this.skyDome.position.copy(this.camera.position);
    this.clouds.rotation.y += dt * 0.012;                       // the whole cloudscape drifts slowly around
    this.clouds.children.forEach((c) => { c.position.y = c.userData.y + Math.sin(t * 0.15 + c.userData.ph) * 0.6; });
    // shadow clouds drift across with the wind and wrap around
    this.casters.forEach((c) => {
      c.position.x += dt * 1.1; c.position.z += dt * 0.35;
      if (c.position.x > 18) { c.position.x -= 36; }
      if (c.position.z > 14) { c.position.z -= 28; }
    });
  }
  registerCanvas(cv, tex) {
    const ctx = cv.getContext('2d');
    const r = { ctx, tex, w: cv.width, h: cv.height, orig: ctx.getImageData(0, 0, cv.width, cv.height) };
    (this.recolor = this.recolor || []).push(r);
    return r;
  }
  boot() {
    let tries = 0;
    const go = () => {
      if (this.dead) return;
      if (!window.PlateKit) { if (tries++ < 200) setTimeout(go, 50); return; }
      const fonts = (document.fonts && document.fonts.load)
        ? Promise.all([document.fonts.load('700 80px Helvetica')]).catch(() => null)
        : Promise.resolve();
      Promise.race([fonts, new Promise((r) => setTimeout(r, 1500))]).then(() => { if (!this.dead) this.initScene(); });
    };
    go();
  }
  m(hex) {
    this.mats = this.mats || {};
    if (!this.mats[hex]) this.mats[hex] = new this.THREE.MeshLambertMaterial({ color: hex, flatShading: true });
    return this.mats[hex];
  }
  put(geo, hex, x, y, z, parent, opts) {
    const T = this.THREE, o = opts || {};
    const mesh = new T.Mesh(geo, this.m(hex));
    mesh.position.set(x, y, z);
    if (o.rx) mesh.rotation.x = o.rx; if (o.ry) mesh.rotation.y = o.ry; if (o.rz) mesh.rotation.z = o.rz;
    mesh.castShadow = o.cast !== false; mesh.receiveShadow = true;
    if (o.ink !== false) {
      const e = new T.LineSegments(new T.EdgesGeometry(geo, 28), this.inkMat);
      mesh.add(e); this.inkLines.push(e);
    }
    (parent || this.root).add(mesh);
    return mesh;
  }
  box(w, h, d, hex, x, y, z, parent, opts) { return this.put(new this.THREE.BoxGeometry(w, h, d), hex, x, y, z, parent, opts); }
  cyl(r1, r2, h, segs, hex, x, y, z, parent, opts) { return this.put(new this.THREE.CylinderGeometry(r1, r2, h, segs, 1), hex, x, y, z, parent, opts); }
  initScene() {
    const { THREE, OrbitControls, RoomEnvironment } = window.PlateKit;
    this.THREE = THREE;
    const el = this.stageEl, canvas = el.querySelector('canvas');
    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    renderer.setClearColor(0x000000, 0);
    canvas.style.position = 'relative';
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.NoToneMapping;          // keep white white
    this.renderer = renderer;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#FFFFFF');
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;   // only the plates' chrome uses it
    scene.environmentIntensity = 0.45;
    this.scene = scene;
    this.popG = new THREE.Group(); scene.add(this.popG);   // scales the whole box in when it first appears
    this.root = new THREE.Group(); this.popG.add(this.root);   // the whole box: floats as one piece when closed
    this.inkMat = new THREE.LineBasicMaterial({ color: '#000000' });
    this.inkLines = [];

    const camera = new THREE.PerspectiveCamera(50, 1, 0.05, 300);
    camera.position.set(7.4, 6.6, 8.4);
    this.camera = camera;
    const controls = new OrbitControls(camera, canvas);
    controls.target.set(0, 0.5, 0);
    controls.enableDamping = true; controls.dampingFactor = 0.08;
    controls.maxPolarAngle = Math.PI * 0.49; controls.minDistance = 1.2; controls.maxDistance = 90;
    controls.autoRotateSpeed = 0.6;
    controls.addEventListener('start', () => { this.fly = null; if (!this.state.closed && this.state.view !== 'free') this.setState({ view: 'free' }); });
    this.controls = controls;

    // bright, even light so white reads as white; shadows carry the form
    this.hemi = new THREE.HemisphereLight('#FFFFFF', '#FFFFFF', 2.7);
    scene.add(this.hemi);
    const sun = new THREE.DirectionalLight('#FFFFFF', 1.5);
    sun.position.set(-8, 20, 12);
    sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
    const sc = sun.shadow.camera; sc.left = -11; sc.right = 11; sc.top = 11; sc.bottom = -11; sc.near = 1; sc.far = 70;
    sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.02;
    scene.add(sun); scene.add(sun.target);
    this.sun = sun;
    // soft shadow on the white void beneath the floating cube
    this.voidShadow = new THREE.Mesh(new THREE.PlaneGeometry(60, 60).rotateX(-Math.PI / 2), new THREE.ShadowMaterial({ opacity: 0, transparent: true }));
    this.voidShadow.position.y = -3.2; this.voidShadow.receiveShadow = true;
    scene.add(this.voidShadow);

    this.buildSky();
    this.buildRoom();
    this.buildPlatform();
    this.buildBoardAndBench();
    this.buildPRWall();
    this.buildCalendar();   // only the clipboard is hung now: wall 1 carries the window and the wall bars
    this.buildFlag();
    this.buildPlatePiles('kg');
    this.buildGhosts();
    this.buildBarsAndChalk();
    // chalk bucket and the notebook on the bench are out of the scene for now
    this.chalkG.parent.remove(this.chalkG); this.notebookG.parent.remove(this.notebookG);
    // no rack for now
    this.rackG.visible = false;
    // the platform hides upside down under the hatch: one panel that flips over
    this.flipG = new THREE.Group(); this.root.add(this.flipG);
    this.flipG.add(this.hatch);
    this.flipG.add(this.platG); this.platG.rotation.x = Math.PI; this.platG.position.y = -0.02;
    this.flipG.rotation.x = Math.PI; this.flipG.position.y = -0.02;
    this.flipG.traverse((o) => { if (o.isMesh) o.castShadow = false; });   // flat panel: no self-shadow speckle while it spins
    // the bar holder rides up with the back wall
    this.barsG.parent.remove(this.barsG);   // no wall bars for now
    this.applyLayout();

    const resize = () => {
      const w = Math.max(1, el.clientWidth), h = Math.max(1, el.clientHeight);
      renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
    };
    resize();
    this.ro = new ResizeObserver(resize); this.ro.observe(el);

    this.boxP = 0;      // 0 = open diorama, 1 = closed floating cube
    this.sqA = 0; this.sqT = 9; this.shake = 0;
    // low-poly white dust puffs for the box impacts
    this.puffs = [];
    for (let i = 0; i < 90; i++) {
      const m = new THREE.Mesh(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshLambertMaterial({ color: '#FFFFFF', flatShading: true, transparent: true, opacity: 0 }));
      // ink edges so white dust still reads against the white void
      const ink = new THREE.LineSegments(new THREE.EdgesGeometry(m.geometry), new THREE.LineBasicMaterial({ color: '#000000', transparent: true, opacity: 0 }));
      m.add(ink);
      m.visible = false; this.root.add(m);
      this.puffs.push({ m, ink, v: new THREE.Vector3(), life: 0, max: 1, s: 0.1 });
    }
    this.spinY = 0;
    let last = performance.now();
    const loop = (now) => {
      if (this.dead) return;
      this.raf = requestAnimationFrame(loop);
      const dt = Math.min((now - last) / 1000, 1 / 20); last = now;
      this.frame(dt, now / 1000);
    };
    this.raf = requestAnimationFrame(loop);
    this.initDust();
    this.startOnboarding();
  }
  initDust() {
    const T = this.THREE, N = 240;
    this.DS = { count: 0.45, size: [0.05, 0.11], life: [0.9, 1.7],
      color: '#E9E2D6', amount: 0.05, sizeMul: 0.2, linger: 0.24, spread: 0.05, rise: 0.94 };
    const mesh = new T.InstancedMesh(new T.IcosahedronGeometry(1, 0), new T.MeshStandardMaterial({ color: '#FFFFFF', flatShading: true, roughness: 0.85, metalness: 0 }), N);
    mesh.instanceMatrix.setUsage(T.DynamicDrawUsage); mesh.frustumCulled = false; mesh.castShadow = true;
    const zero = new T.Matrix4().makeScale(0, 0, 0), white = new T.Color('#FFFFFF');
    for (let i = 0; i < N; i++) { mesh.setMatrixAt(i, zero); mesh.setColorAt(i, white); }
    this.root.add(mesh);
    this.dMesh = mesh; this.dN = N; this.dHead = 0;
    this.dPos = new Float32Array(N * 3); this.dVel = new Float32Array(N * 3); this.dRot = new Float32Array(N * 3); this.dSpin = new Float32Array(N * 3);
    this.dLife = new Float32Array(N); this.dMax = new Float32Array(N); this.dS0 = new Float32Array(N);
    this.dDummy = new T.Object3D(); this.dCol = new T.Color();
  }
  emitDust(x, z, count, speed, ringR, sm) {
    const D = this.DS, N = this.dN, C = this.dCol;
    const raw = count * D.count * D.amount, n = Math.min(120, Math.floor(raw) + (Math.random() < raw % 1 ? 1 : 0));
    const rnd = (r) => r[0] + Math.random() * (r[1] - r[0]);
    for (let k = 0; k < n; k++) {
      const i = this.dHead; this.dHead = (this.dHead + 1) % N;
      const a = Math.random() * Math.PI * 2, rr = ringR * (0.8 + Math.random() * 0.3), j = i * 3;
      this.dPos[j] = x + Math.cos(a) * rr; this.dPos[j + 1] = 0.04 + Math.random() * 0.04; this.dPos[j + 2] = z + Math.sin(a) * rr;
      const sp = speed * D.spread * (0.3 + Math.random() * 0.8);
      this.dVel[j] = Math.cos(a) * sp; this.dVel[j + 1] = (0.2 + Math.random() * 0.6) * speed * 0.5 * D.rise; this.dVel[j + 2] = Math.sin(a) * sp;
      for (let q = 0; q < 3; q++) { this.dRot[j + q] = Math.random() * 6.28; this.dSpin[j + q] = (Math.random() - 0.5) * 1.6; }
      this.dLife[i] = 0; this.dMax[i] = rnd(D.life) * D.linger;
      this.dS0[i] = (rnd(D.size) + speed * 0.012) * D.sizeMul * (sm || 1);
      C.set(D.color).offsetHSL(0, 0, (Math.random() - 0.5) * 0.06);
      this.dMesh.setColorAt(i, C);
    }
    this.dMesh.instanceColor.needsUpdate = true;
  }
  updateDust(dt) {
    if (!this.dMesh) return;
    const D = this.DS, N = this.dN, M = this.dDummy, drag = Math.exp(-3.0 * dt);
    let wrote = false;
    for (let i = 0; i < N; i++) {
      if (this.dMax[i] === 0) continue;
      const j = i * 3;
      if (this.dMax[i] > 0) this.dLife[i] += dt;
      if (this.dMax[i] < 0 || this.dLife[i] >= this.dMax[i]) {
        M.position.set(0, -50, 0); M.scale.setScalar(0); M.updateMatrix(); this.dMesh.setMatrixAt(i, M.matrix);
        this.dMax[i] = 0; wrote = true; continue;
      }
      this.dVel[j] *= drag; this.dVel[j + 2] *= drag;
      this.dVel[j + 1] = this.dVel[j + 1] * drag + 0.18 * D.rise * dt;
      for (let q = 0; q < 3; q++) { this.dPos[j + q] += this.dVel[j + q] * dt; this.dRot[j + q] += this.dSpin[j + q] * dt; }
      const floorY = this.dS0[i] * 0.6;
      if (this.dPos[j + 1] < floorY) { this.dPos[j + 1] = floorY; if (this.dVel[j + 1] < 0) this.dVel[j + 1] = 0; }
      const t = this.dLife[i] / this.dMax[i];
      const pop = t < 0.22 ? 1 - Math.pow(1 - t / 0.22, 3) : 1;
      const shrink = t > 0.45 ? Math.max(0, 1 - (t - 0.45) / 0.55) : 1;
      const sc = this.dS0[i] * (0.35 + 1.0 * pop + 0.7 * t) * shrink;
      M.position.set(this.dPos[j], this.dPos[j + 1], this.dPos[j + 2]);
      M.rotation.set(this.dRot[j], this.dRot[j + 1], this.dRot[j + 2]);
      M.scale.setScalar(sc); M.updateMatrix();
      this.dMesh.setMatrixAt(i, M.matrix); wrote = true;
    }
    if (wrote) this.dMesh.instanceMatrix.needsUpdate = true;
  }
  shot(T, dir, d) { const v = new this.THREE.Vector3(dir[0], dir[1], dir[2]).normalize().multiplyScalar(d); return { T, P: [T[0] + v.x, T[1] + v.y, T[2] + v.z] }; }
  setClip(on) {
    this.renderer.localClippingEnabled = true;
    const plane = on ? [new this.THREE.Plane(new this.THREE.Vector3(0, 1, 0), 0.3)] : null;
    this.root.traverse((o) => { if (o.material) [].concat(o.material).forEach((m) => { m.clippingPlanes = plane; m.needsUpdate = true; }); });
  }
  buildShell() {
    const R = this.ROOM, C = this.CUBE, bot = -0.3, top = C + 0.15, pad = 0.02;
    this.shell = this.box(R.W + 0.3 + pad * 2, top - bot + pad * 2, R.D + 0.3 + pad * 2, '#FFFFFF', R.cx, (top + bot) / 2, R.cz);
    this.shell.castShadow = true;
  }
  bindTaps() {
    if (this.tapsBound) return; this.tapsBound = true;
    const cv = this.renderer.domElement, T = this.THREE, ray = new T.Raycaster();
    let down = null;
    const ndc = (e) => { const r = cv.getBoundingClientRect(); return new T.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1); };
    const plane = new T.Plane(new T.Vector3(0, 1, 0), 0), hp = new T.Vector3();
    // which kit plate is under the pointer, and where it was touched
    const kitHit = (e) => {
      if (!this.onb || this.onb.phase !== 'kit' || !this.kitItems) return null;
      const live = this.kitItems.filter((it) => it.body); if (!live.length) return null;
      ray.setFromCamera(ndc(e), this.camera);
      const h = ray.intersectObjects(live.map((it) => it.o), true)[0]; if (!h) return null;
      const it = live.find((q) => { let o = h.object; while (o) { if (o === q.o) return true; o = o.parent; } return false; });
      return it ? { it, point: h.point.clone() } : null;
    };
    const aim = (e) => {
      const g = this.grab; if (!g) return;
      ray.setFromCamera(ndc(e), this.camera); plane.constant = -g.planeY;
      if (ray.ray.intersectPlane(plane, hp) && hp.distanceTo(this.camera.position) < 30) {
        const R = this.ROOM, m = 0.35; g.target.set(Math.max(R.x0 + m, Math.min(R.x1 - m, hp.x)), g.planeY, Math.max(R.z0 + m, Math.min(R.z1 - m, hp.z)));
      }
    };
    const release = (e) => {
      const g = this.grab; if (!g) return false;
      this.grab = null; g.body.angularDamping = 0.06;
      try { cv.releasePointerCapture(e.pointerId); } catch (er) {}
      cv.style.cursor = 'pointer';
      return true;
    };
    cv.addEventListener('pointerdown', (e) => {
      down = { x: e.clientX, y: e.clientY, t: performance.now() };
      const h = kitHit(e);
      if (h) {
        const b = h.it.body, C = this.CANNON; b.wakeUp();
        const local = b.pointToLocalFrame(new C.Vec3(h.point.x, h.point.y, h.point.z));
        // picked up: it lifts a little off the floor and follows the finger on that height
        this.grab = { it: h.it, body: b, local, planeY: Math.max(h.point.y, 0.03) + 0.32, target: new T.Vector3(h.point.x, Math.max(h.point.y, 0.03) + 0.32, h.point.z) };
        b.angularDamping = 0.45;
        try { cv.setPointerCapture(e.pointerId); } catch (er) {}
        cv.style.cursor = 'grabbing'; down = null;
      }
    });
    cv.addEventListener('pointermove', (e) => {
      if (this.grab) { aim(e); return; }
      if (e.pointerType === 'mouse' && this.onb && this.onb.phase === 'kit') cv.style.cursor = kitHit(e) ? 'grab' : 'pointer';
    });
    cv.addEventListener('pointercancel', (e) => { release(e); down = null; });
    cv.addEventListener('pointerup', (e) => {
      if (release(e)) { down = null; return; }
      if (!down) return;
      const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y), quick = performance.now() - down.t < 600;
      down = null;
      if (moved > 10 || !quick || !this.onb) return;
      const r = cv.getBoundingClientRect();
      ray.setFromCamera(new T.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), this.camera);
      const O = this.onb;
      if (this.paused) return;
      if (this.fanSwitchHit(ray)) { this.fanOn = !this.fanOn; try { localStorage.setItem('layoutlab-fanon', this.fanOn ? 'on' : 'off'); } catch (er) {} this.buzz('light'); return; }
      if (O.phase === 'idle') this.openBox();   // a tap anywhere opens the box
    });
  }
  startOnboarding() {
    if (!this.root) return;
    if (!this.shell) { this.buildShell(); this.bindTaps(); }
    this.intro = null; this.manualBox = true;
    this.onb = { t: 0, pt: 0, phase: 'idle', fired: {} };
    this.SHOTS = {
      far: this.shot([0, 4.2, 0], [0.6, 0.34, 0.7], 52),
      overview: { T: [0.44, 1.33, -0.89], P: [13.28, 10.8, 14.36], fov: 50 },
      corner: { T: [-4.31, 0.69, -0.22], P: [1.27, 2.01, 3.24], fov: 50 },      // setup: the plate shelf on wall 1
      flag: { T: [2.18, 0.85, -3.15], P: [2.21, 1.67, 2.54], fov: 50 },
      pr: { T: [-3.93, 1.18, -2.72], P: [-0.81, 1.77, -0.02], fov: 50 },        // PR board on wall 1
      board: { T: [-0.93, 1.97, 2.15], P: [-0.65, 2.21, 3.29], fov: 40 },
      kit: { T: [3.35, 0.25, -1.75], P: [1.85, 3.88, 1.0], fov: 50 },        // higher and closer, looking down so the plates read
      setv: { T: [2.38, 1.54, -1.86], P: [3.04, 1.75, -0.89], fov: 50 }
    };
    Object.keys(this.layoutShots || {}).forEach((k) => { this.SHOTS[k] = this.layoutShots[k]; });
    this.setState({ closed: true, showForm: false, showReplay: false });
    this.state.closed = true; this.boxP = 1; this.spinY = 0.45; this.wodAskedPR = false;
    this.popG.scale.setScalar(0.0001); this.popG.visible = false; this.popG.rotation.set(0, 0, 0);
    this.shell.visible = true;
    this.cutLines.forEach((m) => { m.visible = false; });
    this.well.visible = false;
    this.flipG.rotation.x = 0; this.flipG.position.y = 0; this.flipG.scale.set(1, 1, 1);
    this.setClip(false);
    if (this.pileUnit !== 'kg') this.buildPlatePiles('kg');
    this.plateItems.forEach((pi) => { pi.o.visible = false; pi.o.scale.setScalar(1); this.posePlate(pi); });
    this.ghostG.visible = false; this.ghostMat.opacity = 0; this.ghostInk.opacity = 0; this.glowMat.opacity = 0; this.ghostFlagG.visible = false;
    this.prGlowMat.opacity = 0; this.drawPR(null);
    if (this.state.prPhoto) URL.revokeObjectURL(this.state.prPhoto);
    if (this.state.wodPhoto) URL.revokeObjectURL(this.state.wodPhoto);
    clearTimeout(this.prTimer); clearTimeout(this.wodTimer);
    this.setState({ showPR: false, prStep: 'choose', prPhoto: null, prFrom: '', prVals: {}, showWod: false, wodStep: 'choose', wodPhoto: null, wod: null, showPanel: false, tab: 'kit', setIdx: 0, doneSets: [], showDone: false, setChange: '', nextUp: false, showNav: false, navTab: null, toast: '' });
    this.plan = null; this.bellT = null; this.bellG.rotation.z = 0; this.wbFade = 0; this.wbGlowMat.opacity = 0; this.viewShiftGoal = 0;
    this.clearKit(); this.kitOutT = null;
    (this.onBar || []).forEach((m) => this.root.remove(m.o)); this.onBar = []; this.barSide = []; this.grab = null;
    this.rackG.visible = false; this.rackG.position.y = 0;
    this.drawWB(null);
    [this.boardG, this.benchG, this.chalkG, this.flagG, this.fanG].forEach((o) => { if (o) o.visible = false; });
    this.notebookG.position.set(this.NB[0], this.NB[1], this.NB[2]); this.notebookG.rotation.set(0, 0, 0);
    this.bottleG.position.set(this.BT[0], this.BT[1], this.BT[2]); this.bottleG.rotation.set(0, 0, 0);
    this.walls.forEach((w) => { w.g.position.y = 0; });
    this.wallFrames.forEach((f) => { f.o.rotation.z = 0; });
    this.flagCloth.scale.y = 1; this.flagCloth.position.y = -this.flag.H / 2; this.flagG.scale.set(1, 1, 1);
    this.poseFlag(0, 0);
    this.lid.rotation.set(0, 0, 0);
    this.controls.enabled = false;
    const f = this.SHOTS.far;
    this.fly = null;
    this.controls.target.set(f.T[0], f.T[1], f.T[2]); this.camera.position.set(f.P[0], f.P[1], f.P[2]);
    this.wallDown = null; this.setFurnished();
    this.poseBox(1, 0.55, 0);
  }
  poseBox(k, lift, lidUp) {
    const H = this.H, C = this.CUBE;
    this.wallMeshes.forEach((w) => { w.scale.y = (H + (C - H) * k) / H; });
    this.frontWall.visible = k > 0.002; this.frontWall.scale.y = Math.max(0.001, k * C / H);
    this.lid.visible = lidUp < 30; this.lid.position.y = C + 0.075 + lidUp;
    this.slab.visible = true; this.thinFloor.visible = false;
    this.boxP = k;
    this.root.position.y = lift;
  }
  openBox() {
    const O = this.onb; O.phase = 'opening'; O.pt = 0; this.popG.visible = true;
    O.s0 = this.spinY; O.s1 = Math.round(this.spinY / (Math.PI * 2)) * Math.PI * 2;   // land facing the camera, by the shortest turn
  }
  runOnb(dt) {
    const O = this.onb, t = (O.t += dt), pt = (O.pt += dt), PI = Math.PI;
    const cl = (x) => Math.min(1, Math.max(0, x));
    const outBack = (x, k = 1.8) => { x = cl(x); const c = k + 1; return 1 + c * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); };
    const inOut = (x) => { x = cl(x); return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; };
    const sine = (x) => { x = cl(x); return 0.5 - 0.5 * Math.cos(PI * x); };
    const outCubic = (x) => 1 - Math.pow(1 - cl(x), 3);
    const wob = (since, amp, k = 4.5, w = 15) => since < 0 ? 0 : amp * Math.exp(-since * k) * Math.sin(since * w);
    const once = (key, fn) => { if (!O.fired[key]) { O.fired[key] = 1; fn(); } };
    const S = this.SHOTS, bob = Math.sin(t * 0.9) * 0.25;
    if (this.wbGlowMat) this.runWorkout(dt, t);

    if (O.phase === 'idle') {
      // the closed cube pops in and turns slowly in the sky, waiting for a tap
      if (t > 0.5) { this.popG.visible = true; this.popG.scale.setScalar(Math.max(0.0001, outBack((t - 0.5) / 0.8, 1.6))); }
      this.spinY += dt * 0.1;
      this.spinRoot(this.spinY);
      this.poseBox(1, 0.55 + Math.sin(t * 1.1) * 0.12, 0);
      this.popG.rotation.set(Math.sin(t * 0.8) * 0.035, 0, Math.sin(t * 0.63 + 1) * 0.03);     // a light, floating sway
      return;
    }

    if (O.phase === 'opening') {
      const pt = O.pt * 1.7;   // the box opens faster: same choreography, 1.7x
      // one soft, continuous move: the turn eases to a stop facing us, the lid floats up and away,
      // the walls glide down, the box settles gently and the camera drifts in. No dust, no bump.
      this.popG.scale.setScalar(1);
      this.spinY = O.s0 + (O.s1 - O.s0) * sine(pt / 1.6);
      this.spinRoot(this.spinY);
      if (pt > 0.35) this.shell.visible = false;
      const lidUp = 42 * Math.pow(sine((pt - 0.3) / 2.2), 1.7);
      this.lid.rotation.z = 0.25 * sine((pt - 0.3) / 2.0);
      const k = 1 - sine((pt - 0.8) / 2.0);
      const settle = 1 - sine((pt - 0.4) / 2.6);
      this.poseBox(k, (0.55 + Math.sin(t * 1.1) * 0.12) * settle, lidUp);
      this.popG.rotation.x *= Math.exp(-dt * 3); this.popG.rotation.z *= Math.exp(-dt * 3);
      once('fly', () => this.flyTo(S.overview.T, S.overview.P, 2.1));
      if (pt > 3.5) {
        // the gym moves in before any setup: platform turns over, rack drops, bench + bottle + whiteboard arrive
        O.phase = 'furnish'; O.pt = 0; O.ft0 = t; this.endOpening();
      }
      return;
    }
    if (O.ft0 != null && t - O.ft0 < 9) this.furnish(t - O.ft0);
    if (O.phase === 'furnish') {
      // everything has landed: now zoom in on the wall where the box gets set up
      if (pt > 2.3) { O.phase = 'setup'; O.pt = 0; this.gymMode = 'first'; this.gymStep = 0; this.pileAnim = {}; this.showGym(); }
      return;
    }
    // 3 · the gym setup, one question at a time, each answer building the gym
    if (O.phase === 'setup' || O.phase === 'gymEdit') { this.runSetup(dt, t); return; }

    if (O.phase === 'dropTest') {
      const rt = t - O.dt0, gf = 1 - cl(rt / 0.4), have = O.dhave;
      this.ghostMat.opacity = gf * 0.45; this.ghostG.visible = gf > 0.01; this.glowMat.opacity = gf * 0.4;
      this.popPiles(rt, O.drank, have);
      // then the piles lift away again and the form comes back
      if (rt > O.dEnd) {
        const q = cl((rt - O.dEnd) / 0.35);
        this.plateItems.forEach((pi) => { if (pi.o.visible) pi.o.scale.setScalar(Math.max(0.001, 1 - q)); });
        if (q >= 1) { this.plateItems.forEach((pi) => { pi.o.visible = false; pi.o.scale.setScalar(1); }); O.phase = 'form'; this.setState({ showForm: true }); }
      }
      return;
    }
    if (O.phase === 'toCorner' || O.phase === 'ghost' || O.phase === 'form') {
      // ghost piles fade in on the bare corner and gently breathe until tapped
      this.ghostG.visible = true;
      const fin = sine((O.phase === 'toCorner' ? pt - 1.2 : 9) / 0.8);
      const breathe = 0.5 + 0.5 * Math.sin(t * 2.6);
      this.ghostMat.opacity = fin * (0.34 + 0.22 * breathe);
      this.ghostMat.emissiveIntensity = 0.2 + 0.55 * breathe;
      this.glowMat.opacity = fin * (0.18 + 0.42 * breathe);
      this.ghostFlagG.visible = true;
      this.ghostFlagMat.opacity = fin * (0.3 + 0.2 * breathe); this.ghostFlagMat.emissiveIntensity = 0.2 + 0.55 * breathe;
      this.poseGhostFlag(1, t);
      if (O.phase === 'toCorner' && pt > 2.0) O.phase = 'ghost';
      return;
    }

    if (O.rt0 != null) {
      const rt = t - O.rt0;
      // ghosts fade as the real piles drop in, one after another; then the flag unrolls with the name
      const gf = 1 - cl(rt / 0.5);
      this.ghostMat.opacity = gf * 0.45; this.ghostG.visible = gf > 0.01;
      this.glowMat.opacity = gf * 0.4; this.ghostFlagMat.opacity = gf * 0.4; this.ghostFlagG.visible = gf > 0.01;
      this.popPiles(rt, O.rank, O.have);
      // flag: the rod pops onto its nails, then the cloth unrolls downward and flutters to rest
      const fa = O.flagAt, rx = (rt - fa) / 0.35, ux = (rt - fa - 0.2) / 0.85;
      this.flagG.visible = rt >= fa;
      this.flagG.scale.set(Math.max(0.0001, outBack(rx, 2.0)), 1, 1);
      const sy = Math.max(0.0001, outCubic(ux)), FH = this.flag.H;
      this.flagCloth.scale.y = sy; this.flagCloth.position.y = -FH / 2 * sy;
      const sf = rt - fa - 0.2, e = sf < 0 ? 0 : sf < 0.85 ? 0.6 + 0.4 * Math.sin((sf / 0.85) * PI / 2) : Math.exp(-(sf - 0.85) * 1.2);
      this.poseFlag(e, t);

      // next: the PR board
      if (O.phase === 'reveal' && rt > fa + 1.2) { O.phase = 'toPR'; O.pt = 0; this.flyTo(S.pr.T, S.pr.P, 2.2); }
      if (O.phase === 'toPR' && pt > 1.5) { O.phase = 'pr'; this.showPRs('first'); }
      const prOn = O.phase === 'toPR' ? sine((pt - 1.4) / 0.8) : (O.phase === 'pr' || O.phase === 'prForm') ? 1 : 0;
      this.prGlowFade = (this.prGlowFade || 0) + (prOn - (this.prGlowFade || 0)) * (1 - Math.exp(-dt * 5));
      this.prGlowMat.opacity = this.prGlowFade * (0.22 + 0.4 * (0.5 + 0.5 * Math.sin(t * 2.6)));
      // then, on to the workout whiteboard (already in the room since the start)
      if (O.phase === 'toBoard' && O.bt0 != null && t - O.bt0 > 2.1) { O.phase = 'wb'; this.showWod('first'); }
    }
  }
  shakeKick(a) { this.shake = Math.max(this.shake, a); }
  renderDimmed(camera) {
    const T = this.THREE, R = this.renderer;
    if (!this.dimScene) {
      this.dimScene = new T.Scene(); this.dimCam = new T.OrthographicCamera(-1, 1, 1, -1, 0, 1);
      this.dimMat = new T.MeshBasicMaterial({ color: '#FFFFFF', transparent: true, opacity: 0, depthTest: false, depthWrite: false });
      this.dimScene.add(new T.Mesh(new T.PlaneGeometry(2, 2), this.dimMat));
      this.scene.traverse((o) => { if (o.isLight) o.layers.enable(1); });
    }
    this.dimMat.color.set(this.state.boxLight || '#EFE3CF'); this.dimMat.opacity = 0.62 * this.dimK;
    R.render(this.scene, camera);
    R.autoClear = false;
    R.render(this.dimScene, this.dimCam);
    R.clearDepth();
    const bg = this.scene.background; this.scene.background = null;
    camera.layers.set(1); R.render(this.scene, camera); camera.layers.set(0);
    this.scene.background = bg;
    R.autoClear = true;
  }
  furnish(PT) {
    const PI = Math.PI, cl = (x) => Math.min(1, Math.max(0, x)), O = this.onb;
    const sine = (x) => { x = cl(x); return 0.5 - 0.5 * Math.cos(PI * x); };
    const outCubic = (x) => 1 - Math.pow(1 - cl(x), 3);
    const wob = (since, amp, k = 4.5, w = 15) => since < 0 ? 0 : amp * Math.exp(-since * k) * Math.sin(since * w);
    const cu = sine((PT - 0.2) / 0.8) * 4;
    this.cutLines.forEach((m, i) => { const x = cl(cu - i); m.visible = x > 0 && PT < 1.75; m.scale.set(Math.max(0.001, x), 1, 1); });
    const fk = sine((PT - 0.9) / 1.1);
    this.flipG.rotation.x = PI * fk; this.flipG.position.y = -0.02 * fk;
    this.well.visible = false;      // the opening stays open: the scene background shows through
    const sk = PT > 0.9 && PT < 2.05 ? 0.985 : 1; this.flipG.scale.set(sk, 1, sk);
    if (PT > 2.1 && !O.fired.clipOff) { O.fired.clipOff = 1; this.setClip(false); }
    const g0 = 3.0, bx = (PT - g0 - 0.1) / 1.2, bk = outCubic(bx), B = this.BOARD;
    this.boardG.visible = PT > g0 + 0.1;
    this.boardG.position.set(B[0] - (1 - bk) * 1.2, 0, B[1] + (1 - bk) * 3.6);
    this.boardG.rotation.set(wob(PT - g0 - 1.3, 0.07, 4, 16), this.BOARD_RY + (1 - bk) * PI * 1.25, 0);
    this.wheels.forEach((w) => { w.rotation.x = -(1 - bk) * 110; });
    const toss = (o, t0, dur, from, to, arc, spin, baseRy, flip = 0, wa = 0.11) => {
      const x = (PT - t0) / dur; o.visible = x >= 0; const v = cl(x);
      o.position.set(from[0] + (to[0] - from[0]) * v, from[1] * (1 - v) + to[1] * v + arc * 4 * v * (1 - v), from[2] + (to[2] - from[2]) * v);
      const since = PT - t0 - dur;
      o.rotation.set(wob(since, wa, 5, 17), baseRy + spin * (1 - v), wob(since + 0.05, wa * 0.7, 5, 21) + flip * (1 - v));
      if (x >= 1 && !O.fired['land' + o.id]) { O.fired['land' + o.id] = 1; return true; }
      return false;
    };
    const BN = this.BENCH;
    if (toss(this.benchG, g0, 0.9, [BN[0] + 3.0, 1.2, BN[1] + 2.6], [BN[0], 0, BN[1]], 2.0, -2.2, this.CHAIR_RY)) { this.emitDust(BN[0], BN[1], 26, 1.1, 0.4, 0.5); this.shakeKick(0.12); }
    toss(this.chalkG, g0 + 0.3, 0.85, [-1.2, 1.4, 4.4], [this.CHALK[0], 0, this.CHALK[1]], 1.8, 1.6, 0);
    toss(this.notebookG, g0 + 0.9, 0.65, [-1.4, 1.1, 1.6], this.NB, 0.9, 3.2, 0, 0, 0.06);
    { const fq = (PT - g0 - 0.6) / 0.45, c2 = Math.min(1, Math.max(0, fq));
      this.fanG.visible = fq > 0 && !this.noFloorFan; this.fanG.scale.setScalar(Math.max(0.001, fq >= 1 ? 1 : 1 + 2.8 * Math.pow(c2 - 1, 3) + 1.8 * Math.pow(c2 - 1, 2))); }
  }
  puffRing(x, y, z, r, n, sp) {
    for (const pf of this.puffs) {
      if (n <= 0) break;
      if (pf.life > 0) continue;
      n--;
      const a = Math.random() * Math.PI * 2, c = Math.cos(a), s = Math.sin(a);
      pf.m.position.set(x + c * r, y, z + s * r);
      const v = sp * (0.6 + Math.random() * 0.8);
      pf.v.set(c * v, 0.4 + Math.random() * 1.0, s * v);
      pf.life = pf.max = 0.6 + Math.random() * 0.5;
      pf.s = 0.05 + Math.random() * 0.1;
      pf.m.rotation.set(Math.random() * 3, Math.random() * 3, 0);
      pf.m.visible = true;
    }
  }
  frame(dt, t) {
    const st = this.state, THREE = this.THREE, camera = this.camera, controls = this.controls;
    this.syncArt();
    this.inkLines.forEach((l) => { l.visible = st.outline; });
    this.renderer.shadowMap.enabled = st.shadows; this.sun.castShadow = st.shadows;
    this.sceneLook();

    if (!this.manualBox) {
    // ---- close / open the box (a 2.6 s timeline; closing and opening have their own choreography) ----
    const goal = st.closed ? 1 : 0;
    const speed = 1 / 2.6;
    const prevP = this.boxP;
    this.boxP = goal > this.boxP ? Math.min(goal, this.boxP + dt * speed) : Math.max(goal, this.boxP - dt * speed);
    const p = this.boxP, closing = st.closed;
    const cl = (x) => Math.min(1, Math.max(0, x));
    const inOut = (x) => { x = cl(x); return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; };
    const outBack = (x, k = 2.2) => { x = cl(x); const c = k + 1; return 1 + c * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); };
    const inBack = (x, k = 2.0) => { x = cl(x); return (k + 1) * x * x * x - k * x * x; };
    const bounce = (x) => { x = cl(x); const n = 7.5625, d = 2.75;
      if (x < 1 / d) return n * x * x; if (x < 2 / d) return n * (x -= 1.5 / d) * x + 0.75;
      if (x < 2.5 / d) return n * (x -= 2.25 / d) * x + 0.9375; return n * (x -= 2.625 / d) * x + 0.984375; };
    const crossed = (v) => closing ? (prevP < v && p >= v) : (prevP > v && p <= v);
    const H = this.H, C = this.CUBE, S = this.S;
    let wallK = [0, 0, 0], frontK = 0, lidY = C + 0.075 + 9, lidOn = false, lidRot = 0, floatK = 0, lift = 0;
    if (closing) {
      // walls shoot up one after another and overshoot; the front wall follows; the lid slams down and bounces
      wallK = [0, 1, 2].map((i) => outBack((p - 0.04 * i) / 0.36));
      frontK = outBack((p - 0.16) / 0.38);
      const lt = (p - 0.5) / 0.26;
      lidOn = p > 0.5; lidY = C + 0.075 + (1 - bounce(lt)) * 9; lidRot = (1 - cl(lt)) * 0.35;
      floatK = cl((p - 0.8) / 0.2);
      lift = outBack((p - 0.8) / 0.2, 3.0);
      if (crossed(0.5 + 0.26 / 2.75)) this.impact(1.0, C + 0.1);        // lid hits the walls
      if (crossed(0.8)) this.impact(0.45, 0.05, true);                    // it pops off the ground
    } else {
      // q runs 0 → 1 while opening: land, lid pops off, then the walls drop with a bounce
      const q = 1 - p;
      floatK = 1 - inOut(q / 0.2); lift = 1 - inBack(q / 0.2, 1.2);
      const lt = (q - 0.2) / 0.22;
      lidOn = lt < 1; lidY = C + 0.075 + inBack(lt, 2.6) * 14; lidRot = inBack(lt) * 0.9;
      wallK = [0, 1, 2].map((i) => 1 - bounce((q - 0.4 - 0.04 * i) / 0.4));
      frontK = 1 - bounce((q - 0.36) / 0.4);
      if (crossed(1 - 0.2)) this.impact(0.7, 0.05, true);                  // cube lands
      if (crossed(1 - (0.4 + 0.4 / 2.75))) this.impact(0.8, H + 0.1);        // walls hit their height
    }
    if (p <= 0.0001) { wallK = [0, 0, 0]; frontK = 0; lidOn = false; floatK = 0; lift = 0; }
    this.wallMeshes.forEach((w, i) => { w.scale.y = (H + (C - H) * wallK[i]) / H; });
    this.frontWall.visible = frontK > 0.002;
    this.frontWall.scale.y = Math.max(0.001, frontK * C / H);
    this.lid.visible = lidOn; this.lid.position.y = lidY; this.lid.rotation.z = lidRot; this.lid.rotation.x = lidRot * 0.4;
    this.slab.visible = st.base || p > 0.001; this.thinFloor.visible = !this.slab.visible;
    // floating: hop up, gentle bob + slow turn; settles back to rest when it opens
    if (st.closed) this.spinY += dt * 0.18 * floatK;
    else { let a = this.spinY % (Math.PI * 2); if (a > Math.PI) a -= Math.PI * 2; if (a < -Math.PI) a += Math.PI * 2; this.spinY = a * Math.exp(-dt * 3); }
    this.root.rotation.y = this.spinY;
    this.root.position.y = lift * 0.55 + floatK * Math.sin(t * 0.9) * 0.35 + (this.sky ? Math.sin(t * 0.55) * 0.12 : 0);
    this.voidShadow.material.opacity = this.sky ? 0 : 0.18 * floatK;
    }
    this.updateSky(dt, t);
    // squash & stretch after each impact (root pivots at the floor)
    this.sqT += dt;
    const sq = this.sqA * Math.exp(-this.sqT * 7) * Math.sin(this.sqT * 26);
    this.root.scale.set(1 + sq * 0.05, 1 - sq * 0.1, 1 + sq * 0.05);
    this.updatePuffs(dt);
    this.updateDust(dt);

    // cut-away: while open, a wall hides itself when the camera is outside it
    const cut = this.boxP < 0.02;
    this.walls.forEach((w) => {
      if (!cut) { w.g.visible = true; return; }
      w.g.visible = camera.position.clone().sub(w.p).dot(w.n) > 0;
    });

    if (this.intro) this.runIntro(dt);
    if (this.onb && !this.paused) this.runOnb(dt);
    this.propsTick(dt, t);
    controls.autoRotate = (st.spin || st.closed) && !this.fly && !this.manualBox;
    controls.autoRotateSpeed = st.closed ? 0.25 : 0.6;
    if (this.fly) {
      const f = this.fly; f.t += dt;
      const x = Math.min(1, f.t / f.dur), u = x * x * x * (x * (x * 6 - 15) + 10);
      if (f.fov0 == null) { f.fov0 = camera.fov; f.fov1 = this.fovGoal || camera.fov; }
      camera.fov = f.fov0 + (f.fov1 - f.fov0) * u; camera.updateProjectionMatrix();
      if (f.look) {
        if (!f.d0) { f.d0 = f.T0.clone().sub(f.P0); f.l0 = f.d0.length(); f.d0.normalize(); f.d1 = f.T1.clone().sub(f.P1); f.l1 = f.d1.length(); f.d1.normalize(); f.q = new THREE.Quaternion().setFromUnitVectors(f.d0, f.d1); f.qi = new THREE.Quaternion(); }
        camera.position.lerpVectors(f.P0, f.P1, u);
        f.qi.identity().slerp(f.q, u);
        const dv = f.d0.clone().applyQuaternion(f.qi).multiplyScalar(f.l0 + (f.l1 - f.l0) * u);
        controls.target.copy(camera.position).add(dv);
      } else controls.target.lerpVectors(f.T0, f.T1, u);
      if (f.look) {}     // a head turn: the eye barely moves, the gaze swings
      else {
        f.sph.set(f.s0.radius + (f.s1.radius - f.s0.radius) * u, f.s0.phi + (f.s1.phi - f.s0.phi) * u, f.s0.theta + f.dTh * u);
        camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(f.sph));
      }
      if (x >= 1) this.fly = null;
    }
    if (!this.fly && this.fovGoal && Math.abs(camera.fov - this.fovGoal) > 0.05) { camera.fov += (this.fovGoal - camera.fov) * (1 - Math.exp(-dt * 3)); camera.updateProjectionMatrix(); }
    controls.update();
    // while the sheet is up, shift the view so the wall sits in the visible top half
    this.viewShift = (this.viewShift || 0) + (this.shiftGoal() - (this.viewShift || 0)) * (1 - Math.exp(-dt * 4));
    if (this.viewShift > 0.002) {
      const sz = this.renderer.getSize(new THREE.Vector2());
      camera.setViewOffset(sz.x, sz.y, 0, sz.y * this.viewShift, sz.x, sz.y);
    } else if (camera.view && camera.view.enabled) camera.clearViewOffset();
    // camera kick on impacts, scaled to how far away we are
    this.shake *= Math.exp(-dt * 9);
    const sh = this.shake * camera.position.distanceTo(controls.target) * 0.012;
    const off = new THREE.Vector3((Math.random() - 0.5) * sh, (Math.random() - 0.5) * sh, (Math.random() - 0.5) * sh);
    camera.position.add(off);
    const dimGoal = this.onb && this.onb.phase === 'sets' ? 1 : 0;
    this.dimK = (this.dimK || 0) + (dimGoal - (this.dimK || 0)) * (1 - Math.exp(-dt * 3));
    { const L = this.slook || {}, C = this.lookColours ? this.lookColours() : {}, cc = (k, d) => (C[k] && C[k][1]) || d;
      const P = { contrast: L.contrast, bright: L.bright, saturate: L.saturate, hue: L.hue, posterize: L.posterize, duotone: L.duotone, dk: cc(L.duoDark, '#4A3426'), lt: cc(L.duoLight, '#EFE3CF'),
        sketch: L.sketch, skCol: cc(L.skCol, '#4A3426'), skWidth: L.skWidth, skRough: L.skRough, skScale: L.skScale, skGrain: L.skGrain, skDouble: L.skDouble, skWarp: L.skWarp, seed: GLFX.boilSeed(L.sketch ? L.skBoil : 0) };
      const R = this.renderer, fx = (P.duotone || P.sketch || P.posterize >= 2 || P.contrast !== 1 || P.bright !== 1) && GLFX.begin(R);
      if (this.barG && !this.barLayered) this.layerBar();
      if (this.dimK > 0.01) this.renderDimmed(camera); else R.render(this.scene, camera);
      if (fx) GLFX.end(R, P);
      if (this.barG) this.crispBar(camera); }
    camera.position.sub(off);
  }
  impact(amp, y, ground) {
    this.sqA = amp; this.sqT = 0; this.shake = Math.max(this.shake, amp);
    // dust bursts out of the seam all around the box
    const h = this.S / 2 + 0.15;
    let n = ground ? 26 : 40;
    for (const pf of this.puffs) {
      if (n <= 0) break;
      if (pf.life > 0) continue;
      n--;
      const side = Math.floor(Math.random() * 4), u = (Math.random() * 2 - 1) * h;
      const pos = [[u, -h, 0, -1], [u, h, 0, 1], [-h, u, -1, 0], [h, u, 1, 0]][side];
      pf.m.position.set(pos[0], y, pos[1]);
      const sp = 1.6 + Math.random() * 2.6 * amp;
      pf.v.set(pos[2] * sp + (Math.random() - 0.5) * 0.8, 0.6 + Math.random() * 1.6, pos[3] * sp + (Math.random() - 0.5) * 0.8);
      pf.life = pf.max = 0.7 + Math.random() * 0.6;
      pf.s = 0.12 + Math.random() * 0.22;
      pf.m.rotation.set(Math.random() * 3, Math.random() * 3, 0);
      pf.m.visible = true;
    }
  }
  updatePuffs(dt) {
    for (const pf of this.puffs) {
      if (pf.life <= 0) continue;
      pf.life -= dt;
      if (pf.life <= 0) { pf.m.visible = false; continue; }
      const k = 1 - pf.life / pf.max;
      pf.v.multiplyScalar(Math.exp(-dt * 3.2)); pf.v.y -= dt * 0.4;
      pf.m.position.addScaledVector(pf.v, dt);
      pf.m.rotation.x += dt * 1.5; pf.m.rotation.y += dt;
      pf.m.scale.setScalar(pf.s * (0.5 + k * 1.4));
      pf.m.material.opacity = 0.95 * (1 - k * k);
      pf.ink.material.opacity = 0.85 * (1 - k) * (1 - k);
    }
  }
  flyTo(Tv, Pv, dur, look) {
    if (!this.camera) return;
    const T = this.THREE, S = T.Spherical;
    const T1 = new T.Vector3(Tv[0], Tv[1], Tv[2]), P1 = new T.Vector3(Pv[0], Pv[1], Pv[2]);
    const s0 = new S().setFromVector3(this.camera.position.clone().sub(this.controls.target));
    const s1 = new S().setFromVector3(P1.clone().sub(T1));
    let dTh = s1.theta - s0.theta;
    while (dTh > Math.PI) dTh -= Math.PI * 2;
    while (dTh < -Math.PI) dTh += Math.PI * 2;
    this.fly = { t: 0, dur: dur || 1.1, T0: this.controls.target.clone(), T1, s0, s1, dTh, sph: new S(), look: !!look, P0: this.camera.position.clone(), P1 };
  }
  spinRoot(a) {
    const R = this.ROOM, c = Math.cos(a), s = Math.sin(a), cx = R ? R.cx : 0, cz = R ? R.cz : 0;
    this.root.rotation.y = a;
    this.root.position.x = cx - (cx * c + cz * s); this.root.position.z = cz - (-cx * s + cz * c);
  }
  buildFanG() {
    const T = this.THREE, g = new T.Group(), W = '#FFFFFF', K = '#111111', cy = 0.66, R = 0.4;
    [-1, 1].forEach((sx) => {
      this.box(0.05, 0.05, 0.56, K, sx * 0.47, 0.03, 0, g);                                   // foot
      this.box(0.045, cy, 0.045, K, sx * 0.47, cy / 2, 0, g);                                // upright
      this.cyl(0.035, 0.035, 0.03, 10, K, sx * 0.47, 0.035, 0.24, g, { rz: Math.PI / 2 });   // wheel
      this.cyl(0.035, 0.035, 0.03, 10, K, sx * 0.47, 0.035, -0.24, g, { rz: Math.PI / 2 });
      this.cyl(0.03, 0.03, 0.06, 10, K, sx * 0.44, cy, 0, g, { rz: Math.PI / 2 });           // pivot bolt
    });
    this.cyl(R, R, 0.24, 28, W, 0, cy, 0, g, { rx: Math.PI / 2 });                            // the drum
    this.cyl(R - 0.03, R - 0.03, 0.005, 28, K, 0, cy, 0.121, g, { rx: Math.PI / 2, ink: false }); // dark inside
    this.cyl(0.13, 0.13, 0.1, 16, K, 0, cy, -0.16, g, { rx: Math.PI / 2 });                   // motor at the back
    const bl = new T.Group(); bl.position.set(0, cy, 0.128); g.add(bl); bl.userData.spin = true;
    for (let i = 0; i < 3; i++) { const b = this.box(0.12, 0.3, 0.008, W, 0, 0.17, 0, null, { ink: false }); const pv = new T.Group(); pv.rotation.z = i * Math.PI * 2 / 3; pv.add(b); b.rotation.y = 0.35; bl.add(pv); }
    this.cyl(0.05, 0.05, 0.02, 12, W, 0, 0, 0.004, bl, { rx: Math.PI / 2 });
    // front grille: concentric rings and four spokes
    [0.12, 0.22, 0.31, R - 0.01].forEach((r) => { const m = new T.Mesh(new T.TorusGeometry(r, 0.006, 4, 32), this.m(K)); m.position.set(0, cy, 0.135); g.add(m); });
    for (let i = 0; i < 4; i++) { const sp = this.box(0.008, 2 * R - 0.02, 0.008, K, 0, cy, 0.135, g, { ink: false }); sp.rotation.z = i * Math.PI / 4; }
    return g;
  }
  buildRoom() {
    const T = this.THREE, S = this.S, H = this.H, h = S / 2;
    const W = '#FFFFFF', K = '#111111';
    // floor: a thick base slab (toggle, and always while the box is closed) or a flush thin floor
    // the floor is a frame around a 2.44 m hatch, so the platform can rise out of it
    const F = S + 0.32, HO = 2.44, hh = HO / 2, rim = (F - HO) / 2;
    const floorSet = (th) => {
      const g = new T.Group(); this.root.add(g);
      const o = { ink: false };
      this.box(F, th, rim, W, 0, -th / 2, hh + rim / 2, g, o);
      this.box(F, th, rim, W, 0, -th / 2, -hh - rim / 2, g, o);
      this.box(rim, th, HO, W, hh + rim / 2, -th / 2, 0, g, o);
      this.box(rim, th, HO, W, -hh - rim / 2, -th / 2, 0, g, o);
      const e = new T.LineSegments(new T.EdgesGeometry(new T.BoxGeometry(F, th, F)), this.inkMat);
      e.position.y = -th / 2; g.add(e); this.inkLines.push(e);
      return g;
    };
    this.slab = floorSet(0.3);
    this.thinFloor = floorSet(0.01);
    // the hatch lid (looks like floor) and the dark well under it
    this.hatch = new T.Group(); this.root.add(this.hatch);
    this.box(HO, 0.02, HO, W, 0, -0.01, 0, this.hatch, { ink: false });
    this.well = new T.Group(); this.root.add(this.well);
    const wk = { ink: false, cast: false };
    // white lining just inside the hole (clear of the slab faces, so nothing flickers); ink edges give it depth
    const li = hh - 0.008;
    this.box(HO - 0.016, 0.29, 0.01, W, 0, -0.145, li, this.well, { cast: false });
    this.box(HO - 0.016, 0.29, 0.01, W, 0, -0.145, -li, this.well, { cast: false });
    this.box(0.01, 0.29, HO - 0.016, W, li, -0.145, 0, this.well, { cast: false });
    this.box(0.01, 0.29, HO - 0.016, W, -li, -0.145, 0, this.well, { cast: false });
    this.box(HO, 0.01, HO, W, 0, -0.285, 0, this.well, { cast: false });
    this.well.visible = false;
    // the cut line drawn around the hatch at the start of the intro
    // corners walked clockwise; each segment grows from its start corner, so it reads as one stroke
    const cs = [[-hh, hh], [hh, hh], [hh, -hh], [-hh, -hh], [-hh, hh]];
    this.cutLines = [0, 1, 2, 3].map((i) => {
      const [x0, z0] = cs[i], [x1, z1] = cs[i + 1], L = Math.hypot(x1 - x0, z1 - z0) + 0.02;
      const m = this.box(L, 0.004, 0.02, K, x0, 0.002, z0, null, wk);
      m.rotation.y = -Math.atan2(z1 - z0, x1 - x0);
      m.geometry.translate(L / 2 - 0.01, 0, 0);            // pivot at the start corner
      m.children.forEach((c) => c.geometry && c.geometry.translate(L / 2 - 0.01, 0, 0));
      m.visible = false; return m;
    });
    // rubber tile seams, hairline black; the three middle lines are split around the hatch
    this.seamMeshes = [];
    const seam = (w, d, x, z, parent) => { const m = this.box(w, 0.002, d, K, x, 0.001, z, parent, { ink: false, cast: false }); this.seamMeshes.push(m); return m; };
    for (let i = -3; i <= 3; i++) {
      if (Math.abs(i) < hh) {
        const L = h - hh, c = hh + L / 2;
        seam(0.004, L, i, c); seam(0.004, L, i, -c); seam(L, 0.004, c, i); seam(L, 0.004, -c, i);
        seam(0.004, HO, i, 0, this.hatch); seam(HO, 0.004, 0, i, this.hatch);
      } else { seam(0.004, S, i, 0); seam(S, 0.004, 0, i); }
    }
    this.walls = []; this.wallMeshes = [];
    const wall = (nx, nz, px, pz, w, d) => {
      const g = new T.Group(); this.root.add(g);
      const geo = new T.BoxGeometry(w, H, d).translate(0, H / 2, 0);     // pivot at the floor so it can grow upward
      const mesh = this.put(geo, W, px + nx * -0.075, 0, pz + nz * -0.075, g);
      this.walls.push({ g, n: new T.Vector3(nx, 0, nz), p: new T.Vector3(px, 0, pz) });
      this.wallMeshes.push(mesh);
      return g;
    };
    const back = wall(0, 1, 0, -h, S + 0.3, 0.15);
    const left = wall(1, 0, -h, 0, 0.15, S + 0.3);
    const right = wall(-1, 0, h, 0, 0.15, S + 0.3);
    // front wall: hidden in the diorama, rises when the box closes
    const fg = new T.BoxGeometry(S + 0.3, H, 0.15).translate(0, H / 2, 0);
    this.frontWall = this.put(fg, W, 0, 0, h + 0.075);
    this.frontWall.visible = false;
    // lid
    this.lid = this.box(S + 0.3, 0.15, S + 0.3, W, 0, this.CUBE + 0.075, 0);
    this.lid.visible = false;
    // a fine black line where each wall meets the floor
    const hl = { ink: false, cast: false };
    this.box(S, 0.014, 0.006, K, 0, 0.007, -h + 0.003, back, hl);
    this.box(0.006, 0.014, S, K, -h + 0.003, 0.007, 0, left, hl);
    this.box(0.006, 0.014, S, K, h - 0.003, 0.007, 0, right, hl);
    // a high window strip on wall 1 (left), above the rack
    this.box(0.04, 0.5, 3.2, W, -h + 0.02, 2.05, 0.6, left);
    for (let i = 0; i < 5; i++) this.box(0.05, 0.5, 0.04, K, -h + 0.03, 2.05, -1.0 + i * 0.8, left, { ink: false });
    this.backWall = back; this.leftWall = left; this.rightWall = right;
  }
  buildPlatform() {
    const g = new this.THREE.Group(); this.root.add(g); this.platG = g;
    const rk = new this.THREE.Group(); this.root.add(rk); this.rackG = rk;
    const W = '#FFFFFF', K = '#111111';
    // 2.4 m platform: white wood strip down the middle, black rubber where the plates land
    this.box(2.44, 0.04, 2.44, K, 0, 0.02, 0, g);
    this.box(1.2, 0.05, 2.4, W, 0, 0.025, 0, g);
    this.box(0.6, 0.05, 2.4, K, -0.9, 0.025, 0, g);
    this.box(0.6, 0.05, 2.4, K, 0.9, 0.025, 0, g);
    for (let i = 1; i < 6; i++) this.box(1.2, 0.002, 0.004, K, 0, 0.051, -1.2 + i * 0.4, g, { ink: false, cast: false });
    // wall-mounted rack: two thick uprights, a thin pull-up bar across the top, two thin arms straight back to wall 2
    const z = -0.85, TOP = 2.35, wallZ = -1.69;
    [-1, 1].forEach((sx) => {
      const x = sx * 0.62;
      this.box(0.09, TOP, 0.09, K, x, TOP / 2, z, rk);                                     // upright
      this.box(0.22, 0.02, 0.22, K, x, 0.01, z, rk);                                       // floor plate
      for (let y = 0.25; y < TOP - 0.1; y += 0.1) this.box(0.02, 0.02, 0.004, W, x, y, z + 0.046, rk, { ink: false, cast: false });   // punched holes
      this.box(0.1, 0.12, 0.1, K, x, 1.22, z + 0.005, rk);                                  // J-hook sleeve
      this.box(0.09, 0.03, 0.12, K, x, 1.19, z + 0.1, rk);                                   // hook seat
      this.box(0.09, 0.08, 0.02, K, x, 1.24, z + 0.16, rk);                                  // hook lip
      const L = Math.abs(wallZ - z) - 0.065;
      this.box(0.04, 0.04, L, K, x, 2.02, z - 0.045 - L / 2, rk);                           // arm to the wall
      this.box(0.14, 0.24, 0.02, K, x, 2.02, wallZ + 0.01, rk);                              // wall plate
    });
    this.cyl(0.02, 0.02, 1.33, 12, K, 0, TOP - 0.06, z, rk, { rz: Math.PI / 2 });   // pull-up bar
    // its back is to wall 2 (the back wall); the bar runs left-to-right across the platform
    // olympic bar on the hooks: black shaft, white sleeves
    // olympic bar on the hooks: real steel, so it reads against the sky (knurled shaft, polished sleeves, satin collars)
    const bar = new this.THREE.Group(); bar.position.set(0, 1.265, z + 0.08); rk.add(bar); this.barG = bar;
    const T = this.THREE, steel = (o) => new T.MeshStandardMaterial(Object.assign({ metalness: 1 }, o));
    const kc = document.createElement('canvas'); kc.width = 64; kc.height = 64;
    { const x = kc.getContext('2d'); x.fillStyle = '#C9CED4'; x.fillRect(0, 0, 64, 64); x.strokeStyle = '#7E868F'; x.lineWidth = 3;
      for (let i = -64; i <= 64; i += 16) { x.beginPath(); x.moveTo(i, 0); x.lineTo(i + 64, 64); x.stroke(); x.beginPath(); x.moveTo(i + 64, 0); x.lineTo(i, 64); x.stroke(); } }
    const kt = new T.CanvasTexture(kc); kt.wrapS = kt.wrapT = T.RepeatWrapping; kt.repeat.set(6, 80); kt.colorSpace = T.SRGBColorSpace; kt.anisotropy = 8;
    const shaftM = steel({ color: '#D3D8DD', roughness: 0.42, map: kt, bumpMap: kt, bumpScale: 0.6 });
    const smoothM = steel({ color: '#CDD2D8', roughness: 0.3 });
    const sleeveM = steel({ color: '#EEF1F4', roughness: 0.12 });
    const collarM = steel({ color: '#A9B0B8', roughness: 0.22 });
    const part = (r, len, mat, x) => { const m = this.cyl(r, r, len, 28, K, x, 0, 0, bar, { rz: Math.PI / 2 }); m.material = mat; return m; };
    part(0.0142, 0.16, smoothM, 0);                                   // smooth centre
    [-1, 1].forEach((s) => {
      part(0.0142, 0.26, shaftM, s * 0.21);                          // knurled hand sections
      part(0.0142, 0.32, smoothM, s * 0.497);                      // smooth shaft right up to the collar
      part(0.04, 0.03, collarM, s * 0.67);                           // collar
      part(0.03, 0.012, collarM, s * 0.691);                         // inner sleeve stop
      part(0.025, 0.4, sleeveM, s * 0.897);                          // sleeve
      part(0.027, 0.012, sleeveM, s * 1.094);                        // end cap lip
    });
  }
  buildBoardAndBench() {
    this.BOARD = [3.1, -0.2]; this.BENCH = [0, 1.8];
    const g = new this.THREE.Group(); g.position.set(this.BOARD[0], 0, this.BOARD[1]); g.rotation.y = -0.35; this.root.add(g); this.boardG = g; this.wheels = [];
    const W = '#FFFFFF', K = '#111111';
    [-0.68, 0.68].forEach((x) => {
      this.box(0.05, 1.75, 0.05, K, x, 0.875, 0, g);
      this.box(0.05, 0.04, 0.5, K, x, 0.055, 0, g);
      [-0.22, 0.22].forEach((wz) => this.wheels.push(this.cyl(0.035, 0.035, 0.03, 8, K, x, 0.035, wz, g, { rz: Math.PI / 2 })));
    });
    this.box(1.42, 0.98, 0.05, K, 0, 1.25, 0, g);
    this.box(1.34, 0.9, 0.02, W, 0, 1.25, 0.03, g, { ink: false });
    // writable surface for today's workout (recoloured with the palette like the other boards)
    { const T = this.THREE, cv = document.createElement('canvas'); cv.width = 1024; cv.height = 688;
      const x = cv.getContext('2d'); x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, 1024, 688);
      const tex = new T.CanvasTexture(cv); tex.colorSpace = T.SRGBColorSpace; tex.anisotropy = 8;
      this.wbArt = { cv, tex, rec: this.registerCanvas(cv, tex) };
      const face = new T.Mesh(new T.PlaneGeometry(1.33, 0.89), new T.MeshLambertMaterial({ map: tex })); face.position.set(0, 1.25, 0.042); g.add(face); }
    this.box(1.2, 0.03, 0.08, K, 0, 0.77, 0.06, g);
    this.box(0.12, 0.02, 0.02, K, -0.3, 0.795, 0.07, g, { ink: false });
    this.box(0.1, 0.035, 0.05, W, 0.25, 0.8, 0.07, g);
    // simple bench: white top, black legs
    // the rest bench sits just behind the platform, facing it: where the athlete sits between sets
    this.CHAIR_RY = Math.PI; this.NB = [-0.18, 0.4875, 0.02]; this.BT = [0.6, 0.1, 0.06];
    const b = new this.THREE.Group(); b.position.set(this.BENCH[0], 0, this.BENCH[1]); b.rotation.y = this.CHAIR_RY; this.root.add(b); this.benchG = b;
    // flat bench: a thick padded top on a steel rail, two T legs with rubber foot caps
    this.box(1.12, 0.085, 0.3, K, 0, 0.452, 0, b);
    this.box(1.06, 0.035, 0.26, K, 0, 0.392, 0, b);
    [-1, 1].forEach((sx) => {
      const x = sx * 0.41;
      this.box(0.065, 0.31, 0.065, K, x, 0.22, 0, b);
      this.box(0.065, 0.055, 0.42, K, x, 0.055, 0, b);
      [-1, 1].forEach((sz) => this.box(0.085, 0.07, 0.07, K, x, 0.035, sz * 0.21, b));
      [-0.07, 0.07].forEach((z) => this.cyl(0.012, 0.012, 0.03, 8, W, sx * 0.52, 0.392, z, b, { rz: Math.PI / 2, ink: false }));
    });
    // notebook and water bottle on the bench (their own pieces so the intro can toss them)
    const nb = new this.THREE.Group(); nb.position.set(this.NB[0], this.NB[1], this.NB[2]); b.add(nb); this.notebookG = nb;
    this.box(0.26, 0.025, 0.2, W, 0, 0, 0, nb);
    const bt = new this.THREE.Group(); bt.position.set(this.BT[0], this.BT[1], this.BT[2]); b.add(bt); this.bottleG = bt;
    this.cyl(0.035, 0.035, 0.2, 8, K, 0, 0, 0, bt);
    this.cyl(0.022, 0.022, 0.03, 8, W, 0, 0.115, 0, bt);
  }
  buildPRWall() {
    const T = this.THREE, W = '#FFFFFF', K = '#111111', h = this.S / 2;
    const g = new T.Group(); g.position.set(2.55, 1.45, -h + 0.05); this.backWall.add(g); this.prG = g;
    this.wallFrames = this.wallFrames || []; this.wallFrames.push({ o: g, w: 0, a: 0.05 });
    this.box(1.7, 1.16, 0.04, K, 0, 0, 0, g);
    // the table is drawn on a canvas: title, column heads, empty ruled rows
    const cv = document.createElement('canvas'); cv.width = 1024; cv.height = 680;
    const x = cv.getContext('2d');
    x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, 1024, 680);
    x.fillStyle = '#111111';
    x.textBaseline = 'middle'; x.font = '700 58px Helvetica, "Helvetica Neue", Arial, sans-serif'; x.fillText("My PR's", 40, 62);
    const cols = [['', 40], ['', 330], ['', 500], ['', 640], ['', 820]];
    x.fillRect(30, 164, 964, 6);
    x.lineWidth = 2; x.strokeStyle = '#111111';
    for (let r = 0; r < 8; r++) { const y = 224 + r * 60; x.beginPath(); x.moveTo(30, y); x.lineTo(994, y); x.stroke(); }
    cols.slice(1).forEach(([, cx]) => { x.beginPath(); x.moveTo(cx - 18, 112); x.lineTo(cx - 18, 644); x.stroke(); });
    const tex = new T.CanvasTexture(cv); this.prArt = { cv, tex, rec: this.registerCanvas(cv, tex), blank: x.getImageData(0, 0, cv.width, cv.height) }; tex.colorSpace = T.SRGBColorSpace; tex.anisotropy = 8;
    const face = new T.Mesh(new T.PlaneGeometry(1.6, 1.06), new T.MeshLambertMaterial({ map: tex }));
    face.position.z = 0.022; face.receiveShadow = true; g.add(face);
    this.box(1.5, 0.03, 0.07, K, 0, -0.6, 0.04, g);
    this.box(0.12, 0.02, 0.02, K, 0.35, -0.575, 0.05, g, { ink: false });
    // PR bell on a wall bracket, rope hanging
    const bell = new T.Group(); bell.position.set(3.65, 1.75, -h + 0.05); this.backWall.add(bell); this.bellG = bell;
    this.wallFrames.push({ o: bell, w: 0, a: 0.12 });
    this.box(0.16, 0.22, 0.03, K, 0, 0, 0.015, bell);
    this.box(0.04, 0.04, 0.2, K, 0, 0.06, 0.12, bell);
    const prof = [[0.001, 0.0], [0.035, 0.0], [0.05, -0.04], [0.065, -0.12], [0.095, -0.17], [0.1, -0.185], [0.001, -0.185]].map(([a, b]) => new T.Vector2(a, b));
    this.put(new T.LatheGeometry(prof, 9), K, 0, 0.04, 0.22, bell);
    this.cyl(0.012, 0.012, 0.03, 6, W, 0, -0.16, 0.22, bell, { ink: false });
    this.cyl(0.006, 0.006, 0.42, 5, W, 0, -0.38, 0.22, bell, { ink: false });
    this.cyl(0.016, 0.012, 0.06, 6, W, 0, -0.6, 0.22, bell);
  }
  buildCalendar() {
    const T = this.THREE, W = '#FFFFFF', K = '#111111', h = this.S / 2;
    const g = new T.Group(); g.position.set(-h + 0.05, 1.5, 1.55); g.rotation.y = Math.PI / 2;   // calendar left off the wall

    this.box(1.6, 1.16, 0.04, K, 0, 0, 0, g);
    const cv = document.createElement('canvas'); cv.width = 1024; cv.height = 720;
    const x = cv.getContext('2d');
    x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, 1024, 720);
    // just the month grid: a heavy header rule and one box per day (September 2026 starts on a Tuesday)
    x.fillStyle = '#111111';
    const L = 36, Wd = 952, top = 112, cw = Wd / 7, rh = 112;
    x.fillRect(L, top + 22, Wd, 5);
    const y0 = top + 30;
    x.lineWidth = 2; x.strokeStyle = '#111111';
    for (let d = 1, c = 1; d <= 30; d++, c++) x.strokeRect(L + (c % 7) * cw, y0 + Math.floor(c / 7) * rh, cw, rh);
    const tex = new T.CanvasTexture(cv); this.registerCanvas(cv, tex); tex.colorSpace = T.SRGBColorSpace; tex.anisotropy = 8;
    const face = new T.Mesh(new T.PlaneGeometry(1.52, 1.07), new T.MeshLambertMaterial({ map: tex }));
    face.position.z = 0.022; face.receiveShadow = true; g.add(face);
    // binder clip + nail at the top
    this.box(0.22, 0.05, 0.03, K, 0, 0.6, 0.03, g);
    const c = new T.Group(); c.position.set(h - 0.06, 1.3, -h + 1.0); c.rotation.y = -Math.PI / 2; this.rightWall.add(c);
    this.wallFrames.push({ o: c, w: 2, a: 0.09 });
    this.box(0.3, 0.42, 0.02, K, 0, 0, 0, c);
    this.box(0.26, 0.36, 0.006, W, 0, -0.02, 0.013, c, { ink: false });
    this.box(0.12, 0.04, 0.02, K, 0, 0.2, 0.02, c, { ink: false });
  }
  buildFlag() {
    const T = this.THREE, K = '#111111', h = this.S / 2;
    const g = new T.Group(); g.position.set(0, 2.45, -h + 0.06); this.backWall.add(g); this.flagG = g;   // centred on wall 2, behind the rack
    this.wallFrames.push({ o: g, w: 1, a: 0.035 });
    // drawn in black & white; the art-direction recolour maps black -> Dark and white -> Light
    this.FLAG_TEXT = '79';
    const cv = document.createElement('canvas'); cv.width = 740; cv.height = 512;
    const mk = document.createElement('canvas'); mk.width = cv.width; mk.height = cv.height;
    const tex = new T.CanvasTexture(cv); tex.colorSpace = T.SRGBColorSpace; tex.anisotropy = 8;
    const mtex = new T.CanvasTexture(mk);
    this.flagArt = { cv, mk, tex, mtex };
    this.drawFlag(this.FLAG_FONTS[0]);
    this.flagArt.rec = this.registerCanvas(cv, tex);
    // cloth: a few soft vertical folds, hanging from a rod
    const W = 1.45, H = 1.0, geo = new T.PlaneGeometry(W, H, 24, 12), pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const px = pos.getX(i), py = pos.getY(i), sag = (H / 2 - py) / H;
      pos.setZ(i, 0.035 + Math.sin(px * 7.5 + 0.6) * 0.02 * (0.4 + sag) + sag * 0.02);
    }
    geo.computeVertexNormals();
    this.flag = { geo, base: Float32Array.from(pos.array), H };
    // the wall faces away from the sun, so on its own the cloth reads darker than the deck's dark rubber;
    // a little self-light from the same texture brings it up to the deck's tone (folds still shade)
    // the lift is masked to the field only, so the numerals stay exactly the palette's Light like the walls
    this.flagMat = new T.MeshLambertMaterial({ map: tex, side: T.DoubleSide, emissive: '#111111', emissiveMap: mtex, emissiveIntensity: 0.42 });
    const cloth = new T.Mesh(geo, this.flagMat); this.flagCloth = cloth;
    cloth.castShadow = true; cloth.receiveShadow = true; cloth.position.y = -H / 2; g.add(cloth);
    // rod and the two nails it hangs from
    this.cyl(0.012, 0.012, W + 0.12, 8, K, 0, 0.0, 0.05, g, { rz: Math.PI / 2 });
    [-1, 1].forEach((sx) => { this.cyl(0.018, 0.018, 0.03, 8, K, sx * (W / 2 + 0.06), 0, 0.05, g, { rz: Math.PI / 2 }); this.cyl(0.006, 0.006, 0.05, 5, K, sx * W * 0.42, 0.0, 0.025, g, { rx: Math.PI / 2, ink: false }); });
  }
  drawFlag(f) {
    const A = this.flagArt, cv = A.cv, x = cv.getContext('2d'), Wc = cv.width, Hc = cv.height;
    const fontAt = (px) => f.weight + ' ' + px + 'px ' + f.css;
    x.font = fontAt(300);
    let m = x.measureText(this.FLAG_TEXT);
    const asc0 = m.actualBoundingBoxAscent || 215, dsc0 = m.actualBoundingBoxDescent || 0;
    const size = Math.round(300 * Math.min(Wc * 0.66 / Math.max(1, m.width), Hc * 0.6 / Math.max(1, asc0 + dsc0)));
    const font = fontAt(size);
    x.font = font; m = x.measureText(this.FLAG_TEXT);
    const asc = m.actualBoundingBoxAscent || size * 0.72, dsc = m.actualBoundingBoxDescent || 0, cy = Hc / 2 + (asc - dsc) / 2;
    x.fillStyle = '#000000'; x.fillRect(0, 0, Wc, Hc);
    x.fillStyle = '#FFFFFF'; x.textAlign = 'center'; x.textBaseline = 'alphabetic';
    x.fillText(this.FLAG_TEXT, Wc / 2, cy);
    const mx = A.mk.getContext('2d');
    mx.fillStyle = '#FFFFFF'; mx.fillRect(0, 0, Wc, Hc);
    mx.fillStyle = '#000000'; mx.strokeStyle = '#000000'; mx.lineWidth = 6; mx.font = font; mx.textAlign = 'center'; mx.textBaseline = 'alphabetic';
    mx.fillText(this.FLAG_TEXT, Wc / 2, cy); mx.strokeText(this.FLAG_TEXT, Wc / 2, cy);
    A.mtex.needsUpdate = true; A.tex.needsUpdate = true;
    if (A.rec) { A.rec.orig = x.getImageData(0, 0, Wc, Hc); this.artKey = null; }   // re-run the palette recolour
  }
  solver(denoms) {
    const Q = 0.25, units = denoms.map((d) => Math.round(d / Q)).sort((a, b) => b - a), memo = new Map();
    return (w) => {
      const n = Math.round(w / Q); if (n < 0) return null; if (memo.has(n)) return memo.get(n);
      const best = new Array(n + 1).fill(Infinity), pick = new Array(n + 1).fill(-1); best[0] = 0;
      for (let i = 1; i <= n; i++) for (const uu of units) if (uu <= i && best[i - uu] + 1 < best[i]) { best[i] = best[i - uu] + 1; pick[i] = uu; }
      let res = null;
      if (best[n] !== Infinity) { res = []; let i = n; while (i > 0) { res.push(pick[i] * Q); i -= pick[i]; } res.sort((a, b) => b - a); }
      memo.set(n, res); return res;
    };
  }
  loadable(lo, hi, plus, bar, denoms, solve) {
    const step = Math.min(...denoms) * 2, cap = Math.max(hi || lo, lo) + step * 4, c = [];
    for (let t = bar; t <= cap + 1e-9; t += step) { const p = solve((t - bar) / 2); if (p) c.push({ total: Math.round(t * 100) / 100, side: p }); }
    if (!c.length) return { total: bar, side: [] };
    const near = (x) => c.reduce((a, b) => (Math.abs(b.total - x) < Math.abs(a.total - x) ? b : a));
    if (plus) return c.find((q) => q.total >= lo - 1e-9) || c[c.length - 1];
    if (hi != null && hi > lo) { const r = c.filter((q) => q.total >= lo - 1e-9 && q.total <= hi + 1e-9); return r.length ? r[r.length - 1] : near((lo + hi) / 2); }
    return near(lo);
  }
  fmtW(w) { return (Math.round(w * 100) / 100).toString(); }
  legend(side) { if (!side.length) return 'empty bar'; const c = {}; side.forEach((w) => { c[w] = (c[w] || 0) + 1; }); return Object.keys(c).map(Number).sort((a, b) => b - a).map((w) => c[w] + '× ' + this.fmtW(w)).join(' + '); }
  ringBell() {
    this.bellT = this.onb ? this.onb.t : 0;
    try {
      const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
      const ac = this.ac || (this.ac = new AC()); if (ac.state === 'suspended') ac.resume();
      const now = ac.currentTime, out = ac.createGain(); out.gain.value = 0.22; out.connect(ac.destination);
      // a small brass bell: a few inharmonic partials with long, staggered decays, struck three times
      [0, 0.32, 0.64].forEach((d, k) => {
        [[1, 1.0, 2.6], [2.76, 0.45, 1.6], [5.4, 0.22, 0.9], [8.9, 0.1, 0.5]].forEach(([r, a, dec]) => {
          const o = ac.createOscillator(), g = ac.createGain();
          o.type = 'sine'; o.frequency.value = 880 * r;
          g.gain.setValueAtTime(0.0001, now + d); g.gain.exponentialRampToValueAtTime(a * (1 - k * 0.2), now + d + 0.008);
          g.gain.exponentialRampToValueAtTime(0.0001, now + d + dec);
          o.connect(g); g.connect(out); o.start(now + d); o.stop(now + d + dec + 0.05);
        });
      });
    } catch (e) {}
  }
  showSet(i, at, opts) {
    if (!this.plan || !this.onb) return;
    const O = this.onb, x = this.plan.flat[i], sp = this.specsFor(this.state.unit);
    const prev = this.barSide || [], next = x.side.slice();
    let c = 0; while (c < prev.length && c < next.length && prev[c] === next[c]) c++;
    const T0 = at != null ? at : O.t, nOff = prev.length - c;
    (this.onBar || []).forEach((m) => { if (!m.out && m.k >= c) { m.out = true; m.outT = T0 + (prev.length - 1 - m.k) * 0.13; } });
    const t1 = T0 + (nOff ? nOff * 0.13 + 0.32 : 0.05);
    let cum = 0;
    next.forEach((w, k) => {
      const s = sp.find((q) => q.kg === w); if (!s) return;
      const xpos = 0.695 * (this.barSX || 1) + cum + s.t / 2; cum += s.t + 0.002;
      if (k < c) return;
      [-1, 1].forEach((sg) => {
        const g = this.plate(s); g.rotation.set(Math.random() * 6.28, 0, Math.PI / 2);
        this.barPose(g, sg * 1.5, 1.265); g.visible = false; this.root.add(g); g.traverse((o) => o.layers.enable(1));
        (this.onBar = this.onBar || []).push({ o: g, sg, k, x: sg * xpos, d: s.d, mass: this.state.unit === 'lb' ? w * 0.4536 : w, inT: t1 + (k - c) * 0.2 + (sg > 0 ? 0.05 : 0) });
      });
    });
    this.barSide = next;
    // what changes from the previous set, in words
    let change = '';
    if (prev.length || (opts && opts.next)) {
      const off = prev.slice(c), on = next.slice(c), L = (a) => a.map((w) => this.fmtW(w)).join(' + ');
      if (!off.length && !on.length) change = 'Same plates as the last set';
      else change = [off.length ? 'Take off ' + L(off) : '', on.length ? (off.length ? 'add ' : 'Add ') + L(on) : ''].filter(Boolean).join(', then ') + ' each side';
    }
    this.setIdx = i; this.setChange = change; this.barAim(i);
  }
  barPose(o, a, y) { const R = this.RACK || [0, 0]; o.position.set(a + R[0], y, -0.77 + R[1]); }
  clank(f) {
    try {
      const ac = this.ac; if (!ac || ac.state !== 'running') return;
      const now = ac.currentTime, out = ac.createGain(); out.gain.value = 0.05 + 0.1 * Math.min(1, f); out.connect(ac.destination);
      [[1650, 0.09], [2430, 0.06], [3900, 0.035]].forEach(([fr, dec]) => {
        const o = ac.createOscillator(), g = ac.createGain(); o.type = 'triangle'; o.frequency.value = fr * (0.92 + Math.random() * 0.12);
        g.gain.setValueAtTime(0.0001, now); g.gain.exponentialRampToValueAtTime(1, now + 0.003); g.gain.exponentialRampToValueAtTime(0.0001, now + dec);
        o.connect(g); g.connect(out); o.start(now); o.stop(now + dec + 0.02);
      });
    } catch (e) {}
  }
  groundY(x, z) { const P = this.PLAT || [0, 0]; return Math.abs(x - P[0]) < 1.22 && Math.abs(z - P[1]) < 1.22 ? 0.05 : 0; }
  initKitWorld() {
    if (this.kitWorld) return;
    const C = window.PlateKit.CANNON; this.CANNON = C;
    const w = new C.World({ gravity: new C.Vec3(0, -9.81, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = 20; w.solver.tolerance = 0.0005;
    const mP = new C.Material('plate'), mG = new C.Material('ground'); this.kitMatPlate = mP;
    w.addContactMaterial(new C.ContactMaterial(mP, mG, { friction: 0.55, restitution: 0.2 }));
    w.addContactMaterial(new C.ContactMaterial(mP, mP, { friction: 0.35, restitution: 0.12 }));
    const fixed = (shape, x, y, z) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(shape); b.position.set(x, y, z); w.addBody(b); return b; };
    const ground = new C.Body({ mass: 0, material: mG }); ground.addShape(new C.Plane()); ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0); w.addBody(ground);
    const PL = this.PLAT || [0, 0], RK = this.RACK || [0, 0], RM = this.ROOM;
    this.kitFloors = [ground, fixed(new C.Box(new C.Vec3(1.22, 0.025, 1.22)), PL[0], 0.025, PL[1])];     // floor + the raised platform
    fixed(new C.Box(new C.Vec3(RM.W / 2 + 0.5, 3, 0.25)), RM.cx, 3, RM.z0 - 0.25); fixed(new C.Box(new C.Vec3(RM.W / 2 + 0.5, 3, 0.25)), RM.cx, 3, RM.z1 + 0.25);
    fixed(new C.Box(new C.Vec3(0.25, 3, RM.D / 2 + 0.5)), RM.x0 - 0.25, 3, RM.cz); fixed(new C.Box(new C.Vec3(0.25, 3, RM.D / 2 + 0.5)), RM.x1 + 0.25, 3, RM.cz);
    // the rack's uprights and feet, so a thrown plate bounces off them
    [-0.62, 0.62].forEach((x) => {
      fixed(new C.Box(new C.Vec3(0.045, 1.175, 0.045)), x + RK[0], 1.175, -0.85 + RK[1]);     // the two uprights
    });
    // drag: a damped spring from the grabbed point to the finger (as in the playground)
    const rel = new C.Vec3(), pw = new C.Vec3(), pv = new C.Vec3(), F = new C.Vec3();
    w.addEventListener('preStep', () => this.kitRollStep());
    w.addEventListener('preStep', () => {
      const g = this.grab; if (!g) return;
      const b = g.body; b.pointToWorldFrame(g.local, pw); pw.vsub(b.position, rel);
      b.angularVelocity.cross(rel, pv); pv.vadd(b.velocity, pv);
      const m = b.mass, k = 260, c = 2 * Math.sqrt(k) * 0.85;
      F.set(m * (k * (g.target.x - pw.x) - c * pv.x), m * (k * (g.target.y - pw.y) - c * pv.y - w.gravity.y), m * (k * (g.target.z - pw.z) - c * pv.z));
      const mx = m * 140, L = F.length(); if (L > mx) F.scale(mx / L, F);
      b.applyForce(F, rel);
    });
    this.kitWorld = w;
  }
  clearKit() {
    if (this.grab) this.grab = null;
    (this.kitItems || []).forEach((it) => { if (it.body) this.kitWorld.removeBody(it.body); });
    if (this.kitG) { this.kitG.parent.remove(this.kitG); this.kitG = null; }
    this.kitItems = null;
  }
  spawnKitPlate(it) {
    const C = this.CANNON, A = this.assets(it.spec), m = it.mass;
    const b = new C.Body({ mass: m, material: this.kitMatPlate, linearDamping: 0.03, angularDamping: 0.06, sleepSpeedLimit: 0.06, sleepTimeLimit: 0.8 });
    b.addShape(new C.Cylinder(A.R, A.R, A.t, 20));
    const Ix = m * (3 * A.R * A.R + A.t * A.t) / 12, Iy = 0.5 * m * A.R * A.R;
    b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
    b.position.set(it.x, 7 + Math.random() * 2.5, it.z);
    b.quaternion.setFromEuler((Math.random() - 0.5) * 0.22, Math.random() * 6.28, (Math.random() - 0.5) * 0.22);
    b.velocity.set(0, -2, 0);
    b.angularVelocity.set((Math.random() - 0.5) * 0.6, (Math.random() - 0.5) * 1.2, (Math.random() - 0.5) * 0.6);
    b.addEventListener('collide', (e) => this.kitImpact(it, e));
    this.kitWorld.addBody(b); it.body = b;
  }
  spawnKitRoll(it) {
    const C = this.CANNON, A = this.assets(it.spec), m = it.mass, R = A.R, f = Math.min(1, m / 25), F = this.kitFrame;
    const dx = F.fx, dz = F.fz, rx = -dz, rz = dx, D = 1.6;            // roll direction (away from the athlete) and its side axis
    const side = (it.shelf + it.k) % 2 ? 1 : -1;
    const sx = it.x - rx * side * R, sz = it.z - rz * side * R;          // the lane is offset so the plate lands centred
    const b = new C.Body({ mass: m, material: this.kitMatPlate, linearDamping: 0.03, angularDamping: 0.06, sleepSpeedLimit: 0.06, sleepTimeLimit: 0.8 });
    b.addShape(new C.Cylinder(R, R, A.t, 20));
    const Ix = m * (3 * R * R + A.t * A.t) / 12, Iy = 0.5 * m * R * R;
    b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
    // stand it on edge: the plate's axis (local y) along the side axis, a hair of lean toward the side it will fall
    const lean = side * (0.004 + 0.012 * (1 - f));
    const q = new C.Quaternion(); q.setFromVectors(new C.Vec3(0, 1, 0), new C.Vec3(rx, 0, rz));
    const ql = new C.Quaternion(); ql.setFromAxisAngle(new C.Vec3(dx, 0, dz), -lean); ql.mult(q, q);
    b.quaternion.copy(q);
    const v0 = (2.6 + 1.6 * (1 - f)) * (0.97 + Math.random() * 0.06);
    b.position.set(sx - dx * D, R + 0.002 + this.groundY(sx - dx * D, sz - dz * D), sz - dz * D);
    b.velocity.set(dx * v0, 0, dz * v0);
    b.angularVelocity.set(dz * v0 / R, 0, -dx * v0 / R);     // rolling without slipping: w = (up x v) / R
    b.addEventListener('collide', (e) => this.kitImpact(it, e));
    this.kitWorld.addBody(b); it.body = b;
    it.roll = { x0: 0, v0, decel: (v0 * v0) / (2 * D), R, side, stab: 0.35 + 0.65 * f, tipSpeed: 0.35, tip: 4, dx, dz, rx, rz, lx: sx, lz: sz, start: [sx - dx * D, sz - dz * D], fallen: false, tipping: false };
    it.pop = { t: 0 };
    this.emitDust(sx - dx * D, sz - dz * D, 30 * Math.sqrt(f) + 6, 1.2, 0.05, 0.5 + 0.6 * f);
  }
  kitRollStep() {
    const C = this.CANNON, Y = this._rY || (this._rY = new C.Vec3(0, 1, 0)), ax = this._rAx || (this._rAx = new C.Vec3());
    const A = this._rA || (this._rA = new C.Vec3()), Tq = this._rT || (this._rT = new C.Vec3()), F = this._rF || (this._rF = new C.Vec3()), P = this._rP || (this._rP = new C.Vec3());
    (this.kitItems || []).forEach((it) => {
      const r = it.roll, b = it.body; if (!r || !b || r.fallen) return;
      if (this.grab && this.grab.it === it) { r.fallen = true; return; }
      b.quaternion.vmult(Y, ax);
      const vx = b.velocity.x, vz = b.velocity.z, sp = Math.hypot(vx, vz);
      if (r.tipping) {
        const k = 14, c = 5;
        F.set(b.mass * (k * (it.x - b.position.x) - c * vx), 0, b.mass * (k * (it.z - b.position.z) - c * vz));
        b.applyForce(F, P.set(0, 0, 0));
      }
      if (Math.abs(ax.y) > 0.8) { if (sp < 0.5) r.fallen = true; return; }
      if (Math.abs(ax.y) > 0.6) return;
      const along = (b.position.x - r.start[0]) * r.dx + (b.position.z - r.start[1]) * r.dz;
      const vAlong = vx * r.dx + vz * r.dz, vSide = vx * r.rx + vz * r.rz;
      const off = (b.position.x - r.lx) * r.rx + (b.position.z - r.lz) * r.rz;
      const vt = Math.sqrt(Math.max(0, r.v0 * r.v0 - 2 * r.decel * along));
      if (vt > r.tipSpeed) {
        const fa = b.mass * 5 * (vt - vAlong), fs = b.mass * (-10 * off - 5 * vSide);
        F.set(r.dx * fa + r.rx * fs, 0, r.dz * fa + r.rz * fs);
        b.applyForce(F, P.set(0, 0, 0));
        ax.cross(Y, A);
        const wa = b.angularVelocity.dot(A);
        Tq.copy(A); Tq.scale(b.inertia.x * (-r.stab * 40 * ax.y - r.stab * 8 * wa), Tq);
        b.applyTorque(Tq);
      } else {
        r.tipping = true;
        F.set(r.rx * r.side * b.mass * r.tip, 0, r.rz * r.side * b.mass * r.tip);
        b.wakeUp();
        b.applyForce(F, P.set(0, r.R * 0.9, 0));
      }
    });
  }
  kitImpact(it, e) {
    const v = Math.abs(e.contact.getImpactVelocityAlongNormal()); if (v < 1.2) return;
    if (this.kitFloors.indexOf(e.body) < 0) return;
    const f = it.mass / 25, hit = Math.min(1, v / 12), b = it.body;
    this.shakeKick(0.16 * f * (0.35 + 0.65 * hit));
    it.squash = { t: 0, amp: 0.22 * Math.min(1, (0.3 + 0.7 * hit) * (0.25 + 0.75 * Math.sqrt(f))) };
    const k = f * (0.45 + 0.55 * hit), sm = 0.2 + 1.25 * f;
    const ay = b.quaternion.vmult(new this.CANNON.Vec3(0, 1, 0));
    if (Math.abs(ay.y) > 0.7) this.emitDust(b.position.x, b.position.z, 6 * f + 110 * k, 0.4 * f + 2.8 * k, it.d / 2, sm);
    else { const c = e.contact, ri = c.bi === b ? c.ri : c.rj; this.emitDust(b.position.x + ri.x, b.position.z + ri.z, 4 * f + 60 * k, 0.3 * f + 2.2 * k, 0.03 + 0.06 * f, sm); }
  }
  buildKit(plan) {
    const T = this.THREE, u = this.state.unit, sp = this.specsFor(u);
    this.initKitWorld(); this.clearKit();
    const g = new T.Group(); this.root.add(g); this.kitG = g; this.kitItems = []; this.kitLabels = [];
    const SW = 2.05, GAP = 0.08, LH = 0.02;
    const groups = plan.kit.map((row) => ({ row, s: sp.find((q) => q.kg === row.w) })).filter((r) => r.s).sort((a, b) => a.row.w - b.row.w);
    groups.forEach((gr) => { gr.pw = gr.s.d + 0.06; gr.pl = gr.row.qty * gr.pw - 0.06; gr.w = Math.max(gr.pl, 0.36); });
    const shelves = []; let cur = null;
    groups.forEach((gr) => {
      if (!cur || (cur.w + GAP + gr.w > SW && cur.gs.length)) { cur = { w: -GAP, D: 0, gs: [] }; shelves.push(cur); }
      gr.u0 = cur.w + GAP; cur.w += GAP + gr.w; cur.D = Math.max(cur.D, gr.s.d); cur.gs.push(gr);
    });
    const depth = shelves.reduce((a, sh) => a + LH + 0.05 + sh.D + 0.12, -0.12);
    // laid out in the athlete's view: v runs away from them, u to their right; labels face their eye
    const K = this.SHOTS.kit, fl = Math.hypot(K.T[0] - K.P[0], K.T[2] - K.P[2]), fx = (K.T[0] - K.P[0]) / fl, fz = (K.T[2] - K.P[2]) / fl, th = Math.atan2(-fx, -fz);
    const C0 = this.KIT_C || [K.T[0], K.T[2]], at = (uu, vv) => [C0[0] - fz * uu + fx * vv, C0[1] + fx * uu + fz * vv];
    this.kitFrame = { fx, fz };
    let z = -depth / 2, n = 0;
    shelves.forEach((sh, si) => {
      z += LH + 0.05; const zc = z + sh.D / 2;
      sh.gs.forEach((gr) => {
        const s = gr.s, uL = -sh.w / 2 + gr.u0 + (gr.w - gr.pl) / 2;    // screen-right is -x
        for (let i = 0; i < gr.row.qty; i++) {
          const [x, zz] = at(uL + i * gr.pw + s.d / 2, zc), p = this.plate(s);
          p.visible = false; g.add(p);
          this.kitItems.push({ o: p, spec: s, x, z: zz, d: s.d, w: gr.row.w, mass: u === 'lb' ? gr.row.w * 0.4536 : gr.row.w, shelf: si, k: i });
        }
        // (no painted count on the floor: the panel lists the kit)
      });
      z += sh.D + 0.12;
    });
    if (this.kitMode === 'roll') {
      // rolled in: the farthest row first, so nothing rolls through plates that have already landed
      const last = shelves.length - 1;
      this.kitItems.forEach((it) => { it.t0 = 0.4 + (last - it.shelf) * 0.55; });
      this.kitDone = 0.4 + shelves.length * 0.55 + 2.2;
    } else {
      // heaviest first, like the playground
      this.kitItems.slice().sort((a, b) => b.w - a.w).forEach((it) => { it.t0 = 0.7 + n * 0.16; n++; });
      this.kitDone = 0.7 + n * 0.16 + 1.4;
    }
  }
  runWorkout(dt, t) {
    const O = this.onb, cl = (q) => Math.min(1, Math.max(0, q));
    const bounce = (q) => { q = cl(q); const n = 7.5625, d = 2.75;
      if (q < 1 / d) return n * q * q; if (q < 2 / d) return n * (q -= 1.5 / d) * q + 0.75;
      if (q < 2.5 / d) return n * (q -= 2.25 / d) * q + 0.9375; return n * (q -= 2.625 / d) * q + 0.984375; };
    const once = (key, fn) => { if (!O.fired[key]) { O.fired[key] = 1; fn(); } };
    // first person on the kit: a wider lens, back to normal elsewhere
    if (this.fanBlades && this.fanG.visible) this.fanBlades.rotation.z -= dt * 14;
    // bell swing
    if (this.bellT != null) { const sb = t - this.bellT; this.bellG.rotation.z = sb < 0 ? 0 : 0.42 * Math.exp(-sb * 1.3) * Math.sin(sb * 11); }
    // PR board filled: a bright pulse on the board, the bell rings, then on to the whiteboard
    if (O.phase === 'prFilled') {
      const s = t - O.pfT;
      if (s > 0.9) this.goToBoard();
    }
    // whiteboard waits for a tap, glowing
    const wbOn = O.phase === 'wb' || O.phase === 'wodForm' ? 1 : 0;
    this.wbFade = (this.wbFade || 0) + (wbOn - (this.wbFade || 0)) * (1 - Math.exp(-dt * 4));
    this.wbGlowMat.opacity = this.wbFade * (0.2 + 0.4 * (0.5 + 0.5 * Math.sin(t * 2.6)));
    // back home: the workout's plates are put away, popping out one after another
    if (this.kitOutT != null && this.kitItems) {
      const s0 = t - this.kitOutT; let all = true;
      this.kitItems.forEach((it, i) => { const q = cl((s0 - i * 0.04) / 0.3); it.o.scale.setScalar(Math.max(0.001, 1 - q * q)); if (q < 1) all = false; });
      this.kitLabels.forEach((l) => { l.material.opacity = Math.min(l.material.opacity, 1 - cl(s0 / 0.3)); });
      if (all) { this.clearKit(); this.kitOutT = null; }
    }
    // the kit: plates spawn high above their spots and the rigid-body world does the rest
    if (this.kitItems && O.kt0 != null) {
      const kt = t - O.kt0;
      if (this.kitOutT == null) this.kitItems.forEach((it) => { if (!it.body && kt >= it.t0) { if (this.kitMode === 'roll') this.spawnKitRoll(it); else this.spawnKitPlate(it); } });
      this.kitWorld.step(1 / 120, Math.min(dt, 1 / 20), 10);
      this.kitItems.forEach((it) => {
        const b = it.body; if (!b) return;
        if (b.position.y < -2) { b.position.set(it.x, 4, it.z); b.velocity.set(0, 0, 0); b.angularVelocity.set(0, 0, 0); }
        it.o.visible = true;
        it.o.position.set(b.position.x, b.position.y, b.position.z);
        it.o.quaternion.set(b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w);
        if (it.pop && this.kitOutT == null) {
          it.pop.t += dt; const u2 = Math.min(1, it.pop.t / 0.32), k3 = 1 + 2.9 * Math.pow(u2 - 1, 3) + 1.9 * Math.pow(u2 - 1, 2);
          it.o.scale.setScalar(Math.max(0.001, k3)); if (u2 >= 1) { it.pop = null; it.o.scale.setScalar(1); }
        }
        if (it.squash && this.kitOutT == null) {
          it.squash.t += dt; const q = it.squash.t, a = it.squash.amp * Math.exp(-q * 9) * Math.cos(q * 34);
          it.o.scale.set(1 + a * 0.45, 1 - a, 1 + a * 0.45);
          if (q > 0.6) { it.squash = null; it.o.scale.set(1, 1, 1); }
        }
      });
      if (this.kitLabels && this.kitOutT == null) this.kitLabels.forEach((l, i) => { l.material.opacity = cl((kt - this.kitDone - i * 0.1) / 0.4); });
    }
    // the rack drops onto the platform the first time we go to the sets
    if (O.rackT != null) {
      const q = (t - O.rackT) / 0.75;
      this.rackG.position.y = q < 0 ? 40 : (1 - bounce(q)) * 7;
      if (q >= 1 / 2.75) once('rackLand', () => {
        this.shakeKick(0.6); this.sqA = 0.25; this.sqT = 0;
        const RK = this.RACK || [0, 0];
        [[-0.62, -0.85], [0.62, -0.85]].forEach(([x, z]) => this.emitDust(x + RK[0], z + RK[1], 44, 1.9, 0.1, 1.0));
        this.emitDust(RK[0], -0.85 + RK[1], 50, 2.2, 0.6, 1.0);
      });
    }
    // plates slide on the sleeves and seat with a clank; old ones slide off the end and drop to the floor
    if (this.onBar) {
      let bump = 0;
      this.onBar = this.onBar.filter((m) => {
        if (m.out) {
          const s = t - m.outT; if (s < 0) return true;
          const q = cl(s / 0.32), ex = m.sg * (1.25 + m.d / 2 * 0.2);
          if (s < 0.32) { this.barPose(m.o, m.x + (ex - m.x) * q * q, 1.265); return true; }
          // off the sleeve: fall, turning onto its face, then sink away
          const f = s - 0.32, y = Math.max(0.05 + m.d / 2 * Math.cos(Math.min(1, f * 2.4) * 1.2), 1.265 - 4.9 * f * f);
          this.barPose(m.o, ex + m.sg * f * 0.5, y);
          m.o.rotation.z = Math.PI / 2 + m.sg * Math.min(1, f * 2.4) * 1.2;
          if (!m.land && y <= 0.05 + m.d / 2 + 0.01 && f > 0.2) { m.land = t; const ff = m.mass / 25; this.emitDust(m.o.position.x, m.o.position.z, 6 + 60 * ff, 0.4 + 2 * ff, m.d / 2, 0.2 + ff); this.shakeKick(0.04 * ff); }
          if (m.land) { const k2 = cl((t - m.land - 0.35) / 0.35); m.o.scale.setScalar(Math.max(0.001, 1 - k2)); if (k2 >= 1) { this.root.remove(m.o); return false; } }
          return true;
        }
        const q = (t - m.inT) / 0.34; m.o.visible = q >= 0;
        if (q < 0) return true;
        const e = 1 - Math.pow(1 - cl(q), 3), st = m.sg * 1.5;
        let px = st + (m.x - st) * e;
        if (q >= 1 && !m.seat) { m.seat = t; const f = m.mass / 25; this.clank(f + 0.15); bump = Math.max(bump, 0.02 + 0.05 * f); }
        if (m.seat) px = m.x + m.sg * 0.012 * Math.exp(-(t - m.seat) * 14) * Math.sin((t - m.seat) * 40);
        this.barPose(m.o, px, 1.265);
        return true;
      });
      if (bump) this.shakeKick(bump);
    }
    if (O.phase === 'complete') { this.spinIdle = true; }
  }
  drawPR(data) {
    const A = this.prArt, cv = A.cv, x = cv.getContext('2d'), W = cv.width, H = cv.height;
    const done = () => { A.rec.orig = x.getImageData(0, 0, W, H); A.tex.needsUpdate = true; this.artKey = null; };
    if (!data) { x.putImageData(A.blank, 0, 0); done(); return; }
    if (data.photo) {
      const img = new Image();
      img.onload = () => {
        const sc = Math.max(W / img.width, H / img.height), w = img.width * sc, h = img.height * sc;
        x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, W, H);
        x.drawImage(img, (W - w) / 2, (H - h) / 2, w, h);
        // to grey with a little extra contrast, so the palette recolour reads cleanly
        const id = x.getImageData(0, 0, W, H), d = id.data;
        for (let i = 0; i < d.length; i += 4) {
          let l = (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255;
          l = Math.min(1, Math.max(0, (l - 0.5) * 1.35 + 0.55)) * 255;
          d[i] = d[i + 1] = d[i + 2] = l;
        }
        x.putImageData(id, 0, 0); done();
      };
      img.src = data.photo;
      return;
    }
    if (data.prs) {
      // one lifter's board: lift on the left, best weight on the right
      const F2 = 'Helvetica, "Helvetica Neue", Arial, sans-serif', u2 = this.state.unit.toUpperCase();
      x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, W, H);
      x.fillStyle = '#111111'; x.textBaseline = 'middle';
      x.font = '700 58px ' + F2; x.fillText("My PR's", 40, 62);
      x.font = '700 26px ' + F2; x.textAlign = 'right'; x.fillText(u2, 984, 66); x.textAlign = 'left';
      x.fillRect(30, 112, 964, 6);
      x.lineWidth = 2; x.strokeStyle = '#111111';
      data.prs.slice(0, 8).forEach((r, i) => {
        const y = 150 + i * 64;
        x.font = '700 34px ' + F2; x.fillText(r.lift.toUpperCase(), 40, y + 4);
        x.font = '400 40px ' + F2; x.textAlign = 'right'; x.fillText(r.value, 984, y + 4); x.textAlign = 'left';
        x.beginPath(); x.moveTo(30, y + 34); x.lineTo(994, y + 34); x.stroke();
      });
      done(); return;
    }
    // typed table: heading, column heads in the box's unit, one row per athlete
    const F = 'Helvetica, "Helvetica Neue", Arial, sans-serif', u = this.state.unit.toUpperCase();
    x.fillStyle = '#FFFFFF'; x.fillRect(0, 0, W, H);
    x.fillStyle = '#111111'; x.textBaseline = 'middle';
    x.font = '700 58px ' + F; x.fillText('PR BOARD', 40, 62);
    x.font = '700 24px ' + F; x.textAlign = 'right'; x.fillText(u, 984, 66); x.textAlign = 'left';
    const cols = [['NAME', 40], ['SNATCH', 360], ['C&J', 520], ['B. SQUAT', 660], ['F. SQUAT', 830]];
    x.font = '700 28px ' + F; cols.forEach(([t, cx]) => x.fillText(t, cx, 140));
    x.fillRect(30, 164, 964, 6);
    x.lineWidth = 2; x.strokeStyle = '#111111';
    for (let r = 0; r < 8; r++) { const y = 224 + r * 60; x.beginPath(); x.moveTo(30, y); x.lineTo(994, y); x.stroke(); }
    cols.slice(1).forEach(([, cx]) => { x.beginPath(); x.moveTo(cx - 18, 112); x.lineTo(cx - 18, 644); x.stroke(); });
    data.rows.slice(0, 8).forEach((r, i) => {
      const y = 196 + i * 60;
      x.font = '700 30px ' + F; x.fillText((r.name || '—').toUpperCase().slice(0, 16), 40, y);
      x.font = '400 32px ' + F;
      ['sn', 'cj', 'bs', 'fs'].forEach((k, j) => x.fillText(r[k] || '—', cols[j + 1][1], y));
    });
    done();
  }
  poseGhostFlag(e, t) {
    const F = this.ghostCloth, pos = F.geo.attributes.position, b = F.base, H = F.H;
    for (let i = 0; i < pos.count; i++) {
      const x = b[i * 3], y = b[i * 3 + 1], z = b[i * 3 + 2], sag = (H / 2 - y) / H, sg = Math.pow(sag, 1.25);
      pos.setXYZ(i, x + e * 0.03 * sag * Math.sin(t * 1.7 + 0.8), y, z + e * (0.07 * sg * Math.sin(x * 4.5 - t * 2.2 + y * 2) + 0.02 * sag * Math.sin(x * 9 + t * 3.1)));
    }
    pos.needsUpdate = true; F.geo.computeVertexNormals();
  }
  poseFlag(e, t) {
    const F = this.flag, pos = F.geo.attributes.position, b = F.base, H = F.H;
    for (let i = 0; i < pos.count; i++) {
      const x = b[i * 3], y = b[i * 3 + 1], z = b[i * 3 + 2], sag = (H / 2 - y) / H, sg = Math.pow(sag, 1.25);
      pos.setXYZ(i,
        x + e * 0.035 * sag * Math.sin(t * 4.6 + 0.8),
        y + e * 0.025 * sag * Math.sin(t * 6.3 + x * 3.1),
        z + e * (0.1 * sg * Math.sin(x * 5.2 - t * 7.4 + y * 2.4) + 0.035 * sag * Math.sin(x * 11.5 + t * 12.5 + y * 6)));
    }
    pos.needsUpdate = true; F.geo.computeVertexNormals();
  }
  buildPlatePiles(unit) {
    const T = this.THREE, h = this.S / 2, specs = this.specsFor(unit || 'kg'), K = '#111111';
    (this.plateItems || []).forEach((it) => { if (it.o.parent) it.o.parent.remove(it.o); });
    this.plateItems = []; this.pileUnit = unit || 'kg';
    if (this.shelfG) this.shelfG.parent.remove(this.shelfG);
    const sg = new T.Group(); this.root.add(sg); this.shelfG = sg;
    const SH = this.SHELF_P || [0.06, 0, 2.32], Z0 = -3.5 + SH[2], Z1 = -1.2 + SH[2], xw = -h + SH[0], YO = SH[1];
    let pileNo = 0;
    const row = (list, y, counts, pegLen) => {
      if (!list.length) return;
      this.box(0.035, 0.09, Z1 - Z0 + 0.3, K, xw + 0.0175, y, (Z0 + Z1) / 2, sg);                       // the rail
      list.forEach((s, j) => {
        // heaviest on the left as you face the wall (+z)
        const z = Z1 - (Z1 - Z0) * (j + 0.5) / list.length, n = counts[j % counts.length], k = pileNo++;
        this.cyl(0.022, 0.022, pegLen, 10, K, xw + 0.035 + pegLen / 2, y, z, sg, { rz: Math.PI / 2 });   // the peg
        this.cyl(0.045, 0.045, 0.02, 12, K, xw + 0.045, y, z, sg, { rz: Math.PI / 2 });                  // its base plate
        for (let i = 0; i < n; i++) {
          const p = this.plate(s), x = xw + 0.06 + i * (s.t + 0.003) + s.t / 2;
          const it = { o: p, spec: s, y, k, i, n, bx: x, bz: z, kg: s.kg, mass: s.unit === 'LB' ? s.kg * 0.4536 : s.kg, d: s.d, t: s.t, ry: Math.random() * Math.PI * 2 };
          this.root.add(p); this.plateItems.push(it); this.posePlate(it);
        }
      });
    };
    const bumpers = specs.filter((sp) => sp.kind === 'bumper'), change = specs.filter((sp) => sp.kind !== 'bumper');
    row(bumpers, 0.6 + YO, [6, 5, 6, 5], 0.42);
    row(change, 1.3 + YO, [8, 6, 8, 6, 8, 6], 0.26);
  }
  popPiles(rt, rank, have) {
    this.plateItems.forEach((pi) => {
      if (have.indexOf(pi.kg) < 0) { pi.o.visible = false; return; }
      const q = (rt - 0.5 - rank[pi.k] * 0.11 - pi.i * 0.03) / 0.3, c = Math.min(1, Math.max(0, q));
      pi.o.visible = q > 0;
      const sc = q >= 1 ? 1 : 1 + 2.8 * Math.pow(c - 1, 3) + 1.8 * Math.pow(c - 1, 2);
      pi.o.scale.setScalar(Math.max(0.001, sc));
      this.posePlate(pi);
    });
  }
  buildGhosts() {
    const T = this.THREE, h = this.S / 2;
    const g = new T.Group(); this.root.add(g); this.ghostG = g;
    this.ghostMat = new T.MeshLambertMaterial({ color: '#FFFFFF', transparent: true, opacity: 0.5, emissive: '#FFF4DC', emissiveIntensity: 0.4 });
    this.ghostInk = new T.LineBasicMaterial({ color: '#4A3426', transparent: true, opacity: 0 });   // kept for the fade code; ghosts have no outline
    this.plateItems.forEach((it) => {
      const A = this.assets(it.spec), pg = new T.Group();
      [A.ringTop, A.ringBot, A.side, A.hubTop, A.hubBot, A.hubOut].forEach((geo) => { const m = new T.Mesh(geo, this.ghostMat); m.renderOrder = 2; pg.add(m); });
      pg.position.copy(it.o.position); pg.rotation.copy(it.o.rotation);
      g.add(pg);
    });
    // soft additive halos so the ghosts glow, as if asking to be tapped
    const gc = document.createElement('canvas'); gc.width = gc.height = 128;
    const gx = gc.getContext('2d'), gr = gx.createRadialGradient(64, 64, 0, 64, 64, 64);
    gr.addColorStop(0, 'rgba(255,248,226,0.9)'); gr.addColorStop(0.45, 'rgba(255,240,205,0.35)'); gr.addColorStop(1, 'rgba(255,240,205,0)');
    gx.fillStyle = gr; gx.fillRect(0, 0, 128, 128);
    this.glowMat = new T.SpriteMaterial({ map: new T.CanvasTexture(gc), transparent: true, depthWrite: false, blending: T.AdditiveBlending, opacity: 0 });
    const pegs = {};
    this.plateItems.forEach((it) => { if (!pegs[it.k] || it.bx > pegs[it.k].x) pegs[it.k] = { x: it.bx, y: it.y, z: it.bz, r: it.d / 2 }; });
    Object.keys(pegs).forEach((k) => {
      const q = pegs[k], sp = new T.Sprite(this.glowMat);
      sp.position.set(q.x + 0.12, q.y, q.z); sp.scale.set(q.r * 3.4, q.r * 3.4, 1); sp.renderOrder = 3;
      g.add(sp);
    });
    // a ghost flag where the real one will hang, swaying gently
    const fg = new T.Group(); fg.position.copy(this.flagG.position); fg.rotation.copy(this.flagG.rotation); this.backWall.add(fg); this.ghostFlagG = fg;
    const FW = 1.45, FH = 1.0, fgeo = new T.PlaneGeometry(FW, FH, 24, 12), fp = fgeo.attributes.position;
    for (let i = 0; i < fp.count; i++) { const px = fp.getX(i), py = fp.getY(i), sag = (FH / 2 - py) / FH; fp.setZ(i, 0.035 + Math.sin(px * 7.5 + 0.6) * 0.02 * (0.4 + sag) + sag * 0.02); }
    fgeo.computeVertexNormals();
    this.ghostCloth = { geo: fgeo, base: Float32Array.from(fp.array), H: FH };
    this.ghostFlagMat = new T.MeshLambertMaterial({ color: '#FFFFFF', transparent: true, opacity: 0.5, side: T.DoubleSide, emissive: '#FFF4DC', emissiveIntensity: 0.4, depthWrite: false });
    const gcloth = new T.Mesh(fgeo, this.ghostFlagMat); gcloth.position.y = -FH / 2; fg.add(gcloth);
    const rod = new T.Mesh(new T.CylinderGeometry(0.012, 0.012, FW + 0.12, 8).rotateZ(Math.PI / 2), this.ghostMat); rod.position.set(0, 0, 0.05); fg.add(rod);
    const fglow = new T.Sprite(this.glowMat); fglow.position.set(0, -FH / 2, 0.12); fglow.scale.set(FW * 1.6, FH * 1.7, 1); fg.add(fglow);
    fg.visible = false;
    // the PR board's own glow, for its tap moment
    this.prGlowMat = this.glowMat.clone(); this.prGlowMat.opacity = 0;
    const pglow = new T.Sprite(this.prGlowMat); pglow.position.set(0, 0, 0.15); pglow.scale.set(2.6, 1.9, 1); this.prG.add(pglow); this.prGlow = pglow;
    this.wbGlowMat = this.glowMat.clone(); this.wbGlowMat.opacity = 0;
    const wglow = new T.Sprite(this.wbGlowMat); wglow.position.set(0, 1.25, 0.25); wglow.scale.set(2.3, 1.7, 1); this.boardG.add(wglow);
    const hit = new T.Mesh(new T.BoxGeometry(1.6, 1.6, 4.4), new T.MeshBasicMaterial({ visible: false }));
    hit.position.set(-h + 0.7, 0.8, -h + 2.25); g.add(hit); this.ghostHit = hit;
    g.visible = false;
  }
  posePlate(it) {
    it.o.position.set(it.bx, it.y, it.bz);
    it.o.rotation.set(it.ry, 0, -Math.PI / 2);     // face to the room (+x), threaded on its peg
  }
  plate(spec) {
    const T = this.THREE, A = this.assets(spec), g = new T.Group();
    [[A.ringTop, A.face], [A.ringBot, A.face], [A.side, A.rim], [A.hubTop, A.chrome], [A.hubBot, A.chrome], [A.hubOut, A.chrome], [A.hubIn, A.chromeIn]]
      .forEach(([geo, mat]) => { const m = new T.Mesh(geo, mat); m.castShadow = true; m.receiveShadow = true; g.add(m); });
    return g;
  }
  buildBarsAndChalk() {
    const T = this.THREE, W = '#FFFFFF', K = '#111111', h = this.S / 2;
    // wall-mounted bar rack: two brackets with three hooks each, bars resting horizontally
    const hd = new T.Group(); hd.position.set(-h, 0, 1.75); hd.rotation.y = Math.PI / 2; this.root.add(hd); this.barsG = hd;
    const levels = [0.55, 0.85, 1.15];
    [-0.52, 0.52].forEach((bx) => {
      this.box(0.07, 0.86, 0.03, K, bx, 0.85, 0.015, hd);
      levels.forEach((y) => {
        this.box(0.05, 0.03, 0.16, K, bx, y - 0.035, 0.1, hd);
        this.box(0.05, 0.05, 0.025, K, bx, y - 0.01, 0.17, hd, { ink: false });
      });
    });
    [[2.2, 0.0], [2.2, 0.05], [2.01, -0.03]].forEach(([L, dx], i) => {
      const bar = new T.Group(); bar.position.set(dx, levels[i], 0.12); hd.add(bar);
      const sh = L - 0.9;
      this.cyl(0.014, 0.014, sh, 8, K, 0, 0, 0, bar, { rz: Math.PI / 2 });
      [-1, 1].forEach((sg) => {
        this.cyl(0.04, 0.04, 0.03, 10, K, sg * (sh / 2 + 0.015), 0, 0, bar, { rz: Math.PI / 2 });
        this.cyl(0.025, 0.025, 0.42, 10, W, sg * (sh / 2 + 0.24), 0, 0, bar, { rz: Math.PI / 2 });
      });
    });
    // chalk bucket
    this.CHALK = [-h + 0.4, 0.35];
    const c = new T.Group(); c.position.set(this.CHALK[0], 0, this.CHALK[1]); this.root.add(c); this.chalkG = c;
    // open-topped bucket (double-sided so you can see inside)
    const bk = new T.MeshLambertMaterial({ color: K, flatShading: true, side: T.DoubleSide }); (this.extraDark = this.extraDark || []).push(bk);
    this.put(new T.CylinderGeometry(0.17, 0.14, 0.3, 9, 1, true), K, 0, 0.15, 0, c).material = bk;
    this.put(new T.CylinderGeometry(0.175, 0.175, 0.025, 9, 1, true), K, 0, 0.3, 0, c).material = bk;
    this.cyl(0.14, 0.14, 0.01, 9, K, 0, 0.005, 0, c, { ink: false });
    // chalk: a low-poly dune of white powder heaped inside the bucket
    const prof = [[0.148, 0.0], [0.125, 0.03], [0.09, 0.064], [0.045, 0.1], [0.0, 0.115]].map(([r, y]) => new T.Vector2(r, y));
    const dune = new T.LatheGeometry(prof, 11);
    const pos = dune.attributes.position, v = new T.Vector3();
    for (let i = 0; i < pos.count; i++) {
      v.fromBufferAttribute(pos, i);
      const r = Math.hypot(v.x, v.z), inner = 1 - r / 0.148;
      const key = Math.round(v.x * 997) * 13 + Math.round(v.z * 991) * 7 + Math.round(v.y * 983);
      const n = Math.sin(key * 12.9898) * 43758.5453; const j = (n - Math.floor(n)) - 0.5;
      v.x += inner * 0.03; v.z -= inner * 0.018;                     // the peak leans off-centre, like a dune
      v.y += j * 0.03 * inner;
      pos.setXYZ(i, v.x, v.y, v.z);
    }
    dune.computeVertexNormals();
    this.put(dune, W, 0, 0.245, 0, c, { cast: false });
    // powder dusted on the rim
    [[0.6, 0.05], [2.4, 0.04], [4.4, 0.06]].forEach(([a, r]) => this.put(new T.CylinderGeometry(r, r, 0.006, 6, 1), W, Math.cos(a) * 0.16, 0.315, Math.sin(a) * 0.16, c, { ink: false, cast: false }));
    const handle = new T.Mesh(new T.TorusGeometry(0.17, 0.008, 4, 10, Math.PI), this.m(K));
    handle.position.y = 0.3; handle.rotation.y = 0.6; c.add(handle);
  }
  faceTexture(spec) {
    const THREE = this.THREE;
    const S = 512, c = document.createElement('canvas');
    c.width = c.height = S;
    const g = c.getContext('2d');
    const cx = S / 2, r = S / 2;
    const base = new THREE.Color(spec.color);
    const dark = base.clone().offsetHSL(0, 0, -0.08).getStyle();
    const darker = base.clone().offsetHSL(0, 0, -0.14).getStyle();
    g.fillStyle = spec.color; g.fillRect(0, 0, S, S);
    g.strokeStyle = dark; g.lineWidth = 14;
    g.beginPath(); g.arc(cx, cx, r * 0.955, 0, Math.PI * 2); g.stroke();
    g.strokeStyle = darker; g.globalAlpha = 0.55; g.lineWidth = 3;
    g.beginPath(); g.arc(cx, cx, r * 0.905, 0, Math.PI * 2); g.stroke();
    g.beginPath(); g.arc(cx, cx, r * (spec.kind === 'bumper' ? 0.40 : 0.52), 0, Math.PI * 2); g.stroke();
    g.globalAlpha = 1;
    g.fillStyle = spec.ink;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    if (spec.kind === 'bumper') {
      g.font = '700 104px Helvetica, "Helvetica Neue", Arial, sans-serif';
      g.fillText(spec.label, cx, cx - r * 0.66);
      g.font = '700 60px Helvetica, "Helvetica Neue", Arial, sans-serif';
      g.fillText(spec.unit || 'KG', cx, cx + r * 0.66);
      g.font = '600 26px Helvetica, "Helvetica Neue", Arial, sans-serif';
      g.save(); g.translate(cx - r * 0.66, cx); g.rotate(-Math.PI / 2); g.fillText('COMPETITION', 0, 0); g.restore();
      g.save(); g.translate(cx + r * 0.66, cx); g.rotate(Math.PI / 2); g.fillText('Ø 450 MM', 0, 0); g.restore();
    } else {
      g.font = '700 118px Helvetica, "Helvetica Neue", Arial, sans-serif';
      g.fillText(spec.label, cx, cx - r * 0.73);
      g.font = '700 70px Helvetica, "Helvetica Neue", Arial, sans-serif';
      g.fillText(spec.unit || 'KG', cx, cx + r * 0.75);
    }
    const tex = new THREE.CanvasTexture(c);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = 8;
    return tex;
  }
  assets(spec) {
    const segs = this.state.plateSegs || 80, low = segs <= 30;
    const key = (spec.unit || 'KG') + spec.kg + '_' + segs;
    if (this.cache[key]) return this.cache[key];
    const THREE = this.THREE;
    const R = spec.d / 2, t = spec.t;
    const holeR = 0.0255;
    const bumper = spec.kind === 'bumper';
    const hubR = bumper ? 0.068 : Math.min(0.046, R * 0.46);
    const hubH = t + 0.005;
    const face = new THREE.MeshStandardMaterial({ map: this.faceTexture(spec), roughness: bumper ? 0.8 : 0.38, metalness: bumper ? 0 : 0.2 });
    // rim: plate colour with softly darkened edges, so stacked plates of the same colour read as separate discs
    const rc = document.createElement('canvas'); rc.width = 4; rc.height = 128;
    const rg = rc.getContext('2d');
    const base = new THREE.Color(spec.color).offsetHSL(0, 0, -0.05), edge = base.clone().offsetHSL(0, 0, -0.16);
    const grad = rg.createLinearGradient(0, 0, 0, 128);
    grad.addColorStop(0, edge.getStyle()); grad.addColorStop(0.1, base.getStyle());
    grad.addColorStop(0.9, base.getStyle()); grad.addColorStop(1, edge.getStyle());
    rg.fillStyle = grad; rg.fillRect(0, 0, 4, 128);
    const rimTex = new THREE.CanvasTexture(rc); rimTex.colorSpace = THREE.SRGBColorSpace;
    const rim = new THREE.MeshStandardMaterial({ map: rimTex, roughness: bumper ? 0.85 : 0.4, metalness: bumper ? 0 : 0.2, flatShading: low });
    const chrome = new THREE.MeshStandardMaterial({ color: '#D8DCE1', metalness: 1, roughness: 0.2 });
    const chromeIn = chrome.clone(); chromeIn.side = THREE.BackSide; chromeIn.color = new THREE.Color('#9AA1AA');
    const a = {
      R, t, face, rim, chrome, chromeIn,
      ringTop: new THREE.RingGeometry(hubR * 0.98, R, segs, 1).rotateX(-Math.PI / 2).translate(0, t / 2, 0),
      ringBot: new THREE.RingGeometry(hubR * 0.98, R, segs, 1).rotateX(Math.PI / 2).translate(0, -t / 2, 0),
      side: new THREE.CylinderGeometry(R, R, t, segs, 1, true),
      hubTop: new THREE.RingGeometry(holeR, hubR, Math.max(8, Math.round(segs * 0.6)), 1).rotateX(-Math.PI / 2).translate(0, hubH / 2, 0),
      hubBot: new THREE.RingGeometry(holeR, hubR, Math.max(8, Math.round(segs * 0.6)), 1).rotateX(Math.PI / 2).translate(0, -hubH / 2, 0),
      hubOut: new THREE.CylinderGeometry(hubR, hubR, hubH, Math.max(8, Math.round(segs * 0.6)), 1, true),
      hubIn: new THREE.CylinderGeometry(holeR, holeR, hubH, Math.max(6, Math.round(segs * 0.4)), 1, true)
    };
    this.cache[key] = a;
    return a;
  }

  // ---------------- the Layout Lab's props and art direction ----------------
  buildWallFanG() {
    const T = this.THREE, g = new T.Group(), W = '#FFFFFF', K = '#111111', R = 0.27;
    this.box(0.16, 0.22, 0.03, K, 0, 0, 0.015, g);                                          // wall bracket
    this.box(0.05, 0.05, 0.2, K, 0, -0.02, 0.12, g);                                         // arm
    const sw = new T.Group(); sw.position.set(0, 0, 0.22); g.add(sw); sw.userData.osc = true;   // sweeps left-right
    this.cyl(0.035, 0.035, 0.07, 10, K, 0, -0.02, 0, sw);                                    // swivel joint
    const hd = new T.Group(); hd.rotation.x = 0.28; sw.add(hd);                              // tilted down a little
    this.cyl(0.09, 0.1, 0.16, 16, W, 0, 0, 0.1, hd, { rx: Math.PI / 2 });                    // motor housing
    this.cyl(R, R, 0.1, 28, W, 0, 0, 0.27, hd, { rx: Math.PI / 2 });                          // the drum
    this.cyl(R - 0.025, R - 0.025, 0.005, 28, K, 0, 0, 0.32, hd, { rx: Math.PI / 2, ink: false });
    const bl = new T.Group(); bl.position.set(0, 0, 0.33); hd.add(bl); bl.userData.spin = true;
    for (let i = 0; i < 3; i++) { const b = this.box(0.09, 0.2, 0.006, W, 0, 0.12, 0, null, { ink: false }); const pv = new T.Group(); pv.rotation.z = i * Math.PI * 2 / 3; pv.add(b); b.rotation.y = 0.35; bl.add(pv); }
    this.cyl(0.04, 0.04, 0.02, 12, W, 0, 0, 0.004, bl, { rx: Math.PI / 2 });
    [0.09, 0.17, R - 0.01].forEach((r) => { const m = new T.Mesh(new T.TorusGeometry(r, 0.005, 4, 32), this.m(K)); m.position.set(0, 0, 0.335); hd.add(m); });
    for (let i = 0; i < 4; i++) { const sp = this.box(0.006, 2 * R - 0.02, 0.006, K, 0, 0, 0.335, hd, { ink: false }); sp.rotation.z = i * Math.PI / 4; }
    // the switch below it: a plate with a rocker; tap it to turn the fan on or off
    const sw2 = new T.Group(); sw2.position.set(0, -0.85, 0.008); g.add(sw2);
    const plate = this.box(0.09, 0.13, 0.014, W, 0, 0, 0, sw2); plate.userData.fanSwitch = true;
    const rk = this.box(0.034, 0.06, 0.014, K, 0, 0, 0.012, sw2); rk.userData.fanSwitch = true; rk.userData.rocker = true;
    // the power cable: out of the top of the switch, a lazy wiggle up the wall, into the bracket
    const path = new T.CatmullRomCurve3([[0, -0.78, 0.012], [0.025, -0.66, 0.012], [-0.012, -0.48, 0.012], [0.02, -0.3, 0.012], [0.004, -0.16, 0.014], [0, -0.11, 0.02]].map((q) => new T.Vector3(q[0], q[1], q[2])));
    this.put(new T.TubeGeometry(path, 40, 0.006, 6, false), K, 0, 0, 0, g, { ink: false });
    return g;
  }
  buildBarHolderG() {
    const T = this.THREE, g = new T.Group(), W = '#FFFFFF', K = '#111111', levels = [0.55, 0.85, 1.15];
    [-0.52, 0.52].forEach((bx) => {
      this.box(0.07, 0.86, 0.03, K, bx, 0.85, 0.015, g);
      levels.forEach((y) => { this.box(0.05, 0.03, 0.16, K, bx, y - 0.035, 0.1, g); this.box(0.05, 0.05, 0.025, K, bx, y - 0.01, 0.17, g, { ink: false }); });
    });
    [[2.2, 0.0], [2.2, 0.05], [2.01, -0.03]].forEach(([L, dx], i) => {
      const bar = new T.Group(); bar.position.set(dx, levels[i], 0.12); g.add(bar);
      const sh = L - 0.9;
      this.cyl(0.014, 0.014, sh, 8, K, 0, 0, 0, bar, { rz: Math.PI / 2 });
      [-1, 1].forEach((sg) => { this.cyl(0.04, 0.04, 0.03, 10, K, sg * (sh / 2 + 0.015), 0, 0, bar, { rz: Math.PI / 2 }); this.cyl(0.025, 0.025, 0.42, 10, W, sg * (sh / 2 + 0.24), 0, 0, bar, { rz: Math.PI / 2 }); });
    });
    return g;
  }
  buildWallWindowG() {
    const T = this.THREE, g = new T.Group(), W = '#FFFFFF', K = '#111111', L = 2.4, H = 0.55, y = 2.05;
    this.box(L, H, 0.04, W, 0, y, 0.02, g);
    this.box(L + 0.08, 0.04, 0.09, W, 0, y - H / 2 - 0.02, 0.045, g);          // sill
    for (let i = 0; i <= 4; i++) this.box(0.04, H, 0.05, K, -L / 2 + i * (L / 4), y, 0.03, g, { ink: false });
    this.box(L, 0.035, 0.05, K, 0, y + H / 2 - 0.0175, 0.03, g, { ink: false });
    this.box(L, 0.035, 0.05, K, 0, y - H / 2 + 0.0175, 0.03, g, { ink: false });
    return g;
  }
  buildCoolerG() {
    const T = this.THREE, g = new T.Group(), W = '#FFFFFF', K = '#111111';
    this.box(0.36, 0.06, 0.36, K, 0, 0.03, 0, g);                       // plinth
    this.box(0.34, 0.92, 0.34, W, 0, 0.52, 0, g);                       // body
    this.box(0.24, 0.26, 0.01, K, 0, 0.8, 0.171, g, { ink: false });    // tap recess
    this.box(0.18, 0.02, 0.07, K, 0, 0.66, 0.2, g);                     // drip tray
    [-0.05, 0.05].forEach((x) => this.cyl(0.015, 0.015, 0.05, 8, W, x, 0.86, 0.19, g, { rx: Math.PI / 2 }));   // taps
    this.box(0.3, 0.03, 0.3, K, 0, 0.995, 0, g);                         // collar
    const jug = this.cyl(0.14, 0.14, 0.36, 18, W, 0, 1.2, 0, g);
    jug.material = new T.MeshStandardMaterial({ color: '#BFDDF2', transparent: true, opacity: 0.6, roughness: 0.15, metalness: 0 });
    this.cyl(0.05, 0.14, 0.06, 18, W, 0, 1.03, 0, g).material = jug.material;
    this.cyl(0.06, 0.06, 0.03, 12, K, 0, 1.395, 0, g);                  // cap
    return g;
  }
  buildPlantG() {
    const T = this.THREE, g = new T.Group(), W = '#FFFFFF', K = '#111111', G = '#5E8A5A';
    this.cyl(0.17, 0.13, 0.36, 14, W, 0, 0.18, 0, g);
    this.cyl(0.18, 0.18, 0.04, 14, W, 0, 0.37, 0, g);
    this.cyl(0.16, 0.16, 0.01, 14, K, 0, 0.385, 0, g, { ink: false });
    const leaves = [[0, 0, 0.95, 0], [0.06, 0.03, 0.82, 0.18], [-0.07, 0.02, 0.78, -0.2], [0.02, -0.07, 0.7, 0.15], [-0.03, 0.07, 0.88, -0.1], [0.09, -0.04, 0.6, 0.3], [-0.09, -0.05, 0.62, -0.28]];
    leaves.forEach(([x, z, h, tilt], i) => {
      const geo = new T.ConeGeometry(0.045, h, 4).scale(1, 1, 0.35);
      const m = this.put(geo, G, x, 0.39 + h / 2, z, g);
      m.rotation.set(tilt * 0.6, i * 0.9, tilt);
    });
    return g;
  }
  lookColours() {
    const st = this.state;
    return { brown: ['Brown', st.boxDark || '#4A3426'], dark: ['Dark', '#2B1E16'], black: ['Black', '#111111'], navy: ['Navy', '#1E2A4A'], red: ['Red', '#8E2A1E'],
      cream: ['Cream', st.boxLight || '#EFE3CF'], white: ['White', '#FFFFFF'], orange: ['Orange', '#E8742C'], yellow: ['Yellow', '#F3C318'], sky: ['Sky', '#9FD3F2'] };
  }
  sceneLook() {
    const L = this.slook, cv = this.renderer && this.renderer.domElement; if (!cv) return;
    const key = JSON.stringify(L) + this.state.boxDark + this.state.boxLight;
    this.hemi.intensity = L.ambient; this.sun.intensity = L.sunI;
    const sst = this.state, flat = !sst.media && sst.bgMode !== 'sky';
    if (L.sketch && flat) {
      // the sketch line traces the objects' outline, so the background moves from the 3D scene to the page behind it
      this.scene.background = null; this.stageEl.style.backgroundColor = sst.bgColor;
    } else if (this.stageEl.style.backgroundColor) this.stageEl.style.backgroundColor = '';
    if (L.sketch) {
      if (L.skInner) this.inkLines.forEach((l) => { l.visible = true; });
      this.inkMat.color.set(this.lookColours()[L.skCol][1]); this.skInkSet = true;
      this.lookBoil();
    } else if (this.skInkSet) { this.skInkSet = false; this.artKey = null; }   // let the palette put the ink colour back
    if (this.grainEl && L.grain > 0) this.grainEl.style.backgroundPosition = Math.floor(Math.random() * 256) + 'px ' + Math.floor(Math.random() * 256) + 'px';
    if (key === this.slookKey) return;
    this.slookKey = key;
    const parts = [];
    if (L.contrast !== 1) parts.push('contrast(' + L.contrast + ')');
    if (L.bright !== 1) parts.push('brightness(' + L.bright + ')');
    if (L.saturate !== 1) parts.push('saturate(' + L.saturate + ')');
    if (L.hue) parts.push('hue-rotate(' + L.hue + 'deg)');
    if (L.duotone || L.posterize >= 2 || L.sketch) { this.lookSvg(); parts.push('url(#ll-fx)'); }
    if (L.blur > 0) parts.push('blur(' + L.blur + 'px)');
    cv.style.filter = GLFX.cssLeft(parts).join(' ') || 'none';
    // pixelate: render fewer pixels and let the browser scale them up without smoothing
    const px = Math.max(1, Math.round(L.pixel));
    if (px !== this.lookPx) {
      this.lookPx = px; this.renderer.setPixelRatio(px <= 1 ? Math.min(window.devicePixelRatio || 1, 2) : 1 / px);
      const el = this.stageEl; this.renderer.setSize(Math.max(1, el.clientWidth), Math.max(1, el.clientHeight), false);
      cv.style.imageRendering = px > 1 ? 'pixelated' : 'auto';
    }
    // texture layers over the scene
    const st = this.stageEl, mk = (css) => { const d = document.createElement('div'); d.setAttribute('aria-hidden', 'true'); d.style.cssText = 'position:absolute;inset:0;pointer-events:none;' + css; st.appendChild(d); return d; };
    if (!this.grainEl) {
      const noise = (n, scale) => { const c = document.createElement('canvas'); c.width = c.height = n; const x = c.getContext('2d'), id = x.createImageData(n, n);
        for (let i = 0; i < id.data.length; i += 4) { const v = Math.random() * 255; id.data[i] = id.data[i + 1] = id.data[i + 2] = v; id.data[i + 3] = 255; }
        x.putImageData(id, 0, 0); if (!scale) return c.toDataURL();
        const b = document.createElement('canvas'); b.width = b.height = n * scale; const bx = b.getContext('2d'); bx.imageSmoothingEnabled = true; bx.filter = 'blur(2px)'; bx.drawImage(c, 0, 0, n * scale, n * scale); return b.toDataURL(); };
      this.paperEl = mk('background-image:url(' + noise(64, 6) + ');background-size:384px 384px;mix-blend-mode:multiply;opacity:0');
      this.dotsEl = mk('mix-blend-mode:multiply;opacity:0');
      this.scanEl = mk('mix-blend-mode:multiply;opacity:0');
      this.grainEl = mk('background-image:url(' + noise(256) + ');mix-blend-mode:overlay;opacity:0');
      this.vigEl = mk('opacity:0');
    }
    const dk = this.lookColours()[L.duoDark][1];
    this.paperEl.style.opacity = String(L.paper * 0.55);
    this.dotsEl.style.opacity = String(L.halftone);
    this.dotsEl.style.backgroundImage = 'radial-gradient(circle at center, ' + dk + ' 0 ' + (L.dotSize * 0.28).toFixed(1) + 'px, transparent ' + (L.dotSize * 0.32).toFixed(1) + 'px)';
    this.dotsEl.style.backgroundSize = L.dotSize + 'px ' + L.dotSize + 'px';
    this.scanEl.style.opacity = String(L.scan * 0.6);
    this.scanEl.style.backgroundImage = 'repeating-linear-gradient(0deg, ' + dk + ' 0 1px, transparent 1px 3px)';
    this.grainEl.style.opacity = String(L.grain);
    this.vigEl.style.opacity = String(L.vignette);
    this.vigEl.style.backgroundImage = 'radial-gradient(ellipse at center, transparent 45%, ' + dk + ' 120%)';
  }
  lookSvg() {
    const L = this.slook, C = this.lookColours();
    if (!this.lookSvgEl || !this.lookSvgEl.isConnected) {
      this.lookSvgEl = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      this.lookSvgEl.setAttribute('width', '0'); this.lookSvgEl.setAttribute('height', '0'); this.lookSvgEl.setAttribute('aria-hidden', 'true');
      Object.assign(this.lookSvgEl.style, { position: 'absolute', width: 0, height: 0 });
      this.stageEl.appendChild(this.lookSvgEl);
    }
    const hex = (h) => { const c = parseInt(h.slice(1), 16); return [(c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255].map((v) => v.toFixed(3)); };
    let post = '';
    if (L.posterize >= 2) {
      const n = Math.round(L.posterize), tv = []; for (let i = 0; i < n; i++) tv.push((i / (n - 1)).toFixed(3));
      const f = '<feFunc% type="discrete" tableValues="' + tv.join(' ') + '"/>';
      post = '<feComponentTransfer>' + f.replace('%', 'R') + f.replace('%', 'G') + f.replace('%', 'B') + '</feComponentTransfer>';
    }
    let inner = post;
    if (L.duotone) {
      const dk = hex(C[L.duoDark][1]), lt = hex(C[L.duoLight][1]);
      inner = '<feColorMatrix type="matrix" values="0.299 0.587 0.114 0 0  0.299 0.587 0.114 0 0  0.299 0.587 0.114 0 0  0 0 0 1 0"/>' + post +
        '<feComponentTransfer><feFuncR type="table" tableValues="' + dk[0] + ' ' + lt[0] + '"/><feFuncG type="table" tableValues="' + dk[1] + ' ' + lt[1] + '"/><feFuncB type="table" tableValues="' + dk[2] + ' ' + lt[2] + '"/></feComponentTransfer>';
    }
    if (L.sketch) {
      // the outline: alpha grown by the line weight minus the shapes, wobbled by noise, broken by grain, maybe drawn twice
      const c = hex(C[L.skCol][1]), g = L.skGrain, A = (4 * g).toFixed(2), B = (1 - 2.2 * g).toFixed(2), fq = L.skScale.toFixed(4), r = L.skRough, w = L.skWidth;
      inner += '<feComponentTransfer result="base"><feFuncA type="identity"/></feComponentTransfer>';
      inner += '<feTurbulence class="sk" type="fractalNoise" baseFrequency="' + fq + '" numOctaves="2" seed="3" result="n1"/>';
      inner += '<feTurbulence class="sk" type="fractalNoise" baseFrequency="' + fq + '" numOctaves="2" seed="11" result="n2"/>';
      inner += '<feTurbulence class="sk" type="fractalNoise" baseFrequency="0.85" numOctaves="1" seed="5" result="gr"/>';
      inner += '<feColorMatrix in="gr" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  ' + A + ' 0 0 0 ' + B + '" result="grain"/>';
      inner += '<feDisplacementMap in="base" in2="n1" scale="' + (r * L.skWarp).toFixed(2) + '" xChannelSelector="R" yChannelSelector="G" result="fill"/>';
      const stroke = (noise, name, wd) => '<feMorphology in="SourceAlpha" operator="dilate" radius="' + wd.toFixed(2) + '" result="' + name + 'd"/>' +
        '<feComposite in="' + name + 'd" in2="SourceAlpha" operator="out" result="' + name + 'r"/>' +
        '<feDisplacementMap in="' + name + 'r" in2="' + noise + '" scale="' + r.toFixed(2) + '" xChannelSelector="R" yChannelSelector="G" result="' + name + 'w"/>' +
        '<feComposite in="' + name + 'w" in2="grain" operator="in" result="' + name + 'g"/>' +
        '<feFlood flood-color="rgb(' + c.map((v) => Math.round(v * 255)).join(',') + ')" result="' + name + 'c"/>' +
        '<feComposite in="' + name + 'c" in2="' + name + 'g" operator="in" result="' + name + '"/>';
      inner += stroke('n1', 'l1', w);
      if (L.skDouble) inner += stroke('n2', 'l2', Math.max(0.5, w * 0.7));
      inner += '<feMerge><feMergeNode in="fill"/><feMergeNode in="l1"/>' + (L.skDouble ? '<feMergeNode in="l2"/>' : '') + '</feMerge>';
    }
    this.lookSvgEl.innerHTML = '<filter id="ll-fx" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">' + inner + '</filter>';
    this.skTurb = Array.from(this.lookSvgEl.querySelectorAll('feTurbulence.sk'));
  }
  lookBoil() {
    const L = this.slook; if (!L.skBoil || !this.skTurb) return;
    const now = performance.now(); if (now - (this.boilT || 0) < 1000 / L.skBoil) return;
    this.boilT = now; const s0 = Math.floor(Math.random() * 1000);
    this.skTurb.forEach((t, i) => t.setAttribute('seed', String(s0 + i * 7)));
  }

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

  // ===================== FLOW: one question at a time, a small 3D toy under it (no gym box) =====================
  // overrides: after the opening the flow takes over, the gym never renders
  frame() {
    if (this.flKeyed) return; this.flKeyed = true;
    this.onFlKey = (e) => { if (e.target && /input|textarea/i.test(e.target.tagName)) return; if (e.key === 'w' || e.key === 'W') this.flToggleRough(); if (e.key === 'c' || e.key === 'C') this.flToggleBg(); };
    window.addEventListener('keydown', this.onFlKey);
    // on the phone: double-tap the clock for rough edges, double-tap the battery for the background
    if (this.phone) [['left', () => this.flToggleRough()], ['right', () => this.flToggleBg()]].forEach(([side, fn]) => {
      const z = document.createElement('div'); z.setAttribute('aria-hidden', 'true'); z.setAttribute('data-nopress', '');
      Object.assign(z.style, { position: 'absolute', top: 0, [side]: 0, width: '110px', height: '54px', zIndex: 60, touchAction: 'manipulation' });
      let last = 0;
      z.addEventListener('pointerup', (e) => { e.stopPropagation(); const now = performance.now(); if (now - last < 380) { last = 0; fn(); this.buzz('success'); try { this.flCheckSound(); } catch (er) {} } else last = now; });
      z.addEventListener('pointerdown', (e) => e.stopPropagation());
      z.addEventListener('click', (e) => e.stopPropagation());
      this.phone.appendChild(z);
    });
  }
  closeOpening() {
    const L = this.openL; this.openL = null;
    if (!L || L.gone) return;
    this.buzz('light');
    this.dropLayer(L);
    this.flowStart();
  }
  flowStart() {
    if (this.FL) return;
    if (!this.THREE) { setTimeout(() => { if (!this.dead) this.flowStart(); }, 100); return; }
    const T = this.THREE, P = this.phone;
    const pal = this.pal || { boxLight: '#EFE3CF', boxDark: '#4A3426', bgColor: '#E8742C' };
    this.FC = { bg: pal.bgColor, light: pal.boxLight, dark: pal.boxDark };
    const L = this.fh('div', { position: 'absolute', inset: 0, zIndex: 4, background: this.FC.bg, overflow: 'hidden', touchAction: 'none' }, P);
    L.setAttribute('data-nopress', '');
    const cv = document.createElement('canvas'); Object.assign(cv.style, { position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block' }); L.appendChild(cv);
    const R = new T.WebGLRenderer({ canvas: cv, antialias: true, alpha: true });
    R.setPixelRatio(Math.min(2, window.devicePixelRatio || 1)); R.setClearColor(0x000000, 0);
    R.outputColorSpace = T.SRGBColorSpace; R.toneMapping = T.NoToneMapping;
    const S = new T.Scene(), cam = new T.PerspectiveCamera(35, 390 / 844, 0.1, 100);
    S.add(new T.HemisphereLight(0xffffff, 0x8a7a70, 2.2));
    const sun = new T.DirectionalLight(0xffffff, 1.6); sun.position.set(2.5, 6, 4); S.add(sun);
    R.shadowMap.enabled = true; R.shadowMap.type = T.PCFSoftShadowMap; sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024);
    { const c = sun.shadow.camera; c.left = -4; c.right = 4; c.top = 4; c.bottom = -4; c.near = 0.5; c.far = 20; } sun.shadow.bias = -0.0008; this.flSun = sun;
    // the question, top and centred; then the swipe hint, an icon only
    const q = this.fh('div', { position: 'absolute', left: '28px', right: '28px', top: '92px', textAlign: 'center', color: this.FC.light, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '30px', lineHeight: 1.1, letterSpacing: '-0.01em', pointerEvents: 'none', zIndex: 3 }, L);
    q.setAttribute('aria-live', 'polite');
    const sw = this.fh('div', { position: 'absolute', left: '50%', bottom: '34px', width: '44px', height: '44px', marginLeft: '-22px', display: 'none', visibility: 'hidden', color: this.FC.light, pointerEvents: 'none', zIndex: 3 }, L);
    sw.innerHTML = '<svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 14l6-6 6 6"/></svg>';
    sw.animate([{ transform: 'translateY(4px)' }, { transform: 'translateY(-6px)' }], { duration: 900, iterations: Infinity, direction: 'alternate', easing: 'ease-in-out' });
    const ui = this.fh('div', { position: 'absolute', inset: 0, zIndex: 4, pointerEvents: 'none' }, L);
    this.FL = { L, cv, R, S, cam, q, sw, ui, objs: [], tick: null, swipe: false, words: [], t: 0 };
    const size = () => { const w = L.clientWidth || 390, h = L.clientHeight || 844; R.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); };
    size(); new ResizeObserver(size).observe(L);
    this.flBindPointer();
    let last = performance.now();
    const loop = (now) => {
      if (this.dead) return;
      this.flRaf = requestAnimationFrame(loop);
      const dt = Math.min(0.05, (now - last) / 1000); last = now; this.FL.t += dt;
      if (this.FL.tick) this.FL.tick(dt, this.FL.t);
      this.flTween(dt); this.flDustTick(dt); this.flPhysDustTick(dt);
      const fx = this.flCamFx(dt, now / 1000), c0 = cam.position.clone(), f0 = cam.fov;
      cam.position.add(fx.off); cam.fov = fx.fov; cam.updateProjectionMatrix();
      GLFX.draw(R, S, cam, { contrast: 1, bright: 1, sketch: !this.flNoRough, skCol: this.FC.dark, skWidth: 2.2, skRough: 5, skScale: 0.03, skGrain: 0.4, skDouble: true, skWarp: 0 });
      cam.position.copy(c0); cam.fov = f0; cam.updateProjectionMatrix();
    };
    this.flRaf = requestAnimationFrame(loop);
    this.d.gyms = null;
    if (this.flBgPending) this.flToggleBg();
    this.flGo('name');
  }
  componentWillUnmount() { this.dead = true; cancelAnimationFrame(this.flRaf); cancelAnimationFrame(this.raf); }

  // ---------------- shared pieces ----------------
  // words appear one at a time, like the session-over line (260 ms apart, no motion)
  flSay(text, then) {
    const F = this.FL, q = F.q; F.words.forEach(clearTimeout); F.words = [];
    q.textContent = ''; q.setAttribute('aria-label', text);
    const ws = text.split(/\s+/).filter(Boolean);
    const spans = ws.map((w, i) => { const s = document.createElement('span'); s.textContent = w + (i < ws.length - 1 ? ' ' : ''); s.style.visibility = 'hidden'; q.appendChild(s); return s; });
    spans.forEach((s, i) => F.words.push(setTimeout(() => { if (!this.dead) s.style.visibility = 'visible'; }, i * 260)));
    F.words.push(setTimeout(() => { if (!this.dead && then) then(); }, ws.length * 260));
    return ws.length * 260;
  }
  flClear() {
    const F = this.FL;
    F.objs.forEach((o) => { F.S.remove(o); });
    F.objs = []; F.tick = null; F.drag = null; F.hit = null; F.swipe = false; F.sw.style.display = 'none'; F.ui.innerHTML = ''; F.tw = [];
    F.onSwipe = null; F.onTap = null;
    F.words.forEach(clearTimeout); F.words = []; F.q.textContent = ''; F.q.removeAttribute('aria-label');
  }
  fh(tag, css, parent, text) { const r = this.raw; this.raw = true; const e = this.h(tag, css, parent, text); this.raw = r; if (parent === this.ui) e.classList.remove('sys'); return e; }
  flAdd(o) { this.FL.S.add(o); this.FL.objs.push(o); return o; }
  flCam(P, T, fov) { const c = this.FL.cam; c.position.set(P[0], P[1], P[2]); c.fov = fov || 35; this.flFov = c.fov; c.updateProjectionMatrix(); c.lookAt(T[0], T[1], T[2]); }
  flSwipe(fn) { const F = this.FL; F.swipe = true; F.onSwipe = fn; F.onTap = () => { this.buzz('light'); fn(); }; F.sw.style.display = 'block'; }
  // tiny tween list: {o, k, from, to, d, t, ease, done}
  flAnim(fn, d, done) { (this.FL.tw = this.FL.tw || []).push({ fn, d, t: 0, done }); }
  flTween(dt) {
    const F = this.FL; if (!F.tw || !F.tw.length) return;
    F.tw = F.tw.filter((a) => { a.t += dt; const u = Math.min(1, a.t / a.d); a.fn(u); if (u >= 1) { if (a.done) a.done(); return false; } return true; });
  }
  outBack(x, k) { x = Math.min(1, Math.max(0, x)); k = k == null ? 1.8 : k; const c = k + 1; return 1 + c * Math.pow(x - 1, 3) + k * Math.pow(x - 1, 2); }
  outCubic(x) { x = Math.min(1, Math.max(0, x)); return 1 - Math.pow(1 - x, 3); }
  popIn(o, delay, s1) {
    s1 = s1 || 1; o.scale.setScalar(0.0001);
    setTimeout(() => { if (this.dead) return; this.flAnim((u) => o.scale.setScalar(Math.max(0.0001, s1 * this.outBack(u, 1.7))), 0.5); }, delay || 0);
  }
  toon(hex) {
    const T = this.THREE;
    if (!this.flRamp) { const d = new Uint8Array([90, 90, 90, 255, 175, 175, 175, 255, 255, 255, 255, 255]); const tx = new T.DataTexture(d, 3, 1, T.RGBAFormat); tx.minFilter = tx.magFilter = T.NearestFilter; tx.needsUpdate = true; this.flRamp = tx; }
    return new T.MeshToonMaterial({ color: hex, gradientMap: this.flRamp });
  }
  textTex(txt, opts) {
    const o = opts || {}, T = this.THREE, c = document.createElement('canvas'), W = o.w || 256, H = o.h || 256;
    c.width = W; c.height = H; const x = c.getContext('2d');
    if (o.bg) { x.fillStyle = o.bg; x.fillRect(0, 0, W, H); }
    x.fillStyle = o.col || this.FC.light; x.textAlign = 'center'; x.textBaseline = 'middle';
    x.font = (o.weight || 900) + ' ' + (o.size || 190) + "px 'Space Grotesk', Arial, sans-serif";
    x.fillText(txt, W / 2, H / 2 + (o.dy || 8));
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; t.anisotropy = 4; return t;
  }
  flRay(e) {
    const F = this.FL, r = F.cv.getBoundingClientRect(), T = this.THREE;
    const v = new T.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    const rc = this.flRc || (this.flRc = new T.Raycaster()); rc.setFromCamera(v, F.cam); return rc;
  }
  flPlane(e, n, c) { const T = this.THREE, rc = this.flRay(e), p = new T.Vector3(); return rc.ray.intersectPlane(new T.Plane(n, c), p) ? p : null; }
  flBindPointer() {
    const F = this.FL, L = F.L;
    L.addEventListener('pointerdown', (e) => {
      if (e.target.closest && e.target.closest('button')) return;
      F.down = { x: e.clientX, y: e.clientY, t: performance.now(), obj: false };
      if (F.hit) { const h = F.hit(e); if (h) { F.down.obj = true; F.drag = h; try { L.setPointerCapture(e.pointerId); } catch (er) {} } }
    });
    L.addEventListener('pointermove', (e) => { if (F.drag && F.drag.move) F.drag.move(e); });
    const up = (e) => {
      const d = F.down; F.down = null; if (!d) return;
      const dx = e.clientX - d.x, dy = e.clientY - d.y, tap = Math.hypot(dx, dy) < 8 && performance.now() - d.t < 450;
      if (F.drag) { const g = F.drag; F.drag = null; if (g.up) g.up(e, tap); return; }
      if (F.swipe && dy < -55 && Math.abs(dx) < Math.abs(dy) && F.onSwipe) { this.buzz('light'); F.onSwipe(); return; }
      if (dy > 55 && Math.abs(dx) < Math.abs(dy) && F.onSwipeDown) { this.buzz('light'); F.onSwipeDown(); return; }
      if (tap && F.onTap) F.onTap(e);
    };
    L.addEventListener('pointerup', up); L.addEventListener('pointercancel', up);
  }
  flGo(step) {
    this.flClear(); this.flStep = step;
    ({ name: () => this.flName(), unit: () => this.flUnit(), plates: () => this.flPlates(), bar: () => this.flBarQ(), prs: () => this.flPRs(), prDial: () => this.flPRDial(0),
      wod: () => this.flWod(), kit: () => this.flKit(), sets: () => this.flSets() })[step]();
  }

  // ---------------- a drum: a pool of label plates on the front of a cylinder; pos is a float index ----------------
  flDrum(labels, o) {
    const T = this.THREE, n = labels.length, r = o.r || 0.95, a0 = o.a0 || 0.36, W = o.w || 0.9, wrap = o.wrap !== false;
    const g = new T.Group();
    const body = new T.Mesh(new T.CylinderGeometry(r - 0.03, r - 0.03, W, 48, 1), this.toon(this.FC.dark)); body.rotation.z = Math.PI / 2; g.add(body);
    [-1, 1].forEach((s) => { const rim = new T.Mesh(new T.CylinderGeometry(r + 0.025, r + 0.025, 0.05, 48), this.toon(this.FC.light)); rim.rotation.z = Math.PI / 2; rim.position.x = s * (W / 2 + 0.02); g.add(rim); });
    const tex = {}, texOf = (i) => tex[i] || (tex[i] = this.textTex(labels[i], { w: 256, h: 140, size: o.size || 112, col: this.FC.light, dy: 6 }));
    const K = Math.ceil(1.45 / a0) + 1, pool = [];
    for (let k = -K; k <= K; k++) {
      const m = new T.Mesh(new T.PlaneGeometry(o.lw || 0.62, a0 * r * 0.95), new T.MeshBasicMaterial({ transparent: true, depthWrite: false })); g.add(m); pool.push(m);
    }
    g.position.z = -r;
    const D = { g, n, pos: 0, vel: 0, idx: 0, lock: false, body, opacity: 1 };
    const norm = (i) => (wrap ? ((i % n) + n) % n : Math.max(0, Math.min(n - 1, i)));
    D.set = (i) => { D.pos = i; D.idx = norm(i); };
    D.layout = () => {
      const base = Math.floor(D.pos);
      pool.forEach((m, j) => {
        const li = base + j - K, th = (li - D.pos) * a0, inRange = wrap || (li >= 0 && li < n);
        m.visible = inRange && Math.abs(th) < 1.45;
        if (!m.visible) return;
        const mi = norm(li); if (m.userData.li !== mi) { m.userData.li = mi; m.material.map = texOf(mi); m.material.needsUpdate = true; }
        m.position.set(0, -r * Math.sin(th), r * Math.cos(th) + 0.004); m.rotation.x = th;
        m.material.opacity = D.opacity * Math.max(0, Math.cos(th * 1.05));
      });
    };
    D.tick = (dt, dragging) => {
      if (!dragging) {
        D.pos += D.vel * dt; D.vel *= Math.exp(-dt * 4.5);
        if (!wrap) { if (D.pos < 0) { D.pos += (0 - D.pos) * 0.3; D.vel = 0; } if (D.pos > n - 1) { D.pos += (n - 1 - D.pos) * 0.3; D.vel = 0; } }
        if (Math.abs(D.vel) < 2) D.pos += (Math.round(D.pos) - D.pos) * (1 - Math.exp(-dt * 12));
      }
      const i = norm(Math.round(D.pos));
      if (i !== D.idx) { D.idx = i; this.buzz('selection'); }
      D.layout();
    };
    D.layout();
    return D;
  }
  // drag a drum: pixels to angle, with a flick
  flDrumDrag(D, e, ppi) {
    let y0 = e.clientY, t0 = performance.now(), dragged = false;
    return {
      move: (ev) => { const dy = ev.clientY - y0, now = performance.now(); if (Math.abs(dy) > 2) dragged = true; const d = -dy / ppi; D.pos += d; D.vel = d / Math.max(0.008, (now - t0) / 1000); y0 = ev.clientY; t0 = now; D.dragging = true; },
      up: () => { D.dragging = false; if (performance.now() - t0 > 90) D.vel = 0; if (D.onTap && !dragged) D.onTap(); }
    };
  }
  // ---------------- 2 · where are you training: two dials, tap to lock each ----------------
  flName() {
    const F = this.FL, chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('');
    this.flCam([0, 0.5, 10.5], [0, -0.35, 0], 35);
    this.flSay('So, where are you training now?');
    const drums = [-0.62, 0.62].map((x, i) => {
      const D = this.flDrum(chars, { r: 0.95, a0: 0.38, w: 0.95, lw: 0.7, size: 120 }); D.g.position.x = x; D.g.position.y = -0.45; this.flAdd(D.g); this.popIn(D.g, 300 + i * 120); return D;
    });
    drums[0].set(0); drums[1].set(0);
    let cur = 0;
    const dim = () => drums.forEach((D, i) => { D.opacity = i === cur || D.lock ? 1 : 0.35; D.layout(); });
    dim();
    const lockOne = () => {
      const D = drums[cur]; D.lock = true; this.buzz('light');
      const g = D.g, y0 = g.position.y; this.flAnim((u) => { g.position.y = y0 - 0.08 * Math.sin(u * Math.PI); }, 0.25);
      cur++; dim();
      if (cur >= 2) {
        this.d.name = chars[drums[0].idx] + chars[drums[1].idx];
        setTimeout(() => { if (!this.dead && this.flStep === 'name') this.flGo('unit'); }, 650);
      }
    };
    drums.forEach((D, i) => { D.onTap = () => { if (i === cur && !D.lock) lockOne(); }; });
    F.hit = (e) => {
      const rc = this.flRay(e), D = drums[cur]; if (!D) return null;
      if (!rc.intersectObject(D.g, true).length) { const o = drums.find((q) => !q.lock && rc.intersectObject(q.g, true).length); return null; }
      return this.flDrumDrag(D, e, 46);
    };
    F.tick = (dt) => drums.forEach((D) => D.tick(dt, !!D.dragging));
  }

  // ---------------- 3 · kilos or pounds: drag a kettlebell into the square ----------------
  kettlebell(label) {
    const T = this.THREE, g = new T.Group(), M = this.toon(this.FC.dark);
    const body = new T.Mesh(new T.SphereGeometry(0.42, 32, 24), M); body.scale.set(1, 0.92, 1); body.position.y = 0.42; g.add(body);
    const base = new T.Mesh(new T.CylinderGeometry(0.26, 0.28, 0.05, 32), M); base.position.y = 0.04; g.add(base);
    const handle = new T.Mesh(new T.TorusGeometry(0.24, 0.055, 14, 40, Math.PI), M); handle.position.y = 0.78; g.add(handle);
    [-1, 1].forEach((s) => { const h = new T.Mesh(new T.CylinderGeometry(0.055, 0.06, 0.16, 14), M); h.position.set(s * 0.24, 0.72, 0); g.add(h); });
    const lab = new T.Mesh(new T.PlaneGeometry(0.5, 0.32), new T.MeshBasicMaterial({ map: this.textTex(label, { w: 256, h: 160, size: 120, col: this.FC.light }), transparent: true }));
    lab.position.set(0, 0.42, 0.43); g.add(lab);
    g.userData.label = label; return g;
  }
  flUnit() {
    const F = this.FL, T = this.THREE, name = this.d.name || '79';
    this.flCam([0, 6.2, 10.4], [0, -0.35, 0.45], 35);
    this.flSay('Cool. Let’s set ' + name + '. Do they use kilos or pounds there?');
    // the square on the floor, near us
    const sq = new T.Group(), SZ = 1.25, th = 0.05, SQ = [0, 1.55];
    const Ml = new T.MeshBasicMaterial({ color: this.FC.light });
    [[0, -SZ / 2, SZ + th, th], [0, SZ / 2, SZ + th, th], [-SZ / 2, 0, th, SZ], [SZ / 2, 0, th, SZ]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.01, d), Ml); m.position.set(x, 0.005, z); sq.add(m); });
    sq.position.set(SQ[0], 0, SQ[1]); this.flAdd(sq); this.popIn(sq, 900);
    // a soft floor shadow per bell
    const shadow = () => { const m = new T.Mesh(new T.CircleGeometry(0.4, 32), new T.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.16 })); m.rotation.x = -Math.PI / 2; m.position.y = 0.002; return m; };
    const bells = [['KG', 'kg', -0.95], ['LB', 'lb', 0.95]].map(([lab, u, x], i) => {
      const g = this.kettlebell(lab), sh = shadow(); g.position.set(x, 0, -0.55); sh.position.set(x, 0.002, -0.55);
      this.flAdd(g); this.flAdd(sh); this.popIn(g, 600 + i * 140);
      return { g, sh, u, home: new T.Vector3(x, 0, -0.55) };
    });
    let done = false;
    F.hit = (e) => {
      if (done) return null;
      const rc = this.flRay(e), b = bells.find((q) => rc.intersectObject(q.g, true).length); if (!b) return null;
      this.buzz('selection');
      const GY = -0.42, off = new T.Vector3(); { const p = this.flPlane(e, new T.Vector3(0, 1, 0), GY); if (p) off.copy(b.g.position).sub(p); off.y = 0; }   // drag on the plane at the grab height, so the bell stays under the finger
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 1, 0), GY); if (!p) return; const x = p.x + off.x, z = p.z + off.z; b.g.position.set(x, 0.28, z); b.sh.position.set(x, 0.002, z); b.g.rotation.z = Math.max(-0.25, Math.min(0.25, (x - b.lx || 0) * -1.5)); b.lx = x; },
        up: () => {
          const p = b.g.position, inside = Math.abs(p.x - SQ[0]) < SZ / 2 && Math.abs(p.z - SQ[1]) < SZ / 2;
          const from = p.clone(), to = inside ? new T.Vector3(SQ[0], 0, SQ[1]) : b.home.clone(), r0 = b.g.rotation.z;
          if (inside) done = true;
          this.flAnim((u) => { const e2 = this.outCubic(u); b.g.position.lerpVectors(from, to, e2); b.g.position.y = from.y * (1 - e2); b.sh.position.set(b.g.position.x, 0.002, b.g.position.z); b.g.rotation.z = r0 * (1 - e2); }, 0.32, () => {
            if (!inside) return;
            this.buzz('success');
            const g = b.g; this.flAnim((u) => { const s = 1 + 0.12 * Math.sin(u * Math.PI) * (1 - u); g.scale.set(1 + (s - 1) * 0.6, 1 - (s - 1), 1 + (s - 1) * 0.6); }, 0.35);
            this.setUnit(b.u);
            setTimeout(() => { if (!this.dead && this.flStep === 'unit') this.flGo('plates'); }, 900);
          });
        }
      };
    };
  }

  // ---------------- 4 · which plates: drag the missing ones out of the circle ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs(), n = specs.length, own = this.own();
    this.flCam([0, 0.4, 10.2], [0, 0.0, 0], 35);
    this.flSay('What are the plates available?');
    const C = new T.Vector3(0, 0.05, 0), RR = 1.0;
    const gray = new T.MeshBasicMaterial({ color: 0x9a9690, transparent: true, opacity: 0.32, depthWrite: false });
    const items = specs.map((sp, i) => {
      const a = Math.PI / 2 - i * Math.PI * 2 / n, slot = new T.Vector3(C.x + Math.cos(a) * RR, C.y + Math.sin(a) * RR, 0);
      const g = this.plate(sp), k = 1.2 + 1.7 * (0.45 - sp.d);   // bigger than life; the small change plates more so, so they read
      const w = new T.Group(); w.add(g); g.rotation.x = Math.PI / 2; w.position.copy(slot); this.flAdd(w); this.popIn(w, 700 + i * 70, k);
      const meshes = []; g.traverse((m) => { if (m.isMesh) { m.userData.m0 = m.material; meshes.push(m); } });
      const it = { sp, w, slot, k, meshes, on: own.indexOf(sp.kg) >= 0 };
      it.paint = () => it.meshes.forEach((m) => { m.material = it.on ? m.userData.m0 : gray; });
      if (!it.on) { w.position.copy(slot).sub(C).multiplyScalar(1.55).add(C); }
      it.paint(); return it;
    });
    const sync = () => { this.d.own[this.d.unit] = items.filter((q) => q.on).map((q) => q.sp.kg); };
    F.hit = (e) => {
      const rc = this.flRay(e); let hit = null, bd = 1e9;   // a disc test, so the hole in the middle still grabs the plate
      items.forEach((q) => { const d = rc.ray.distanceToPoint(q.w.position), R = q.sp.d / 2 * q.w.scale.x * 1.15; if (d < R && d < bd) { bd = d; hit = q; } }); if (!hit) return null;
      this.buzz('selection');
      const z0 = new T.Plane(new T.Vector3(0, 0, 1), 0), p0 = new T.Vector3(); rc.ray.intersectPlane(z0, p0);
      const off = hit.w.position.clone().sub(p0); off.z = 0;
      const sc0 = hit.w.scale.x; this.flAnim((u) => hit.w.scale.setScalar(sc0 * (1 + 0.12 * this.outCubic(u))), 0.15);
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 0, 1), 0); if (!p) return; hit.w.position.set(p.x + off.x, p.y + off.y, 0.35); hit.w.rotation.z = Math.sin(performance.now() / 120) * 0.04;
          const out = hit.w.position.clone().setZ(0).distanceTo(C) > RR + 0.42; if (out === hit.on) { hit.on = !out; hit.paint(); this.buzz('light'); } },
        up: () => {
          const from = hit.w.position.clone(), out = from.clone().setZ(0).distanceTo(C) > RR + 0.42;
          hit.on = !out; hit.paint(); sync();
          let to;
          if (out) { const v = from.clone().setZ(0).sub(C); const len = Math.min(Math.max(v.length(), RR + 0.6), 2.25); to = C.clone().add(v.setLength(len)); to.x = Math.max(-1.5, Math.min(1.5, to.x)); to.y = Math.max(-1.9, Math.min(2.2, to.y)); }
          else to = hit.slot.clone();
          this.flAnim((u) => { const e2 = this.outCubic(u); hit.w.position.lerpVectors(from, to, e2); hit.w.rotation.z *= 0.8; hit.w.scale.setScalar(hit.k * (1.12 - 0.12 * e2)); }, 0.3);
        }
      };
    };
    F.tick = (dt, t) => items.forEach((q, i) => { if (F.drag && F.drag.it === q) return; q.w.children[0].rotation.y = Math.sin(t * 0.8 + i) * 0.12; });
    setTimeout(() => { if (!this.dead && this.flStep === 'plates') { this.flSwipe(() => { sync(); this.flGo('bar'); }); F.onTap = null; } }, 1200);   // taps here are for dragging plates, so only a swipe moves on
  }

  // ---------------- 5 · PRs: upload, take a photo, or dial them in ----------------
  flIcons(list) {
    const F = this.FL, row = this.fh('div', { position: 'absolute', left: 0, right: 0, top: '50%', transform: 'translateY(-50%)', display: 'flex', justifyContent: 'center', gap: '22px', pointerEvents: 'auto' }, F.ui);
    const ICON = {
      photo: '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-9 9"/>',
      camera: '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.6"/>',
      dial: '<rect x="6" y="3" width="12" height="18" rx="3"/><path d="M9 8l3-3 3 3M9 16l3 3 3-3"/><path d="M9.5 12h5"/>'
    };
    list.forEach(([k, label, fn], i) => {
      const b = this.fh('button', { width: '84px', height: '84px', borderRadius: '42px', border: 0, background: this.FC.light, color: this.FC.dark, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', boxShadow: '0 6px 0 ' + this.FC.dark }, row);
      b.setAttribute('aria-label', label); b.className = 'tap';
      b.innerHTML = '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[k] + '</svg>';
      b.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: 450, delay: 500 + i * 110, easing: 'cubic-bezier(.3,1.5,.5,1)', fill: 'backwards' });
      b.onclick = () => { this.buzz('light'); fn(); };
    });
  }
  flPRs() {
    this.flCam([0, 0, 7], [0, 0, 0], 35);
    this.flSay('Alright. And what are your PRs?');
    const fill = () => { this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); };
    this.flIcons([
      ['photo', 'Upload a screenshot', () => this.photoPicker('pr', () => { this.closeSheet(); this.reading('Reading your PRs…', () => { fill(); this.flGo('wod'); }); }, () => {})],
      ['camera', 'Take a photo', () => this.scanner({ title: 'Scan your PRs', onCancel: () => {}, onCapture: () => { fill(); this.flGo('wod'); }, draw: (x) => {
        x.fillStyle = '#F4EFE2'; x.fillRect(0, 0, 780, 1000);
        x.strokeStyle = 'rgba(60,90,160,0.25)'; x.lineWidth = 2; for (let y = 120; y < 1000; y += 70) { x.beginPath(); x.moveTo(0, y); x.lineTo(780, y); x.stroke(); }
        x.fillStyle = '#222'; x.font = '58px "Permanent Marker", cursive'; x.fillText('PRs', 60, 100);
        x.font = '46px "Permanent Marker", cursive';
        this.d.prs.forEach((q, i) => x.fillText(q[0] + ' ' + this.fmt(this.demoPR(q)), 60, 245 + i * 140));
        return { count: this.d.prs.length, top: 19.5, gap: 14, h: 6, widths: this.d.prs.map((q) => Math.min(88, 18 + (q[0].length + 4) * 3.4)) };
      } })],
      ['dial', 'Dial them in', () => this.flGo('prDial')]
    ]);
  }
  // one lift at a time: the question is the lift, one big number dial, swipe up for the next
  flPRDial(i) {
    this.flClear(); this.flStep = 'prDial';
    const F = this.FL, lifts = this.d.prs, q = lifts[i], u = this.d.unit, stp = u === 'lb' ? 5 : 2.5, max = u === 'lb' ? 700 : 320;
    const vals = []; for (let v = 0; v <= max; v += stp) vals.push(v);
    this.flCam([0, 0.2, 9.5], [0, -0.25, 0], 35);
    this.flSay(q[0] + '?');
    const labels = vals.map((v) => this.fmt(v));
    const D = this.flDrum(labels, { r: 1.05, a0: 0.33, w: 1.5, lw: 1.35, size: 112, wrap: false });
    D.g.position.y = -0.2; this.flAdd(D.g); this.popIn(D.g, 250);
    // the reading line: a small cream notch each side of the dial
    [-1, 1].forEach((s) => { const m = new this.THREE.Mesh(new this.THREE.ConeGeometry(0.09, 0.2, 3), new this.THREE.MeshBasicMaterial({ color: this.FC.light })); m.rotation.z = s * Math.PI / 2; m.position.set(s * 0.98, -0.2, 0.05); this.flAdd(m); this.popIn(m, 400); });
    const start = q[1] != null ? q[1] : this.demoPR(q); D.set(Math.max(0, Math.round(start / stp)));
    const unit = this.fh('div', { position: 'absolute', right: '34px', top: 'calc(50% + 8px)', color: this.FC.light, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '22px' }, F.ui, u);
    unit.setAttribute('aria-hidden', 'true');
    F.hit = (e) => (this.flRay(e).intersectObject(D.g, true).length ? this.flDrumDrag(D, e, 40) : null);
    F.tick = (dt) => D.tick(dt, !!D.dragging);
    setTimeout(() => { if (!this.dead && this.flStep === 'prDial') this.flSwipe(() => {
      q[1] = vals[D.idx];
      if (i + 1 < lifts.length) this.flPRDial(i + 1); else this.flGo('wod');
    }); }, 500);
  }

  // ---------------- 6 · today's workout: upload or take a photo ----------------
  flWod() {
    this.flCam([0, 0, 7], [0, 0, 0], 35);
    this.flSay(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?');
    const go = () => { this.plan = this.workoutPlan(); this.setIdx = 0; this.doneSets = []; this.d.kitGot = {}; this.flGo('kit'); };
    this.flIcons([
      ['photo', 'Upload a screenshot', () => this.photoPicker('wod', () => { this.closeSheet(); this.reading('Reading your workout…', go); }, () => {})],
      ['camera', 'Take a photo', () => this.scanner({ title: 'Scan the workout', onCancel: () => {}, onCapture: go, draw: (x) => {
        const gr = x.createLinearGradient(0, 0, 780, 1000); gr.addColorStop(0, '#E9E6DF'); gr.addColorStop(1, '#CFCAC0'); x.fillStyle = gr; x.fillRect(0, 0, 780, 1000);
        x.fillStyle = '#B9B3A8'; x.fillRect(0, 0, 780, 30); x.fillRect(0, 970, 780, 30);
        x.fillStyle = '#1F3A73'; x.font = '64px "Permanent Marker", cursive'; x.fillText('WOD', 60, 150);
        x.font = '52px "Permanent Marker", cursive';
        this.d.wod.forEach((w, i) => { x.fillText(w.lift, 60, 300 + i * 200); x.fillText(w.sets + 'x' + w.reps + ' @ ' + w.pct + '%', 100, 370 + i * 200); });
        return { count: this.d.wod.length, top: 26, gap: 20, h: 14, widths: this.d.wod.map(() => 70) };
      } })]
    ]);
  }

  // ---------------- the bottom card (kit and sets), in the opening's colours ----------------
  flCard() {
    const F = this.FL, c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px', borderRadius: '22px', background: this.FC.light, color: this.FC.dark, fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 8px 0 ' + this.FC.dark }, F.ui);
    c.animate([{ transform: 'translateY(120%)' }, { transform: 'none' }], { duration: 420, easing: 'cubic-bezier(.2,.9,.25,1)' });
    return c;
  }
  flBtn(parent, label, fn) {
    const b = this.fh('button', { width: '100%', height: '56px', border: 0, borderRadius: '16px', background: this.FC.dark, color: this.FC.light, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '19px', cursor: 'pointer' }, parent, label);
    b.className = 'tap'; b.onclick = () => { this.buzz('light'); fn(); }; return b;
  }

  // ---------------- 7 · the plate kit: the plates drop in, one pile each ----------------
  flKit(mid) {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flCam([0, 5.0, 5.0], [0, -1.15, -0.75], 35);
    const sp = this.specs(), kit = P.kit, n = kit.length, cols = Math.min(3, Math.max(1, n)), rows = Math.ceil(n / cols), gx = 0.62, gz = 0.62;
    kit.forEach((k, i) => {
      const s = sp.find((q) => q.kg === k.w); if (!s) return;
      const cx = (i % cols - (cols - 1) / 2) * gx, cz = (Math.floor(i / cols) - (rows - 1) / 2) * gz - 0.45;
      for (let j = 0; j < k.qty; j++) {
        const g = this.plate(s); const w = new T.Group(); w.add(g); w.position.set(cx, s.t / 2 + j * (s.t + 0.004), cz); g.rotation.y = Math.random() * 6.28;
        w.visible = false; this.flAdd(w);
        const y1 = w.position.y, delay = 250 + i * 160 + j * 70;
        setTimeout(() => { if (this.dead || this.flStep !== 'kit') return; w.visible = true; this.flAnim((u) => { const b = u < 0.7 ? (u / 0.7) * (u / 0.7) : 1 - 0.25 * Math.sin((u - 0.7) / 0.3 * Math.PI); w.position.y = y1 + (1 - Math.min(1, b)) * 2.4; }, 0.55, () => { if (j === k.qty - 1) this.buzz('light'); }); }, delay);
      }
    });
    const c = this.flCard(), got = this.d.kitGot = this.d.kitGot || {};
    const wrap = this.fh('div', { display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '14px' }, c);
    kit.forEach((k) => {
      const s = sp.find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
      const b = this.fh('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', borderRadius: '999px', border: '2px solid ' + this.FC.dark, fontFamily: 'inherit', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }, wrap);
      b.className = 'tap'; b.setAttribute('role', 'checkbox');
      const dot = this.fh('span', { width: Math.round(10 + s.d * 14) + 'px', height: Math.round(10 + s.d * 14) + 'px', borderRadius: '50%', background: s.color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.2)' }, b);
      this.fh('span', {}, b, k.qty + ' × ' + this.fmt(k.w) + ' ' + P.unit);
      const paint = () => { const on = !!got[k.w]; b.style.background = on ? this.FC.dark : 'transparent'; b.style.color = on ? this.FC.light : this.FC.dark; b.setAttribute('aria-checked', String(on)); };
      paint(); b.onclick = () => { if (got[k.w]) delete got[k.w]; else { got[k.w] = true; this.buzz('light'); } paint(); };
    });
    this.flBtn(c, mid ? 'Back to the set' : 'Start session', () => this.flGo('sets'));
  }

  // ---------------- 8 · set by set: the bar, the plates sliding on, one Done ----------------
  flSets() {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flCam([3.3, 2.5, 6.6], [-0.05, -0.05, 0], 35);
    // the bar: shaft, collars, sleeves; a soft shadow under it
    const bar = new T.Group(), steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 24), m); c.rotation.z = Math.PI / 2; c.position.x = x; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); });
    this.flAdd(bar);
    this.flBar = { bar, on: [], side: [], y: 0.9 };
    const floorY = () => (this.liftOnFloor(this.setIdx) ? 0.225 : 0.9);
    bar.position.y = floorY(); this.flBar.y = bar.position.y;
    F.tick = (dt) => {
      const B = this.flBar, goal = floorY(); B.y += (goal - B.y) * (1 - Math.exp(-dt * 6)); bar.position.y = B.y;
      B.on.forEach((m) => {
        m.t += dt;
        if (m.out) { const q = Math.min(1, m.t / 0.3); m.o.position.x = m.x + m.sg * 0.9 * q * q; m.o.position.y = B.y - 0.8 * Math.max(0, q - 0.5); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.6) / 0.4)); if (q >= 1) { F.S.remove(m.o); m.gone = true; } return; }
        const q = Math.min(1, Math.max(0, (m.t - m.dl) / 0.34)); m.o.visible = m.t >= m.dl;
        m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * this.outCubic(q); m.o.position.y = B.y;
        if (q >= 1 && !m.seat) { m.seat = true; this.buzz('light'); }
      });
      B.on = B.on.filter((m) => !m.gone);
    };
    this.flLoad(this.setIdx);
    this.flSetCard();
  }
  flLoad(i) {
    const B = this.flBar, T = this.THREE, x = this.plan.flat[i], sp = this.specs(), next = x.side.slice(), prev = B.side;
    let c = 0; while (c < prev.length && c < next.length && prev[c] === next[c]) c++;
    B.on.forEach((m) => { if (!m.out && m.k >= c) { m.out = true; m.t = 0; } });
    let cum = 0;
    next.forEach((w, k) => {
      const s = sp.find((q) => q.kg === w); if (!s) return;
      const xp = 0.695 + cum + s.t / 2; cum += s.t + 0.002;
      if (k < c) return;
      [-1, 1].forEach((sg) => {
        const g = this.plate(s), o = new T.Group(); o.add(g); g.rotation.set(Math.random() * 6.28, 0, Math.PI / 2); o.position.set(sg * 1.5, B.y, 0); o.visible = false;
        this.FL.S.add(o); this.FL.objs.push(o);
        B.on.push({ o, sg, k, x: sg * xp, t: 0, dl: 0.15 + (k - c) * 0.18 + (sg > 0 ? 0.05 : 0) });
      });
    });
    B.side = next;
  }
  flSetCard() {
    const F = this.FL, P = this.plan, i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    F.ui.innerHTML = '';
    const c = this.flCard();
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', opacity: 0.75 }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 10px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px', marginBottom: '14px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? this.FC.dark : 'rgba(0,0,0,0.12)' }, dots); });
    this.flBtn(c, 'Done', () => this.flCheck());
    const pl = this.fh('button', { position: 'absolute', right: '16px', top: '64px', display: 'flex', alignItems: 'center', gap: '6px', height: '38px', padding: '0 14px', border: 0, borderRadius: '19px', background: this.FC.light, color: this.FC.dark, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '15px', cursor: 'pointer', pointerEvents: 'auto' }, F.ui);
    pl.className = 'tap'; pl.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></svg>Plates';
    pl.setAttribute('aria-label', 'See the plate kit'); pl.onclick = () => { this.buzz('light'); this.flClear(); this.flStep = 'kit'; this.flKit(true); };
  }
  flCheck() {
    const P = this.plan, n = P.flat.length, i = this.setIdx;
    this.doneSets[i] = true; this.buzz('success');
    if (this.doneSets.filter(Boolean).length >= n) { this.flFinish(); return; }
    let j = i + 1; while (j < n && this.doneSets[j]) j++;
    if (j >= n) { j = 0; while (j < n && this.doneSets[j]) j++; }
    this.setIdx = j; this.flSetCard(); setTimeout(() => { if (!this.dead && this.flBar) this.flLoad(j); }, 300);
  }
  flFinish() {
    this.FL.ui.innerHTML = '';
    setTimeout(() => { if (!this.dead) this.showSessionOver(); }, 500);
  }
  // after the scale: back to "what are we doing today?"
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light'); this.dropLayer(L);
    this.plan = null; this.flBar = null; this.flAgain = true; this.flGo('wod');
  }

  // ===================== FLOW, round 2 (these override the first versions above) =====================
  flClear() {
    const F = this.FL;
    F.objs.forEach((o) => { F.S.remove(o); });
    F.objs = []; F.tick = null; F.drag = null; F.hit = null; F.swipe = false; F.sw.style.display = 'none'; F.sw.style.bottom = '34px'; F.ui.innerHTML = ''; F.tw = []; F.grab = null;
    F.onSwipe = null; F.onTap = null;
    F.words.forEach(clearTimeout); F.words = []; F.q.textContent = ''; F.q.removeAttribute('aria-label');
    (this.flDusts || []).forEach((d) => F.S.remove(d.m)); this.flDusts = [];
    this.flWorld = null; (this.flTimers || []).forEach(clearTimeout); this.flTimers = [];
  }
  flLater(fn, ms) { const t = setTimeout(() => { if (!this.dead) fn(); }, ms); (this.flTimers = this.flTimers || []).push(t); return t; }

  // ---------------- sound: a short mechanical click (dials, sliders), a thud (drops) ----------------
  flAudio() {
    if (this.flAC) return this.flAC;
    try { const AC = window.AudioContext || window.webkitAudioContext; if (AC) this.flAC = new AC(); } catch (e) {}
    if (this.flAC && !this.flNoise) {
      const n = Math.floor(this.flAC.sampleRate * 0.05), b = this.flAC.createBuffer(1, n, this.flAC.sampleRate), d = b.getChannelData(0);
      for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / n, 6);
      this.flNoise = b;
    }
    return this.flAC;
  }
  flClick(pitch) {
    const ac = this.flAudio(); if (!ac || !this.flNoise) return;
    if (ac.state === 'suspended') { try { ac.resume(); } catch (e) {} }
    const now = ac.currentTime; if (this.flLastClick && now - this.flLastClick < 0.025) return; this.flLastClick = now;
    const src = ac.createBufferSource(); src.buffer = this.flNoise; src.playbackRate.value = 0.9 + Math.random() * 0.2;
    const bp = ac.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 2400 * (pitch || 1); bp.Q.value = 3.5;
    const g = ac.createGain(); g.gain.setValueAtTime(0.55, now); g.gain.exponentialRampToValueAtTime(0.001, now + 0.045);
    src.connect(bp).connect(g).connect(ac.destination); src.start(now); src.stop(now + 0.06);
    // a little wooden body under the click
    const o = ac.createOscillator(), og = ac.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(420 * (pitch || 1), now); o.frequency.exponentialRampToValueAtTime(180, now + 0.04);
    og.gain.setValueAtTime(0.12, now); og.gain.exponentialRampToValueAtTime(0.001, now + 0.05); o.connect(og).connect(ac.destination); o.start(now); o.stop(now + 0.06);
  }
  flThud(k) {
    const ac = this.flAudio(); if (!ac) return; if (ac.state === 'suspended') { try { ac.resume(); } catch (e) {} }
    const now = ac.currentTime, a = Math.min(1, k || 0.6);
    const o = ac.createOscillator(), g = ac.createGain(); o.type = 'sine'; o.frequency.setValueAtTime(120, now); o.frequency.exponentialRampToValueAtTime(42, now + 0.25);
    g.gain.setValueAtTime(0.7 * a, now); g.gain.exponentialRampToValueAtTime(0.001, now + 0.3); o.connect(g).connect(ac.destination); o.start(now); o.stop(now + 0.32);
    if (this.flNoise) { const s = ac.createBufferSource(); s.buffer = this.flNoise; const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 900; const sg = ac.createGain(); sg.gain.setValueAtTime(0.5 * a, now); sg.gain.exponentialRampToValueAtTime(0.001, now + 0.12); s.connect(lp).connect(sg).connect(ac.destination); s.start(now); }
  }

  // ---------------- dust: low-poly puffs that roll out and shrink ----------------
  flDust(x, y, z, count, power, size) {
    const T = this.THREE, F = this.FL; this.flDusts = this.flDusts || [];
    const M = this.flDustMat || (this.flDustMat = this.toon(this.FC.light));
    const G = this.flDustGeo || (this.flDustGeo = new T.IcosahedronGeometry(1, 0));
    for (let i = 0; i < count; i++) {
      const m = new T.Mesh(G, M), a = Math.random() * Math.PI * 2, sp = (0.6 + Math.random()) * power;
      m.position.set(x + Math.cos(a) * 0.15, y + 0.03, z + Math.sin(a) * 0.15); m.rotation.set(Math.random() * 3, Math.random() * 3, 0);
      const s = (0.03 + Math.random() * 0.05) * (0.7 + power * 0.4) * (size || 1); m.scale.setScalar(s); F.S.add(m);
      this.flDusts.push({ m, v: new T.Vector3(Math.cos(a) * sp, 0.5 + Math.random() * 1.1 * power, Math.sin(a) * sp), life: 0, max: 0.55 + Math.random() * 0.4, s });
    }
  }
  flDustTick(dt) {
    if (!this.flDusts || !this.flDusts.length) return;
    const F = this.FL;
    this.flDusts = this.flDusts.filter((d) => {
      d.life += dt; const u = d.life / d.max; if (u >= 1) { F.S.remove(d.m); return false; }
      d.v.multiplyScalar(Math.exp(-dt * 3.2)); d.v.y -= dt * 0.8;
      d.m.position.addScaledVector(d.v, dt); if (d.m.position.y < 0.02) d.m.position.y = 0.02;
      d.m.scale.setScalar(Math.max(0.001, d.s * (1 + u * 0.8) * (1 - u * u))); d.m.rotation.x += dt * 2; return true;
    });
  }

  // ---------------- dials: low poly, a clear reading window, a click per notch ----------------
  flDrum(labels, o) {
    const T = this.THREE, n = labels.length, r = o.r || 0.95, a0 = o.a0 || 0.36, W = o.w || 0.9, wrap = o.wrap !== false;
    const g = new T.Group(), segs = 10;
    const flat = (hex) => { const m = this.toon(hex); m.flatShading = true; return m; };
    const body = new T.Mesh(new T.CylinderGeometry(r - 0.03, r - 0.03, W, segs, 1), flat(this.FC.dark)); body.rotation.z = Math.PI / 2; g.add(body);
    [-1, 1].forEach((s) => { const rim = new T.Mesh(new T.CylinderGeometry(r + 0.04, r + 0.04, 0.07, segs), flat(this.FC.light)); rim.rotation.z = Math.PI / 2; rim.position.x = s * (W / 2 + 0.03); g.add(rim); });
    // the reading window: a cream frame around the front row
    const fh = a0 * r * 1.02, fw = W + 0.14, bt = 0.035, fm = new T.MeshBasicMaterial({ color: this.FC.light }), frame = new T.Group();
    [[0, fh / 2, fw, bt], [0, -fh / 2, fw, bt], [-fw / 2, 0, bt, fh + bt], [fw / 2, 0, bt, fh + bt]].forEach(([x, y, w, h]) => { const m = new T.Mesh(new T.BoxGeometry(w, h, 0.03), fm); m.position.set(x, y, r + 0.06); frame.add(m); });
    g.add(frame);
    const tex = {}, texOf = (i) => tex[i] || (tex[i] = this.textTex(labels[i], { w: 256, h: 140, size: o.size || 112, col: this.FC.light, dy: 6 }));
    const K = Math.ceil(1.45 / a0) + 1, pool = [];
    for (let k = -K; k <= K; k++) {
      const m = new T.Mesh(new T.PlaneGeometry(o.lw || 0.62, a0 * r * 0.95), new T.MeshBasicMaterial({ transparent: true, depthWrite: false })); g.add(m); pool.push(m);
    }
    g.position.z = -r;
    const D = { g, n, pos: 0, vel: 0, idx: 0, lock: false, body, opacity: 1, frame };
    const norm = (i) => (wrap ? ((i % n) + n) % n : Math.max(0, Math.min(n - 1, i)));
    D.set = (i) => { D.pos = i; D.idx = norm(i); };
    D.layout = () => {
      const base = Math.floor(D.pos);
      pool.forEach((m, j) => {
        const li = base + j - K, th = (li - D.pos) * a0, inRange = wrap || (li >= 0 && li < n);
        m.visible = inRange && Math.abs(th) < 1.45;
        if (!m.visible) return;
        const mi = norm(li); if (m.userData.li !== mi) { m.userData.li = mi; m.material.map = texOf(mi); m.material.needsUpdate = true; }
        const front = Math.max(0, 1 - Math.abs(th) / (a0 * 0.75));     // 1 on the reading line, 0 a notch away
        m.position.set(0, -r * Math.sin(th), r * Math.cos(th) + 0.004 + front * 0.03); m.rotation.x = th;
        m.scale.setScalar(1 + 0.18 * front);
        m.material.opacity = D.opacity * (0.28 + 0.72 * front) * Math.max(0, Math.cos(th * 1.05));
      });
      frame.visible = D.opacity > 0.5;
    };
    D.tick = (dt, dragging) => {
      if (!dragging) {
        D.pos += D.vel * dt; D.vel *= Math.exp(-dt * 4.5);
        if (!wrap) { if (D.pos < 0) { D.pos += (0 - D.pos) * 0.3; D.vel = 0; } if (D.pos > n - 1) { D.pos += (n - 1 - D.pos) * 0.3; D.vel = 0; } }
        if (Math.abs(D.vel) < 2) D.pos += (Math.round(D.pos) - D.pos) * (1 - Math.exp(-dt * 12));
      }
      const i = norm(Math.round(D.pos));
      if (i !== D.idx) { D.idx = i; this.flClick(1); }
      D.layout();
    };
    D.layout();
    return D;
  }

  // ---------------- 3 · kettlebells: one solid piece, a soft shadow; the square gives under the drop ----------------
  kettlebell(label) {
    const T = this.THREE, g = new T.Group(), M = this.toon(this.FC.dark); M.flatShading = true;
    // the bell: a sphere cut flat at the bottom, closed with a disc (no ring around the foot)
    const cut = Math.PI * 0.84, body = new T.Mesh(new T.SphereGeometry(0.42, 16, 12, 0, Math.PI * 2, 0, cut), M);
    const yb = 0.42 * Math.cos(cut); body.position.y = -yb; g.add(body);
    const foot = new T.Mesh(new T.CircleGeometry(0.42 * Math.sin(cut), 16), M); foot.rotation.x = Math.PI / 2; foot.position.y = 0.001; g.add(foot);
    const top = 0.42 - yb;
    const handle = new T.Mesh(new T.TorusGeometry(0.24, 0.058, 8, 18, Math.PI), M); handle.position.y = top + 0.12; g.add(handle);
    [-1, 1].forEach((s) => { const h = new T.Mesh(new T.CylinderGeometry(0.058, 0.07, 0.2, 8), M); h.position.set(s * 0.24, top + 0.04, 0); g.add(h); });
    const lab = new T.Mesh(new T.PlaneGeometry(0.5, 0.32), new T.MeshBasicMaterial({ map: this.textTex(label, { w: 256, h: 160, size: 120, col: this.FC.light }), transparent: true }));
    lab.position.set(0, -yb, 0.43); g.add(lab);
    g.userData.label = label; return g;
  }
  softShadow(r) {
    const T = this.THREE;
    if (!this.flShadowTex) { const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d'), gr = x.createRadialGradient(64, 64, 4, 64, 64, 62); gr.addColorStop(0, 'rgba(0,0,0,0.38)'); gr.addColorStop(0.55, 'rgba(0,0,0,0.16)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = gr; x.fillRect(0, 0, 128, 128); this.flShadowTex = new T.CanvasTexture(c); }
    const m = new T.Mesh(new T.PlaneGeometry(r * 2, r * 2), new T.MeshBasicMaterial({ map: this.flShadowTex, transparent: true, depthWrite: false })); m.rotation.x = -Math.PI / 2; m.position.y = 0.003; return m;
  }
  flUnit() {
    const F = this.FL, T = this.THREE, name = this.d.name || '79';
    this.flCam([0, 6.2, 10.4], [0, -0.35, 0.45], 35);
    this.flSay('Cool. Let’s set ' + name + '. Do they use kilos or pounds there?');
    const sq = new T.Group(), SZ = 1.25, th = 0.06, SQ = [0, 1.55];
    const Ml = new T.MeshBasicMaterial({ color: this.FC.light });
    [[0, -SZ / 2, SZ + th, th], [0, SZ / 2, SZ + th, th], [-SZ / 2, 0, th, SZ], [SZ / 2, 0, th, SZ]].forEach(([x, z, w, d]) => { const m = new T.Mesh(new T.BoxGeometry(w, 0.02, d), Ml); m.position.set(x, 0.01, z); sq.add(m); });
    sq.position.set(SQ[0], 0, SQ[1]); this.flAdd(sq); this.popIn(sq, 900);
    const bells = [['KG', 'kg', -0.95], ['LB', 'lb', 0.95]].map(([lab, u, x], i) => {
      const g = this.kettlebell(lab), sh = this.softShadow(0.62); g.position.set(x, 0, -0.55); sh.position.set(x, 0.003, -0.55);
      this.flAdd(g); this.flAdd(sh); this.popIn(g, 600 + i * 140);
      return { g, sh, u, home: new T.Vector3(x, 0, -0.55) };
    });
    let done = false;
    const shadowAt = (b) => { b.sh.position.set(b.g.position.x, 0.003, b.g.position.z); const s = 1 + b.g.position.y * 0.5; b.sh.scale.setScalar(s); b.sh.material.opacity = 1 / (s * s); };
    F.hit = (e) => {
      if (done) return null;
      const rc = this.flRay(e), b = bells.find((q) => rc.intersectObject(q.g, true).length); if (!b) return null;
      this.buzz('selection'); this.flAudio();
      const GY = -0.42, off = new T.Vector3(); { const p = this.flPlane(e, new T.Vector3(0, 1, 0), GY); if (p) off.copy(b.g.position).sub(p); off.y = 0; }
      return {
        move: (ev) => { const p = this.flPlane(ev, new T.Vector3(0, 1, 0), GY); if (!p) return; const x = p.x + off.x, z = p.z + off.z; b.g.position.set(x, 0.42, z); b.g.rotation.z = Math.max(-0.25, Math.min(0.25, ((x - b.lx) || 0) * -1.5)); b.lx = x; shadowAt(b); },
        up: () => {
          const p = b.g.position, inside = Math.abs(p.x - SQ[0]) < SZ / 2 && Math.abs(p.z - SQ[1]) < SZ / 2;
          const from = p.clone(), to = inside ? new T.Vector3(SQ[0], 0, SQ[1]) : b.home.clone(), r0 = b.g.rotation.z;
          if (inside) done = true;
          // it falls: accelerating, not easing in
          this.flAnim((u) => { const e2 = inside ? u * u : this.outCubic(u); b.g.position.lerpVectors(from, to, inside ? Math.min(1, u * 1.6) : e2); b.g.position.y = from.y * (1 - e2); b.g.rotation.z = r0 * (1 - e2); shadowAt(b); }, inside ? 0.26 : 0.32, () => {
            if (!inside) return;
            this.buzz('success');
            this.flImpact({ m: 16, v: 4.2, x: SQ[0], z: SQ[1], R: 0.3, target: null });
            const g = b.g; this.flAnim((u) => { const s = 1 + 0.14 * Math.sin(u * Math.PI) * (1 - u); g.scale.set(1 + (s - 1) * 0.6, 1 - (s - 1), 1 + (s - 1) * 0.6); }, 0.35);
            // the square gives a little under the weight, and settles a hair lower
            this.flAnim((u) => { sq.position.y = -0.05 * Math.sin(Math.min(1, u * 1.4) * Math.PI / 2) * (1 - 0.6 * Math.max(0, u - 0.7) / 0.3) - 0.0; g.position.y = sq.position.y; }, 0.5);
            this.setUnit(b.u);
            this.flLater(() => { if (this.flStep === 'unit') this.flGo('plates'); }, 1000);
          });
        }
      };
    };
  }

  // ---------------- 4b · which bar: a horizontal 3D slider, the pick in the middle ----------------
  barModel(w, i) {
    const T = this.THREE, g = new T.Group(), L = [1, 0.914, 0.8][i] || 1, th = [1, 0.88, 0.8][i] || 1;
    const flat = (hex) => { const m = this.toon(hex); m.flatShading = true; return m; };
    const shaft = flat('#B4BAC1'), sleeve = flat('#EDEFF1'), collar = flat('#5E6670');
    const cyl = (r, len, m, y) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 8), m); c.position.y = y; g.add(c); return c; };
    const half = 1.1 * L, sl = 0.42 * L, sr = 0.025 * th * 1.6, rr = 0.0142 * th * 1.7;
    cyl(rr, (half - sl) * 2, shaft, 0);
    [-1, 1].forEach((s) => { cyl(rr * 2.6, 0.035, collar, s * (half - sl)); cyl(sr, sl, sleeve, s * (half - sl / 2)); cyl(sr * 1.15, 0.02, collar, s * half); });
    const lab = new T.Mesh(new T.PlaneGeometry(0.62, 0.26), new T.MeshBasicMaterial({ map: this.textTex(this.fmt(w) + ' ' + this.d.unit, { w: 320, h: 130, size: 92, col: this.FC.light }), transparent: true }));
    lab.position.y = -1.55;
    const sh = this.softShadow(0.42); sh.scale.set(1, 0.55, 1); sh.position.y = -1.22;
    const wrap = new T.Group(); wrap.add(g); wrap.add(lab); wrap.add(sh); wrap.userData.bar = g;
    return wrap;
  }
  flBarQ() {
    const F = this.FL, T = this.THREE, list = this.BARS[this.d.unit], n = list.length, SP = 1.02;
    this.flCam([0, 1.05, 7.0], [0, -0.5, 0], 35);
    this.flSay('What bar do you use?');
    const bars = list.map(([w], i) => { const g = this.barModel(w, i); g.position.y = -0.3; this.flAdd(g); this.popIn(g, 350 + i * 90); return g; });
    let pos = 1, vel = 0, idx = Math.round(pos), dragging = false;
    const layout = (t) => bars.forEach((g, i) => {
      const d = i - pos, ad = Math.abs(d);
      g.position.x = d * SP;
      g.userData.bar.rotation.y = (t || 0) * 0.6 + i; g.rotation.z = -0.24;   // leaning a little
    });
    bars.forEach((g, i) => this.flLater(() => { g.userData.popped = true; }, 900 + i * 90));
    F.tick = (dt, t) => {
      if (!dragging) { pos += vel * dt; vel *= Math.exp(-dt * 5); pos = Math.max(-0.3, Math.min(n - 0.7, pos)); if (Math.abs(vel) < 1.5) pos += (Math.max(0, Math.min(n - 1, Math.round(pos))) - pos) * (1 - Math.exp(-dt * 10)); }
      const i = Math.max(0, Math.min(n - 1, Math.round(pos))); if (i !== idx) { idx = i; this.flClick(0.8); this.buzz('selection'); }
      layout(t);
    };
    const pick = () => { this.d.bar[this.d.unit] = list[idx][0]; this.flGo('prs'); };
    const ppi = 390 * SP / (F.cam.position.z * 0.2914);
    F.hit = (e) => {
      let x0 = e.clientX, y0 = e.clientY, sx = e.clientX, sy = e.clientY, t0 = performance.now(); dragging = true; this.flAudio();
      return {
        move: (ev) => { const dx = ev.clientX - x0, now = performance.now(); const d = -dx / ppi; pos += d; vel = d / Math.max(0.008, (now - t0) / 1000); x0 = ev.clientX; t0 = now; },
        up: (ev, tap) => {
          dragging = false; if (performance.now() - t0 > 90) vel = 0;
          const dx = ev.clientX - sx, dy = ev.clientY - sy;
          if (tap || (dy < -55 && Math.abs(dy) > Math.abs(dx) * 1.5)) { vel = 0; pos = idx; this.buzz('light'); pick(); }
        }
      };
    };
    this.flLater(() => { if (this.flStep === 'bar') { F.sw.style.display = 'block'; } }, 900);
  }

  // ---------------- 7 · the kit: plates fall from the sky, land with dust; you can drag and throw them ----------------
  flKit(mid) {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flStep = 'kit';
    this.flCam([0, 5.0, 5.0], [0, -1.15, -0.75], 35);
    const C = window.PlateKit.CANNON, w = new C.World({ gravity: new C.Vec3(0, -9.81, 0) });
    w.broadphase = new C.SAPBroadphase(w); w.allowSleep = true; w.solver.iterations = 14;
    const mP = new C.Material('p'), mG = new C.Material('g');
    w.addContactMaterial(new C.ContactMaterial(mP, mG, { friction: 0.5, restitution: 0.22 }));
    w.addContactMaterial(new C.ContactMaterial(mP, mP, { friction: 0.35, restitution: 0.12 }));
    const ground = new C.Body({ mass: 0, material: mG }); ground.addShape(new C.Plane()); ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0); w.addBody(ground);
    // invisible fences just outside the view, so a throw stays on screen
    [[0, -3.1, 3.2, 0.2], [0, 1.3, 3.2, 0.2], [-1.65, -0.9, 0.2, 2.6], [1.65, -0.9, 0.2, 2.6]].forEach(([x, z, hx, hz]) => { const b = new C.Body({ mass: 0, material: mG }); b.addShape(new C.Box(new C.Vec3(hx, 1.5, hz))); b.position.set(x, 1.5, z); w.addBody(b); });
    this.flWorld = w;
    // a floor that only shows shadows
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.22 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const sp = this.specs(), kit = P.kit, n = kit.length, cols = Math.min(3, Math.max(1, n)), rows = Math.ceil(n / cols), gx = 0.66, gz = 0.66, items = [];
    kit.forEach((k, i) => {
      const s = sp.find((q) => q.kg === k.w); if (!s) return;
      const cx = (i % cols - (cols - 1) / 2) * gx, cz = (Math.floor(i / cols) - (rows - 1) / 2) * gz - 0.45;
      for (let j = 0; j < k.qty; j++) {
        const g = this.plate(s), o = new T.Group(); o.add(g); g.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
        o.visible = false; this.flAdd(o);
        const R = s.d / 2, t = s.t, mass = s.unit === 'LB' ? s.kg * 0.4536 : s.kg;
        const it = { o, R, t, mass, s, landed: false };
        items.push(it);
        this.flLater(() => {
          if (this.flWorld !== w) return;
          const b = new C.Body({ mass, material: mP, linearDamping: 0.04, angularDamping: 0.08, sleepSpeedLimit: 0.08, sleepTimeLimit: 0.7 });
          b.addShape(new C.Cylinder(R, R, t, 16));
          const Ix = mass * (3 * R * R + t * t) / 12, Iy = 0.5 * mass * R * R; b.inertia.set(Ix, Iy, Ix); b.invInertia.set(1 / Ix, 1 / Iy, 1 / Ix); b.updateInertiaWorld(true);
          b.position.set(cx + (Math.random() - 0.5) * 0.05, 5 + j * 0.35 + Math.random() * 0.6, cz + (Math.random() - 0.5) * 0.05);
          b.quaternion.setFromEuler((Math.random() - 0.5) * 0.3, Math.random() * 6.28, (Math.random() - 0.5) * 0.3);
          b.velocity.set(0, -3, 0); b.angularVelocity.set((Math.random() - 0.5) * 0.8, (Math.random() - 0.5) * 1.5, (Math.random() - 0.5) * 0.8);
          b.addEventListener('collide', (e) => {
            const v = Math.abs(e.contact.getImpactVelocityAlongNormal()); if (v < 2 || it.landed) return;
            // first landing only: a small puff, a thud, a little shake
            it.landed = true;
            const f = Math.min(1, mass / 25) * Math.min(1, v / 7);
            this.flDust(b.position.x, 0, b.position.z, Math.round(3 + 7 * f), 0.35 + 0.7 * f, 0.45);
            this.flShake = Math.max(this.flShake || 0, 0.02 + 0.07 * f); this.flThud(0.25 + 0.6 * f); this.buzz('light');
          });
          w.addBody(b); it.b = b; o.visible = true;
        }, (mid ? 100 : 250) + i * 170 + j * 90);
      }
    });
    F.tick = (dt) => {
      if (this.flWorld !== w) return;
      if (F.grab && F.grab.b) { const G = F.grab, b = G.b; const v = G.to.clone().sub(new T.Vector3(b.position.x, b.position.y, b.position.z)).multiplyScalar(14); b.velocity.set(v.x, v.y, v.z); b.angularVelocity.scale(0.9, b.angularVelocity); b.wakeUp(); }
      w.step(1 / 120, dt, 8);
      items.forEach((it) => { if (!it.b) return; it.o.position.copy(it.b.position); it.o.quaternion.copy(it.b.quaternion); });
    };
    // pick a plate up: a disc test from the ray (works through the hole), then it follows the finger and can be thrown
    F.hit = (e) => {
      const rc = this.flRay(e); let hit = null, bd = 1e9;
      items.forEach((it) => { if (!it.b) return; const d = rc.ray.distanceToPoint(it.o.position); if (d < it.R * 1.1 && d < bd) { bd = d; hit = it; } });
      if (!hit) return null;
      this.buzz('selection'); this.flAudio();
      const H = 0.55, plane = new T.Plane(new T.Vector3(0, 1, 0), -H), p = new T.Vector3();
      const G = F.grab = { b: hit.b, to: new T.Vector3(hit.b.position.x, H, hit.b.position.z) };
      return {
        move: (ev) => { const r2 = this.flRay(ev); if (r2.ray.intersectPlane(plane, p)) G.to.set(Math.max(-1.45, Math.min(1.45, p.x)), H, Math.max(-2.9, Math.min(1.1, p.z))); },
        up: () => { F.grab = null; const v = hit.b.velocity; const sp2 = Math.hypot(v.x, v.z), mx = 5; if (sp2 > mx) { v.x *= mx / sp2; v.z *= mx / sp2; } }
      };
    };
    // the chips; the session starts with a swipe up or a tap
    const c = this.flCard(), got = this.d.kitGot = this.d.kitGot || {};
    const wrap = this.fh('div', { display: 'flex', flexWrap: 'wrap', gap: '8px' }, c);
    kit.forEach((k) => {
      const s = sp.find((q) => q.kg === k.w) || { color: '#999', d: 0.3 };
      const b = this.fh('button', { display: 'inline-flex', alignItems: 'center', gap: '8px', height: '40px', padding: '0 14px 0 10px', borderRadius: '999px', border: '2px solid ' + this.FC.dark, fontFamily: 'inherit', fontWeight: 800, fontSize: '16px', cursor: 'pointer' }, wrap);
      b.className = 'tap'; b.setAttribute('role', 'checkbox');
      this.fh('span', { width: Math.round(10 + s.d * 14) + 'px', height: Math.round(10 + s.d * 14) + 'px', borderRadius: '50%', background: s.color, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.2)' }, b);
      this.fh('span', {}, b, k.qty + ' × ' + this.fmt(k.w) + ' ' + P.unit);
      const paint = () => { const on = !!got[k.w]; b.style.background = on ? this.FC.dark : 'transparent'; b.style.color = on ? this.FC.light : this.FC.dark; b.setAttribute('aria-checked', String(on)); };
      paint(); b.onclick = () => { if (got[k.w]) delete got[k.w]; else { got[k.w] = true; this.buzz('light'); } paint(); };
    });
    c.style.bottom = '84px';
    this.flLater(() => { if (this.flStep === 'kit') this.flSwipe(() => this.flGo('sets')); }, 900);
  }

  // ---------------- 8 · set by set: close on one end of the bar; white card; swipe for the next set ----------------
  flSets() {
    const F = this.FL, T = this.THREE, P = this.plan; if (!P) { this.flGo('wod'); return; }
    this.flCam([2.05, 1.32, 1.55], [0.5, 0.86, -0.12], 40);
    const bar = new T.Group(), flat = (hex) => { const m = this.toon(hex); m.flatShading = true; return m; };
    const steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 20), m); c.rotation.z = Math.PI / 2; c.position.x = x; c.castShadow = true; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); });
    bar.position.y = 0.9; this.flAdd(bar);
    this.flBar = { bar, on: [], side: [], y: 0.9 };
    F.tick = (dt) => {
      const B = this.flBar; if (!B) return;
      B.on.forEach((m) => {
        m.t += dt;
        if (m.out) { const q = Math.min(1, m.t / 0.3); m.o.position.x = m.x + m.sg * 0.9 * q * q; m.o.position.y = B.y - 0.8 * Math.max(0, q - 0.5); m.o.scale.setScalar(Math.max(0.001, 1 - Math.max(0, q - 0.6) / 0.4)); if (q >= 1) { F.S.remove(m.o); m.gone = true; } return; }
        const q = Math.min(1, Math.max(0, (m.t - m.dl) / 0.34)); m.o.visible = m.t >= m.dl;
        m.o.position.x = m.sg * 1.5 + (m.x - m.sg * 1.5) * this.outCubic(q); m.o.position.y = B.y;
        if (q >= 1 && !m.seat) { m.seat = true; this.flClick(0.45); this.buzz('light'); }
      });
      B.on = B.on.filter((m) => !m.gone);
    };
    this.flLoad(this.setIdx);
    this.flSetCard(0);
  }
  flSetCard(dir) {
    const F = this.FL, P = this.plan, i = Math.min(this.setIdx, P.flat.length - 1), x = P.flat[i], grp = P.groups[x.gi];
    const last = this.doneSets.filter(Boolean).length >= P.flat.length - 1;
    const old = F.ui.querySelector('[data-setcard]');
    if (old) { old.removeAttribute('data-setcard'); old.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-60px)', opacity: 0 }], { duration: 260, easing: 'ease-in', fill: 'forwards' }); setTimeout(() => old.remove(), 270); }
    [...F.ui.querySelectorAll('[data-plates]')].forEach((e) => e.remove());
    const c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px 18px 18px', borderRadius: '22px', background: '#FFFFFF', color: '#000000', fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 10px 30px rgba(0,0,0,0.18)' }, F.ui);
    c.setAttribute('data-setcard', '');
    c.animate([{ transform: dir ? 'translateY(70px)' : 'translateY(120%)', opacity: dir ? 0 : 1 }, { transform: 'none', opacity: 1 }], { duration: dir ? 320 : 420, delay: dir ? 120 : 0, easing: 'cubic-bezier(.2,.9,.25,1)', fill: 'backwards' });
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'rgba(0,0,0,0.5)' }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 12px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? '#34C759' : j === i ? '#000000' : 'rgba(0,0,0,0.12)' }, dots); });
    if (last) {
      const b = this.fh('button', { width: '100%', height: '56px', marginTop: '16px', border: 0, borderRadius: '16px', background: '#000000', color: '#FFFFFF', fontFamily: 'inherit', fontWeight: 900, fontSize: '19px', cursor: 'pointer' }, c, 'End session');
      b.className = 'tap'; b.onclick = () => { this.buzz('success'); this.doneSets[this.setIdx] = true; this.flFinish(); };
    }
    const pl = this.fh('button', { position: 'absolute', right: '16px', top: '64px', display: 'flex', alignItems: 'center', gap: '6px', height: '38px', padding: '0 14px', border: 0, borderRadius: '19px', background: '#FFFFFF', color: '#000000', fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '15px', cursor: 'pointer', pointerEvents: 'auto' }, F.ui);
    pl.setAttribute('data-plates', ''); pl.className = 'tap'; pl.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></svg>Plates';
    pl.setAttribute('aria-label', 'See the plate kit'); pl.onclick = () => { this.buzz('light'); this.flClear(); this.flKit(true); };
    // the next set: swipe up (or tap); the last one ends with its button
    if (last) { F.swipe = false; F.onSwipe = null; F.onTap = null; F.sw.style.display = 'none'; }
    else this.flSwipe(() => this.flCheck());
    F.sw.style.bottom = '196px';
  }
  flCheck() {
    const P = this.plan, n = P.flat.length, i = this.setIdx;
    this.doneSets[i] = true; this.buzz('success');
    if (this.doneSets.filter(Boolean).length >= n) { this.flFinish(); return; }
    let j = i + 1; while (j < n && this.doneSets[j]) j++;
    if (j >= n) { j = 0; while (j < n && this.doneSets[j]) j++; }
    this.setIdx = j; this.flSetCard(1); this.flLater(() => { if (this.flBar) this.flLoad(j); }, 250);
  }
  flFinish() {
    const F = this.FL; F.ui.innerHTML = ''; F.swipe = false; F.onSwipe = null; F.onTap = null; F.sw.style.display = 'none'; F.sw.style.bottom = '34px';
    this.flLater(() => this.showSessionOver(), 500);
  }

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
    Object.assign(c.style, { background: '#FFFFFF', color: this.pal.boxDark, boxShadow: '0 10px 30px rgba(0,0,0,0.18)' });
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

  // ===================== FLOW, round 6: polish =====================
  // words appear one by one, no fade — the spoken timing stays
  flSay(text, then) {
    const F = this.FL, q = F.q; F.words.forEach(clearTimeout); F.words = [];
    q.getAnimations().forEach((a) => a.cancel());
    q.textContent = ''; q.setAttribute('aria-label', text); q.style.transform = ''; q.style.opacity = '1';
    const ws = text.split(/\s+/).filter(Boolean); let t = 0;
    ws.forEach((w, i) => {
      const s = document.createElement('span'); s.textContent = w; s.style.visibility = 'hidden'; q.appendChild(s);
      if (i < ws.length - 1) q.appendChild(document.createTextNode(' '));
      F.words.push(setTimeout(() => { if (!this.dead) s.style.visibility = 'visible'; }, t));
      t += 95 + 18 * w.replace(/[^\w’']/g, '').length;
      if (/[,;:]$/.test(w)) t += 230;
      if (/[.?!…]$/.test(w)) t += 420;
    });
    const total = t + 120;
    F.words.push(setTimeout(() => { if (!this.dead && then) then(); }, total));
    return total;
  }
  flSwipeQuiet(fn) { const F = this.FL; F.swipe = true; F.onSwipe = fn; F.onTap = fn; F.sw.style.display = 'none'; }
  // leaving a question: everything clears out fast (ease-out), then the next question starts on an empty screen
  flPanTo(step) {
    if (this.flPanning) return;
    if (this.flDirect) { this.flDirect = false; this.flGo(step); return; }
    this.flPanning = true;
    const F = this.FL, EO = 'cubic-bezier(.16,1,.3,1)';
    F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null; F.drag = null;
    F.q.getAnimations().forEach((a) => a.cancel());
    F.q.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-26px)', opacity: 0 }], { duration: 260, easing: EO, fill: 'forwards' });
    [...F.ui.children].forEach((el) => el.animate([{ transform: 'none', opacity: 1 }, { transform: 'translateY(-26px)', opacity: 0 }], { duration: 260, easing: EO, fill: 'forwards' }));
    (this.flSpk || []).forEach((d) => F.S.remove(d.m)); this.flSpk = [];
    const objs = F.objs.slice(), s0 = objs.map((o) => o.scale.clone());
    this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); objs.forEach((o, i) => o.scale.copy(s0[i]).multiplyScalar(Math.max(0.0001, 1 - e))); }, 0.3, () => {
      this.flPanning = false; this.flGo(step);
    });
  }
  flGo(step) {
    this.flClear(); this.flStep = step; this.flApplyStyle();
    ({ name: () => this.flName(), unit: () => this.flUnit(), plates: () => this.flPlates(), bar: () => this.flBarQ(), prs: () => this.flPRs(), prDial: () => this.flPRDial(0),
      wod: () => this.flWod(), kit: () => this.flKit(), sets: () => this.flSets(), menu: () => this.flMenu() })[step]();
    this.flFromMenu = false; this.flFromKit = false;
    // inside a menu item, a swipe up goes back to the menu
    const F = this.FL;
    if ((this.flMode === 'menu' || this.flMode === 'gym') && ['wod', 'prs', 'name', 'unit', 'plates', 'bar'].indexOf(step) >= 0) {
      F.swipe = true; F.onSwipe = () => { this.flCheckSound(); this.flMode = 'menu'; this.flPanTo('menu'); };
    }
  }

  // ---------------- 4 · plates: a checklist — draw a tick in YES or NO for each plate ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs(), n = specs.length;
    this.flCam([0, 0, 8.2], [0, 0, 0], 35);
    const k = 2 * 8.2 * Math.tan(17.5 * Math.PI / 180) / 844, top = 214, bot = 790, rowH = (bot - top) / n;
    const wx = (px) => (px - 195) * k, wy = (py) => (422 - py) * k;
    const ink = this.flInk(), box = Math.round(Math.min(46, rowH * 0.74)), XY = 262, XN = 334;
    const gray = new T.MeshBasicMaterial({ color: 0x9a9690, transparent: true, opacity: 0.3, depthWrite: false });
    const rows = []; this.flPlRows = rows;
    let done = false;
    const sketchBox = (cv, s) => {
      const x = cv.getContext('2d'), p = 12; x.clearRect(0, 0, cv.width, cv.height); x.save(); x.scale(cv.width / (s + 2 * p), cv.height / (s + 2 * p));
      x.strokeStyle = ink; x.lineWidth = 2.6; x.lineCap = 'round'; x.lineJoin = 'round';
      const J = cv._j || (cv._j = Array.from({ length: 24 }, () => (Math.random() - 0.5) * 2.2)); let ji = 0; const j = () => J[ji++ % 24], pts = [[p, p], [p + s, p], [p + s, p + s], [p, p + s]];
      x.beginPath(); pts.forEach((a, i) => { const b = pts[(i + 1) % 4]; x.moveTo(a[0] + j(), a[1] + j()); x.quadraticCurveTo((a[0] + b[0]) / 2 + j(), (a[1] + b[1]) / 2 + j(), b[0] + j(), b[1] + j()); }); x.stroke(); x.restore();
    };
    const paintPlate = (r) => r.meshes.forEach((m) => { m.material = r.state === 'no' ? gray : m.userData.m0; });
    const finish = () => {
      if (done || rows.some((r) => !r.state)) return;
      done = true;
      this.d.own[this.d.unit] = rows.filter((r) => r.state === 'yes').map((r) => r.s.kg);
      const yes = rows.filter((r) => r.state === 'yes');
      this.flLater(() => { this.flShine(yes.map((r) => r.w), 0.8); yes.forEach((r, i) => this.flLater(() => this.flSparkles(r.w.position.clone().setZ(0.4), 2, 0.35), i * 50)); }, 200);
      this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 1100);
    };
    const makeBox = (r, which, x, y) => {
      const s = box, p = 12, cv = document.createElement('canvas'), dpr = 2;
      cv.width = (s + 2 * p) * dpr; cv.height = (s + 2 * p) * dpr;
      Object.assign(cv.style, { position: 'absolute', left: (x - s / 2 - p) + 'px', top: (y - s / 2 - p) + 'px', width: (s + 2 * p) + 'px', height: (s + 2 * p) + 'px', pointerEvents: 'auto', touchAction: 'none', cursor: 'crosshair' });
      cv.setAttribute('role', 'checkbox'); cv.setAttribute('aria-label', (which === 'yes' ? 'Have ' : 'Don’t have ') + this.fmt(r.s.kg) + ' ' + this.d.unit);
      F.ui.appendChild(cv); sketchBox(cv, s);
      cv.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: 360, delay: r.i * 60 + (which === 'yes' ? 0 : 40), easing: 'cubic-bezier(.3,1.5,.5,1)', fill: 'backwards' });
      const B = { cv, s, p, which, pts: [] };
      const ctx = cv.getContext('2d');
      const draw = () => {
        sketchBox(cv, s); if (B.pts.length < 2) return;
        ctx.save(); ctx.scale(dpr, dpr); ctx.strokeStyle = ink; ctx.lineWidth = 4.2; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        ctx.beginPath(); B.pts.forEach(([a, b], i) => (i ? ctx.lineTo(a, b) : ctx.moveTo(a, b))); ctx.stroke(); ctx.restore();
      };
      B.clear = () => { B.pts = []; draw(); };
      let drawing = false, len = 0;
      const at = (e) => { const R = cv.getBoundingClientRect(), sc = R.width / (s + 2 * p); return [(e.clientX - R.left) / sc, (e.clientY - R.top) / sc]; };
      cv.addEventListener('pointerdown', (e) => { if (done) return; e.stopPropagation(); e.preventDefault(); try { cv.setPointerCapture(e.pointerId); } catch (er) {} drawing = true; len = 0; B.pts = [at(e)]; this.flAudio(); draw(); });
      cv.addEventListener('pointermove', (e) => { if (!drawing) return; e.stopPropagation(); const q = at(e), l = B.pts[B.pts.length - 1]; len += Math.hypot(q[0] - l[0], q[1] - l[1]); B.pts.push(q); draw(); if (B.pts.length % 6 === 0) this.flClick(2.2); });
      const accept = () => {
        // ticked: this row is decided; the other box empties
        r.state = which; (which === 'yes' ? r.no : r.yes).clear(); paintPlate(r); this.buzz('light'); this.flClick(which === 'yes' ? 1.2 : 0.7);
        if (which === 'yes') this.flShine([r.w], 0.4);
        finish();
      };
      const up = (e) => {
        if (!drawing) return; drawing = false; if (e && e.stopPropagation) e.stopPropagation();
        if (len < 6) {
          // a tap: the pen draws the tick for you, quickly
          const c0 = p + s / 2, pts = [[c0 - s * 0.3, c0 + s * 0.02], [c0 - s * 0.08, c0 + s * 0.26], [c0 + s * 0.34, c0 - s * 0.3]], seq = [];
          for (let i = 0; i < 2; i++) for (let k = 0; k <= 8; k++) seq.push([pts[i][0] + (pts[i + 1][0] - pts[i][0]) * k / 8 + (Math.random() - 0.5) * 1.2, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * k / 8 + (Math.random() - 0.5) * 1.2]);
          B.pts = [];
          this.flAnim((u) => { B.pts = seq.slice(0, Math.max(1, Math.ceil(u * seq.length))); draw(); }, 0.18, () => { if (!done) accept(); });
          return;
        }
        if (len < s * 0.3) { cv.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-4px)' }, { transform: 'translateX(4px)' }, { transform: 'translateX(0)' }], { duration: 220 }); B.clear(); return; }
        accept();
      };
      cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
      // a stroke that ends outside the box still counts
      const winUp = (e) => { if (!cv.isConnected) { window.removeEventListener('pointerup', winUp); window.removeEventListener('pointercancel', winUp); return; } up(e); };
      window.addEventListener('pointerup', winUp); window.addEventListener('pointercancel', winUp);
      return B;
    };
    this.flAfter('What are the plates available?', () => {
      [['YES', XY], ['NO', XN]].forEach(([l, x]) => { const h = this.fh('div', { position: 'absolute', left: x + 'px', top: (top - 16) + 'px', transform: 'translate(-50%,-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '15px', letterSpacing: '0.08em', pointerEvents: 'none' }, F.ui, l); h.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, fill: 'backwards' }); });
      specs.forEach((s, i) => {
        const y = top + rowH * (i + 0.5), g = this.plate(s), w = new T.Group(); w.add(g); g.rotation.x = Math.PI / 2;
        const dia = rowH * 0.84 * k * (0.62 + 0.38 * Math.min(1, s.d / 0.45)), sc = dia / s.d; w.scale.setScalar(sc);
        const ty = wy(y); w.position.set(wx(58), ty + 4, 0); this.flAdd(w);
        const meshes = []; g.traverse((m) => { if (m.isMesh) { m.userData.m0 = m.material; meshes.push(m); } });
        const r = { s, i, w, g, meshes, state: null };
        // each plate drops into its row and settles
        w.visible = false;
        this.flLater(() => { w.visible = true; this.flAnim((u) => { const b = u < 0.6 ? (u / 0.6) ** 2 : 1 - 0.18 * Math.sin((u - 0.6) / 0.4 * Math.PI) * (1 - u); w.position.y = ty + (1 - Math.min(1, b)) * 4; }, 0.55, () => this.flClick(0.5)); }, i * 70);
        const lab = this.fh('div', { position: 'absolute', left: '106px', top: y + 'px', transform: 'translateY(-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: Math.round(Math.min(20, rowH * 0.36)) + 'px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, this.fmt(s.kg) + ' ' + this.d.unit);
        lab.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, delay: i * 70 + 300, fill: 'backwards' });
        r.yes = makeBox(r, 'yes', XY, y); r.no = makeBox(r, 'no', XN, y);
        rows.push(r);
      });
    });
    F.tick = (dt, t) => { rows.forEach((r, i) => { r.g.rotation.y = Math.sin(t * 0.8 + i) * 0.12; }); this.flSpkTick(dt); };
  }

  // ---------------- 6 · the board: smaller, angled, pushed in with a horizontal spin ----------------
  get WB_REST() { return { s: 0.85, ry: -0.28, cam: { P: [0, 1.9, 7.0], T: [0, 1.1, 0] } }; }
  flWod() {
    const F = this.FL, T = this.THREE, R = this.WB_REST;
    this.flCam(R.cam.P, R.cam.T, 35);
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.18 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); this.flAdd(wb);
    const instant = this.flFromKit || this.flFromMenu;
    if (instant) { wb.rotation.y = R.ry; if (this.plan) this.flDrawBoard(wb, this.plan); } else wb.visible = false;
    let busy = false;
    this.flAfter(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?', () => {
      if (instant) return;
      // pushed in: it rolls on from the right spinning round on its wheels, overshoots a touch and rocks to rest, angled
      wb.visible = true; wb.position.x = 3.6; wb.rotation.y = -1.9; this.flClick(0.5);
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3), o = Math.sin(e * Math.PI) * 0.18; wb.position.x = 3.6 * (1 - e); wb.rotation.y = -1.9 + (R.ry + 1.9) * e + o; wb.userData.wheels.forEach((w) => { w.rotation.x = -(1 - e) * 40; }); }, 1.15, () => {
        this.flAnim((u) => { wb.rotation.z = 0.05 * Math.exp(-u * 5) * Math.sin(u * 16); wb.rotation.y = R.ry + 0.06 * Math.exp(-u * 4) * Math.sin(u * 11); }, 1.0);
      });
    });
    const ready = () => {
      this.plan = this.workoutPlan(); this.setIdx = 0; this.doneSets = []; this.d.kitGot = {};
      this.flDrawBoard(wb, this.plan); this.flShine([wb], 0.6);
      this.flLater(() => {
        const cam = F.cam, P0 = cam.position.clone(), T0 = new T.Vector3(...R.cam.T), cy = 1.45 * R.s, T1 = new T.Vector3(0, cy, 0), P1 = new T.Vector3(0.15, cy, 0.7), tgt = new T.Vector3();
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

  // ---------------- the kit: dragging previews where you're going — down to the board, up to the bar ----------------
  flBarGroup() {
    const T = this.THREE, bar = new T.Group();
    const steel = new T.MeshStandardMaterial({ color: '#C9CED4', metalness: 0.9, roughness: 0.3 }), sleeveM = new T.MeshStandardMaterial({ color: '#EEF1F4', metalness: 0.9, roughness: 0.15 });
    const cyl = (r, len, m, x) => { const c = new T.Mesh(new T.CylinderGeometry(r, r, len, 20), m); c.rotation.z = Math.PI / 2; c.position.x = x; c.castShadow = true; bar.add(c); };
    cyl(0.0142, 1.31, steel, 0); [-1, 1].forEach((s) => { cyl(0.032, 0.03, steel, s * 0.67); cyl(0.025, 0.42, sleeveM, s * 0.895); cyl(0.03, 0.02, steel, s * 1.105); });
    bar.position.y = 0.9; return bar;
  }
  flKitPreview() {
    const F = this.FL, T = this.THREE, R = this.WB_REST;
    const WB = new T.Vector3(0, 0, -3.8), SB = new T.Vector3(5.2, 0, 0.2);
    // the board stands behind the plates, the bar waits off to the right
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); wb.rotation.y = R.ry; wb.position.copy(WB); if (this.plan) this.flDrawBoard(wb, this.plan); this.flAdd(wb);
    const bar = this.flBarGroup(); bar.position.x = SB.x; bar.position.z = SB.z; this.flAdd(bar);
    const c = F.cam, K = { P: c.position.clone(), T: c.position.clone().add(c.getWorldDirection(new T.Vector3()).multiplyScalar(6.5)) };
    const Bv = { P: WB.clone().add(new T.Vector3(...R.cam.P)), T: WB.clone().add(new T.Vector3(...R.cam.T)) };
    const Sv = { P: SB.clone().add(new T.Vector3(2.45, 1.25, 1.75)), T: SB.clone().add(new T.Vector3(0.78, 0.8, -0.08)) };
    const kitBg = new T.Color(this.flBgAlt ? this.pal.boxLight : this.pal.bgColor), wodBg = new T.Color(this.flUserBg ? this.pal.boxLight : this.pal.bgColor), mix = new T.Color();
    const tg = new T.Vector3();
    const pose = (v) => {
      // v < 0: toward the board; v > 0: toward the bar
      const a = Math.min(1, Math.abs(v)), e = a * a * (3 - 2 * a), D = v < 0 ? Bv : Sv;
      c.position.lerpVectors(K.P, D.P, e); tg.lerpVectors(K.T, D.T, e); c.lookAt(tg);
      F.ui.style.opacity = String(1 - Math.min(1, a * 2.2));
      (this.flKitItems || []).forEach((it) => it.o.scale.setScalar(Math.max(0.0001, 1 - (v < 0 ? e : 0))));
      mix.copy(kitBg).lerp(wodBg, v < 0 ? e : 0); F.L.style.backgroundColor = '#' + mix.getHexString();
    };
    let v = 0;
    const commit = (dir) => {
      F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null;
      const v0 = v, v1 = dir;
      this.flAnim((u) => { v = v0 + (v1 - v0) * (1 - Math.pow(1 - u, 3)); pose(v); }, 0.35, () => {
        F.ui.style.opacity = '';
        if (dir < 0) { this.flAgain = true; this.flFromKit = true; this.flCheckSound(); this.flGo('wod'); }
        else { this.flCheckSound(); this.flGo('sets'); }
      });
    };
    return {
      drag: (e) => {
        const sy = e.clientY; let moved = false;
        return {
          move: (ev) => { const dy = ev.clientY - sy; if (Math.abs(dy) > 6) moved = true; v = Math.max(-1, Math.min(1, -dy / 320)); pose(v); },
          up: (ev, tap) => {
            if (tap && !moved) { commit(1); return; }
            if (Math.abs(v) > 0.3) commit(v < 0 ? -1 : 1);
            else { const v0 = v; this.flAnim((u) => { v = v0 * Math.pow(1 - u, 3); pose(v); }, 0.3, () => { F.ui.style.opacity = ''; }); }
          }
        };
      }
    };
  }
  flMenuGo(it) {
    // zoom straight into the picked item, then its question
    const F = this.FL, T = this.THREE, c = F.cam, P0 = c.position.clone(), T0 = P0.clone().add(c.getWorldDirection(new T.Vector3()).multiplyScalar(7));
    const tp = it.w.position.clone().add(new T.Vector3(0, 0.75, 0)), P1 = tp.clone().add(new T.Vector3(0, 0.2, 2.3)), tg = new T.Vector3();
    F.hit = null; [...F.ui.children].forEach((el) => el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 220, fill: 'forwards' }));
    this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 3); c.position.lerpVectors(P0, P1, e); tg.lerpVectors(T0, tp, e); c.lookAt(tg); }, 0.5, () => { this.flDirect = true; this.flFromMenu = true; it.go(); });
  }

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

  // ===================== FLOW, round 8 =====================
  // ---------- going back to the menu follows the finger: the screen pans with you, let go past a point and it carries on ----------
  flPanBackBind() {
    const F = this.FL; if (F.pbBound) return; F.pbBound = true;
    const L = F.L; let S = null;
    L.addEventListener('pointerdown', (e) => {
      if (!F.panBack || F.drag || this.flPanning || (e.target.closest && e.target.closest('button'))) { S = null; return; }
      S = { y0: e.clientY, x0: e.clientX, px: 0, G: this.flPanGeo(), P0: F.cam.position.clone(), g0: this.flGridY || 0, on: false };
    });
    L.addEventListener('pointermove', (e) => {
      if (!S || !F.panBack) return;
      const dy = e.clientY - S.y0, dx = e.clientX - S.x0;
      if (!S.on) { if (-dy > 14 && -dy > Math.abs(dx) * 1.3) S.on = true; else return; }
      this.flPanLive(S, Math.max(0, -dy - 14));
    });
    const up = () => {
      if (!S) return; const s = S; S = null; if (!s.on) return;
      if (s.px > 110) this.flPanFinish(s, 'menu');
      else { const p0 = s.px; this.flAnim((u) => this.flPanLive(s, p0 * Math.pow(1 - u, 3)), 0.28); }
    };
    L.addEventListener('pointerup', up); L.addEventListener('pointercancel', up);
  }
  flPanLive(s, px) {
    const F = this.FL; s.px = px;
    F.cam.position.copy(s.P0).addScaledVector(s.G.up, -px * s.G.wpp); this.flPanSet(px); this.flGridY = s.g0 - px; this.flApplyStyle();
  }
  // carry an interactive pan the rest of the way, then the next screen comes up from below
  flPanFinish(s, step) {
    const F = this.FL, p0 = s.px, H = s.G.H; this.flPanning = true;
    F.hit = null; F.onTap = null; F.onSwipe = null; F.panBack = false;
    const d = Math.max(0.12, 0.3 * (1 - p0 / H));
    this.flAnim((u) => this.flPanLive(s, p0 + (H - p0) * u * (2 - u) * 0.5 + (H - p0) * u * u * 0.5), d, () => {
      this.flPanning = false; this.flCheckSound(); this.flMode = 'menu'; this.flPanIn = { g0: s.g0 - H }; this.flGo(step);
    });
  }
  flPanBackGo() { const s = { px: 0, G: this.flPanGeo(), P0: this.FL.cam.position.clone(), g0: this.flGridY || 0 }; this.flPanFinish(s, 'menu'); }

  // ---------------- 4 · plates: draw anywhere — one long line can tick a whole column ----------------
  flPlates() {
    const F = this.FL, T = this.THREE, specs = this.specs(), n = specs.length;
    this.flCam([0, 0, 8.2], [0, 0, 0], 35);
    const k = 2 * 8.2 * Math.tan(17.5 * Math.PI / 180) / 844, top = 214, bot = 790, rowH = (bot - top) / n;
    const wx = (px) => (px - 195) * k, wy = (py) => (422 - py) * k;
    const ink = this.flInk(), box = Math.round(Math.min(46, rowH * 0.74)), XY = 262, XN = 334, dpr = 2;
    const gray = new T.MeshBasicMaterial({ color: 0x9a9690, transparent: true, opacity: 0.3, depthWrite: false });
    const rows = [], boxes = []; this.flPlRows = rows;
    let done = false, ready = false;
    const paintPlate = (r) => r.meshes.forEach((m) => { m.material = r.state === 'no' ? gray : m.userData.m0; });
    const editing = !!this.flEditOne; let idleT = null;
    const finish = () => {
      if (done || rows.some((r) => !r.state)) return;
      if (editing) {
        // editing from the gym: changes save as you go; once you stop for a moment it goes back
        this.d.own[this.d.unit] = rows.filter((r) => r.state === 'yes').map((r) => r.s.kg);
        clearTimeout(idleT); idleT = this.flLater(() => { if (this.flStep !== 'plates' || done) return; done = true; this.flShine(rows.filter((r) => r.state === 'yes').map((r) => r.w), 0.8); this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 900); }, 1800);
        return;
      }
      done = true;
      this.d.own[this.d.unit] = rows.filter((r) => r.state === 'yes').map((r) => r.s.kg);
      const yes = rows.filter((r) => r.state === 'yes');
      this.flLater(() => { this.flShine(yes.map((r) => r.w), 0.8); yes.forEach((r, i) => this.flLater(() => this.flSparkles(r.w.position.clone().setZ(0.4), 2, 0.35), i * 50)); }, 350);
      this.flLater(() => { if (this.flStep === 'plates') { this.flCheckSound(); this.flPanTo('bar'); } }, 1250);
    };
    // each box: a sketchy square on its own little canvas, with a tick that draws itself in
    const makeBox = (r, which, x, y) => {
      const s = box, p = 12, cv = document.createElement('canvas');
      cv.width = (s + 2 * p) * dpr; cv.height = (s + 2 * p) * dpr;
      Object.assign(cv.style, { position: 'absolute', left: (x - s / 2 - p) + 'px', top: (y - s / 2 - p) + 'px', width: (s + 2 * p) + 'px', height: (s + 2 * p) + 'px', pointerEvents: 'none' });
      cv.setAttribute('role', 'checkbox'); cv.setAttribute('aria-label', (which === 'yes' ? 'Have ' : 'Don’t have ') + this.fmt(r.s.kg) + ' ' + this.d.unit); cv.setAttribute('aria-checked', 'false');
      F.ui.appendChild(cv);
      const J = Array.from({ length: 24 }, () => (Math.random() - 0.5) * 2.2), ctx = cv.getContext('2d');
      const B = { cv, which, r, x0: x - s / 2, y0: y - s / 2, s, tick: 0, acc: 0 };
      const tickPts = (() => { const c0 = p + s / 2, a = [[c0 - s * 0.3, c0 + s * 0.02], [c0 - s * 0.08, c0 + s * 0.26], [c0 + s * 0.34, c0 - s * 0.3]], q = []; for (let i = 0; i < 2; i++) for (let k2 = 0; k2 <= 8; k2++) q.push([a[i][0] + (a[i + 1][0] - a[i][0]) * k2 / 8 + (Math.random() - 0.5) * 1.4, a[i][1] + (a[i + 1][1] - a[i][1]) * k2 / 8 + (Math.random() - 0.5) * 1.4]); return q; })();
      B.draw = () => {
        let ji = 0; const j = () => J[ji++ % 24];
        ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.strokeStyle = ink; ctx.lineWidth = 2.6; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
        const pts = [[p, p], [p + s, p], [p + s, p + s], [p, p + s]];
        ctx.beginPath(); pts.forEach((a, i) => { const b = pts[(i + 1) % 4]; ctx.moveTo(a[0] + j(), a[1] + j()); ctx.quadraticCurveTo((a[0] + b[0]) / 2 + j(), (a[1] + b[1]) / 2 + j(), b[0] + j(), b[1] + j()); }); ctx.stroke();
        const m = Math.ceil(B.tick * tickPts.length);
        if (m > 1) { ctx.lineWidth = 4.4; ctx.beginPath(); tickPts.slice(0, m).forEach(([a, b], i) => (i ? ctx.lineTo(a, b) : ctx.moveTo(a, b))); ctx.stroke(); }
      };
      B.set = (on) => {
        cv.setAttribute('aria-checked', String(on));
        if (!on) { if (B.tick) { B.tick = 0; B.draw(); } return; }
        if (B.tick >= 1) return;
        this.flAnim((u) => { B.tick = u; B.draw(); }, 0.16);
      };
      B.draw();
      cv.animate([{ transform: 'scale(0)' }, { transform: 'scale(1)' }], { duration: 360, delay: r.i * 60 + (which === 'yes' ? 0 : 40), easing: 'cubic-bezier(.3,1.5,.5,1)', fill: 'backwards' });
      boxes.push(B); return B;
    };
    const decide = (B) => {
      const r = B.r; if (r.state === B.which) return;
      r.state = B.which; B.set(true); (B.which === 'yes' ? r.no : r.yes).set(false); paintPlate(r);
      this.buzz('light'); this.flClick(B.which === 'yes' ? 1.2 : 0.7);
      if (B.which === 'yes') this.flShine([r.w], 0.4);
    };
    // one drawing surface over the whole screen: the pen leaves a trail that fades; every box the line runs through gets ticked
    const pad = document.createElement('canvas'), pctx = pad.getContext('2d');
    pad.width = 390 * dpr; pad.height = 844 * dpr;
    Object.assign(pad.style, { position: 'absolute', left: 0, top: 0, width: '390px', height: '844px', pointerEvents: 'none', touchAction: 'none', zIndex: 2 });
    pad.setAttribute('aria-hidden', 'true');
    F.ui.appendChild(pad);
    const loc = (e) => { const R = pad.getBoundingClientRect(), sc = R.width / 390; return [(e.clientX - R.left) / sc, (e.clientY - R.top) / sc]; };
    const inBox = (B, x, y, pad2) => x >= B.x0 - pad2 && x <= B.x0 + B.s + pad2 && y >= B.y0 - pad2 && y <= B.y0 + B.s + pad2;
    let st = null;
    const fadeTrail = () => { const a = pad.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 380, easing: 'ease-out' }); a.onfinish = () => { pctx.setTransform(1, 0, 0, 1, 0, 0); pctx.clearRect(0, 0, pad.width, pad.height); }; };
    pad.addEventListener('pointerdown', (e) => {
      if (done || !ready) return; e.stopPropagation(); e.preventDefault(); clearTimeout(idleT);
      try { pad.setPointerCapture(e.pointerId); } catch (er) {}
      pad.getAnimations().forEach((a) => a.cancel()); pctx.setTransform(1, 0, 0, 1, 0, 0); pctx.clearRect(0, 0, pad.width, pad.height);
      const q = loc(e); st = { last: q, start: q, len: 0, hit: false, n: 0 }; boxes.forEach((B) => { B.acc = 0; });
      this.flAudio();
    });
    pad.addEventListener('pointermove', (e) => {
      if (!st) return; e.stopPropagation();
      const q = loc(e), l = st.last, seg = Math.hypot(q[0] - l[0], q[1] - l[1]); if (seg < 1) return;
      st.len += seg; st.last = q;
      pctx.setTransform(dpr, 0, 0, dpr, 0, 0); pctx.strokeStyle = ink; pctx.lineWidth = 4.2; pctx.lineCap = 'round'; pctx.beginPath(); pctx.moveTo(l[0], l[1]); pctx.lineTo(q[0], q[1]); pctx.stroke();
      // how much of this bit of line runs inside each box
      const steps = Math.max(1, Math.ceil(seg / 3));
      for (let i = 1; i <= steps; i++) {
        const x = l[0] + (q[0] - l[0]) * i / steps, y = l[1] + (q[1] - l[1]) * i / steps;
        boxes.forEach((B) => { if (inBox(B, x, y, 4)) { B.acc += seg / steps; if (B.acc >= B.s * 0.22) { st.hit = true; decide(B); } } });
      }
      if (++st.n % 6 === 0) this.flClick(2.2);
    });
    const up = (e) => {
      if (!st) return; const s0 = st; st = null; if (e && e.stopPropagation) e.stopPropagation();
      if (s0.len < 6) {
        // a tap on a box ticks it
        const B = boxes.find((b) => inBox(b, s0.start[0], s0.start[1], 8)); if (B) decide(B);
      } else if (!s0.hit && F.panBack && s0.start[1] - s0.last[1] > 90 && Math.abs(s0.last[0] - s0.start[0]) < (s0.start[1] - s0.last[1]) / 1.5) {
        fadeTrail(); this.flPanBackGo(); return;
      }
      fadeTrail(); finish();
    };
    pad.addEventListener('pointerup', up); pad.addEventListener('pointercancel', up);
    const winUp = (e) => { if (!pad.isConnected) { window.removeEventListener('pointerup', winUp); window.removeEventListener('pointercancel', winUp); return; } up(e); };
    window.addEventListener('pointerup', winUp); window.addEventListener('pointercancel', winUp);
    this.flAfter('What are the plates available?', () => {
      [['YES', XY], ['NO', XN]].forEach(([l, x]) => { const h = this.fh('div', { position: 'absolute', left: x + 'px', top: (top - 16) + 'px', transform: 'translate(-50%,-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 800, fontSize: '13px', letterSpacing: '0.08em', pointerEvents: 'none' }, F.ui, l); h.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, fill: 'backwards' }); });
      specs.forEach((s, i) => {
        const y = top + rowH * (i + 0.5), g = this.plate(s), w = new T.Group(); w.add(g); g.rotation.x = Math.PI / 2;
        const dia = rowH * 0.84 * k * (0.62 + 0.38 * Math.min(1, s.d / 0.45)), sc = dia / s.d; w.scale.setScalar(sc);
        const ty = wy(y); w.position.set(wx(58), ty + 4, 0); this.flAdd(w);
        const meshes = []; g.traverse((m) => { if (m.isMesh) { m.userData.m0 = m.material; meshes.push(m); } });
        const r = { s, i, w, g, meshes, state: null };
        w.visible = false;
        this.flLater(() => { w.visible = true; this.flAnim((u) => { const b = u < 0.6 ? (u / 0.6) ** 2 : 1 - 0.18 * Math.sin((u - 0.6) / 0.4 * Math.PI) * (1 - u); w.position.y = ty + (1 - Math.min(1, b)) * 4; }, 0.55, () => this.flClick(0.5)); }, i * 70);
        const lab = this.fh('div', { position: 'absolute', left: '106px', top: y + 'px', transform: 'translateY(-50%)', color: ink, fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: Math.round(Math.min(20, rowH * 0.36)) + 'px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, this.fmt(s.kg) + ' ' + this.d.unit);
        lab.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 200, delay: i * 70 + 300, fill: 'backwards' });
        r.yes = makeBox(r, 'yes', XY, y); r.no = makeBox(r, 'no', XN, y);
        rows.push(r);
      });
      pad.style.pointerEvents = 'auto'; ready = true; F.ui.appendChild(pad);
      // editing: what you said before is already ticked
      if (editing) { const own = (this.d.own && this.d.own[this.d.unit]) || []; rows.forEach((r, i) => { r.state = own.indexOf(r.s.kg) >= 0 ? 'yes' : 'no'; paintPlate(r); this.flLater(() => (r.state === 'yes' ? r.yes : r.no).set(true), 380 + i * 60); }); }
    });
    F.tick = (dt, t) => { rows.forEach((r, i) => { r.g.rotation.y = Math.sin(t * 0.8 + i) * 0.12; }); this.flSpkTick(dt); };
  }

  // ---------------- 6 · the board: rolls in and stops, no wobble; upload, see the plan, tap it to start ----------------
  flWod() {
    const F = this.FL, T = this.THREE, R = this.WB_REST;
    this.flCam(R.cam.P, R.cam.T, 35);
    const fl = new T.Mesh(new T.PlaneGeometry(12, 12), new T.ShadowMaterial({ opacity: 0.18 })); fl.rotation.x = -Math.PI / 2; fl.receiveShadow = true; this.flAdd(fl);
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); this.flAdd(wb);
    const instant = this.flFromKit || this.flFromMenu;
    let busy = false, hasPlan = false;
    if (instant) { wb.rotation.y = R.ry; if (this.plan) { this.flDrawBoard(wb, this.plan); hasPlan = true; } } else wb.visible = false;
    this.flAfter(this.flAgain ? 'What are we doing today?' : 'You’re strong! What are we doing today?', () => {
      if (instant) return;
      // pushed in: it rolls on from the right, turning as it comes, and slows to a stop — no bounce
      wb.visible = true; wb.position.x = 3.6; wb.rotation.y = -1.9; this.flClick(0.5);
      this.flAnim((u) => { const e = 1 - Math.pow(1 - u, 4), er = 1 - Math.pow(1 - Math.min(1, u * 1.08), 3); wb.position.x = 3.6 * (1 - e); wb.rotation.y = -1.9 + (R.ry + 1.9) * er; wb.userData.wheels.forEach((w) => { w.rotation.x = -(1 - e) * 40; }); }, 1.3);
    });
    const start = () => {
      busy = true; this.flCheckSound(); this.buzz('light');
      const cam = F.cam, P0 = cam.position.clone(), T0 = new T.Vector3(...R.cam.T), cy = 1.45 * R.s, T1 = new T.Vector3(0, cy, 0), P1 = new T.Vector3(0.15, cy, 0.7), tgt = new T.Vector3();
      this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; cam.position.lerpVectors(P0, P1, e); tgt.lerpVectors(T0, T1, e); cam.lookAt(tgt); }, 1.0, () => { this.flGo('kit'); });
    };
    const ready = () => {
      this.plan = this.workoutPlan(); this.lastPlan = this.plan; this.setIdx = 0; this.doneSets = []; this.d.kitGot = {};
      this.flDrawBoard(wb, this.plan); this.flShine([wb], 0.6); this.flSparkles(new T.Vector3(0.4, 1.6, 0.4), 5, 1.2);
      busy = false; hasPlan = true;
    };
    // the uploaded workout can be scrubbed off the board, just like in the app; a clean board uploads again
    const WP = this.flBoardWiper(wb, () => { hasPlan = false; this.plan = null; this.lastPlan = null; });
    F.hit = (e) => {
      if (busy || !wb.visible || !this.flRay(e).intersectObject(wb, true).length) return null;
      let moved = false;
      return {
        move: (ev) => {
          if (!hasPlan) return;
          if (!moved) { if (Math.hypot(ev.clientX - e.clientX, ev.clientY - e.clientY) < 10) return; moved = true; this.flAudio(); }
          WP.wipeAt(ev); if (Math.random() < 0.18) { this.flClick(2.6); this.buzz('selection'); }
        },
        up: (ev, tap) => { if (!tap || busy) return;
          if (hasPlan) { start(); return; }
          this.buzz('light'); this.flCheckSound(); WP.reset();
          this.flPickPhoto(() => { busy = true; this.reading('Reading your workout…', ready); }); } };
    };
    F.tick = (dt) => this.flSpkTick(dt);
  }

  // ---------------- the kit: drag down zooms back out of the board; drag up (or tap) and the camera goes down to the bar ----------------
  flKitPreview() {
    const F = this.FL, T = this.THREE, R = this.WB_REST, c = F.cam;
    const WB = new T.Vector3(0, 0, -40);
    const wb = this.whiteboardModel(); wb.scale.setScalar(R.s); wb.rotation.y = R.ry; wb.position.copy(WB); if (this.plan) this.flDrawBoard(wb, this.plan); wb.visible = false; this.flAdd(wb);
    const cy = 1.45 * R.s, Z = { P: WB.clone().add(new T.Vector3(0.15, cy, 0.7)), T: WB.clone().add(new T.Vector3(0, cy, 0)) };
    const Bv = { P: WB.clone().add(new T.Vector3(...R.cam.P)), T: WB.clone().add(new T.Vector3(...R.cam.T)) };
    const K = { P: c.position.clone(), Q: c.quaternion.clone(), T: c.position.clone().add(c.getWorldDirection(new T.Vector3()).multiplyScalar(6.5)), fov: this.flFov || 35 };
    // below the kit, one screen down, the bar waits exactly as the sets will show it
    const G0 = this.flPanGeo(), down = G0.up.clone().multiplyScalar(-G0.H * G0.wpp), KP = K.P.clone().add(down);
    const camK = new T.PerspectiveCamera(40, 1, 0.1, 100); camK.position.copy(KP); camK.quaternion.copy(K.Q); camK.updateMatrixWorld(true);
    const camS = new T.PerspectiveCamera(40, 1, 0.1, 100); camS.position.set(2.45, 1.25, 1.75); camS.lookAt(0.78, 0.8, -0.08); camS.updateMatrixWorld(true);
    const upS = new T.Vector3(0, 1, 0).applyQuaternion(camS.quaternion), wppS = 2 * camS.position.distanceTo(new T.Vector3(0.78, 0.8, -0.08)) * Math.tan(20 * Math.PI / 180) / G0.H;
    const proxy = new T.Group(); proxy.matrixAutoUpdate = false; proxy.visible = false;
    const bar = this.flBarGroup(); proxy.add(bar); this.flAdd(proxy);
    const kitBg = new T.Color(this.flBgAlt ? this.pal.boxLight : this.pal.bgColor), wodBg = new T.Color(this.flUserBg ? this.pal.boxLight : this.pal.bgColor), mix = new T.Color();
    const tg = new T.Vector3(), items = () => this.flKitItems || [];
    const pose = (v) => {
      const a = Math.min(1, Math.abs(v));
      F.ui.style.opacity = String(1 - Math.min(1, a * 2.6));
      if (v <= 0) proxy.visible = false;
      if (v <= 0) {
        // back: first the plates fold away into the board's surface, then the camera pulls back out of the board
        const a1 = Math.min(1, a / 0.28), a2 = Math.max(0, (a - 0.28) / 0.72), e2 = a2 < 0.5 ? 4 * a2 * a2 * a2 : 1 - Math.pow(-2 * a2 + 2, 3) / 2;
        items().forEach((it) => it.o.scale.setScalar(Math.max(0.0001, 1 - a1 * a1)));
        this.flFov = K.fov;
        if (a2 <= 0) { wb.visible = false; c.position.copy(K.P); c.quaternion.copy(K.Q); }
        else { wb.visible = true; c.position.lerpVectors(Z.P, Bv.P, e2); tg.lerpVectors(Z.T, Bv.T, e2); c.lookAt(tg); }
        mix.copy(kitBg).lerp(wodBg, e2); F.L.style.backgroundColor = '#' + mix.getHexString();
        F.L.style.backgroundImage = a2 > 0 ? 'none' : '';
        if (a2 <= 0) this.flApplyStyle();
      } else {
        // next: a pan straight down, the bar comes up from below
        const e = a < 0.5 ? 2 * a * a : 1 - Math.pow(-2 * a + 2, 2) / 2;
        wb.visible = false; items().forEach((it) => it.o.scale.setScalar(1));
        c.quaternion.copy(K.Q); c.position.copy(K.P).addScaledVector(down, e);
        proxy.visible = e > 0.002; if (proxy.visible) this.flProxyAt(proxy, c, camS, upS, wppS, G0.H * (1 - e));
        this.flFov = K.fov + (40 - K.fov) * e;
        this.flGridY = -G0.H * e; this.flApplyStyle();
      }
    };
    let v = 0;
    const commit = (dir) => {
      F.hit = null; F.onTap = null; F.onSwipe = null; F.onSwipeDown = null;
      const v0 = v, v1 = dir;
      this.flAnim((u) => { v = v0 + (v1 - v0) * (1 - Math.pow(1 - u, 3)); pose(v); }, dir < 0 ? 0.55 : 0.4, () => {
        F.ui.style.opacity = ''; F.L.style.backgroundColor = ''; F.L.style.backgroundImage = ''; this.flGridY = 0;
        if (dir < 0) { this.flAgain = true; this.flFromKit = true; this.flCheckSound(); this.flGo('wod'); }
        else { this.flCheckSound(); this.flGo('sets'); }
      });
    };
    return {
      drag: (e) => {
        const sy = e.clientY; let moved = false;
        return {
          move: (ev) => { const dy = ev.clientY - sy; if (Math.abs(dy) > 6) moved = true; v = Math.max(-1, Math.min(1, -dy / 340)); pose(v); },
          up: (ev, tap) => {
            if (tap && !moved) { commit(1); return; }
            if (Math.abs(v) > 0.3) commit(v < 0 ? -1 : 1);
            else { const v0 = v; this.flAnim((u) => { v = v0 * Math.pow(1 - u, 3); pose(v); }, 0.3, () => { F.ui.style.opacity = ''; F.L.style.backgroundColor = ''; F.L.style.backgroundImage = ''; this.flGridY = 0; this.flApplyStyle(); }); }
          }
        };
      }
    };
  }

  // ---------------- the menu: tap an object and it wakes up where it is ----------------
  penModel() {
    const T = this.THREE, g = new T.Group(), body = this.toon(this.pal.boxDark), tipM = this.toon('#E9E2D6'), capM = this.toon('#111111');
    const b = new T.Mesh(new T.CylinderGeometry(0.035, 0.035, 0.72, 10), body); g.add(b);
    const cone = new T.Mesh(new T.ConeGeometry(0.035, 0.12, 10), tipM); cone.position.y = -0.42; cone.rotation.x = Math.PI; g.add(cone);
    const nib = new T.Mesh(new T.ConeGeometry(0.012, 0.04, 8), capM); nib.position.y = -0.49; nib.rotation.x = Math.PI; g.add(nib);
    g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
    return g;
  }
  // a box whose lid, front and side fold away to leave a tiny gym: floor, two walls, the bar on its hooks, the flag, the plates
  gymRoomModel(name) {
    const T = this.THREE, g = new T.Group(), S = 1.15, th = 0.04, ink = this.pal.boxDark;
    const mat = () => { const m = this.toon(this.pal.boxLight); m.transparent = true; return m; };
    const edge = (mesh) => { const e = new T.LineSegments(new T.EdgesGeometry(mesh.geometry), new T.LineBasicMaterial({ color: ink, transparent: true })); mesh.add(e); return e; };
    const slab = (w, h, d) => { const m = new T.Mesh(new T.BoxGeometry(w, h, d), mat()); m.castShadow = true; m.receiveShadow = true; edge(m); return m; };
    const floor = slab(S, th, S); floor.position.y = th / 2; g.add(floor);
    const back = slab(S, S, th); back.position.set(0, S / 2, -S / 2 + th / 2); g.add(back);
    const left = slab(th, S, S); left.position.set(-S / 2 + th / 2, S / 2, 0); g.add(left);
    // the parts that open: lid lifts off, front and right fall outward
    const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d');
    x.fillStyle = this.pal.boxLight; x.fillRect(0, 0, 256, 256); x.fillStyle = ink; x.textAlign = 'center'; x.textBaseline = 'middle'; x.font = '900 120px "Playfair Display", Georgia, serif'; x.fillText(name || '79', 128, 140);
    const tx = new T.CanvasTexture(c); tx.colorSpace = T.SRGBColorSpace;
    const fm = mat(), frontFace = this.toon('#FFFFFF'); frontFace.map = tx; frontFace.transparent = true;
    const frontPivot = new T.Group(); frontPivot.position.set(0, 0, S / 2); g.add(frontPivot);
    const front = new T.Mesh(new T.BoxGeometry(S, S, th), [fm, fm, fm, fm, frontFace, fm]); front.position.set(0, S / 2, -th / 2); front.castShadow = true; const fe = edge(front); frontPivot.add(front);
    const rightPivot = new T.Group(); rightPivot.position.set(S / 2, 0, 0); g.add(rightPivot);
    const right = slab(th, S, S); right.position.set(-th / 2, S / 2, 0); rightPivot.add(right);
    const lid = slab(S, th, S); lid.position.set(0, S - th / 2, 0); g.add(lid);
    // inside
    const inside = new T.Group(); g.add(inside);
    const items = {};
    { // the bar on two hooks, on the back wall
      const grp = new T.Group(), bar = this.flBarGroup(); bar.position.y = 0; bar.scale.setScalar(0.47); grp.add(bar);
      const K = this.toon('#2B2B2B');
      [-0.3, 0.3].forEach((hx) => { const h = new T.Mesh(new T.BoxGeometry(0.05, 0.12, 0.09), K); h.position.set(hx, -0.03, -0.03); grp.add(h); });
      grp.position.set(0, 0.72, -S / 2 + th + 0.07); inside.add(grp); items.bar = grp;
    }
    { // the flag with the gym's name, on the left wall
      const fc = document.createElement('canvas'); fc.width = 320; fc.height = 200; const f = fc.getContext('2d');
      f.fillStyle = ink; f.fillRect(0, 0, 320, 200); f.fillStyle = this.pal.boxLight; f.textAlign = 'center'; f.textBaseline = 'middle'; f.font = '900 118px "Playfair Display", Georgia, serif'; f.fillText(name || '79', 160, 108);
      const ft = new T.CanvasTexture(fc); ft.colorSpace = T.SRGBColorSpace;
      const geo = new T.PlaneGeometry(0.62, 0.39, 10, 1), flag = new T.Mesh(geo, new T.MeshBasicMaterial({ map: ft, side: T.DoubleSide, transparent: true }));
      flag.userData.p0 = geo.attributes.position.array.slice();
      const grp = new T.Group(); grp.add(flag); grp.rotation.y = Math.PI / 2; grp.position.set(-S / 2 + th + 0.02, 0.68, 0.02); inside.add(grp); items.flag = grp; items.flagMesh = flag;
    }
    { // the plates, stacked and sorted on the floor
      const grp = new T.Group(), own = (this.d.own && this.d.own[this.d.unit]) || [], sp = this.specs().filter((s) => !own.length || own.indexOf(s.kg) >= 0).slice(0, 6);
      sp.forEach((s, i) => {
        const col = i % 3, row = Math.floor(i / 3), sc = 0.42;
        for (let j = 0; j < 2; j++) { const p = this.plate(s); p.scale.setScalar(sc); p.position.set((col - 1) * 0.27, 0.005 + j * s.t * sc + s.t * sc / 2, row * 0.27); p.traverse((m) => { if (m.isMesh) m.castShadow = true; }); grp.add(p); }
      });
      grp.position.set(0.12, th, 0.02); inside.add(grp); items.plates = grp;
    }
    { // a kettlebell in the corner: kilos or pounds
      const kb = this.kettlebell(this.d.unit.toUpperCase()), grp = new T.Group(); kb.scale.setScalar(0.32); kb.position.y = 0; grp.add(kb);
      grp.position.set(-0.36, th, 0.36); inside.add(grp); items.bell = grp;
    }
    const fade = [front, right, lid].map((m) => m);
    const setOp = (m, o) => m.traverse((q) => { if (q.material) (Array.isArray(q.material) ? q.material : [q.material]).forEach((mt) => { mt.opacity = o; mt.transparent = o < 1; mt.depthWrite = o > 0.5; }); });
    g.userData = {
      items, S,
      open: (k) => {
        const e = Math.min(1, Math.max(0, k)), a = Math.min(1, e / 0.7);
        const fall = a * a * (3 - 2 * a);
        frontPivot.rotation.x = fall * Math.PI / 2; rightPivot.rotation.z = -fall * Math.PI / 2;
        lid.position.y = S - th / 2 + fall * 0.9; lid.rotation.z = fall * 0.4;
        const fo = Math.max(0, 1 - Math.max(0, (e - 0.35) / 0.4));
        fade.forEach((m) => { setOp(m, fo); m.visible = fo > 0.01; });
        Object.keys(items).forEach((key, i) => { const o = items[key]; if (!o.isObject3D || key === 'flagMesh') return; const q = Math.min(1, Math.max(0, (e - 0.45 - i * 0.08) / 0.35)); o.scale.setScalar(Math.max(0.0001, this.outBack(q, 1.6))); });
      },
      wave: (t) => { const m = items.flagMesh, p = m.geometry.attributes.position, a = p.array, p0 = m.userData.p0; for (let i = 0; i < a.length; i += 3) { const xx = p0[i] + 0.31; a[i + 2] = Math.sin(t * 3 + xx * 9) * 0.025 * xx; } p.needsUpdate = true; }
    };
    g.userData.open(0);
    return g;
  }
  flMenu() {
    const F = this.FL, T = this.THREE;
    this.flMode = 'menu'; this.flEditOne = false;
    const MC = { P: new T.Vector3(0, 1.4, 7.2), T: new T.Vector3(0, 0.55, 0) };
    this.flCam(MC.P.toArray(), MC.T.toArray(), 35);
    const SP = 1.9, plan = this.lastPlan;
    const items = [
      { key: 'train', label: 'Train', make: () => { const g = this.whiteboardModel(); g.scale.setScalar(0.62); this.flDrawBoard(g, plan); return g; } },
      { key: 'prs', label: 'My PRs', make: () => { const g = this.notebookModel2('MY PRs'); g.position.y = 0.8; g.rotation.x = -0.25; return g; } },
      { key: 'gym', label: 'Gym', make: () => this.gymRoomModel(this.d.name) }
    ];
    const n = items.length, labels = [];
    let pos = this.flMenuPos != null ? this.flMenuPos : 0, vel = 0, idx = Math.round(pos), dragging = false;
    // the active item: k goes 0 → 1 as it wakes up
    let act = null, k = 0, busy = false;
    items.forEach((it, i) => {
      const w = new T.Group(), m = it.make(); w.add(m); it.m = m; it.w = w; w.position.x = (i - pos) * SP; this.flAdd(w);
      const sh = this.softShadow(0.7); sh.scale.set(1, 0.6, 1); w.add(sh); it.sh = sh;
      const lab = this.fh('div', { position: 'absolute', left: 0, top: 0, transform: 'translate(-50%,-50%)', color: this.flInk(), fontFamily: "'Space Grotesk', Arial, sans-serif", fontWeight: 900, fontSize: '22px', whiteSpace: 'nowrap', pointerEvents: 'none' }, F.ui, it.label);
      labels.push(lab);
    });
    const tr = items[0], nbI = items[1], gy = items[2];
    // several gyms: inside the gym, the rooms sit side by side (along the screen's right); the last slot adds a new one
    const gyms = this.flGymList(); let gcur = this.flGymIdx, gpos = gcur, gtgt = gcur, gdrag = false;
    const rooms = gyms.map((g, j) => (j === gcur ? gy.m : this.gymRoomModel(g.name, g))); rooms.push(this.gymAddModel());
    rooms.forEach((r, j) => { if (j !== gcur) { r.userData.open(1); r.scale.setScalar(0.0001); gy.w.add(r); } });
    const RIGHT = new T.Vector3(0.794, 0, -0.607), GSP = 2.4;
    const gymSettle = () => {
      if (busy) return;
      const j = Math.round(gtgt);
      if (j !== gcur && j < gyms.length) {
        gyms[gcur] = this.flGymSnap(); this.flGymLoad(gyms[j]); gcur = j; this.flGymIdx = j;
        rooms[j].userData.open(1); gy.m = rooms[j]; this.buzz('selection');
      }
    };
    const newGym = () => {
      this.buzz('light'); this.flCheckSound(); busy = true;
      gyms[gcur] = this.flGymSnap();
      gyms.push({ name: '', unit: this.d.unit, own: { kg: [], lb: [] }, bar: JSON.parse(JSON.stringify(this.d.bar || {})) });
      this.flGymIdx = gyms.length - 1; this.flGymLoad(gyms[this.flGymIdx]); gcur = this.flGymIdx; gtgt = gpos = gcur;
      this.flMenuActive = 'gym'; this.flEditOne = false; this.flMode = 'gym'; this.flPanTo('name');
    };
    const askDelete = () => {
      this.buzz('warning');
      const nm = gyms[gcur].name || 'this gym';
      if (gyms.length <= 1) { this.flAlert('Can’t delete ' + nm, 'You need at least one gym.', [{ label: 'OK', bold: true }]); return; }
      this.flAlert('Delete ' + nm + '?', 'Its plates and bar settings will be removed.', [{ label: 'Cancel', bold: true }, { label: 'Delete', destructive: true, fn: () => {
        gyms.splice(gcur, 1); this.flGymIdx = Math.max(0, gcur - 1); this.flGymLoad(gyms[this.flGymIdx]); this.flGyms = gyms;
        this.buzz('success'); this.flMenuActive = 'gym'; this.flGo('menu');
      } }]);
    };
    // the notebook's page and the pen
    const rows = () => this.d.prs.filter((q) => q[1] != null).map((q) => q[0] + '  ' + this.fmt(q[1]) + ' ' + this.d.unit);
    nbI.m.userData.drawPage(rows());
    const pen = this.penModel(); pen.position.set(0.55, 0.36, 0.34); pen.rotation.set(0.5, 0, -0.95); pen.scale.setScalar(0.0001); nbI.w.add(pen);
    // the board's state: the last session, wiped clean, or a fresh upload
    let board = plan ? 'plan' : 'clean';
    // cameras: the menu, and a gentle move toward the active item (the gym gets its isometric corner view)
    const camFor = (it) => {
      const c = it.w.position.clone();
      if (it.key === 'gym') return { P: c.clone().add(new T.Vector3(3.9, 3.6, 5.1)), T: c.clone().add(new T.Vector3(0, 0.42, 0)) };
      if (it.key === 'prs') return { P: c.clone().add(new T.Vector3(0, 1.2, 6.5)), T: c.clone().add(new T.Vector3(0, 0.74, 0)) };
      return { P: c.clone().add(new T.Vector3(0, 1.2, 5.2)), T: c.clone().add(new T.Vector3(0, 0.82, 0)) };
    };
    const tg = new T.Vector3();
    const applyK = () => {
      const kk = k, e = kk * kk * (3 - 2 * kk);
      if (act) {
        const A = camFor(act); F.cam.position.lerpVectors(MC.P, A.P, e); tg.lerpVectors(MC.T, A.T, e); F.cam.lookAt(tg);
        labels.forEach((L, i) => { L.style.opacity = String((items[i] === act ? 1 : 0.25) * (1 - e)); });
        if (act === nbI) {
          nbI.m.userData.hinge.rotation.y = -2.95 * e; nbI.m.rotation.set(-0.25 + 0.15 * e, 0.18 * (1 - e), 0); nbI.m.scale.setScalar(1 - 0.3 * e); nbI.m.position.x = 0.37 * e;
          pen.scale.setScalar(Math.max(0.0001, this.outBack(Math.min(1, Math.max(0, (kk - 0.4) / 0.6)), 1.4)));
        }
        if (act === gy) gy.m.userData.open(kk);
        if (act === tr) tr.m.rotation.y = 0;
      } else { F.cam.position.copy(MC.P); F.cam.lookAt(MC.T); }
    };
    const activate = (it, instant) => {
      act = it; this.flMenuActive = it.key; dragging = false; vel = 0; pos = items.indexOf(it); this.flMenuPos = pos;
      if (instant) { k = 1; applyK(); return; }
      const k0 = k; busy = true; this.flClick(0.9);
      this.flAnim((u) => { k = k0 + (1 - k0) * (1 - Math.pow(1 - u, 3)); applyK(); }, it === gy ? 1.1 : 0.6, () => { busy = false; if (it === gy) this.flSparkles(gy.w.position.clone().add(new T.Vector3(0, 0.9, 0.3)), 5, 1); });
    };
    const deactivate = (k0) => {
      busy = true; const from = k0 != null ? k0 : k;
      this.flAnim((u) => { k = from * Math.pow(1 - u, 3); applyK(); }, 0.45, () => { k = 0; applyK(); act = null; this.flMenuActive = null; busy = false; labels.forEach((L) => { L.style.opacity = ''; }); });
    };
    // first-time: the items pop in; back from an edit: the item is already awake
    const back = this.flMenuActive && items.find((q) => q.key === this.flMenuActive);
    if (back) activate(back, true); else items.forEach((it, i) => this.popIn(it.w, 120 + i * 90));
    const v = new T.Vector3();
    F.tick = (dt, t) => {
      if (!act) {
        if (!dragging) { pos += vel * dt; vel *= Math.exp(-dt * 5); pos = Math.max(-0.3, Math.min(n - 0.7, pos)); if (Math.abs(vel) < 1.5) pos += (Math.max(0, Math.min(n - 1, Math.round(pos))) - pos) * (1 - Math.exp(-dt * 10)); }
        const i0 = Math.max(0, Math.min(n - 1, Math.round(pos))); if (i0 !== idx) { idx = i0; this.buzz('selection'); }
        this.flMenuPos = pos;
      }
      items.forEach((it, i) => {
        const d = i - pos, ad = Math.abs(d), ke = act && it !== act ? k * k * (3 - 2 * k) : 0; it.w.position.x = d * SP + Math.sign(d) * ke * 1.6; it.w.position.z = -Math.min(1, ad) * 0.6;
        const calm = it === act ? 1 - Math.min(1, k * 1.5) : 1;
        if (it.key === 'gym') it.m.rotation.y = (0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4)) * calm;
        else if (it.key === 'prs') { if (it !== act) it.m.rotation.y = 0.18 + 0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4); }
        else it.m.rotation.y = 0.25 * Math.sin(t * 0.6 + i) * (ad < 0.5 ? 1 : 0.4) * calm;
        v.set(it.w.position.x, -0.45, it.w.position.z).project(F.cam); const L = labels[i]; L.style.left = ((v.x + 1) / 2 * 100) + '%'; L.style.top = ((1 - v.y) / 2 * 100) + '%';
        if (!act) L.style.opacity = String(Math.max(0.25, 1 - ad * 0.75));
      });
      { // the row of gyms
        const show = act === gy ? k * k * (3 - 2 * k) : 0;
        if (act !== gy) { gtgt = gcur; }
        if (!gdrag) gpos += (gtgt - gpos) * (1 - Math.exp(-dt * 9));
        rooms.forEach((r, j) => { r.position.copy(RIGHT).multiplyScalar((j - gpos) * GSP); if (r !== gy.m) { r.scale.setScalar(Math.max(0.0001, show)); r.rotation.y = 0; } if (show > 0.5) r.userData.wave(t + j); });
        if (!gdrag && Math.abs(gtgt - gpos) < 0.02) gymSettle();
        gy.sh.position.x = gy.m.position.x; gy.sh.position.z = gy.m.position.z; gy.sh.visible = Math.abs(gpos - gcur) < 0.5;
      }
      this.flSpkTick(dt);
    };
    // ---- what each awake item does
    const hitObj = (e, o) => this.flRay(e).intersectObject(o, true).length > 0;
    const edit = (key, step) => { this.buzz('light'); this.flCheckSound(); this.flMenuActive = key; this.flEditOne = true; this.flMode = 'gym'; busy = true; this.flPanTo(step); };
    const trainStart = () => {
      busy = true; this.buzz('light'); this.flCheckSound();
      this.plan = this.lastPlan; this.setIdx = 0; this.doneSets = []; this.d.kitGot = {}; this.flMode = 'menu'; this.flAgain = true;
      const sc = 0.62, cy = 1.45 * sc, c0 = tr.w.position.clone(), P0 = F.cam.position.clone(), T0 = tg.clone(), P1 = c0.clone().add(new T.Vector3(0.1, cy, 0.5)), T1 = c0.clone().add(new T.Vector3(0, cy, 0)), q = new T.Vector3();
      labels.forEach((L) => { L.style.opacity = '0'; });
      this.flAnim((u) => { const e = u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; F.cam.position.lerpVectors(P0, P1, e); q.lerpVectors(T0, T1, e); F.cam.lookAt(q); }, 0.9, () => { this.flMenuActive = 'train'; this.flGo('kit'); });
    };
    // wiping the board: the marker comes off wherever the finger scrubs; enough of it and the board is clean
    const wb = tr.m, bc = wb.userData.c, bx = bc.getContext('2d'), clean = document.createElement('canvas'); clean.width = bc.width; clean.height = bc.height;
    { const tmp = this.whiteboardModel(); this.flDrawBoard(tmp, null); clean.getContext('2d').drawImage(tmp.userData.c, 0, 0); }
    const cells = new Set(), CW = 10, CH = 5;
    const wipeAt = (e) => {
      const hit = this.flRay(e).intersectObject(wb.userData.board, false)[0]; if (!hit || !hit.uv) return;
      const x = hit.uv.x * bc.width, y = (1 - hit.uv.y) * bc.height, r = 92;
      bx.save(); bx.beginPath(); bx.arc(x, y, r, 0, Math.PI * 2); bx.clip(); bx.drawImage(clean, 0, 0); bx.restore(); wb.userData.tex.needsUpdate = true;
      if (y > 150) { for (let ox = -1; ox <= 1; ox++) for (let oy = -1; oy <= 1; oy++) { const cx = Math.floor((x + ox * r * 0.6) / bc.width * CW), cyy = Math.floor((y + oy * r * 0.6 - 150) / (bc.height - 150) * CH); if (cx >= 0 && cx < CW && cyy >= 0 && cyy < CH) cells.add(cx + ',' + cyy); } }
      if (board === 'plan' && cells.size >= CW * CH * 0.45) {
        board = 'clean'; this.lastPlan = null; bx.drawImage(clean, 0, 0); wb.userData.tex.needsUpdate = true;
        this.buzz('success'); this.flCheckSound(); this.flSparkles(tr.w.position.clone().add(new T.Vector3(0, 0.95, 0.3)), 5, 0.9);
      }
    };
    const upload = () => {
      this.buzz('light'); this.flCheckSound();
      this.flPickPhoto(() => { busy = true; this.reading('Reading your workout…', () => {
        this.lastPlan = this.workoutPlan(); this.flDrawBoard(wb, this.lastPlan); board = 'plan'; cells.clear(); busy = false;
        this.flShine([wb], 0.6); this.flSparkles(tr.w.position.clone().add(new T.Vector3(0, 0.95, 0.3)), 5, 0.9);
      }); });
    };
    const prUpload = () => {
      this.buzz('light'); this.flCheckSound();
      this.flPickPhoto(() => { busy = true; this.reading('Reading your PRs…', () => {
        this.d.prs.forEach((q) => { q[1] = this.demoPR(q); }); nbI.m.userData.drawPage(rows()); busy = false;
        this.flShine([nbI.m], 0.7); this.flSparkles(nbI.w.position.clone().add(new T.Vector3(0.4, 0.9, 0.4)), 5, 1);
      }); });
    };
    // swipe up while an item is awake: it settles back into the menu with your finger
    const backDrag = (sy) => ({
      move: (ev) => { const p = Math.max(0, Math.min(1, (sy - ev.clientY - 10) / 300)); k = 1 - p; applyK(); },
      up: () => { if (k < 0.65) deactivate(k); else { const k0 = k; this.flAnim((u) => { k = k0 + (1 - k0) * (1 - Math.pow(1 - u, 3)); applyK(); }, 0.25); } }
    });
    const ppi = 390 * SP / (F.cam.position.z * 0.2914 * 1.15);
    F.hit = (e) => {
      if (busy) return { up: () => {} };
      if (act) {
        const sx = e.clientX, sy = e.clientY;
        // a gesture on an awake item: decide by what's under the finger and which way it goes
        let mode = null, inner = null, g0 = gpos;
        const onBoard = act === tr && hitObj(e, wb.userData.board);
        // press and hold a gym to delete it
        const lp = act === gy && Math.round(gtgt) < gyms.length && hitObj(e, gy.m) ? setTimeout(() => { if (!mode) { mode = 'held'; askDelete(); } }, 600) : null;
        return {
          move: (ev) => {
            const dx = ev.clientX - sx, dy = ev.clientY - sy;
            if (!mode) {
              if (Math.hypot(dx, dy) < 10) return;
              clearTimeout(lp);
              if (act === gy && Math.abs(dx) > Math.abs(dy)) { mode = 'gyms'; gdrag = true; g0 = gpos; }
              else if (-dy > Math.abs(dx) * (onBoard && board === 'plan' ? 2.6 : 1.3)) { mode = 'back'; inner = backDrag(sy); }
              else if (onBoard && board === 'plan') { mode = 'wipe'; this.flAudio(); }
              else mode = 'none';
            }
            if (mode === 'back') inner.move(ev);
            if (mode === 'gyms') gpos = Math.max(-0.25, Math.min(rooms.length - 0.75, g0 - dx / 420));
            if (mode === 'wipe') { wipeAt(ev); if (Math.random() < 0.18) { this.flClick(2.6); this.buzz('selection'); } }
          },
          up: (ev, tap) => {
            clearTimeout(lp);
            if (mode === 'held') return;
            if (mode === 'gyms') { gdrag = false; const dx = ev.clientX - sx; gtgt = Math.max(0, Math.min(rooms.length - 1, Math.round(gpos + (dx < -40 ? 0.35 : dx > 40 ? -0.35 : 0)))); return; }
            if (mode === 'back') { inner.up(ev); return; }
            if (!tap) return;
            if (act === tr) { if (!hitObj(ev, tr.m)) return; if (board === 'plan') trainStart(); else upload(); return; }
            if (act === nbI) { if (hitObj(ev, pen)) { this.buzz('light'); this.flCheckSound(); this.flMenuActive = 'prs'; this.flPrRet = 'menu'; this.flEditOne = true; busy = true; this.flPanTo('prDial'); return; }
              if (hitObj(ev, nbI.m)) prUpload(); return; }
            if (act === gy) {
              if (Math.round(gtgt) >= gyms.length) { if (hitObj(ev, rooms[rooms.length - 1])) newGym(); return; }
              const I = gy.m.userData.items;
              if (hitObj(ev, I.flag)) edit('gym', 'name'); else if (hitObj(ev, I.bar)) edit('gym', 'bar'); else if (hitObj(ev, I.plates)) edit('gym', 'plates'); else if (hitObj(ev, I.bell)) edit('gym', 'unit');
            }
          }
        };
      }
      let x0 = e.clientX, t0 = performance.now(); dragging = true; this.flAudio();
      return {
        move: (ev) => { const dx = ev.clientX - x0, now = performance.now(); const d = -dx / ppi; pos += d; vel = d / Math.max(0.008, (now - t0) / 1000); x0 = ev.clientX; t0 = now; },
        up: (ev, tap) => {
          dragging = false; if (performance.now() - t0 > 90) vel = 0;
          if (tap) { const it = items[idx]; this.buzz('light'); this.flCheckSound(); activate(it); }
        }
      };
    };
  }
  // the scale, then the menu — the board keeps the session you just did
  closeSessionOver() {
    const L = this.doneL; this.doneL = null; if (!L) return;
    this.buzz('light'); this.dropLayer(L);
    if (this.plan) this.lastPlan = this.plan;
    this.plan = null; this.flBar = null; this.flMenuPos = 0; this.flMenuActive = null; this.flMode = 'menu'; this.flGo('menu');
  }

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
    const c = this.fh('div', { position: 'absolute', left: '12px', right: '12px', bottom: '24px', padding: '16px 18px 18px', borderRadius: '22px', background: '#FFFFFF', color: this.pal.boxDark, fontFamily: "'Space Grotesk', Arial, sans-serif", pointerEvents: 'auto', boxShadow: '0 10px 30px rgba(0,0,0,0.18)' }, F.ui);
    this.fh('div', { fontSize: '13px', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', color: this.pal.boxDark, opacity: 0.6 }, c, x.group);
    const row = this.fh('div', { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: '10px', margin: '2px 0 12px' }, c);
    this.fh('div', { fontSize: '30px', fontWeight: 900, letterSpacing: '-0.02em' }, row, x.label + ' of ' + x.of);
    this.fh('div', { fontSize: '17px', fontWeight: 800, whiteSpace: 'nowrap' }, row, x.reps + ' reps · ' + this.fmt(x.total) + ' ' + P.unit);
    const dots = this.fh('div', { display: 'flex', gap: '6px' }, c), base = P.flat.findIndex((q) => q.gi === x.gi);
    c.paintDots = () => { dots.innerHTML = ''; grp.sets.forEach((q, k) => { const j = base + k; this.fh('span', { flex: 1, height: '7px', borderRadius: '4px', background: this.doneSets[j] ? this.pal.bgColor : j === i ? this.pal.boxDark : this.pal.boxDark + '22' }, dots); }); };
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
    // twelve hand-drawn edges: each a slightly wobbly tube, drawn twice for a rough pen line
    const C = [[-h, 0, -h], [h, 0, -h], [h, 0, h], [-h, 0, h], [-h, S, -h], [h, S, -h], [h, S, h], [-h, S, h]].map((p) => new T.Vector3(...p));
    const E = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
    let seed = 7; const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647 - 0.5; };
    E.forEach(([i, j]) => [0.0055].forEach((r, pass) => {
      const a = C[i].clone().addScalar(pass ? rnd() * 0.02 : 0), b = C[j].clone().addScalar(pass ? rnd() * 0.02 : 0), pts = [];
      for (let k = 0; k <= 6; k++) { const p = a.clone().lerp(b, k / 6); if (k && k < 6) p.add(new T.Vector3(rnd(), rnd(), rnd()).multiplyScalar(0.022)); pts.push(p); }
      g.add(new T.Mesh(new T.TubeGeometry(new T.CatmullRomCurve3(pts), 24, r, 5, false), mat));
    }));
    const hit = new T.Mesh(new T.BoxGeometry(S, S, S), new T.MeshBasicMaterial({ visible: false })); hit.position.y = S / 2; g.add(hit);
    g.userData = { add: true, items: {}, open: () => {}, wave: () => {} };
    return g;
  }

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
}
