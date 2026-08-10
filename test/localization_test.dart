import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/l10n/app_localizations.dart';

void main() {
  test('falls back to English for unsupported locales and missing Spanish keys',
      () {
    const unsupported = AppLocalizations(Locale('fr'));
    const spanish = AppLocalizations(Locale('es'));

    expect(unsupported.text('menu.play'), 'PLAY');
    expect(spanish.text('menu.play'), 'JUGAR');
    expect(spanish.text('unknown.key'), 'unknown.key');
  });

  test('replaces named values in localized copy', () {
    const strings = AppLocalizations(Locale('en'));

    expect(
      strings.text('guide.page', {'current': 2, 'total': 4}),
      '2 of 4',
    );
    expect(
      strings.text('a11y.coins', {'amount': 125}),
      '125 coins',
    );
  });
}
