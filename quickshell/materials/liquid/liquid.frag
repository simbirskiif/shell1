#version 440
// Liquid glass: blur + edge refraction + rim highlight on a rounded rect.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2  size;        // item size in px
    float radius;      // corner radius px
    float refraction;  // max edge displacement px (try 24)
    float blurRadius;  // blur radius px (try 10)
    float bezel;       // refracting edge width px (try 28)
    float rim;         // highlight strength 0..1 (try 0.6)
    vec4  tint;        // premultiplied-ish overlay colour, alpha = amount
    float useWidgets;
} ubuf;

layout(binding = 1) uniform sampler2D source; // backdrop texture (wallpaper / screencopy)
layout(binding = 2) uniform sampler2D widgets; // other widgets under the dragged card

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = (qt_TexCoord0 - 0.5) * ubuf.size;
    vec2 half_ = ubuf.size * 0.5;
    float d = sdRoundBox(px, half_, ubuf.radius);

    // shape mask (antialiased)
    float mask = 1.0 - smoothstep(-1.0, 1.0, d);
    if (mask <= 0.0) { fragColor = vec4(0.0); return; }

    // SDF gradient = outward normal
    vec2 e = vec2(1.0, 0.0);
    vec2 n = normalize(vec2(
        sdRoundBox(px + e.xy, half_, ubuf.radius) - sdRoundBox(px - e.xy, half_, ubuf.radius),
        sdRoundBox(px + e.yx, half_, ubuf.radius) - sdRoundBox(px - e.yx, half_, ubuf.radius)) + 1e-6);

    // lens profile: strongest at the rim, zero in the middle
    float t = clamp(1.0 + d / ubuf.bezel, 0.0, 1.0);   // d<0 inside
    float lens = t * t * (3.0 - 2.0 * t);
    lens *= lens;
    vec2 offset = -n * lens * ubuf.refraction / ubuf.size; // pull sample inward

    // chromatic dispersion
    vec2 uvR = qt_TexCoord0 + offset * 1.00;
    vec2 uvG = qt_TexCoord0 + offset * 1.12;
    vec2 uvB = qt_TexCoord0 + offset * 1.25;

    // blur: golden-angle disc, 24 taps
    vec3 col = vec3(0.0);
    const int N = 24;
    for (int i = 0; i < N; ++i) {
        float a = float(i) * 2.399963;
        float r = sqrt((float(i) + 0.5) / float(N)) * ubuf.blurRadius;
        vec2 o = vec2(cos(a), sin(a)) * r / ubuf.size;
        col.r += texture(source, clamp(uvR + o, 0.0, 1.0)).r;
        col.g += texture(source, clamp(uvG + o, 0.0, 1.0)).g;
        col.b += texture(source, clamp(uvB + o, 0.0, 1.0)).b;
    }
    col /= float(N);

    // tint + rim light (top-left light source)
    col = mix(col, ubuf.tint.rgb, ubuf.tint.a);

    // Соседние виджеты (без перетаскиваемого) поверх обоев.
    if (ubuf.useWidgets > 0.5) {
        vec4 w = texture(widgets, qt_TexCoord0);
        col = col * (1.0 - w.a) + w.rgb;
    }

    float edgeBand = smoothstep(-3.0, 0.0, d) ;               // thin line at the border
    float light = pow(clamp(dot(n, normalize(vec2(-0.6, -0.8))) * 0.5 + 0.5, 0.0, 1.0), 3.0);
    col += ubuf.rim * edgeBand * mix(0.15, 0.9, light);
    col += ubuf.rim * 0.25 * lens * light;                    // soft inner glow

    float a = mask * ubuf.qt_Opacity;
    fragColor = vec4(col * a, a);                             // premultiplied
}
