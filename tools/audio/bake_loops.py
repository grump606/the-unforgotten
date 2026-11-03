"""Bakes the seamless-loop OGGs the game plays from the untouched originals in audio/source/.

Run:  python tools/audio/bake_loops.py   (needs numpy and soundfile; deterministic)

Technique (tail into head): the loop is out = x[a:b]. Its first X seconds are an equal-power
crossfade from the tail x[b:b+X] (fading out) into the head x[a:a+X] (fading in). The sound that
"would have come next" after b therefore plays under the start of the loop, so the wrap from
out[-1] to out[0] continues the original waveform (x[b-1] -> x[b]) instead of jumping.
Loop points were chosen from the recordings' 1-second RMS envelopes:
  menu    : 0.5 s of leading silence (kept, so the tail rings into silence); the piece ends with a
            decaying ring-out, so b sits 4.5 s before the end and X = 4 s.
  combat  : abrupt start, ~5 s fade at the end; a = 0, b = len - 5.5 s, X = 5 s.
  coastal : 100.6 s with a fade-in and fade-out; the steady middle a = 4 s, b = len - 9 s, X = 3 s.
Gain is left alone (music is already near -22 dB RMS, peaks below -1 dB). The report prints the
seam jump against the typical adjacent-sample step and RMS around the seam against the whole loop.
Vorbis is written at quality 0.5 and the seam is re-measured after decoding the OGG back.
"""
import os
import numpy as np
import soundfile as sf

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "audio")
# name: (source, output, a_seconds, tail_from_end_seconds, crossfade_seconds)
TRACKS = {
    "menu": ("menu_minimal_piano_cello.mp3", "music/menu_loop.ogg", 0.0, 4.5, 4.0),
    "combat": ("combat_piano_cello.mp3", "music/combat_loop.ogg", 0.0, 5.5, 5.0),
    "coastal": ("coastal_waves.mp3", "ambience/coastal_loop.ogg", 4.0, 9.0, 3.0),
}


def bake(x: np.ndarray, sr: int, a_s: float, end_s: float, xf_s: float) -> np.ndarray:
    a, b, xf = int(a_s * sr), len(x) - int(end_s * sr), int(xf_s * sr)
    assert b + xf <= len(x) and a + xf < b
    t = np.linspace(0.0, np.pi / 2.0, xf)[:, None]
    out = x[a:b].copy()
    out[:xf] = x[b:b + xf] * np.cos(t) + x[a:a + xf] * np.sin(t)
    return out


def db(v: float) -> float:
    return 20 * np.log10(v + 1e-12)


def seam_report(name: str, y: np.ndarray, sr: int, label: str) -> None:
    jump = np.abs(y[0] - y[-1]).max()
    typical = np.abs(np.diff(y, axis=0)).mean()
    p99 = np.percentile(np.abs(np.diff(y, axis=0)), 99.9)
    w = int(0.25 * sr)
    seam = np.concatenate([y[-w:], y[:w]])
    rms = lambda z: db(np.sqrt((z ** 2).mean()))
    print(f"  [{label}] wrap jump {jump:.5f} | mean step {typical:.5f} | 99.9% step {p99:.5f} | "
          f"jump/mean {jump / max(typical, 1e-12):.2f} | RMS seam(Â±0.25s) {rms(seam):.1f} dB vs loop {rms(y):.1f} dB | "
          f"peak {db(np.abs(y).max()):.1f} dB")


def main() -> None:
    for name, (src, dst, a, end, xf) in TRACKS.items():
        x, sr = sf.read(os.path.join(ROOT, "source", src), always_2d=True)
        y = bake(x, sr, a, end, xf)
        peak = np.abs(y).max()
        if peak > 0.708:  # -3 dB ceiling
            y = y * (0.708 / peak)
        path = os.path.join(ROOT, dst)
        # Written in chunks: one huge write overflows the stack inside libsndfile's Vorbis encoder on Windows.
        with sf.SoundFile(path, "w", sr, y.shape[1], format="OGG", subtype="VORBIS") as out:
            try:
                out.compression_level = 0.5  # Vorbis quality ~q5 (libsndfile compression 0.5)
            except Exception:
                pass
            for i in range(0, len(y), 16384):
                out.write(y[i:i + 16384])
        print(f"{name}: a={a}s b=len-{end}s X={xf}s -> {len(y) / sr:.2f}s, {os.path.getsize(path) / 1e6:.2f} MB")
        seam_report(name, y, sr, "float")
        d, _ = sf.read(path, always_2d=True)
        seam_report(name, d, sr, "ogg")


if __name__ == "__main__":
    main()
