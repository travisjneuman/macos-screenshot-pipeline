# Demo assets

| File | Description |
|------|-------------|
| `hero.png` | Static README / social hero (1280×640) |
| `demo.gif` | 10s · 720p loop for README |
| `demo.mp4` | Same animation, H.264 |

## Regenerate

```bash
python3 scripts/generate-demo-assets.py
# then encode (see script comments / CI notes):
ffmpeg -y -framerate 15 -i docs/assets/_frames/frame_%04d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart docs/assets/demo.mp4
ffmpeg -y -i docs/assets/demo.mp4 \
  -vf "fps=12,scale=1280:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" \
  -loop 0 docs/assets/demo.gif
rm -rf docs/assets/_frames
```

These are **stylized product explainers**, not live screen recordings of a Mac desktop.
A real capture→paste→Photos→markup GIF can replace them later.
