import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_flight/core/widgets/paper_button.dart';

void main() {
  testWidgets('PaperButton exposes a named button and a 48dp tap target',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PaperButton(
              label: 'PLAY',
              semanticLabel: 'Start classic flight',
              compact: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PaperButton));
    expect(semantics.label, 'Start classic flight');
    expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(tester.getSize(find.byType(PaperButton)).height, greaterThanOrEqualTo(48));

    await tester.tap(find.byType(PaperButton));
    expect(pressed, isTrue);
  });
}
