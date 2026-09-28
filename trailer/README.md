# FAMIGLIA — 30s concept trailer

`famiglia_trailer.mp4` (1280x720, 30 fps, 30 s) is rendered from code:

- `trailer.html` — canvas animation; `draw(t)` renders the frame at time `t`.
- `render.js` — Playwright script that screenshots all 900 frames into `frames/` (`node render.js all`).
- `audio.py` — synthesizes the original score and SFX into `score.wav` (needs numpy).

Mux: `ffmpeg -framerate 30 -i frames/f%04d.jpg -i score.wav -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac -shortest famiglia_trailer.mp4`
