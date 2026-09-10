#!/usr/bin/env python3
"""Encode delivery-app frames and independently verify decoded video durations."""
from pathlib import Path
import subprocess
import imageio_ffmpeg
import json
import hashlib
root=Path(__file__).resolve().parent.parent
folder=root/'reports/video'
flight=json.loads((root/'reports/flight/flight-report.json').read_text())
shots={row['stage']:row for row in flight['screenshots']}
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
common=['-c:v','libx264','-preset','fast','-crf','24','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart']
origin=max(0.0,shots['01_runway_parked']['movie_time_s']-0.5)
end=shots['07_stopped']['movie_time_s']+1.0
subprocess.run([ffmpeg,'-hide_banner','-loglevel','warning','-y','-ss',str(origin),'-i',str(folder/'airport-harbour-flight.avi'),'-t',str(end-origin),*common,str(folder/'airport-harbour-flight.mp4')],check=True)
# Explicit edited highlights; preserve captured playback speed inside each shot.
segments=[]
cuts=[(0.0,3.0)]
for name,before,after in [('02_takeoff',8,12),('03_harbour',4,8),('04_bridge',4,8),('06_touchdown',8,18),('07_stopped',3,0.8)]:
 at=shots[name]['movie_time_s']-origin
 cuts.append((max(0.0,at-before),min(end-origin,at+after)))
for i,(start,stop) in enumerate(cuts):
 out=folder/f'.shot-{i}.mp4'; segments.append(out)
 subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-ss',str(start),'-i',str(folder/'airport-harbour-flight.mp4'),'-t',str(stop-start),*common,str(out)],check=True)
concat=folder/'.shots.txt'
concat.write_text(''.join("file '"+p.name+"'\n" for p in segments))
subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(folder/'flight-highlights.mp4')],check=True)
for item in segments+[concat]: item.unlink()
media={'source':'Native delivery app MovieWriter; no external images/audio','playback':'Fixed-step rendered capture; not a real-time performance benchmark','full_trim_from_raw_s':[origin,end],'highlights_cuts_s':cuts,'files':{}}
for name in ['airport-harbour-flight.mp4','flight-highlights.mp4']:
 path=folder/name
 frames,seconds=imageio_ffmpeg.count_frames_and_secs(str(path))
 header=subprocess.run([ffmpeg,'-hide_banner','-i',str(path)],capture_output=True,text=True).stderr
 media['files'][name]={'frames':frames,'duration_s':seconds,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'probe':header}
(folder/'media.json').write_text(json.dumps(media,ensure_ascii=False,indent=2))
print(json.dumps(media,ensure_ascii=False,indent=2))
