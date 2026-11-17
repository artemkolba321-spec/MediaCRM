import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_crm/core/theme/app_theme.dart';
import 'package:media_crm/core/widgets/ui.dart';

void main() {
  testWidgets('EmptyState renders title, message and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: EmptyState(
            title: 'Пока пусто',
            message: 'Добавьте первую запись.',
            icon: Icons.inbox_outlined,
            action: FilledButton(
              onPressed: () => tapped = true,
              child: const Text('Добавить'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Пока пусто'), findsOneWidget);
    expect(find.text('Добавьте первую запись.'), findsOneWidget);

    await tester.tap(find.text('Добавить'));
    expect(tapped, isTrue);
  });

  testWidgets('StatTile formats label and value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: StatTile(
              label: 'Аудитория',
              value: '12 345',
              icon: Icons.people_outline_rounded,
              color: Colors.blue,
              delta: 4.2,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Аудитория'), findsOneWidget);
    expect(find.text('12 345'), findsOneWidget);
    expect(find.textContaining('4.2'), findsOneWidget);
  });
}
