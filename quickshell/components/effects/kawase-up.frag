#version 440

// Апсемплинг dual Kawase: 8 сэмплов (центр + 7 вершин правильного
// семиугольника) по более грубому уровню, затем смешивание с более
// тонким уровнем по crossFade. В KawaseBlurDualFilterV2 веса равные,
// а перекрёстное затухание задаётся альфой прохода.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;        // 1/ширина, 1/высота результата (этого уровня)
    float blurOffset;  // радиус семиугольника в пикселях результата
    float crossFade;   // 0 — только тонкий уровень, 1 — только грубый
} ubuf;

layout(binding = 1) uniform sampler2D fine;
layout(binding = 2) uniform sampler2D coarse;

const vec2 STEP_0 = vec2( 1.0, 0.0);
const vec2 STEP_1 = vec2( 0.623489802,  0.781831482);
const vec2 STEP_2 = vec2(-0.222520934,  0.974927912);
const vec2 STEP_3 = vec2(-0.900968868,  0.433883739);
const vec2 STEP_4 = vec2( 0.900968868, -0.433883739);
const vec2 STEP_5 = vec2(-0.222520934, -0.974927912);
const vec2 STEP_6 = vec2(-0.623489802, -0.781831482);

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 o = ubuf.texel * max(ubuf.blurOffset, 0.0);

    vec3 c = texture(coarse, uv).rgb;
    c += texture(coarse, uv + STEP_0 * o).rgb;
    c += texture(coarse, uv + STEP_1 * o).rgb;
    c += texture(coarse, uv + STEP_2 * o).rgb;
    c += texture(coarse, uv + STEP_3 * o).rgb;
    c += texture(coarse, uv + STEP_4 * o).rgb;
    c += texture(coarse, uv + STEP_5 * o).rgb;
    c += texture(coarse, uv + STEP_6 * o).rgb;
    c *= 0.125;

    vec3 f = texture(fine, uv).rgb;
    float a = clamp(ubuf.crossFade, 0.0, 1.0);

    fragColor = vec4(mix(f, c, a), 1.0) * ubuf.qt_Opacity;
}
