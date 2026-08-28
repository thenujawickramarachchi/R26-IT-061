import 'package:flutter_test/flutter_test.dart';
import 'package:dengue_phi_inspector/main.dart';

void main() {
  test('Backend URL normalization', () {
    expect(
      normalizeBaseUrl('http://192.168.1.6:8000/'),
      'http://192.168.1.6:8000',
    );
  });
}
