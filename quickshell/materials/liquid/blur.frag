#version 440
// Separable gaussian blur. Run twice: dir=(1,0) then dir=(0,1).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;   // 1.0/width, 1.0/height of source
    vec2 dir;     // (1,0) or (0,1)
    float radius; // blur radius in px (<= 32)
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    float sigma = max(ubuf.radius * 0.5, 0.001);
    int taps = int(min(ubuf.radius, 32.0));
    vec4 sum = texture(source, qt_TexCoord0);
    float wsum = 1.0;
    for (int i = 1; i <= taps; ++i) {
        float w = exp(-float(i * i) / (2.0 * sigma * sigma));
        vec2 o = ubuf.dir * ubuf.texel * float(i);
        sum  += w * (texture(source, qt_TexCoord0 + o) + texture(source, qt_TexCoord0 - o));
        wsum += 2.0 * w;
    }
    fragColor = (sum / wsum) * ubuf.qt_Opacity;
}
