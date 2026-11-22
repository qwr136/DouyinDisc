"""Pure static TrollFools generator checks; imports no project scripts."""

import ast
import re
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def literal_assignments(tree, names):
    values = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and target.id in names:
            require(target.id not in values, 'duplicate builder setting: ' + target.id)
            values[target.id] = ast.literal_eval(node.value)
    return values


def check_builder(project, name, domain, minimum, sdk):
    builder = ast.parse((project / 'scripts/build_dylib.py').read_text(encoding='utf-8'))
    entry = 'Sources/' + name + 'Entry.m'
    values = literal_assignments(builder, {'NAME', 'IDENTIFIER', 'TARGET', 'SDK_DIR', 'SOURCE_FILES', 'FRAMEWORKS'})
    for key, value in {'NAME': name, 'IDENTIFIER': domain, 'TARGET': 'arm64-apple-ios' + minimum,
                       'SDK_DIR': 'iPhoneOS' + sdk + '.sdk'}.items():
        require(values.get(key) == value, 'builder %s differs from manifest' % key)
    inputs = values.get('SOURCE_FILES')
    sources = (entry, 'Sources/' + name + 'Policy.c', 'Sources/' + name + 'NativeDisplay.m')
    if name == 'DouyinDisc':
        sources += ('Sources/DouyinDiscNavigationStore.m', 'Sources/DouyinDiscNavigation.m', 'Sources/DouyinDiscNavigationHooks.m')
    require(inputs == sources,
            'builder must compile every approved entry, policy and feature source')
    frameworks = literal_assignments(builder, {'FRAMEWORKS'}).get('FRAMEWORKS')
    require(frameworks == ('Foundation', 'UIKit', 'QuartzCore', 'CoreGraphics', 'ImageIO', 'PhotosUI', 'MobileCoreServices'),
            'builder framework list must match the explicitly approved Apple APIs')
    for path in inputs:
        if path.endswith('DouyinDiscNavigationHooks.m'):
            source = (project / path).read_text(encoding='utf-8')
            require(len(source) >= 12000 and 'void douyindisc_installNavigationHooks(void)' in source and source.rstrip().endswith('@end'),
                    'navigation hook source is incomplete or truncated')
            require(source.count('@implementation DouyinDiscTextLease') == 1,
                    'navigation lease implementation must be unique')
        require(isinstance(path, str) and re.fullmatch(r'Sources/' + re.escape(name) + r'[A-Za-z0-9]*\.(?:m|mm|c|cc|cpp)', path),
                'non-namespaced compiled source: ' + repr(path))
        file = project / path
        require(file.is_file() and not file.is_symlink() and file.stat().st_size > 0, 'missing or empty compiled source: ' + path)
        code = strip_comments(file.read_text(encoding='utf-8'))
        require(code.strip(), 'compiled source only contains comments: ' + path)
        require(not re.search(r'(?im)^\s*#\s*(?:import|include)\s*[^\n]*(?:substrate|roothide|rootless|preferenceloader|ellekit|libhooker)', code),
                'jailbreak header in compiled source: ' + path)
    calls = sorted((node for node in ast.walk(builder) if isinstance(node, ast.Call) and
                    isinstance(node.func, ast.Name) and node.func.id == 'run'), key=lambda node: node.lineno)
    expected = (
        "run(sys.executable, 'scripts/toolchain.py', 'verify', '--output', 'reports/local-toolchain.json')",
        "run('/usr/bin/xcrun', '--sdk', 'iphoneos', 'clang', '-target', TARGET, '-isysroot', str(sdk), "
        "'-dynamiclib', '-fobjc-arc', '-fvisibility=hidden', '-Wall', '-Wextra', "
        "'-install_name', '@loader_path/' + output.name, *[value for framework in FRAMEWORKS for value in ('-framework', framework)], *SOURCE_FILES, '-o', str(staged))",
        "run('/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', '--identifier', IDENTIFIER, str(staged))",
        "run('/usr/bin/codesign', '--verify', '--strict', str(staged))",
        "run(sys.executable, 'tests/verify_dylib.py', '--project', '.', str(staged))",
    )
    require([ast.dump(call) for call in calls] == [ast.dump(ast.parse(text, mode='eval').body) for text in expected],
            'builder must verify before clang, compile the locked SDK/TARGET with Apple-only flags, then sign and verify')
    sdk_assignment = [node for node in ast.walk(builder) if isinstance(node, ast.Assign) and
                      any(isinstance(target, ast.Name) and target.id == 'sdk' for target in node.targets)]
    require(len(sdk_assignment) == 1 and ast.dump(sdk_assignment[0].value) ==
            ast.dump(ast.parse("theos / 'sdks' / SDK_DIR", mode='eval').body), 'builder SDK path is not under THEOS/sdks')


def strip_comments(source):
    return re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|/\*.*?\*/|//[^\n]*''',
                  lambda match: match[1] or ' ', source, flags=re.S)


