import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_flutter/main.dart';

void main() {
  testWidgets('Dengue prediction screen loads correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DenguePredictionApp());

    expect(find.text('Dengue Risk Prediction'), findsOneWidget);

    expect(find.text('Colombo District'), findsOneWidget);

    expect(find.text('Predict Dengue Risk'), findsOneWidget);

    expect(find.text('Select Area'), findsOneWidget);

    expect(find.text('Year'), findsOneWidget);

    expect(find.text('Week'), findsOneWidget);
  });
}
