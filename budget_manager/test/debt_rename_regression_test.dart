import 'package:budget_manager/screens/debt_profile_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_fixture.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('renaming a debt profile closes without framework errors', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(TestFixture.create))!;
    addTearDown(fixture.dispose);
    await tester.runAsync(
      () => fixture.provider.createDebtProfile(
        name: 'Before',
        initialBalanceCents: 300,
      ),
    );
    final id = fixture.provider.debtProfiles.single.id!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.provider,
        child: MaterialApp(home: DebtProfileDetailScreen(profileId: id)),
      ),
    );

    await tester.tap(find.byKey(const Key('rename-debt-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rename-debt-profile-field')),
      'After',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(fixture.provider.debtProfiles.single.name, 'After');
  });
}