def check_guard(project, name, bundle):
    code = strip_comments((project / ('Sources/' + name + 'Entry.m')).read_text(encoding='utf-8'))
    symbol = name.lower()
    require(not re.search(r'(?m)^\s*#\s*if\s+0\b', code), 'disabled entry code is not valid evidence of a bundle guard')
    guard = (r'__attribute__\s*\(\(constructor\)\)\s+static\s+void\s+' + symbol + r'_entry\(void\)\s*\{\s*'
             r'@autoreleasepool\s*\{\s*NSString\s*\*\s*bundleIdentifier\s*=\s*NSBundle\.mainBundle\.bundleIdentifier\s*;\s*'
             r'if\s*\(\s*!\[bundleIdentifier\s+isEqualToString:@"' + re.escape(bundle) + r'"\]\s*\)\s*'
             r'\{\s*return;\s*\}\s*' + symbol + r'_initialize\(\);\s*\}\s*\}')
    require(re.search(guard, code), 'entry is not hard-guarded for the manifest App bundle')
    require(re.search(r'\bid\s+build\s*=\s*\[NSBundle\.mainBundle\s+objectForInfoDictionaryKey:@"CFBundleVersion"\];\s*if\s*\(\s*!\[build\s+isKindOfClass:NSString\.class\]\s*\|\|\s*!\[\(NSString\s*\*\)build\s+isEqualToString:@"399017"\]\s*\)\s*return;', code), 'entry is not hard-guarded for the documented target build')
    require(re.search(r'\bstatic\s+void\s+' + symbol + r'_initialize\(void\)\s*\{', code), 'missing namespaced initializer')


def check_project(project, meta):
    """Check a generated project using its already-parsed manifest; never execute project code."""
    try:
        project = Path(project)
        require(isinstance(meta, dict), 'manifest must be an object')
        name, bundle = meta.get('name'), meta.get('bundle')
        require(isinstance(name, str) and re.fullmatch(r'[A-Z][A-Za-z0-9]*', name) and
                'xiaofei' not in name.lower(), 'invalid project namespace')
        domain = 'com.minis.' + name.lower()
        require(meta.get('package') == domain and meta.get('author') == 'Xiaofei' and
                meta.get('class_prefix') == name and meta.get('id') == meta.get('symbol_prefix') == name.lower(),
                'manifest namespace/package/author differ from project name')
        require(isinstance(bundle, str) and re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', bundle) and
                bundle.lower() != 'com.apple.springboard', 'TrollFools requires an explicit App bundle, not SpringBoard')
        require(meta.get('target_type') == 'dylib' and meta.get('scheme') == 'trollfools' and
                meta.get('architecture') == 'arm64', 'invalid TrollFools target metadata')
        require(meta.get('preferences') is False and meta.get('slider') is False, 'TrollFools does not support PreferenceLoader or slider')
        minimum = meta.get('minimum_ios')
        require(isinstance(minimum, str) and re.fullmatch(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?', minimum), 'invalid minimum iOS')
        fields = [int(part) for part in minimum.split('.')]
        require(15 <= fields[0] <= 65535 and all(part <= 255 for part in fields[1:]), 'minimum iOS must fit Mach-O and be 15.0 or newer')
        sdk = meta.get('sdk_version')
        require(isinstance(sdk, str) and re.fullmatch(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?', sdk), 'invalid manifest SDK version')
        for path in ('tweak.json', 'toolchain-lock.json', 'build.sh', 'tests/run_tests.py', 'tests/verify_dylib.py'):
            require((project / path).is_file(), 'required project file missing: ' + path)
        for path in ('control', 'Makefile', name + 'Build.mk', name + '.plist', name + 'Prefs', 'Hooks', 'layout'):
            require(not (project / path).exists(), 'jailbreak template file must not be present: ' + path)
        wrapper = (project / 'build.sh').read_text(encoding='utf-8').splitlines()
        gates = [line.strip() for line in wrapper if re.match(r'\s*python3\s+scripts/', line)]
        require(gates == ['python3 scripts/toolchain.py verify --output reports/local-toolchain.json',
                          'python3 scripts/build_dylib.py'], 'build.sh must verify before calling the native builder')
        check_builder(project, name, domain, minimum, sdk)
        check_guard(project, name, bundle)
        workflow = project / '.github/workflows/build.yml'
        enabled = meta.get('github_actions')
        require(isinstance(enabled, bool) and workflow.is_file() == enabled, 'workflow presence differs from manifest')
        if enabled:
            text = '\n'.join(line for line in workflow.read_text(encoding='utf-8').splitlines()
                             if not line.lstrip().startswith('#'))
            require(re.search(r'(?m)^\s*contents:\s*read\s*$', text) and not re.search(
                r'(?im)\baction-gh-release@|\bcontents:\s*["\']?write\b|\bgh\s+release\b|\bgit\s+push\b|^\s+publish\s*:', text),
                'TrollFools workflow may upload artifacts but not create releases')
    except (ValueError, OSError, SyntaxError, TypeError) as error:
        return [str(error)]
    return []
