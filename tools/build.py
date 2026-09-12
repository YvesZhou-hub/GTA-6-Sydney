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
 if 'ERROR:' in log:
  raise RuntimeError(log[-4000:])
 if name=='bundle-smoke' and 'HARBOR_WORLD_READY' not in log:
  raise RuntimeError('Exported application did not finish assembling the city: '+log[-4000:])
run('import',[engine,'--headless','--path',root/'game','--editor','--import','--quit'])
def game_hashes():
 # The export preset contains a temporary absolute template path during export.
 # Its public/original bytes are the source identity, consistently in both checks.
 if preset.read_text() not in (text,original_preset):
  raise RuntimeError('Export preset changed during the build; refusing mismatched source identity.')
 return {str(f.relative_to(root)):hashlib.sha256(original_preset.encode() if f==preset else f.read_bytes()).hexdigest() for f in sorted((root/'game').rglob('*')) if f.is_file() and '.godot' not in f.parts}
build_sources=game_hashes()
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
 for name in ('LICENSE','PLAY_PERMISSION.md'):
  permission=root/name
  if permission.is_file(): shutil.copy2(permission,bundle/'Contents/Resources'/name)
 run('codesign',['codesign','--force','--deep','--sign','-',bundle])
 run('signature',['codesign','--verify','--deep','--strict',bundle])
 run('bundle-smoke',[binary,'--headless','--quit-after','15','--','--interactive-qa'])
 if game_hashes()!=build_sources:
  raise RuntimeError('Game source changed during export or smoke; refusing to package a mismatched PCK. Freeze edits and rebuild.')
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
 if game_hashes()!=build_sources:
  raise RuntimeError('Game source changed during packaging; rebuild before release.')
 report={'engine':subprocess.check_output([str(engine),'--version'],text=True).strip(),'app':str(dest),'architecture':'arm64','archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'app_identity':{'executable_sha256':hashlib.sha256((dest/'Contents/MacOS/Harbourlife').read_bytes()).hexdigest(),'pck_sha256':hashlib.sha256((dest/'Contents/Resources/Harbourlife.pck').read_bytes()).hexdigest()},'signature':'ad-hoc verified; not notarized','source_sha256':build_sources,'source_frozen_from':'after import, before export; checked again after smoke and ZIP packaging'}
 (reports/'build.json').write_text(json.dumps(report,indent=2))
 print('BUILT '+str(dest))
