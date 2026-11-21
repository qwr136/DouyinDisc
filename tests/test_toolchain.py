"""Native shared-toolchain branch tests; synthetic bytes, no build or device."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

from test_verify_dylib import specimen

PROJECT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('trollfools_shared_gate', PROJECT/'scripts/toolchain.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
META = json.loads((PROJECT/'tweak.json').read_text())
LOCK = json.loads((PROJECT/'toolchain-lock.json').read_text())


class NativeToolchainTests(unittest.TestCase):
    def test_verify_never_checks_deb_packaging_or_make(self):
        with mock.patch.object(gate, 'verify_platform', return_value={'fixture': 'host'}), \
             mock.patch.object(gate, 'verify_sources', return_value={'fixture': 'sources'}), \
             mock.patch.object(gate, 'verify_packaging') as packaging, \
             mock.patch.object(gate.shutil, 'which') as which:
            evidence = gate.verify(PROJECT, LOCK)
        packaging.assert_not_called()
        which.assert_not_called()
        self.assertEqual(evidence['packaging']['status'], 'not-required')
        self.assertEqual(evidence['sources'], {'fixture': 'sources'})

    def test_prepare_never_installs_deb_tools(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            native = root/'project'
            native.mkdir()
            (native/'tweak.json').write_text(json.dumps(META))
            theos, sdks = root/'theos', root/'sdks'
            with mock.patch.object(gate, 'verify_platform'), \
                 mock.patch.object(gate, 'locations', return_value=(root, theos, sdks)), \
                 mock.patch.object(gate, 'checkout'), mock.patch.object(gate, 'run'), \
                 mock.patch.object(gate, 'verify_sources'), \
                 mock.patch.object(gate, 'install_packaging') as installer:
                gate.prepare(native, LOCK)
            installer.assert_not_called()
            self.assertTrue((theos/'sdks'/LOCK['sdk']['directory']).is_symlink())

    def test_receipt_inspects_this_library_and_excludes_secrets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'artifacts').mkdir()
            (root/'tests').mkdir()
            (root/'tweak.json').write_text(json.dumps(META))
            shutil.copyfile(PROJECT/'tests/verify_dylib.py', root/'tests/verify_dylib.py')
            artifact = root/'artifacts'/(META['name']+'.dylib')
            artifact.write_bytes(specimen())
            report = root/'receipt.json'
            env = {'GITHUB_RUN_ID': '44', 'GITHUB_RUN_ATTEMPT': '2',
                   'GITHUB_REPOSITORY': 'fixture/native', 'GITHUB_TOKEN': 'never-serialize-this'}
            with mock.patch.object(gate, 'verify', return_value={'status': 'verified'}), \
                 mock.patch.object(gate, 'run', return_value='a'*40), \
                 mock.patch.dict(os.environ, env):
                gate.receipt(root, LOCK, report)
            text = report.read_text()
            result = json.loads(text)
            self.assertNotIn('never-serialize-this', text)
            self.assertEqual(result['target_type'], 'dylib')
            self.assertEqual(result['packages'], [])
            self.assertEqual(result['run_attempt'], '2')
            self.assertEqual(result['artifacts'][0]['architecture'], 'arm64')
            self.assertEqual(result['artifacts'][0]['filename'], artifact.name)
            with (root/'artifacts/Other.dylib').open('wb') as output:
                output.write(specimen())
            with mock.patch.object(gate, 'verify', return_value={'status': 'verified'}), \
                 mock.patch.object(gate, 'run', return_value='a'*40):
                with self.assertRaisesRegex(ValueError, 'exactly this project'):
                    gate.receipt(root, LOCK, root/'must-not-exist.json')
            self.assertFalse((root/'must-not-exist.json').exists())
