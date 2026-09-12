#!/usr/bin/env python3
"""Edit actual captured Harbourlife shots, typography and original music.

Run with tools/runtime/video-env/bin/python. Never invent gameplay footage.
Only accepted captures are permitted; source frame counts and IDs are retained.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import wave
import numpy as np
import imageio_ffmpeg
from promo_score import create as create_score

ROOT = Path(__file__).resolve().parents[1]
FF = imageio_ffmpeg.get_ffmpeg_exe()
FONTDIR = ROOT / 'game/assets/fonts'
COPY = {
    '01_tank_impact': ('我把悉尼，做成了开放世界', '坦克开火 · 建筑可以被破坏'),
    '02_harbour_hero': ('认出这里了吗？', '悉尼歌剧院 × 海港大桥'),
    '03_street_drive': ('想开就开，载具全部免费', '超跑、摩托、游艇、反重力平衡车……'),
    '04_fighter_rocket': ('这次，直接飞过去', '驾驶战斗机 · 发射火箭'),
    '05_opera_steps': ('从天上，回到街头', '走上歌剧院台阶，探索海港'),
    '06_public_interior': ('有些地方，可以走进去', '公共空间持续制作中'),
    '07_summer_sunset': ('把时间，停在喜欢的那一刻', '夏季日出日落 · 自由调整时间'),
}


def run(args, log):
    result = subprocess.run([FF, '-hide_banner', '-loglevel', 'error', '-y', *map(str, args)], capture_output=True, text=True)
    log.write_text(result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr[-4000:])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ass_time(t):
    centis = round(t * 100)
    return f'{centis // 360000}:{centis // 6000 % 60:02d}:{centis // 100 % 60:02d}.{centis % 100:02d}'


def subtitle_file(path, segments, seconds, teaser=False):
    header = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Title,Noto Sans CJK SC,72,&H00F2F5F4,&H00FFFFFF,&H80201711,&HAA000000,-1,0,0,0,100,100,0,0,1,3,2,1,100,100,120,1
Style: Sub,Noto Sans CJK SC,34,&H00E7E9E6,&H00FFFFFF,&H80201711,&HAA000000,0,0,0,0,100,100,0,0,1,2,1,1,104,100,70,1
Style: Brand,Noto Sans CJK SC,26,&H00EDF6F3,&H00FFFFFF,&H8018100B,&HAA000000,-1,0,0,0,100,100,2,0,1,1.6,1,7,72,72,52,1
Style: CTA,Noto Sans CJK SC,84,&H00F2F6F4,&H00FFFFFF,&H70140E08,&HAA000000,-1,0,0,0,100,100,0,0,1,3,2,5,100,100,100,1
Style: Small,Noto Sans CJK SC,32,&H00D6DED9,&H00FFFFFF,&H90140E08,&HAA000000,0,0,0,0,100,100,0,0,1,1.5,1,5,100,100,100,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    lines = [header]
    def event(start, end, style, text, tags=''):
        if end > start:
            lines.append(f'Dialogue: 0,{ass_time(start)},{ass_time(end)},{style},,0,0,0,,{{\\fad(90,100){tags}}}{text}\n')
    event(0, seconds, 'Brand', 'HARBOURLIFE   /   悉尼海港 · 实机录制')
    for segment in segments:
        start, end = segment['output_start'], segment['output_end']
        title, sub = COPY[segment['id']]
        if teaser and segment is segments[0]:
            title, sub = '在悉尼开坦克，是什么体验？', '一个正在开发的开放世界游戏'
        if segment is segments[-1]:
            end = min(end, seconds - 3.0)
        event(start + .10, end - .08, 'Title', title, r'\pos(100,915)')
        event(start + .12, end - .08, 'Sub', sub, r'\pos(104,978)')
    event(seconds - 3.0, seconds, 'CTA', '关注我，评论「悉尼」领试玩', r'\pos(960,493)')
    event(seconds - 2.9, seconds, 'Small', 'HARBOURLIFE · macOS 试玩版 · 一起把这座城造完', r'\pos(960,590)')
    path.write_text(''.join(lines), encoding='utf-8-sig')


def load_wav(path):
    with wave.open(str(path), 'rb') as wav:
        assert wav.getsampwidth() == 2
        rate, channels = wav.getframerate(), wav.getnchannels()
        a = np.frombuffer(wav.readframes(wav.getnframes()), '<i2').astype(float) / 32768
        a = a.reshape(-1, channels)
    if channels == 1:
        a = np.repeat(a, 2, axis=1)
    if rate != 48000:
        x = np.arange(len(a) * 48000 // rate) * rate / 48000
        a = np.stack([np.interp(x, np.arange(len(a)), a[:, ch]) for ch in (0, 1)], axis=1)
    return a


def soundtrack(output, segments, seconds):
    music_path = output / 'original-score.wav'
    create_score(seconds, music_path, [s['output_start'] for s in segments[1:]])
    mix = load_wav(music_path) * .72
    sounds = {kind: load_wav(ROOT / 'reports/promo-audio' / (kind + '.wav')) for kind in ('tank', 'fighter', 'impact')}
    cues = []
    for segment in segments:
        for ev in segment['events']:
            if ev['event'] not in ('fire', 'impact'):
                continue
            at = ev.get('time_s', ev['frame'] / 30)
            if not segment['source_start'] <= at < segment['source_end']:
                continue
            kind = ev.get('kind', 'tank') if ev['event'] == 'fire' else 'impact'
            start = round((segment['output_start'] + at - segment['source_start']) * 48000)
            sound = sounds[kind]
            count = min(len(sound), len(mix) - start)
            if start < 0 or count <= 0:
                continue
            mix[start:start + count] += sound[:count] * (.82 if kind == 'impact' else .92)
            cues.append({'kind': kind, 'output_time_s': start / 48000, 'source_shot': segment['id'], 'production_event': ev})
    mix = np.tanh(mix * 1.12) * .87
    with wave.open(str(output / 'mixed-source.wav'), 'wb') as wav:
        wav.setparams((2, 2, 48000, len(mix), 'NONE', 'not compressed'))
        wav.writeframes((mix * 32767).astype('<i2').tobytes())
    return cues


def edit(capture, output, teaser=False):
    report = json.loads((capture / 'capture-report.json').read_text())
    assert report['result']['passed'] and not report['capture'].get('synthetic_test_only')
    assert report['capture']['width'] == 1920 and report['capture']['height'] == 1080
    assert report['capture']['fps'] == 30
    rows = {row['id']: row for row in report['shots']}
    selected = list(COPY) if not teaser else ['01_tank_impact', '04_fighter_rocket', '02_harbour_hero', '07_summer_sunset']
    output.mkdir(parents=True, exist_ok=False)
    segments, elapsed = [], 0.0
    for index, key in enumerate(selected):
        row = rows[key]
        assert row['passed'] and row['sha256'] == sha(capture / row['file'])
        start, end = 0., row['frames_received'] / 30
        if teaser:
            end = min(end, [4., 4., 3.5, 5.][index])
        segment = {'id': key, 'source_file': row['file'], 'source_sha256': row['sha256'], 'source_start': start, 'source_end': end,
                   'output_start': elapsed, 'output_end': elapsed + end - start, 'events': row.get('events', [])}
        elapsed = segment['output_end']
        target = output / f'part-{index:02d}.mp4'
        run(['-i', capture / row['file'], '-ss', start, '-t', end - start, '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '17', '-pix_fmt', 'yuv420p', target], output / f'encode-{index:02d}.log')
        segments.append(segment)
    concat = output / 'parts.txt'
    concat.write_text(''.join(f"file 'part-{index:02d}.mp4'\n" for index in range(len(segments))))
    subtitle_file(output / 'captions.ass', segments, elapsed, teaser)
    cues = soundtrack(output, segments, elapsed)
    title = 'Harbourlife-悉尼开放世界-横屏预告.mp4' if not teaser else 'Harbourlife-坦克钩子-短版.mp4'
    target = output / title
    # All paths are local; no shell interpolation. Current work path has no ':'/apostrophe.
    ass = str(output / 'captions.ass').replace('\\', '/')
    fonts = str(FONTDIR).replace('\\', '/')
    run(['-f', 'concat', '-safe', '0', '-i', concat, '-i', output / 'mixed-source.wav',
         '-vf', f"ass=filename='{ass}':fontsdir='{fonts}'", '-af', 'loudnorm=I=-14:TP=-3.5:LRA=9,aresample=48000,alimiter=limit=0.70:level=false:latency=true',
         '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', '30',
         '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-movflags', '+faststart', '-t', elapsed, target], output / 'final-encode.log')
    frames, duration = imageio_ffmpeg.count_frames_and_secs(str(target))
    assert abs(duration - elapsed) < .05 and frames == round(elapsed * 30)
    reader = imageio_ffmpeg.read_frames(str(target))
    metadata = next(reader)
    reader.close()
    assert tuple(metadata['size']) == (1920, 1080) and abs(metadata['fps'] - 30) < .001
    probe = subprocess.run([FF, '-hide_banner', '-i', str(target)], capture_output=True, text=True).stderr
    audio_probe = [line.strip() for line in probe.splitlines() if 'Audio:' in line]
    assert len(audio_probe) == 1 and 'aac' in audio_probe[0] and '48000 Hz' in audio_probe[0] and 'stereo' in audio_probe[0]
    decode = subprocess.run([FF, '-hide_banner', '-v', 'error', '-i', str(target), '-f', 'null', '-'], capture_output=True, text=True)
    assert decode.returncode == 0 and not decode.stderr.strip()
    loudness = subprocess.run([FF, '-hide_banner', '-i', str(target), '-af',
                               'loudnorm=I=-14:TP=-1.5:LRA=9:print_format=json', '-vn', '-f', 'null', '-'],
                              capture_output=True, text=True)
    assert loudness.returncode == 0
    (output / 'decoded-loudness.log').write_text(loudness.stderr)
    measured = json.loads(re.search(r'\{\s*"input_i".*?\}', loudness.stderr, re.S)[0])
    assert float(measured['input_tp']) <= -1.0, 'Decoded AAC exceeds true-peak safety margin'
    sound_paths = [ROOT / 'reports/promo-audio' / (kind + '.wav') for kind in ('tank', 'fighter', 'impact')]
    sound_paths += [ROOT / 'game/scripts/weapon_audio.gd', ROOT / 'tools/promo_score.py', ROOT / 'tools/promo_audio_export.gd',
                    output / 'original-score.wav', output / 'mixed-source.wav']
    proof = {'file': target.name, 'sha256': sha(target), 'bytes': target.stat().st_size, 'width': metadata['size'][0], 'height': metadata['size'][1],
             'frames': frames, 'seconds': duration, 'fps': metadata['fps'], 'decoded_metadata': metadata, 'audio_probe': audio_probe, 'decoded_loudness': measured,
             'audio_source_sha256': {str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else path.name: sha(path) for path in sound_paths},
             'editor_sha256': sha(Path(__file__)), 'capture_launch': report['launch'],
             'capture_report_sha256': sha(capture / 'capture-report.json'), 'segments': segments, 'audio_cues': cues,
             'visuals': 'Actual rendered game frames; subtitles/brand only. No generated replacement footage. Automated inputs and authored camera; not a real-time performance benchmark.',
             'audio': 'Original synthesized score plus production weapon samples aligned to actual recorded events; editorial audio mix, not live mixer capture.',
             'decode_passed': True, 'views': 'Not published to Douyin or measured; no view-count claim.'}
    (output / 'video-verification.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: proof[k] for k in ('file', 'frames', 'seconds', 'sha256', 'bytes')}, ensure_ascii=False))
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--teaser', action='store_true')
    args = parser.parse_args()
    edit(args.capture.resolve(), args.output.resolve(), args.teaser)
