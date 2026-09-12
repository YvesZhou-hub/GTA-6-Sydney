#!/usr/bin/env python3
"""Original instrumental score and editorial transitions, no sampled music.

Writes 48 kHz stereo PCM. Requires numpy (tools/runtime/video-env).
This is a trailer soundtrack, not a capture of the live game's audio mixer.
"""
from pathlib import Path
import argparse
import json
import wave
import numpy as np

RATE = 48000


def create(seconds: float, output: Path, cuts=()):
    rng = np.random.default_rng(180913)
    mix = np.zeros((int((seconds + 3) * RATE), 2), np.float64)
    beat = 60 / 128

    def put(at, sound, gain=1.0, pan=0.0):
        start = int(at * RATE)
        sound = np.asarray(sound)
        if start < 0:
            sound, start = sound[-start:], 0
        count = min(len(sound), len(mix) - start)
        if count <= 0:
            return
        stereo = np.array([np.sqrt((1 - pan) * .5), np.sqrt((1 + pan) * .5)])
        mix[start:start + count] += sound[:count, None] * gain * stereo

    def timeline(duration):
        return np.arange(int(duration * RATE)) / RATE

    def note(hz, duration, intensity=.16):
        t = timeline(duration)
        phase = 2 * np.pi * hz * t
        tone = (np.sin(phase + .32 * np.sin(phase * 2)) + .21 * np.sin(phase * 2.002)
                + .08 * np.sin(phase * 3))
        return intensity * tone * (1 - np.exp(-t * 90)) * np.exp(-t * 4.5) * np.minimum(1, (duration - t) * 25)

    # C minor / Ab / Eb / Bb, an original short progression and sparse melody.
    chords = [(48, 55, 63, 67), (44, 51, 60, 63), (51, 58, 67, 70), (46, 53, 62, 65)]
    bars = int(np.ceil(seconds / (4 * beat)))
    for bar in range(bars):
        at = bar * beat * 4
        chord = chords[(bar // 2) % 4]
        full = 4 <= at < seconds - 4
        pad_t = timeline(4 * beat + .6)
        env = np.minimum(1, pad_t / .4) * np.minimum(1, np.maximum(0, (4 * beat + .6 - pad_t) / .7))
        for index, midi in enumerate(chord):
            hz = 440 * 2 ** ((midi - 69) / 12)
            pad = (np.sin(2 * np.pi * hz * pad_t) + .28 * np.sin(2 * np.pi * hz * 1.003 * pad_t))
            put(at, pad * env, .028, [-.55, .35, -.25, .5][index])
        for eighth in range(8):
            start = at + eighth * beat / 2
            midi = chord[[0, 2, 1, 3, 2, 1, 3, 2][eighth]] + 12
            hz = 440 * 2 ** ((midi - 69) / 12)
            pluck = note(hz, .52)
            put(start, pluck, .60 if full else .22, .4 * (-1 if eighth % 2 else 1))
            put(start + beat * .75, pluck, .17, -.4 * (-1 if eighth % 2 else 1))
        for index in range(4):
            start = at + beat * index
            t = timeline(.48)
            kick = np.sin(2 * np.pi * (43 * t + 4.4 * (1 - np.exp(-t * 24))))
            kick = kick * np.exp(-t * 12) * np.minimum(t * 1800, 1)
            put(start, kick, .36 if full else .14)
            bass_hz = 440 * 2 ** ((chord[0] - 12 - 69) / 12)
            bass = np.sin(2 * np.pi * bass_hz * t) + .18 * np.sin(2 * np.pi * bass_hz * 2 * t)
            put(start + beat / 2, bass * np.exp(-t * 9) * np.minimum(t * 80, 1), .12 if full else .045)
            if full and index % 2:
                t = timeline(.24)
                noise = rng.normal(0, .6, len(t))
                snap = np.diff(noise, prepend=0) * .3 + np.sin(2 * np.pi * 180 * t) * .25
                put(start, snap * np.exp(-t * 24) * np.minimum(t * 2200, 1), .16)
            if full:
                for off in (0, .5):
                    t = timeline(.052 if off == 0 else .11)
                    noise = rng.normal(0, .5, len(t))
                    hat = np.diff(noise, prepend=0) * np.exp(-t * (85 if off == 0 else 40))
                    put(start + off * beat, hat, .025 if off == 0 else .042, .35)
    for cut in cuts:
        # Short airy transition sound, deliberately quieter than weapon transients.
        t = timeline(.6)
        noise = rng.normal(0, .2, len(t))
        env = np.sin(np.pi * t / .6) ** 2
        carrier = np.sin(2 * np.pi * (480 * t + 900 * t * t))
        put(max(0, cut - .43), (noise * .24 + carrier * .03) * env, .3, -.1)
    n = int(seconds * RATE)
    mix = mix[:n]
    fade = np.minimum(1, np.arange(n) / (.03 * RATE)) * np.minimum(1, (n - np.arange(n)) / (1.2 * RATE))
    mix *= fade[:, None]
    peak = float(np.max(np.abs(mix)))
    if peak > .65:
        mix *= .65 / peak
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), 'wb') as wav:
        wav.setparams((2, 2, RATE, n, 'NONE', 'not compressed'))
        wav.writeframes((mix * 32767).astype('<i2').tobytes())
    report = {'source': 'Original deterministic instrumental synthesis; no samples, recordings or third-party music',
              'bpm': 128, 'seconds': seconds, 'sample_rate': RATE, 'channels': 2,
              'peak_before_mastering': float(np.abs(mix).max()), 'voice': False}
    output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    parser.add_argument('--seconds', type=float, default=40)
    parser.add_argument('--cuts', default='')
    args = parser.parse_args()
    print(json.dumps(create(args.seconds, args.output, [float(x) for x in args.cuts.split(',') if x]), indent=2))
