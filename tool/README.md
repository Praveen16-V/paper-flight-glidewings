# Static verification tooling

The sandbox this work was done in had no Dart/Flutter SDK, and pub.dev was
firewalled (so dependencies could not resolve even if an SDK were installed).
These scripts check the error classes the power-up overhaul could realistically
introduce, and are kept because they remain useful as a fast pre-commit sweep.

They are **not** a substitute for `flutter analyze` / `flutter test`.

| Script | Checks |
|---|---|
| `verify.py` | Non-exhaustive enum switches, references to deleted symbols, undefined `GameConfig` members, brace/paren balance, unused private members and imports |
| `verify_tests.py` | Every symbol the test suite references actually exists |
| `sim_logic.py` | Python port of the power-up timer/cooldown state machine, exercising the behaviours the Dart tests assert |

Run all three:

```sh
python3 tool/verify.py && python3 tool/verify_tests.py && python3 tool/sim_logic.py
```

Known false positives in `verify.py`: imports used only for a type annotation
(e.g. `SettingsModel`) may be reported as possibly unused. `verify_tests.py`
assumes a variable named `snapshot` is a `LivePowerUpState`, which is wrong in
`replay_trace_test.dart` and `runtime_diagnostics_test.dart`.
