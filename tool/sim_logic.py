#!/usr/bin/env python3
"""Faithful Python port of the power-up timer/cooldown state machine.

Ports tickPowerUpTimers + collectPowerUp + consumeShield from
game_session_provider.dart / paper_flight_game.dart and exercises the
behaviours the Dart tests assert, so the *logic* is validated even though the
Dart itself cannot be executed here.
"""

DURATION = {
    'shield': 8.0, 'magnet': 8.0, 'ghost': 4.0, 'slowMo': 4.0,
    'coinRush': 6.0, 'doubleScore': 6.0, 'shrink': 5.0,
    'blackHole': 2.5, 'giant': 6.0, 'blast': 6.0,
}
RECHARGE = {'giant': 20.0, 'blast': 20.0, 'shield': 15.0, 'ghost': 15.0}
RECHARGE_DEFAULT = 12.0


def recharge_for(t):
    return RECHARGE.get(t, RECHARGE_DEFAULT)


class Session:
    def __init__(self):
        self.active = set()
        self.remaining = {}
        self.cooldowns = {}
        self.shield_active = False
        self.announcement = None

    # ── ported from GameSessionNotifier ──────────────────────────────────
    def activate(self, t):
        self.active.add(t)
        if t == 'shield':
            self.shield_active = True

    def set_timer(self, t, s):
        self.remaining[t] = s

    def is_recharging(self, t):
        return self.cooldowns.get(t, 0) > 0

    def tick(self, elapsed):
        if elapsed <= 0:
            return set()
        if not self.active and not self.cooldowns:
            return set()

        if self.cooldowns:
            nxt = {}
            for k, v in self.cooldowns.items():
                left = v - elapsed
                if left > 0:
                    nxt[k] = left
            self.cooldowns = nxt

        timers = dict(self.remaining)
        expired = set()
        for t in self.active:
            r = timers.get(t)
            if r is None:
                continue
            n = r - elapsed
            if n <= 0:
                expired.add(t)
                timers.pop(t, None)
            else:
                timers[t] = n

        if not expired:
            self.remaining = timers
            return set()

        with_cd = dict(self.cooldowns)
        for t in expired:
            with_cd[t] = recharge_for(t)

        self.active -= expired
        self.remaining = timers
        self.cooldowns = with_cd
        if 'shield' in expired:
            self.shield_active = False
        return expired

    def consume_shield(self):
        self.active.discard('shield')
        self.shield_active = False
        self.remaining.pop('shield', None)
        self.cooldowns['shield'] = recharge_for('shield')

    def clear_all(self):
        self.active.clear()
        self.remaining.clear()
        self.cooldowns.clear()
        self.shield_active = False
        self.announcement = None

    # ── ported from PaperFlightGame ──────────────────────────────────────
    def collect(self, t):
        """Returns True if the pickup took effect."""
        if t not in self.active and self.is_recharging(t):
            return False
        self.activate(t)
        self.set_timer(t, DURATION[t])
        self.announcement = t
        return True


results = []


def check(name, cond):
    results.append((name, bool(cond)))


# Item 1: everything is timed and expires
s = Session()
for t in DURATION:
    s = Session()
    s.collect(t)
    check(f'[1] {t} active on collect', t in s.active)
    check(f'[1] {t} has positive timer', s.remaining[t] > 0)
    s.tick(DURATION[t])
    check(f'[1] {t} expires on its timer', t not in s.active)

# Item 1: pause safety is enforced by the caller (loop gates on phase); here we
# confirm a zero tick is inert.
s = Session()
s.collect('ghost')
before = s.remaining['ghost']
s.tick(0)
check('[1] zero tick is a no-op', s.remaining['ghost'] == before)

# Item 3: no stacking — refresh instead
s = Session()
s.collect('ghost')
full = s.remaining['ghost']
s.tick(full * 0.8)
check('[3] timer drained', s.remaining['ghost'] < full)
s.collect('ghost')
check('[3] refresh restores full', s.remaining['ghost'] == full)
check('[3] still exactly one active', len(s.active) == 1)

# Item 3+10 interaction: refreshing an ACTIVE effect is allowed even though
# collecting a RECHARGING one is not.
s = Session()
s.collect('ghost')
s.tick(1.0)
check('[3/10] refresh allowed while active', s.collect('ghost'))

# Item 10: cooldown starts on expiry, blocks re-collect, then clears
s = Session()
s.collect('ghost')
s.tick(DURATION['ghost'])
check('[10] cooldown starts on expiry', s.is_recharging('ghost'))
check('[10] cooldown == configured', s.cooldowns['ghost'] == recharge_for('ghost'))
check('[10] re-collect declined', not s.collect('ghost'))
check('[10] declined leaves it inactive', 'ghost' not in s.active)
check('[10] a different type is allowed', s.collect('magnet'))

# cooldown keeps draining with nothing active (the early-return bug)
s = Session()
s.collect('ghost')
s.tick(DURATION['ghost'])
check('[10] nothing active after expiry', not s.active)
cd0 = s.cooldowns['ghost']
s.tick(1.0)
check('[10] cooldown still drains with nothing active',
      s.cooldowns['ghost'] < cd0)
s.tick(recharge_for('ghost'))
check('[10] cooldown clears', not s.is_recharging('ghost'))
check('[10] collectable again', s.collect('ghost'))

# shield consumed on impact recharges
s = Session()
s.collect('shield')
s.consume_shield()
check('[10] spent shield recharges', s.is_recharging('shield'))
check('[10] spent shield inactive', not s.shield_active)

# Item 5: run end clears everything including cooldowns
s = Session()
s.collect('ghost')
s.collect('magnet')
s.tick(DURATION['ghost'])
s.clear_all()
check('[5] run end clears active', not s.active)
check('[5] run end clears timers', not s.remaining)
check('[5] run end clears cooldowns', not s.cooldowns)

# independent clocks
s = Session()
s.collect('blackHole')   # 2.5
s.collect('coinRush')    # 6.0
exp = s.tick(DURATION['blackHole'])
check('[5] short one expired', 'blackHole' in exp)
check('[5] long one survives', 'coinRush' in s.active)

# balance invariant: recharge always outlasts duration
for t in DURATION:
    check(f'[10] {t} recharge > duration', recharge_for(t) > DURATION[t])

failed = [n for n, ok in results if not ok]
print(f'{len(results) - len(failed)}/{len(results)} logic checks passed')
if failed:
    print('\nFAILURES:')
    for f in failed:
        print('  ✗', f)
raise SystemExit(1 if failed else 0)
