#!/usr/bin/env python3
"""Static verification for the power-up overhaul (Items 1-10).

No Dart SDK is available in this sandbox (pub.dev is firewalled, so even with
one the flame/riverpod dependencies could not resolve). This checks the
specific error classes the overhaul could realistically have introduced:

  1. Non-exhaustive switches over PowerUpType / PowerUpCombo / ObstacleType.
     Dart requires enum switches without a default to cover every case, so a
     missing case after adding Giant/Blast or removing three types is a
     compile error.
  2. References to symbols that were deleted (windCaller, decoyClone,
     turboDash, timeDash, isChargeBased, powerUpCharges, empowered...).
  3. Private fields/methods that are declared but never read — dead code left
     behind by a removal.
  4. Identifiers used but never defined within their file or imports.
  5. Unused imports.
  6. Brace/paren/bracket balance.
"""
import re
import sys
import glob
import os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FAIL = []
WARN = []


def strip_code(src):
    """Remove comments and string literals so scanning sees only code."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
        elif c in "'\"":
            # triple quoted?
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
    """Parse `enum Name { a, b }` from the enums file."""
    path = os.path.join(ROOT, 'lib/core/enums/game_enums.dart')
    src = strip_code(open(path).read())
    m = re.search(r'\benum\s+' + name + r'\s*\{(.*?)\}', src, re.S)
    if not m:
        return []
    body = m.group(1)
    members = []
    for part in body.split(','):
        part = part.strip()
        if not part:
            continue
        t = re.match(r'^([a-zA-Z_]\w*)', part)
        if t:
            members.append(t.group(1))
    return members


# ── 1. Exhaustive switches ────────────────────────────────────────────────────
def check_switch_exhaustiveness(enum_name, members):
    pattern = re.compile(r'\bswitch\s*\(', re.S)
    for path in glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True):
        src = strip_code(open(path).read())
        for m in pattern.finditer(src):
            # find the matching brace block of this switch
            open_brace = src.find('{', m.end())
            if open_brace < 0:
                continue
            depth, j = 0, open_brace
            while j < len(src):
                if src[j] == '{':
                    depth += 1
                elif src[j] == '}':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body = src[open_brace:j]
            cases = set(re.findall(
                r'\bcase\s+' + enum_name + r'\.(\w+)', body))
            if not cases:
                continue
            # A default/wildcard makes it exhaustive by definition.
            if re.search(r'\bdefault\s*:', body) or re.search(r'\b_\s*=>', body):
                continue
            missing = set(members) - cases
            if missing:
                line = src[:m.start()].count('\n') + 1
                FAIL.append(
                    f'{os.path.relpath(path, ROOT)}:{line}  switch over '
                    f'{enum_name} missing: {sorted(missing)}')


# ── 2. Deleted symbols ────────────────────────────────────────────────────────
DELETED = [
    'windCaller', 'WindCaller', 'decoyClone', 'DecoyClone', 'decoyCloneCharges',
    'turboDash', 'TurboDash', 'timeDash', 'TimeDash',
    'isChargeBased', 'powerUpCharges', 'empoweredPowerUpCharges',
    'activeEmpoweredPowerUps', 'addPowerUpCharge', 'consumePowerUpCharge',
    'consumeEmpoweredPowerUpCharge', 'triggerPowerUpCharge',
    'shieldMaxStackedCharges', 'snapRechargeMeters',
    'empoweredMagnetRadius', 'empoweredSlowMoMultiplier',
    'chargePowerUpMaxCharges', 'chargePowerUpBurstDuration',
    'playTimeDashPhaseAnimation', 'magnetEmpowered',
]


def check_deleted_symbols():
    for path in glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True):
        src = strip_code(open(path).read())
        for sym in DELETED:
            for m in re.finditer(r'\b' + re.escape(sym) + r'\b', src):
                line = src[:m.start()].count('\n') + 1
                FAIL.append(
                    f'{os.path.relpath(path, ROOT)}:{line}  references '
                    f'deleted symbol `{sym}`')


# ── 3. Unused private members ─────────────────────────────────────────────────
def check_unused_privates():
    for path in glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True):
        src = strip_code(open(path).read())
        decls = set()
        # private fields
        for m in re.finditer(
                r'^\s*(?:static\s+)?(?:final\s+|const\s+|late\s+final\s+|late\s+)?'
                r'[\w<>,\s\?\[\]]+?\s+(_\w+)\s*(?:=|;)', src, re.M):
            decls.add(m.group(1))
        # private methods
        for m in re.finditer(
                r'^\s*(?:static\s+)?[\w<>,\s\?\[\]]+?\s+(_\w+)\s*\(', src, re.M):
            decls.add(m.group(1))
        for d in sorted(decls):
            uses = len(re.findall(r'\b' + re.escape(d) + r'\b', src))
            if uses <= 1:
                WARN.append(
                    f'{os.path.relpath(path, ROOT)}  `{d}` declared but '
                    f'never used')


# ── 4. Unused imports ─────────────────────────────────────────────────────────
def check_unused_imports():
    for path in glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True):
        raw = open(path).read()
        src = strip_code(raw)
        body = re.sub(r'^\s*(import|export)[^\n]*\n', '', src, flags=re.M)
        for m in re.finditer(
                r"^\s*import\s+'([^']+)'(?:\s+as\s+(\w+))?([^;]*);",
                raw, re.M):
            uri, alias, rest = m.group(1), m.group(2), m.group(3)
            if 'show' in rest:
                names = re.findall(r'\b(\w+)\b', rest.split('show')[1])
                if names and not any(
                        re.search(r'\b' + n + r'\b', body) for n in names):
                    WARN.append(
                        f'{os.path.relpath(path, ROOT)}  unused import {uri}')
                continue
            if alias:
                if not re.search(r'\b' + alias + r'\s*\.', body):
                    WARN.append(
                        f'{os.path.relpath(path, ROOT)}  unused import '
                        f'{uri} (as {alias})')
                continue
            # Heuristic: check the file's top-level declarations are referenced
            target = None
            if uri.startswith('package:paper_flight/'):
                target = os.path.join(ROOT, 'lib',
                                      uri[len('package:paper_flight/'):])
            elif not uri.startswith(('package:', 'dart:')):
                target = os.path.normpath(
                    os.path.join(os.path.dirname(path), uri))
            if not target or not os.path.exists(target):
                continue
            tsrc = strip_code(open(target).read())
            exported = set(re.findall(
                r'^\s*(?:abstract\s+|sealed\s+|final\s+|base\s+)*'
                r'(?:class|enum|mixin|extension|typedef)\s+(\w+)',
                tsrc, re.M))
            exported |= set(re.findall(
                r'^\s*(?:const|final)\s+[\w<>,\s\?]*\s+(\w+)\s*=', tsrc, re.M))
            exported |= set(re.findall(
                r'^\s*[\w<>,\s\?]+\s+(\w+)\s*\(', tsrc, re.M))
            if not exported:
                continue
            if not any(re.search(r'\b' + e + r'\b', body) for e in exported):
                WARN.append(
                    f'{os.path.relpath(path, ROOT)}  possibly unused import '
                    f'{uri}')


# ── 5. Balance ────────────────────────────────────────────────────────────────
def check_balance():
    for path in (glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True)
                 + glob.glob(os.path.join(ROOT, 'test/*.dart'))):
        src = strip_code(open(path).read())
        for o, c, nm in (('{', '}', 'brace'), ('(', ')', 'paren'),
                         ('[', ']', 'bracket')):
            d = src.count(o) - src.count(c)
            if d:
                FAIL.append(
                    f'{os.path.relpath(path, ROOT)}  unbalanced {nm}: {d:+d}')


# ── 6. Config constants referenced but not defined ────────────────────────────
def check_gameconfig_refs():
    cfg = strip_code(
        open(os.path.join(ROOT, 'lib/core/constants/game_config.dart')).read())
    defined = set(re.findall(
        r'\bstatic\s+(?:const|final)\s+[\w<>,\s\?]+\s+(\w+)\s*=', cfg))
    defined |= set(re.findall(r'\bstatic\s+[\w<>,\s\?]+\s+(\w+)\s*\(', cfg))
    for path in (glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True)
                 + glob.glob(os.path.join(ROOT, 'test/*.dart'))):
        src = strip_code(open(path).read())
        for m in re.finditer(r'\bGameConfig\.(\w+)', src):
            if m.group(1) not in defined:
                line = src[:m.start()].count('\n') + 1
                FAIL.append(
                    f'{os.path.relpath(path, ROOT)}:{line}  GameConfig.'
                    f'{m.group(1)} is not defined')


def main():
    pu = enum_members('PowerUpType')
    combo = enum_members('PowerUpCombo')
    obst = enum_members('ObstacleType')
    corrupt = enum_members('CorruptedPowerUpType')
    print(f'PowerUpType ({len(pu)}): {pu}')
    print(f'PowerUpCombo ({len(combo)}): {combo}')
    print(f'CorruptedPowerUpType ({len(corrupt)}): {corrupt}')
    print(f'ObstacleType: {len(obst)} members\n')

    for name, members in (('PowerUpType', pu), ('PowerUpCombo', combo),
                          ('ObstacleType', obst),
                          ('CorruptedPowerUpType', corrupt)):
        if members:
            check_switch_exhaustiveness(name, members)

    check_deleted_symbols()
    check_gameconfig_refs()
    check_balance()
    check_unused_privates()
    check_unused_imports()

    print(f'=== {len(FAIL)} ERROR(S) ===')
    for f in FAIL:
        print('  ✗', f)
    print(f'\n=== {len(WARN)} WARNING(S) ===')
    for w in WARN:
        print('  !', w)
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
