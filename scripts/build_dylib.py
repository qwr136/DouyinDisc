#!/usr/bin/env python3
"""Build and inspect a single signed iOS device dylib."""

import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
NAME = 'DouyinDisc'
IDENTIFIER = 'com.minis.douyindisc'
FRAMEWORKS = ('Foundation', 'UIKit', 'QuartzCore', 'CoreGraphics', 'ImageIO', 'UniformTypeIdentifiers')
SOURCE_FILES = ('Sources/DouyinDiscEntry.m', 'Sources/DouyinDiscPolicy.c', 'Sources/DouyinDiscNativeDisplay.m', 'Sources/DouyinDiscNavigationStore.m', 'Sources/DouyinDiscNavigation.m', 'Sources/DouyinDiscNavigationHooks.m')
SDK_DIR = 'iPhoneOS16.5.sdk'
TARGET = 'arm64-apple-ios15.0'


def build():
    artifacts = ROOT / 'artifacts'
    if artifacts.is_symlink():
        raise ValueError('refusing a symlink at artifacts/')
    output = artifacts / (NAME + '.dylib')
    output.unlink(missing_ok=True)

    env = os.environ.copy()
    for key in ('SDKROOT', 'CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'OBJC_INCLUDE_PATH',
                'LIBRARY_PATH', 'CCC_OVERRIDE_OPTIONS', 'TOOLCHAINS'):
        env.pop(key, None)
    root = Path(env.get('TOOLCHAIN_ROOT') or '/tmp/xiaofei-toolchain')
    theos = Path(env.get('THEOS') or root / 'theos')
    env['THEOS'] = str(theos)

    def run(*args):
        subprocess.run(args, cwd=ROOT, env=env, check=True)

    # The shell wrapper gates its own entry; direct invocation must not bypass verify.
    run(sys.executable, 'scripts/toolchain.py', 'verify', '--output', 'reports/local-toolchain.json')
    sdk = theos / 'sdks' / SDK_DIR
    if not (ROOT / sdk).is_dir():
        raise ValueError('locked SDK missing: ' + str(sdk))

    artifacts.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.build.', dir=artifacts) as work:
        staged = Path(work) / output.name
        run('/usr/bin/xcrun', '--sdk', 'iphoneos', 'clang',
            '-target', TARGET, '-isysroot', str(sdk), '-dynamiclib', '-fobjc-arc',
            '-fvisibility=hidden', '-Wall', '-Wextra',
            '-install_name', '@loader_path/' + output.name,
            *[value for framework in FRAMEWORKS for value in ('-framework', framework)],
            *SOURCE_FILES, '-o', str(staged))
        run('/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', '--identifier', IDENTIFIER, str(staged))
        run('/usr/bin/codesign', '--verify', '--strict', str(staged))
        run(sys.executable, 'tests/verify_dylib.py', '--project', '.', str(staged))
        staged.replace(output)
    print('Built and verified ' + str(output.relative_to(ROOT)))


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1:
            raise ValueError('usage: python3 scripts/build_dylib.py')
        build()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
