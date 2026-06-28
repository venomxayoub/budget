import 'package:budget_manager/utils/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currency parsing and formatting use exact integer cents', () {
    expect(parseCurrencyToCents('12'), 1200);
    expect(parseCurrencyToCents('12.3'), 1230);
    expect(parseCurrencyToCents('12.34'), 1234);
    expect(parseCurrencyToCents('12.345'), isNull);
    expect(formatCurrency(1234), r'$12.34');
  });
}
