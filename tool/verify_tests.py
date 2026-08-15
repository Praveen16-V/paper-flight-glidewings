#!/usr/bin/env python3
"""Verify the test suite references only symbols that actually exist.

Tests are the part most likely to reference something renamed or deleted
during the overhaul, and they are not covered by the lib/ scan.
"""
import re
import os
import glob
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = []


def strip_code(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
        elif c in "'\"":
            if src.startswith(c * 3, i):
                j = src.find(c * 3, i + 3)
                i = n if j < 0 else j + 3
            else:
                j = i + 1
                while j < n:
                    if src[j] == '\\':
                        j += 2
                        continue
                    if src[j] == c or src[j] == '\n':
                        break
                    j += 1
                i = j + 1
            out.append('""')
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def enum_members(name):
    src = strip_code(open(os.path.join(
        ROOT, 'lib/core/enums/game_enums.dart')).read())
    m = re.search(r'\benum\s+' + name + r'\s*\{(.*?)\}', src, re.S)
    if not m:
        return set()
    return {t.group(1) for t in
            (re.match(r'^([a-zA-Z_]\w*)', p.strip())
             for p in m.group(1).split(',')) if t}


# GameConfig members
cfg = strip_code(open(os.path.join(
    ROOT, 'lib/core/constants/game_config.dart')).read())
CFG = set(re.findall(
    r'\bstatic\s+(?:const|final)\s+[\w<>,\s\?]+\s+(\w+)\s*=', cfg))
CFG |= set(re.findall(r'\bstatic\s+[\w<>,\s\?]+\s+(\w+)\s*\(', cfg))

# Session state fields + notifier methods
sess = strip_code(open(os.path.join(
    ROOT, 'lib/providers/game_session_provider.dart')).read())
SESSION = set(re.findall(r'\bfinal\s+[\w<>,\s\?]+\s+(\w+)\s*;', sess))
SESSION |= set(re.findall(r'^\s*[\w<>,\s\?]+\s+(\w+)\s*\(', sess, re.M))
SESSION |= set(re.findall(r'\bbool\s+(\w+)\s*\(', sess))
SESSION |= set(re.findall(r'=>\s*\n?\s*\w', sess)) and SESSION

# LivePowerUpState fields
live = strip_code(open(os.path.join(
    ROOT, 'lib/game/live_powerup_state.dart')).read())
LIVE = set(re.findall(r'\bbool\s+(\w+)\s*=', live))
LIVE |= set(re.findall(r'\bint\s+(\w+)\s*=', live))
LIVE |= set(re.findall(r'\bvoid\s+(\w+)\s*\(', live))

PU = enum_members('PowerUpType')
COMBO = enum_members('PowerUpCombo')
OBST = enum_members('ObstacleType')
CORRUPT = enum_members('CorruptedPowerUpType')

# Extension getters on PowerUpType / ObstacleType
enums_src = strip_code(open(os.path.join(
    ROOT, 'lib/core/enums/game_enums.dart')).read())
EXT = set(re.findall(r'\b(?:String|Color|bool|int|double|Set<\w+>|PowerUpType)'
                     r'\s+get\s+(\w+)', enums_src))
EXT |= set(re.findall(r'\b\w+\s+(\w+)\s*\(int\s+\w+\)', enums_src))

for path in sorted(glob.glob(os.path.join(ROOT, 'test/*.dart'))):
    src = strip_code(open(path).read())
    rel = os.path.relpath(path, ROOT)

    for m in re.finditer(r'\bGameConfig\.(\w+)', src):
        if m.group(1) not in CFG:
            FAIL.append(f'{rel}:{src[:m.start()].count(chr(10))+1}  '
                        f'GameConfig.{m.group(1)} undefined')

    for enum_name, members in (('PowerUpType', PU), ('PowerUpCombo', COMBO),
                               ('ObstacleType', OBST),
                               ('CorruptedPowerUpType', CORRUPT)):
        for m in re.finditer(r'\b' + enum_name + r'\.(\w+)', src):
            v = m.group(1)
            if v in ('values',):
                continue
            if v not in members and v not in EXT:
                FAIL.append(f'{rel}:{src[:m.start()].count(chr(10))+1}  '
                            f'{enum_name}.{v} undefined')

    # session/live field access on known holders
    for m in re.finditer(r'\bsession\(\)\.(\w+)', src):
        if m.group(1) not in SESSION:
            FAIL.append(f'{rel}:{src[:m.start()].count(chr(10))+1}  '
                        f'GameSessionState.{m.group(1)} undefined')
    for m in re.finditer(r'\bnotifier\(\)\.(\w+)', src):
        if m.group(1) not in SESSION:
            FAIL.append(f'{rel}:{src[:m.start()].count(chr(10))+1}  '
                        f'GameSessionNotifier.{m.group(1)} undefined')
    for m in re.finditer(r'\bsnapshot\.(\w+)', src):
        if m.group(1) not in LIVE:
            FAIL.append(f'{rel}:{src[:m.start()].count(chr(10))+1}  '
                        f'LivePowerUpState.{m.group(1)} undefined')

print(f'PowerUpType: {sorted(PU)}')
print(f'GameConfig members parsed: {len(CFG)}')
print(f'Test files scanned: {len(glob.glob(os.path.join(ROOT, "test/*.dart")))}\n')
print(f'=== {len(FAIL)} ERROR(S) ===')
for f in FAIL:
    print('  ✗', f)
sys.exit(1 if FAIL else 0)
