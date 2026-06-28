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

  test('signed currency parsing and formatting preserves direction', () {
    expect(parseSignedCurrencyToCents('-12.34'), -1234);
    expect(parseSignedCurrencyToCents('+12.3'), 1230);
    expect(parseSignedCurrencyToCents('0'), 0);
    expect(parseSignedCurrencyToCents('--1'), isNull);
    expect(formatSignedCurrency(-1234), r'-$12.34');
    expect(formatSignedCurrency(1234), r'+$12.34');
    expect(formatSignedCurrency(0), r'$0.00');
  });
}
