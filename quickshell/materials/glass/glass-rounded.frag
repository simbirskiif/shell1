#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    vec4 tint;
    vec4 outline;
    float tintOpacity;
    float blur;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    // Не уходим в самый край текстуры: на последнем texel некоторых
    // драйверов возвращается чёрная кромка, которая читалась как линия.
    vec2 uv = clamp(qt_TexCoord0, vec2(0.0015), vec2(0.9985));
    vec2 texel = ubuf.blur / max(ubuf.size, vec2(1.0));

    // 9-tap box-ish blur; weights sum to 1.
    vec3 color = texture(source, uv).rgb * 0.16;
    color += texture(source, uv + vec2(texel.x, 0.0)).rgb * 0.12;
    color += texture(source, uv - vec2(texel.x, 0.0)).rgb * 0.12;
    color += texture(source, uv + vec2(0.0, texel.y)).rgb * 0.12;
    color += texture(source, uv - vec2(0.0, texel.y)).rgb * 0.12;
    color += texture(source, uv + texel).rgb * 0.09;
    color += texture(source, uv - texel).rgb * 0.09;
    color += texture(source, uv + vec2(texel.x, -texel.y)).rgb * 0.09;
    color += texture(source, uv + vec2(-texel.x, texel.y)).rgb * 0.09;

    color = mix(color, ubuf.tint.rgb, clamp(ubuf.tintOpacity, 0.0, 1.0));

    // Мягкий верхний блик.
    color += vec3(1.0) * smoothstep(0.55, 0.0, uv.y) * 0.08;

    vec2 p = (uv - 0.5) * ubuf.size;
    float d = roundedBox(p, ubuf.size * 0.5, ubuf.radius);
    float aa = 1.5 / max(1.0, min(ubuf.size.x, ubuf.size.y));
    float alpha = 1.0 - smoothstep(-aa, aa, d);

    // Жёсткий порог по контуру: полупрозрачная кромка на прямой нижней
    // стороне читалась как светлая квадратная линия на фоне обоев.
    if (alpha < 0.5)
        discard;
    alpha = 1.0;

    fragColor = vec4(color, alpha) * ubuf.qt_Opacity;
}
