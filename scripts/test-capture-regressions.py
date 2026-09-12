#!/usr/bin/env python3
"""Focused regressions for batch ordering, file retention, locking and PNG markup.

Uses bounded fixtures in the macOS cache and stubs GUI actions; does not touch the
real clipboard, Photos library, screenshot preferences, or LaunchAgents.
"""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path.home() / 'Library/Caches/macos-screenshot-pipeline'
CACHE.mkdir(parents=True, exist_ok=True)


def shell(code, env):
    result = subprocess.run(['/bin/bash', '-c', code], env=env,
                            capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, (result.returncode, result.stdout, result.stderr)
    return result.stdout


with tempfile.TemporaryDirectory(prefix='regression-', dir=CACHE) as folder:
    base = Path(folder)
    env = dict(os.environ, HOME=folder, MACOS_SCREENSHOT_PIPELINE_TESTING='1',
               MACOS_SCREENSHOT_PIPELINE_CONFIG='/dev/null')
    source = 'source ' + shlex.quote(str(ROOT / 'bin/process.sh')) + '\n'
    stage = base / 'stage'
    stage.mkdir()
    env['STAGING_DIR'] = str(stage)
    env['TRACE'] = str(base / 'trace')
    first = stage / 'a "quoted" image.png'
    second = stage / 'b.png'
    first.write_bytes(b'image-a')
    second.write_bytes(b'image-b')
    common = '''
log() { :; }
prepare_photos() { :; }
copy_png_to_clipboard() { echo C >> "$TRACE"; }
import_to_photos() { echo P >> "$TRACE"; }
'''
    shell(source + common + 'main', env)
    assert (base / 'trace').read_text().splitlines() == ['C', 'C', 'P', 'P']
    assert not first.exists() and not second.exists()
    print('PASS batch clipboard work precedes all imports; successful files cleaned')

    first.write_bytes(b'image-a')
    shell(source + common + 'import_to_photos() { return 1; }; main', env)
    assert first.exists()
    print('PASS failed Photos import retains original')

    shell(source + common + 'IMPORT_PHOTOS=0; copy_png_to_clipboard() { return 1; }; main', env)
    assert first.exists()
    print('PASS clipboard-only failure retains original')

    shell(source + common + 'DELETE_STAGING_ON_SUCCESS=0; main', env)
    assert first.exists()
    print('PASS keep-staging mode remains intact')

    shell(source + common + '''
copy_png_to_clipboard() { printf changed >> "$1"; }
import_to_photos() { exit 9; }
main
''', env)
    assert first.exists()
    print('PASS change after clipboard work prevents import and deletion')

    shell(source + common + 'import_to_photos() { printf changed >> "$1"; }; main', env)
    assert first.exists()
    print('PASS change during import prevents deletion')

    env['FIXTURE'] = str(first)
    shell(source + '''
sleep() { printf x >> "$FIXTURE"; }
if wait_stable "$FIXTURE"; then exit 9; fi
''', env)
    print('PASS continuously changing file times out without processing')
    first.write_bytes(b'')
    shell(source + '''
sleep() { if [[ ! -s "$FIXTURE" ]]; then printf ready > "$FIXTURE"; fi; }
wait_stable "$FIXTURE"
[[ -n "$STABLE_SIGNATURE" ]]
''', env)
    print('PASS initially empty file can finish writing before processing')
    first.unlink()
    shell(source + common + 'prepare_photos() { exit 9; }; main', env)
    print('PASS empty batch does not touch Photos')

    # Exercise the actual native lock mechanism, including contention/release.
    lock = base / 'process.lock'
    ready = base / 'locked'
    holder = subprocess.Popen(['/usr/bin/lockf', '-k', '-s', '-t', '0', str(lock),
                               '/bin/bash', '-c', 'echo ready > "$1"; read -r line',
                               'holder', str(ready)], stdin=subprocess.PIPE)
    try:
        import time
        deadline = time.monotonic() + 3
        while not ready.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        assert ready.exists()
        blocked = subprocess.run(['/usr/bin/lockf', '-k', '-s', '-t', '0',
                                  str(lock), '/usr/bin/true'])
        assert blocked.returncode == 75
    finally:
        holder.communicate(b'release\n', timeout=3)
    assert subprocess.run(['/usr/bin/lockf', '-k', '-s', '-t', '0',
                           str(lock), '/usr/bin/true']).returncode == 0
    print('PASS native lock blocks concurrent worker and releases after exit')

    # Stub osascript at its boundary to verify exact argv and markup conversion.
    mock = base / 'osascript'
    mock.write_text('''#!/bin/bash
script=$(cat)
if [[ "$script" == *"importedItems"* ]]; then
  [[ "$2" == "$FIXTURE" && "$3" == "$CAPTION" && "$4" == "$KEYWORD" ]] || exit 9
  echo 1
elif [[ "$script" == *"clipboard as"* ]]; then
  printf fixture > "$2"
  echo "$FORMAT"
fi
''')
    mock.chmod(0o755)
    process_source = (ROOT / 'bin/process.sh').read_text().replace('/usr/bin/osascript', shlex.quote(str(mock)))
    env.update(CAPTION='Caption "quote" \\ newline\nnext', KEYWORD='Key "quote" \\')
    shell(process_source + '\nimport_to_photos "$FIXTURE"', env)
    print('PASS Photos path/caption/keyword passed intact as arguments')

    mock.write_text('''#!/bin/bash
if [[ "$*" == *"to quit"* ]]; then
  echo Q >> "$TRACE"
elif [[ "$PRIOR_STATE" == error ]]; then
  exit 1
else
  echo "$PRIOR_STATE"
fi
''')
    for state in ('true', 'false', 'error'):
        for status in (0, 1):
            (base / 'trace').write_text('')
            result = subprocess.run(['/bin/bash', '-c', process_source +
                                     '\nprepare_photos; prepare_photos; trap cleanup EXIT; exit ' + str(status)],
                                    env=dict(env, PRIOR_STATE=state), capture_output=True, text=True)
            assert result.returncode == status
            assert (base / 'trace').read_text().splitlines() == (['Q'] if state == 'false' else [])
    print('PASS Photos prior state restored on normal/error exits; unknown stays open')
    mock.write_text('''#!/bin/bash
script=$(cat)
if [[ "$script" == *"clipboard as"* ]]; then
  printf fixture > "$2"
  echo "$FORMAT"
fi
''')

    sips = base / 'sips'
    sips.write_text('#!/bin/bash\necho convert >> "$TRACE"\nexit "${CONVERT_STATUS:-0}"\n')
    sips.chmod(0o755)
    preview_source = (ROOT / 'bin/edit-clipboard-in-preview.sh').read_text()
    preview_source = preview_source.replace('/usr/bin/osascript', shlex.quote(str(mock)))
    preview_source = preview_source.replace('/usr/bin/sips', shlex.quote(str(sips)))
    (base / 'trace').write_text('')
    shell(preview_source, dict(env, FORMAT='PNG'))
    assert not (base / 'trace').read_text()
    shell(preview_source, dict(env, FORMAT='TIFF'))
    assert (base / 'trace').read_text().splitlines() == ['convert']
    failed = subprocess.run(['/bin/bash', '-c', preview_source],
                            env=dict(env, FORMAT='TIFF', CONVERT_STATUS='1'),
                            capture_output=True, text=True)
    assert failed.returncode == 1
    print('PASS Preview skips PNG conversion, converts TIFF, reports conversion failure')

print('All focused capture regressions passed; GUI acceptance is separate.')
