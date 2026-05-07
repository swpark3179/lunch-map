import 'package:flutter_test/flutter_test.dart';
import 'package:lunch_map/main.dart';

void main() {
  test('MyApp remains a compatibility alias for LunchMapApp', () {
    expect(const MyApp(), isA<LunchMapApp>());
  });
}
