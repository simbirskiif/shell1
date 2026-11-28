#version 440

// Первый проход даунсемплинга dual Kawase: сразу в 1/4 разрешения.
// 4 сэмпла по углам квадрата ±1 исходный тексел — как в
// KawaseBlurDualFilterV2 (STEP_0..3 = ±0.25 в координатах результата
// при четырёхкратном уменьшении).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel; // 1/ширина, 1/высота исходной текстуры
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 o = ubuf.texel;

    vec3 c = texture(source, uv + vec2(o.x, o.y)).rgb;
    c += texture(source, uv + vec2(o.x, -o.y)).rgb;
    c += texture(source, uv + vec2(-o.x, -o.y)).rgb;
    c += texture(source, uv + vec2(-o.x, o.y)).rgb;

    fragColor = vec4(c * 0.25, 1.0) * ubuf.qt_Opacity;
}
