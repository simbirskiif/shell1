#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    vec4 surface;
    vec4 outline;
    float strength;
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * ubuf.size;
    float d = roundedBox(p, ubuf.size * 0.5, ubuf.radius);
    float aa = 1.5 / max(1.0, min(ubuf.size.x, ubuf.size.y));
    float alpha = 1.0 - smoothstep(-aa, aa, d);

    vec2 cell = floor(qt_TexCoord0 * ubuf.size * 0.8);
    float noise = hash(cell);
    vec3 color = ubuf.surface.rgb + (noise - 0.5) * ubuf.strength;

    // Жёсткий порог по контуру: полупрозрачная кромка на прямой нижней
    // стороне читалась как светлая квадратная линия на фоне обоев.
    if (alpha < 0.5)
        discard;
    alpha = 1.0;

    fragColor = vec4(color, alpha) * ubuf.qt_Opacity;
}
