# Art and assets (standard 8)

- Standard humanoid skeleton, glTF, every source listed with its licence (02-movement.md).
- Source art lives in **Foxboard** (Duff's art app). Finished art arrives in
  `grok_art/<date>-foxboard/` via its Send to game button. `grok_art/` never ships.
- **Texture imports are set by hand, never "detect":** colour maps sRGB with normal map OFF; only
  `*_n` / `*_normal` files are normal maps (Import dock -> Normal Map).
- Never ask an image generator for a "seamless tile": use one big painted surface and make the
  seams/repeats in code.
- Small images go into atlases (05-performance.md).
Checks: `test_models_portable`, `test_texture_imports_explicit`.
