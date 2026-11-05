#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 direction;
    float slideFade;
};

layout(binding = 1) uniform sampler2D from;
layout(binding = 2) uniform sampler2D to;

vec4 transition (vec2 uv) {
  // Avoid fract wrapping the texture edges at either mathematical endpoint.
  if (progress <= 0.0)
    return texture(from, uv);
  if (progress >= 1.0)
    return texture(to, uv);

  if (slideFade > 0.0) {
    // Fade the incoming slide over the stationary captured frame, as before.
    vec2 incoming = uv + (progress - 1.0) * sign(direction);
    float inside = step(0.0, incoming.x) * step(incoming.x, 1.0)
                 * step(0.0, incoming.y) * step(incoming.y, 1.0);
    return mix(texture(from, uv), texture(to, clamp(incoming, 0.0, 1.0)),
               inside * mix(1.0, progress, slideFade));
  }

  vec2 p = uv + progress * sign(direction);
  vec2 f = fract(p);
  return mix(
    texture(to, f),
    texture(from, f),
    step(0.0, p.y) * step(p.y, 1.0) * step(0.0, p.x) * step(p.x, 1.0)
  );
}

void transitionMain() {
    fragColor = transition(qt_TexCoord0);
}

void main() {
    transitionMain();
    fragColor *= qt_Opacity;
}
