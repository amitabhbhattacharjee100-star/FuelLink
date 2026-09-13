// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gas_price_compare/gas_api.dart';

void main() {
  test('calculates fuel savings correctly', () {
    dotenv.loadFromString(envString: 'GAS_PRICE_API_KEY=test');
    final service = GasPriceService();
    expect(service.calculateSavings(160, 150, tankSize: 50), 5.0);
  });
}
