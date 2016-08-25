# Exploration of 2d shadow methods

This project is an exploration into hardware accelerated 2d shadow rendering.

All examples are written in D using OpenGL bindings/abstractions.

## Screen Space Depth Accumulation (SSDA)

This method takes advantage of the depth buffer to generate a one dimensional
depth map of geometry surrounding the light. It accumulates this using a stencil
buffer (or the alpha channel) of already rendered geometry on the screen.

**Lighting Method**:
1. Render geometry to a stencil buffer
2. For every light:
  1. Sample stencil in circular steps from the color buffer around the light
  2. Write step distance to one dimensional depth buffer called the "shadow
     map", only if stencil is 1
  3. Draw light up to the step distance sampled from the shadow map to the
     output buffer

**Possible Disadvantages**:
- Current implementation uses sin/cos which might be slow on old hardware
- Uses screen space for light occlusion, meaning off-screen geometry doesn't
  cast shadows (avoidable by overdrawing)
- Not pixel perfect, instead depending on the size of the shadow map
- Doesn't support transparent shadows

**Possible Advantages**:
- Method is independent of the amount of geometry on scene
- Easy to achieve accurate blurring and nice looking shadows
