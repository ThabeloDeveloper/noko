import 'package:flutter_test/flutter_test.dart';
import 'package:noko_driver/constants/colors.dart';

void main() {
  test('driver app exposes the brand color palette', () {
    expect(MyColors.primary.toARGB32(), 0xFF7A1F2B);
    expect(MyColors.success.toARGB32(), 0xFF4CAF50);
  });
}
