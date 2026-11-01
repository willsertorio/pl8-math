#include <metal_stdlib>
using namespace metal;

// The Flow's rough edges: design/flow-handoff/source/glfx.js, as one compute pass after RealityKit draws the
// scene (ARView's postProcess). A grainy dark band is drawn round every silhouette (the scene's alpha, dilated,
// minus the shape), its position wobbled by smooth noise, and drawn twice for a rough pen line.
// The prototype's settings for the Flow: width 2.2, rough 5, scale 0.03, grain 0.4, double, no warp of the fill.

struct SketchParams {
    float2 size;     // the texture, pixels
    float scale;     // pixels per point
    float on;        // 1: draw the line; 0: copy
    float4 ink;      // premultiplied colour of the line, in the texture's space
    float width;     // points
    float rough;     // points
    float freq;      // per point
    float grain;
    float seed;
    float pad0, pad1, pad2;
};

static float h21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vn(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + float2(1, 0)), f.x), mix(h21(i + float2(0, 1)), h21(i + float2(1, 1)), f.x), f.y);
}

// Two octaves, roughly feTurbulence's spread around 0.5.
static float fb(float2 p) {
    return 0.5 + ((vn(p) - 0.5) * 0.66 + (vn(p * 2.0 + 17.3) - 0.5) * 0.33) * 1.35;
}

static float2 n2(float2 p, float s) {
    return float2(fb(p + float2(s, 3.1 * s)), fb(p + float2(41.7 + s, 9.2 - s)));
}

static float alphaAt(texture2d<half, access::read> src, float2 points, constant SketchParams& P) {
    float2 px = clamp(points * P.scale, float2(0), P.size - 1.0);
    return float(src.read(uint2(px)).a);
}

// feMorphology dilate, then 'out' the shape: a band around the silhouettes.
static float ring(texture2d<half, access::read> src, float2 p, float w, constant SketchParams& P) {
    float inside = alphaAt(src, p, P);
    if (inside > 0.999) return 0.0;
    float m = inside;
    for (int i = 0; i < 12; i++) {
        float a = float(i) * 0.5235988;
        float2 d = float2(cos(a), sin(a));
        m = max(m, alphaAt(src, p + d * w, P));
        m = max(m, alphaAt(src, p + d * w * 0.5, P));
    }
    return m * (1.0 - inside);
}

kernel void flowSketch(texture2d<half, access::read> src [[texture(0)]],
                       texture2d<half, access::write> dst [[texture(1)]],
                       constant SketchParams& P [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    half4 base = src.read(gid);
    if (P.on < 0.5) { dst.write(base, gid); return; }
    // In points, y up like the prototype's canvas, so the noise reads the same way.
    float2 p = float2(float(gid.x), P.size.y - 1.0 - float(gid.y)) / P.scale;
    float2 pr = float2(float(gid.x), float(gid.y)) / P.scale;
    float2 a = n2(p * P.freq, P.seed), b = n2(p * P.freq, P.seed + 7.7);
    float g = clamp(4.0 * P.grain * vn(p * 0.85 + 5.0) + (1.0 - 2.2 * P.grain), 0.0, 1.0);
    float2 wa = float2(a.x - 0.5, -(a.y - 0.5)), wb = float2(b.x - 0.5, -(b.y - 0.5));
    float l1 = ring(src, pr + P.rough * wa, P.width, P) * g;
    float4 o = float4(base);
    o = P.ink * l1 + o * (1.0 - l1);
    float l2 = ring(src, pr + P.rough * wb, max(0.5, P.width * 0.7), P) * g;
    o = P.ink * l2 + o * (1.0 - l2);
    dst.write(half4(o), gid);
}
