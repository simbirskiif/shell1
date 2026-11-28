#version 440

// Даунсемплинг dual Kawase в 2 раза. Центр с весом 4 и четыре угла
// с весом 1 — ровно формула KawaseBlurDualFilterV2 для half-res прохода.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel; // 1/ширина, 1/высота входной текстуры
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 o = ubuf.texel;

    vec3 c = texture(source, uv).rgb * 4.0;
    c += texture(source, uv + vec2(o.x, o.y)).rgb;
    c += texture(source, uv + vec2(o.x, -o.y)).rgb;
    c += texture(source, uv + vec2(-o.x, -o.y)).rgb;
    c += texture(source, uv + vec2(-o.x, o.y)).rgb;

    fragColor = vec4(c * 0.125, 1.0) * ubuf.qt_Opacity;
}
