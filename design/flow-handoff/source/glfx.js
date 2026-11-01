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
