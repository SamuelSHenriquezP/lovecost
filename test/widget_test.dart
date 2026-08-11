import 'package:flutter_test/flutter_test.dart';
import 'package:lovecost/main.dart';

void main() {
  testWidgets('NidoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NidoApp());
  });
}
