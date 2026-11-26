#!/usr/bin/env python3
"""Compile the real display implementation into a minimal UIKit simulator host."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import threading
import time
import secrets
import re
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / 'reports'
TRACE_LOCK = threading.Lock()
MARKERS = {'uikit-start.json': 'APP_STARTED', 'uikit-begin.json': 'TEST_BEGIN',
           'uikit-complete.json': 'TEST_DONE'}
EVIDENCE = tuple(MARKERS) + ('uikit-timeline.jsonl', 'numeric-keyboard-panel.png',
    'numeric-keyboard-visible.json', 'numeric-keyboard-captured.json', 'settings-layout.png', 'picker-visible.png',
    'picker-not-visible.png', 'picker-timeout.png')

def trace(event, **fields):
    record = dict(event=event, UTC=datetime.now(timezone.utc).isoformat(),
                  monotonic=time.monotonic(), **fields)
    with TRACE_LOCK:
        with (REPORTS / 'uikit-runner-timeline.jsonl').open('a') as stream:
            stream.write(json.dumps(record) + '\n')

def run(*args, timeout=180, stage=None):
    stage = stage or ' '.join(str(arg) for arg in args[:3])
    start = time.monotonic()
    trace('command_begin', stage=stage, timeout=timeout)
    try:
        process = subprocess.run(args, cwd=ROOT, check=False, text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    except subprocess.TimeoutExpired:
        trace('command_end', stage=stage, duration=time.monotonic()-start,
              returncode=None, outcome='timeout')
        raise
    except OSError as error:
        trace('command_end', stage=stage, duration=time.monotonic()-start,
              returncode=None, outcome=type(error).__name__)
        raise
    trace('command_end', stage=stage, duration=time.monotonic()-start,
          returncode=process.returncode)
    process.check_returncode()
    return process.stdout.strip()

def collect(data, partial=False):
    start = time.monotonic()
    trace('collection_begin')
    try:
        for name in EVIDENCE:
            source = data / 'Documents' / name
            if source.is_file():
                (REPORTS / name).write_bytes(source.read_bytes())
        source = data / 'Documents/uikit-report.txt'
        if source.is_file():
            (REPORTS / ('uikit-partial.txt' if partial else 'uikit-report.txt')).write_bytes(source.read_bytes())
    except OSError as error:
        trace('collection_end', duration=time.monotonic()-start, returncode=None,
              outcome=type(error).__name__)
        raise
    trace('collection_end', duration=time.monotonic()-start, returncode=0)

def launch_host(device, bundle, data, nonce):
    # Reject stale report/markers before the keyboard watcher or host can run.
    for name in EVIDENCE + ('uikit-report.txt',):
        (data / 'Documents' / name).unlink(missing_ok=True)
    capture_stop = threading.Event()
    def capture_keyboard():
        marker = data / 'Documents/numeric-keyboard-visible.json'
        while not capture_stop.wait(.05):
            if marker.is_file():
                try:
                    metadata = json.loads(marker.read_text())
                except (OSError, ValueError):
                    continue
                if metadata.get('nonce') != nonce:
                    continue
                success = False
                try:
                    screen = REPORTS / 'numeric-keyboard-screen.png'
                    run('xcrun', 'simctl', 'io', device, 'screenshot', str(screen), timeout=15,
                        stage='keyboard_screenshot')
                    success = screen.is_file() and screen.stat().st_size > 1000
                except Exception as error:
                    (REPORTS / 'numeric-keyboard-capture-error.txt').write_text(str(error))
                finally:
                    acknowledgment = data / 'Documents/numeric-keyboard-captured.json'
                    temporary = acknowledgment.with_suffix('.tmp')
                    temporary.write_text(json.dumps({'nonce': nonce, 'success': success, 'timeUTC': time.time()}))
                    temporary.replace(acknowledgment)
                    trace('keyboard_capture_acknowledged', success=success, nonce=nonce)
                return
    capture_thread = threading.Thread(target=capture_keyboard, daemon=True)
    capture_thread.start()
    process = None
    start = time.monotonic()
    seen = {}
    outcome = 'error'
    trace('launch_begin', nonce=nonce, startup_budget=90, test_budget=150,
          hard_budget=270, exit_budget=20)
    try:
        # Direct file descriptors avoid losing buffered console output on timeout.
        with (REPORTS / 'uikit-console.txt').open('w') as console:
            try:
                process = subprocess.Popen(
                    ['xcrun', 'simctl', 'launch', '--terminate-running-process', '--console', device, bundle],
                    cwd=ROOT, stdout=console, stderr=subprocess.STDOUT,
                    env={**os.environ, 'SIMCTL_CHILD_DOUYINDISC_TEST_NONCE': nonce})
                trace('launch_spawned', pid=process.pid)
                while True:
                    for filename, event in MARKERS.items():
                        if event in seen:
                            continue
                        try:
                            marker = json.loads((data / 'Documents' / filename).read_text())
                        except (OSError, ValueError):
                            continue
                        if not isinstance(marker, dict) or marker.get('nonce') != nonce or marker.get('event') != event:
                            continue
                        if event == 'TEST_DONE' and 'TEST_BEGIN' not in seen:
                            continue
                        seen[event] = time.monotonic()
                        trace('host_marker_observed', host_event=event, nonce=nonce,
                              host_timeUTC=marker.get('timeUTC'), checks=marker.get('checks'))
                    now = time.monotonic()
                    begin, done = seen.get('TEST_BEGIN'), seen.get('TEST_DONE')
                    reason = None
                    if now-start >= 270:
                        reason = 'overall_270s'
                    elif begin is None and now-start >= 90:
                        reason = 'startup_90s_without_TEST_BEGIN'
                    elif begin is not None and begin-start >= 90:
                        reason = 'startup_90s_before_TEST_BEGIN'
                    elif begin is not None and (done if done is not None else now)-begin >= 150:
                        reason = 'tests_150s_after_TEST_BEGIN'
                    elif done is not None and now-done >= 20 and process.poll() is None:
                        reason = 'console_exit_20s_after_TEST_DONE'
                    if reason:
                        outcome = reason
                        trace('launch_deadline', reason=reason, elapsed=now-start,
                              markers=list(seen), returncode=process.poll())
                        raise RuntimeError('UIKit host deadline exceeded: ' + reason)
                    returncode = process.poll()
                    if returncode is not None:
                        outcome = 'exited'
                        return returncode
                    capture_stop.wait(.05)
            finally:
                if process is not None and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
    finally:
        capture_stop.set()
        capture_thread.join(timeout=16)
        trace('launch_end', duration=time.monotonic()-start, outcome=outcome,
              returncode=process.poll() if process is not None else None)
        try:
            collect(data, partial=outcome != 'exited' or process.returncode != 0)
        except OSError:
            if outcome == 'exited' and process.returncode == 0:
                raise
        if outcome != 'exited':
            try:
                run('xcrun', 'simctl', 'io', device, 'screenshot',
                    str(REPORTS / 'uikit-timeout.png'), timeout=25, stage='failure_screenshot')
            except (OSError, subprocess.SubprocessError) as error:
                trace('failure_screenshot_error', error=type(error).__name__)

def main():
    REPORTS.mkdir(exist_ok=True)
    for name in EVIDENCE + ('uikit-report.txt', 'uikit-partial.txt', 'uikit-console.txt',
                           'uikit-timeout.png', 'numeric-keyboard-screen.png',
                           'numeric-keyboard-capture-error.txt', 'uikit-runner-timeline.jsonl'):
        (REPORTS / name).unlink(missing_ok=True)
    nonce = secrets.token_hex(16)
    trace('session_begin', nonce=nonce)
    result = REPORTS / 'uikit-report.txt'
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
                        MinimumOSVersion='15.0', LSRequiresIPhoneOS=True, UIDeviceFamily=[1], UILaunchScreen={}, NSPhotoLibraryUsageDescription='选择替换导航图标的照片')
            (app / 'Info.plist').write_bytes(plistlib.dumps(meta))
            sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
            run('xcrun', '--sdk', 'iphonesimulator', 'clang', '-target', 'arm64-apple-ios15.0-simulator',
                '-isysroot', sdk, '-fobjc-arc', '-DDOUYINDISC_UI_TEST=1', '-Wall', '-Wextra', '-framework', 'Foundation',
                '-framework', 'UIKit', '-framework', 'QuartzCore', '-framework', 'CoreGraphics',
                '-framework', 'ImageIO', '-framework', 'Photos',
                'tests/ui/DouyinDiscNativeHost.m', 'Sources/DouyinDiscPolicy.c',
                'Sources/DouyinDiscNavigationStore.m', 'Sources/DouyinDiscNavigation.m',
                '-o', str(app / 'DouyinDiscHost'), stage='compile')
            run('/usr/bin/codesign', '--force', '--sign', '-', str(app))
            if os.environ.get('GITHUB_ACTIONS') == 'true':
                run('/usr/bin/defaults', 'write', 'com.apple.iphonesimulator', 'ConnectHardwareKeyboard', '-bool', 'NO')
            run('xcrun', 'simctl', 'boot', device)
            run('xcrun', 'simctl', 'bootstatus', device, '-b', timeout=300)
            run('xcrun', 'simctl', 'install', device, str(app))
            run('xcrun', 'simctl', 'privacy', device, 'grant', 'photos', bundle)
            data = Path(run('xcrun', 'simctl', 'get_app_container', device, bundle, 'data'))
            returncode = launch_host(device, bundle, data, nonce)
            source = data / 'Documents/uikit-report.txt'
            if not source.is_file():
                raise RuntimeError('UIKit host did not produce its completion report; see uikit-console.txt')
            text = source.read_text()
            result.write_text(text)
            print(text)
            lines = [line for line in text.splitlines() if line.startswith('UIKit host: ')]
            summary = re.fullmatch(r'UIKit host: ([1-9][0-9]*) checks, 0 failures', lines[0]) if len(lines) == 1 else None
            passed = sum(line.startswith('PASS: ') for line in text.splitlines())
            if returncode != 0 or 'FAIL:' in text or not summary or passed != int(summary[1]):
                raise RuntimeError('UIKit host checks failed or incomplete')
    finally:
        for operation in ('shutdown', 'delete'):
            try:
                run('xcrun', 'simctl', operation, device, timeout=30, stage='cleanup_' + operation)
            except (OSError, subprocess.SubprocessError) as error:
                trace('cleanup_error', stage=operation, error=type(error).__name__)

if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stdout)
        print(error.stderr)
        raise
