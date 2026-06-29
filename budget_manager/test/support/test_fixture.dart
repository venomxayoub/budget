import 'dart:io';

import 'package:budget_manager/database/database_helper.dart';
import 'package:budget_manager/providers/transaction_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestFixture {
  final Directory directory;
  final DatabaseHelper databaseHelper;
  final TransactionProvider provider;

  const TestFixture({
    required this.directory,
    required this.databaseHelper,
    required this.provider,
  });

  static Future<TestFixture> create({DateTime Function()? clock}) async {
    final directory = await Directory.systemTemp.createTemp(
      'budget_behavior_test_',
    );
    final databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      path: path.join(directory.path, 'budget.db'),
    );
    final provider = TransactionProvider(
      databaseHelper: databaseHelper,
      clock: clock,
    );
    await provider.loadData();
    return TestFixture(
      directory: directory,
      databaseHelper: databaseHelper,
      provider: provider,
    );
  }

  Future<void> dispose() async {
    await databaseHelper.close();
    await directory.delete(recursive: true);
  }
}
