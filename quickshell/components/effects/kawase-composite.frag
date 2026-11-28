#version 440

// Финальный композит поверх размытия: тонировка в цвет темы, лёгкая
// сатурация и маска скругления. Без тонировки блюр читается грязно и
// мелкий текст теряет контраст.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;         // размер результата в пикселях
    float radius;      // радиус скругления
    vec4 tint;
    float tintOpacity;
    float saturation;
    float brightness;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 uv = clamp(qt_TexCoord0, vec2(0.0015), vec2(0.9985));
    vec3 c = texture(source, uv).rgb;

    // Насыщенность вокруг яркости: цвет обоев/обложки не должен
    // превращаться в серую кашу после усреднения.
    float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(luma), c, ubuf.saturation);
    c = clamp(c + ubuf.brightness, 0.0, 1.0);
    c = mix(c, ubuf.tint.rgb, clamp(ubuf.tintOpacity, 0.0, 1.0));

    float alpha = 1.0;
    if (ubuf.radius > 0.5) {
        vec2 p = (qt_TexCoord0 - 0.5) * ubuf.size;
        float d = roundedBox(p, ubuf.size * 0.5, ubuf.radius);
        float aa = 1.5 / max(1.0, min(ubuf.size.x, ubuf.size.y));
        alpha = 1.0 - smoothstep(-aa, aa, d);
    }

    fragColor = vec4(c, alpha) * ubuf.qt_Opacity;
}
