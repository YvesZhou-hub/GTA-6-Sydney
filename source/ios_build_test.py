"""Packaging guard checks; these do not claim device or graphics validation."""
import importlib.util
import contextlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
import types
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('build_ios', ROOT / 'tools/build_ios.py')
build = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build)


class IOSBuildGuards(unittest.TestCase):
    def test_metadata_cleanup_refuses_original_sources(self):
        for path in [ROOT, ROOT / 'game', ROOT / 'game/assets', ROOT / 'licenses']:
            with self.assertRaisesRegex(RuntimeError, 'original sources'):
                build.clean_generated_xattrs(path)

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS extended attribute regression')
    def test_cleanup_removes_only_signing_blockers(self):
        with tempfile.TemporaryDirectory(prefix='ios-xattr-test-') as tmp:
            folder = pathlib.Path(tmp)
            app = folder / 'Example.app'
            storyboard = app / 'Launch Screen.storyboardc'
            storyboard.mkdir(parents=True)
            payload = app / 'data.txt'
            payload.write_text('keep file contents')
            before = build.file_hashes(app)
            subprocess.run(['xattr', '-wx', 'com.apple.FinderInfo', '00' * 31 + '01', str(storyboard)], check=True)
            subprocess.run(['xattr', '-w', 'com.apple.ResourceFork', 'old resource data', str(payload)], check=True)
            subprocess.run(['xattr', '-w', 'com.harbourlife.test', 'keep me', str(payload)], check=True)
            build.clean_generated_xattrs(app)
            self.assertEqual(before, build.file_hashes(app))
            self.assertNotIn('com.apple.FinderInfo', subprocess.check_output(['xattr', str(storyboard)], text=True))
            self.assertNotIn('com.apple.ResourceFork', subprocess.check_output(['xattr', str(payload)], text=True))
            self.assertEqual(subprocess.check_output(['xattr', '-p', 'com.harbourlife.test', str(payload)], text=True).strip(), 'keep me')

    def test_untrusted_archive_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = pathlib.Path(tmp)
            archive = folder / 'corrupt.tpz'
            archive.write_bytes(b'not the official archive')
            template = folder / 'ios.zip'
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                build.ensure_template(template, archive=archive)
            self.assertFalse(template.exists())

    def test_changed_cached_template_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = pathlib.Path(tmp)
            template = folder / 'ios.zip'
            template.write_bytes(b'modified')
            (folder / 'ios-template.json').write_text(json.dumps({
                'archive_sha256': build.ARCHIVE_SHA256,
                'archive_sha512': build.ARCHIVE_SHA512, 'ios_sha256': 'old'}))
            with self.assertRaisesRegex(RuntimeError, 'receipt does not match'):
                build.ensure_template(template)

    def test_unsigned_build_never_provisions_or_signs(self):
        args = types.SimpleNamespace(configuration='Release', sign=False)
        command = build.xcode_command('App.xcodeproj', 'DerivedData', args)
        self.assertIn('CODE_SIGNING_ALLOWED=NO', command)
        self.assertIn('CODE_SIGNING_REQUIRED=NO', command)
        self.assertIn('generic/platform=iOS', command)
        self.assertNotIn('-allowProvisioningUpdates', command)
        self.assertNotIn('-allowProvisioningDeviceRegistration', command)

    def test_signed_build_requires_explicit_team(self):
        with self.assertRaises(SystemExit) as result, contextlib.redirect_stderr(io.StringIO()):
            build.main(['--sign'])
        self.assertEqual(result.exception.code, 2)

    def test_placeholder_is_removed_without_changing_real_team(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = pathlib.Path(tmp)
            project = folder / 'Harbourlife.xcodeproj/project.pbxproj'
            project.parent.mkdir()
            project.write_text('DEVELOPMENT_TEAM = 0000000000;\nDEVELOPMENT_TEAM = ABCDE12345;\n')
            plist = folder / 'export_options.plist'
            with plist.open('wb') as stream:
                build.plistlib.dump({'teamID': build.UNSIGNED_TEAM, 'method': 'development'}, stream)
            build.clear_placeholder_team(folder)
            self.assertNotIn(build.UNSIGNED_TEAM, project.read_text())
            self.assertIn('ABCDE12345', project.read_text())
            with plist.open('rb') as stream:
                self.assertEqual(build.plistlib.load(stream), {'method': 'development'})


if __name__ == '__main__':
    unittest.main()
