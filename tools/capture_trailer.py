#!/usr/bin/env python3
"""Receive genuine Godot RGB frames over loopback and stream bounded shot MP4s.

No startup movie, frame-directory dump, user-save access, or gameplay simulation
in Python. Requires imageio_ffmpeg and Pillow (tools/runtime/video-env).
"""
from __future__ import annotations
import argparse
import hashlib
import json
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_PACKET = 1920 * 1080 * 3 + 65536


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def exact(sock: socket.socket, size: int) -> bytes:
    output = bytearray()
    while len(output) < size:
        chunk = sock.recv(min(size - len(output), 1024 * 1024))
        if not chunk:
            raise RuntimeError(f'Capture disconnected after {len(output)}/{size} bytes')
        output.extend(chunk)
    return bytes(output)


class Receiver:
    def __init__(self, output: Path, ffmpeg: str):
        self.output, self.ffmpeg = output, ffmpeg
        self.encoder = None
        self.shot = None
        self.frames = 0
        self.rows = []
        self.keyframes = []
        self.finished = False
        self.report = {'scope': 'Actual production Godot world; authored camera and automated gameplay inputs. Fixed-step 30fps capture, not a real-time performance claim.', 'audio': 'RGB transport is silent. Production fire/impact event frames are recorded for separate audio mixing.', 'shots': self.rows}

    def event(self, data: dict):
        event = data.get('event')
        if event == 'hello':
            if int(data['fps']) != 30 or (int(data['width']), int(data['height'])) not in [(960, 540), (1920, 1080)]:
                raise RuntimeError('Unsupported capture format')
            self.report['capture'] = data
        elif event == 'shot_begin':
            if self.encoder is not None:
                raise RuntimeError('Overlapping shots')
            name = data['id']
            if not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_' for c in name):
                raise RuntimeError('Unsafe shot ID')
            expected = int(data['frames'])
            if expected < 1 or expected > 210:
                raise RuntimeError('Shot exceeds seven-second bound')
            self.shot, self.frames = dict(data), 0
            self.shot['keyframes'] = []
            path = self.output / f'{name}.mp4'
            capture = self.report['capture']
            cmd = [self.ffmpeg, '-hide_banner', '-loglevel', 'error', '-n', '-f', 'rawvideo', '-pixel_format', 'rgb24', '-video_size', f"{capture['width']}x{capture['height']}", '-framerate', '30', '-i', 'pipe:0', '-an', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(path)]
            self.encoder = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=(self.output / f'{name}-encode.log').open('wb'))
        elif event == 'shot_end':
            if self.encoder is None or data['id'] != self.shot['id']:
                raise RuntimeError('Shot-end order mismatch')
            self.encoder.stdin.close()
            if self.encoder.wait(timeout=120) != 0:
                raise RuntimeError('FFmpeg encoding failed')
            self.encoder = None
            if self.frames != int(self.shot['frames']):
                raise RuntimeError('Frame count mismatch')
            self.shot.update(data)
            path = self.output / f"{self.shot['id']}.mp4"
            import imageio_ffmpeg
            decoded_frames, decoded_seconds = imageio_ffmpeg.count_frames_and_secs(str(path))
            if decoded_frames != self.frames or abs(decoded_seconds - self.frames / 30) > .04:
                raise RuntimeError('Decoded MP4 frame count/duration differ from received frames')
            self.shot.update({'file': path.name, 'sha256': digest(path), 'bytes': path.stat().st_size, 'frames_received': self.frames, 'decoded_frames': decoded_frames, 'decoded_seconds': decoded_seconds})
            self.rows.append(self.shot)
            self.shot = None
            self.save()
        elif event == 'complete':
            if self.encoder is not None:
                raise RuntimeError('Capture ended during shot')
            self.report['result'] = data
            self.finished = True
            self.save()
        elif event == 'shot_skip':
            self.report.setdefault('failed_shots', []).append(data)
            self.save()
        else:
            raise RuntimeError(f'Unknown event {event}')

    def frame(self, raw: bytes):
        from PIL import Image
        if self.encoder is None:
            raise RuntimeError('Frame outside shot')
        capture = self.report['capture']
        width, height = int(capture['width']), int(capture['height'])
        if len(raw) != width * height * 3 or self.frames >= int(self.shot['frames']):
            raise RuntimeError('Invalid frame dimensions/count')
        self.encoder.stdin.write(raw)
        # Three real keyframes per shot only; never retain the full raw sequence.
        if self.frames in [0, int(self.shot['frames']) // 2, int(self.shot['frames']) - 1]:
            name = f"{self.shot['id']}-{self.frames:04d}.jpg"
            image = Image.frombytes('RGB', (width, height), raw)
            image.thumbnail((960, 540))
            image.save(self.output / name, quality=91)
            self.shot['keyframes'].append(name)
            self.keyframes.append((name, self.shot['id'], self.frames))
        self.frames += 1

    def save(self):
        (self.output / 'capture-report.json').write_text(json.dumps(self.report, ensure_ascii=False, indent=2))

    def contact(self):
        from PIL import Image, ImageDraw
        if not self.keyframes:
            return
        sheet = Image.new('RGB', (960, 202 * ((len(self.keyframes) + 2) // 3)), '#151b23')
        draw = ImageDraw.Draw(sheet)
        for i, (name, label, frame) in enumerate(self.keyframes):
            picture = Image.open(self.output / name).convert('RGB').resize((320, 180))
            x, y = (i % 3) * 320, (i // 3) * 202
            sheet.paste(picture, (x, y))
            draw.text((x + 4, y + 183), f'{label} | {frame / 30:.2f}s', fill='white')
        sheet.save(self.output / 'contact-sheet.jpg', quality=94)


def main() -> int:
    import imageio_ffmpeg
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, help='Exported executable, not the .app directory')
    parser.add_argument('--godot', type=Path, default=ROOT / 'tools/runtime/godot')
    parser.add_argument('--output', type=Path, required=True, help='New empty capture directory')
    parser.add_argument('--preview', action='store_true', help='960x540, same genuine shot timing')
    parser.add_argument('--shots', default='', help='Comma-separated shot IDs for bounded retakes')
    parser.add_argument('--self-test', action='store_true', help='Tiny synthetic transport/encode test; never game evidence')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error('Output directory must be empty; existing captures are never overwritten')
    output.mkdir(parents=True, exist_ok=True)
    receiver = Receiver(output, imageio_ffmpeg.get_ffmpeg_exe())
    if args.self_test:
        receiver.event({'event': 'hello', 'fps': 30, 'width': 960, 'height': 540, 'synthetic_test_only': True})
        receiver.event({'event': 'shot_begin', 'id': 'transport_test', 'frames': 3})
        for shade in (32, 96, 160):
            receiver.frame(bytes([shade, shade, shade]) * (960 * 540))
        receiver.event({'event': 'shot_end', 'id': 'transport_test', 'passed': True})
        receiver.event({'event': 'complete', 'passed': True, 'synthetic_test_only': True})
        receiver.contact()
        print('TRAILER_TRANSPORT_TEST passed=true frames=3')
        return 0
    width, height = (960, 540) if args.preview else (1920, 1080)
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.bind(('127.0.0.1', 0))
        server.listen(1)
        server.settimeout(1)
        port = server.getsockname()[1]
        command = [str(args.app.resolve())] if args.app else [str(args.godot.resolve()), '--path', str(ROOT / 'game')]
        command += ['--fixed-fps', '30', '--disable-vsync', '--resolution', f'{width}x{height}', '--log-file', str(output / 'godot.log'), '--', '--trailer-capture', f'--trailer-port={port}']
        if args.preview:
            command.append('--trailer-preview')
        if args.shots:
            command.append(f'--trailer-shots={args.shots}')
        executable = Path(command[0])
        receiver.report['launch'] = {'executable_name': executable.name, 'executable_sha256': digest(executable), 'source_recorder_sha256': digest(ROOT / 'game/scripts/trailer_capture.gd'), 'preview': args.preview, 'fixed_fps': 30}
        pck = executable.parent.parent / 'Resources/Harbourlife.pck'
        if args.app and pck.exists():
            receiver.report['launch']['pck_sha256'] = digest(pck)
        process = subprocess.Popen(command, stdout=(output / 'launch.log').open('wb'), stderr=subprocess.STDOUT, cwd=ROOT)
        start = time.monotonic()
        try:
            while True:
                try:
                    connection, address = server.accept()
                    break
                except socket.timeout:
                    if process.poll() is not None:
                        raise RuntimeError(f'Game exited before opening capture stream (exit {process.returncode}); inspect godot.log')
                    if time.monotonic() - start > 600:
                        raise RuntimeError('Game did not connect within startup budget')
            if address[0] != '127.0.0.1':
                raise RuntimeError('Non-loopback connection rejected')
            with connection:
                connection.settimeout(180)
                while not receiver.finished:
                    packet, length = struct.unpack('!BI', exact(connection, 5))
                    if length > MAX_PACKET:
                        raise RuntimeError('Packet exceeds frame budget')
                    payload = exact(connection, length)
                    if packet == 1:
                        receiver.event(json.loads(payload))
                    elif packet == 2:
                        receiver.frame(payload)
                    else:
                        raise RuntimeError('Unknown packet type')
                    if time.monotonic() - start > 1800:
                        raise RuntimeError('Capture exceeded bounded thirty-minute wall time')
            if process.wait(timeout=60) != 0 or not receiver.report['result'].get('passed'):
                raise RuntimeError('Game capture failed; inspect preserved report/log')
            receiver.contact()
            receiver.report['elapsed_wall_seconds'] = time.monotonic() - start
            receiver.save()
            print(f'TRAILER_CAPTURE_COMPLETE shots={len(receiver.rows)} passed=true output={output}')
            return 0
        except Exception as error:
            receiver.report['error'] = str(error)
            receiver.save()
            receiver.contact()
            print(f'TRAILER_CAPTURE_FAILED {error}', file=sys.stderr)
            return 1
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
            if receiver.encoder is not None:
                receiver.encoder.kill()


if __name__ == '__main__':
    raise SystemExit(main())
