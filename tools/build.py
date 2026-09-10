#!/usr/bin/env python3
"""Offline native build. Staging avoids macOS File Provider metadata in Documents."""
import json,os,pathlib,plistlib,shutil,subprocess,tempfile,zipfile,hashlib,atexit
root=pathlib.Path(__file__).resolve().parent.parent
engine=root/'tools/runtime/godot'
template=root/'tools/runtime/templates/macos.zip'
if not engine.is_file() or not template.is_file():
 raise SystemExit('Missing Godot toolchain. See README: install the official Godot 4.7.2 executable and its macOS export template at tools/runtime/.')
output=pathlib.Path(os.environ.get('HARBOURLIFE_BUILD_DIR',str(pathlib.Path.home()/'Library/Application Support/Harbourlife/builds'))).resolve()
dist=pathlib.Path(os.environ.get('HARBOURLIFE_DIST_DIR',str(root/'dist'))).resolve()
reports=pathlib.Path(os.environ.get('HARBOURLIFE_REPORT_DIR',str(root/'reports'))).resolve()
output.mkdir(parents=True,exist_ok=True)
reports.mkdir(parents=True,exist_ok=True)
dist.mkdir(parents=True,exist_ok=True)
preset=root/'game/export_presets.cfg'
original_preset=preset.read_text()
text=original_preset
atexit.register(lambda: preset.write_text(original_preset))
import re
text=re.sub(r'custom_template/(debug|release)="[^"]*"',lambda m:'custom_template/'+m.group(1)+'="'+str(root/'tools/runtime/templates/macos.zip')+'"',text)
preset.write_text(text)
def run(name,args):
 with (reports/f'{name}.log').open('w') as f:
  subprocess.run([str(x) for x in args],stdout=f,stderr=subprocess.STDOUT,check=True)
 log=(reports/f'{name}.log').read_text()
 if 'SCRIPT ERROR:' in log or (name=='export' and 'ERROR:' in log):
  raise RuntimeError(log[-4000:])
 if name=='bundle-smoke' and 'HARBOR_WORLD_READY' not in log:
  raise RuntimeError('Exported application did not finish assembling the city: '+log[-4000:])
run('import',[engine,'--headless','--path',root/'game','--editor','--import','--quit'])
with tempfile.TemporaryDirectory(prefix='.staging-',dir=output) as stage:
 bundle=pathlib.Path(stage)/'Harbourlife.app'
 run('export',[engine,'--headless','--path',root/'game','--export-release','macOS Local',bundle])
 info_path=bundle/'Contents/Info.plist'
 info=plistlib.loads(info_path.read_bytes())
 original=info['CFBundleExecutable']
 binary=bundle/'Contents/MacOS'/original
 binary.rename(binary.with_name('Harbourlife'))
 binary=binary.with_name('Harbourlife')
 for pck in (bundle/'Contents/Resources').glob('*.pck'): pck.rename(pck.with_name('Harbourlife.pck'))
 info['CFBundleExecutable']='Harbourlife'
 info['CFBundleName']='Harbourlife'
 info_path.write_bytes(plistlib.dumps(info))
 if 'x86_64' in subprocess.check_output(['lipo','-archs',str(binary)],text=True):
  subprocess.run(['lipo',str(binary),'-thin','arm64','-output',str(binary)+'.arm64'],check=True)
  os.replace(str(binary)+'.arm64',binary)
 binary.chmod(0o755)
 shutil.copytree(root/'licenses',bundle/'Contents/Resources/licenses',dirs_exist_ok=True)
 permission=root/'PLAY_PERMISSION.md'
 if permission.is_file(): shutil.copy2(permission,bundle/'Contents/Resources/PLAY_PERMISSION.md')
 run('codesign',['codesign','--force','--deep','--sign','-',bundle])
 run('signature',['codesign','--verify','--deep','--strict',bundle])
 run('bundle-smoke',[binary,'--headless','--quit-after','15'])
 dest=output/'Harbourlife.app'
 if dest.exists(): shutil.rmtree(dest)
 shutil.move(bundle,dest)
 link=dist/'Harbourlife.app'
 if link.is_symlink(): link.unlink()
 elif link.exists(): shutil.rmtree(link)
 link.symlink_to(dest,target_is_directory=True)
 archive=dist/'Harbourlife-macOS-arm64.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for f in sorted(dest.rglob('*')):
   if f.is_file(): z.write(f,pathlib.Path('Harbourlife.app')/f.relative_to(dest))
 preset.write_text(original_preset)
 report={'engine':subprocess.check_output([str(engine),'--version'],text=True).strip(),'app':str(dest),'architecture':'arm64','archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'signature':'ad-hoc verified; not notarized','source_sha256':{str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted((root/'game').rglob('*')) if f.is_file() and '.godot' not in f.parts}}
 (reports/'build.json').write_text(json.dumps(report,indent=2))
 print('BUILT '+str(dest))
