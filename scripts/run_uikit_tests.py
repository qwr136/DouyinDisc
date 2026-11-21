#!/usr/bin/env python3
"""Compile the real display implementation into a minimal UIKit simulator host."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / 'reports'

def run(*args, timeout=180):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=timeout).stdout.strip()

def main():
    REPORTS.mkdir(exist_ok=True)
    result = REPORTS / 'uikit-report.txt'
    result.unlink(missing_ok=True)
    runtimes = json.loads(run('xcrun', 'simctl', 'list', 'runtimes', '-j'))['runtimes']
    runtime = next((r['identifier'] for r in runtimes if r.get('isAvailable') and r.get('version') == '18.5' and 'iOS' in r['identifier']), None)
    if not runtime:
        raise RuntimeError('the selected Xcode must have the iOS 18.5 simulator runtime')
    bundle = 'com.minis.douyindisc.uitest'
    device = run('xcrun', 'simctl', 'create', 'DouyinDisc-' + os.environ.get('GITHUB_RUN_ID', 'local'),
                 'com.apple.CoreSimulator.SimDeviceType.iPhone-16', runtime)
    try:
        with tempfile.TemporaryDirectory() as work:
            app = Path(work) / 'DouyinDiscHost.app'
            app.mkdir()
            meta = dict(CFBundleIdentifier=bundle, CFBundleName='DouyinDiscHost', CFBundleExecutable='DouyinDiscHost',
                        CFBundlePackageType='APPL', CFBundleVersion='1', CFBundleShortVersionString='1.0',
                        MinimumOSVersion='15.0', LSRequiresIPhoneOS=True, UIDeviceFamily=[1], UILaunchScreen={})
            (app / 'Info.plist').write_bytes(plistlib.dumps(meta))
            sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
            run('xcrun', '--sdk', 'iphonesimulator', 'clang', '-target', 'arm64-apple-ios15.0-simulator',
                '-isysroot', sdk, '-fobjc-arc', '-Wall', '-Wextra', '-framework', 'Foundation',
                '-framework', 'UIKit', '-framework', 'QuartzCore', '-framework', 'CoreGraphics',
                'tests/ui/DouyinDiscNativeHost.m', 'Sources/DouyinDiscPolicy.c', '-o', str(app / 'DouyinDiscHost'))
            run('/usr/bin/codesign', '--force', '--sign', '-', str(app))
            run('xcrun', 'simctl', 'boot', device)
            run('xcrun', 'simctl', 'bootstatus', device, '-b', timeout=300)
            run('xcrun', 'simctl', 'install', device, str(app))
            try:
                process = subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process', '--console', device, bundle],
                                         cwd=ROOT, capture_output=True, text=True, timeout=150)
            except subprocess.TimeoutExpired as error:
                def text(value):
                    return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else (value or '')
                (REPORTS / 'uikit-console.txt').write_text(text(error.stdout) + '\n' + text(error.stderr))
                data = Path(run('xcrun', 'simctl', 'get_app_container', device, bundle, 'data'))
                partial = data / 'Documents/uikit-report.txt'
                if partial.is_file():
                    (REPORTS / 'uikit-partial.txt').write_bytes(partial.read_bytes())
                    print(partial.read_text(), flush=True)
                subprocess.run(['xcrun', 'simctl', 'io', device, 'screenshot', str(REPORTS / 'uikit-timeout.png')],
                               capture_output=True, timeout=25)
                print((REPORTS / 'uikit-console.txt').read_text()[-24000:], flush=True)
                raise RuntimeError('UIKit host timed out; partial report and console retained') from error
            (REPORTS / 'uikit-console.txt').write_text(process.stdout + '\n' + process.stderr)
            data = Path(run('xcrun', 'simctl', 'get_app_container', device, bundle, 'data'))
            source = data / 'Documents/uikit-report.txt'
            if not source.is_file():
                raise RuntimeError('UIKit host did not produce its completion report; see uikit-console.txt')
            text = source.read_text()
            result.write_text(text)
            print(text)
            if process.returncode or 'FAIL:' in text or '61 checks, 0 failures' not in text:
                raise RuntimeError('UIKit host checks failed or incomplete')
    finally:
        subprocess.run(['xcrun', 'simctl', 'shutdown', device], capture_output=True)
        subprocess.run(['xcrun', 'simctl', 'delete', device], capture_output=True)

if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stdout)
        print(error.stderr)
        raise
