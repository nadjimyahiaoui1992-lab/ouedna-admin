import 'package:flutter_test/flutter_test.dart';
import 'package:ouedna_admin/core/geo/coordinates_parser.dart';

void main() {
  group('CoordinatesParser', () {
    test('يحوّل الإحداثيات العشرية إلى نقطة صالحة', () async {
      final point = await CoordinatesParser.parse('33.3683, 6.8674');

      expect(point, isNotNull);
      expect(point!.latitude, closeTo(33.3683, 0.000001));
      expect(point.longitude, closeTo(6.8674, 0.000001));
    });

    test('يستخرج إحداثيات Google Maps من صيغة !3d و !4d', () async {
      final point = await CoordinatesParser.parse(
        'https://www.google.com/maps/place/Ouedna/@33.3683,6.8674,15z!3d33.3701!4d6.8702',
      );

      expect(point, isNotNull);
      expect(point!.latitude, closeTo(33.3701, 0.000001));
      expect(point.longitude, closeTo(6.8702, 0.000001));
    });

    test('يفك Plus Code مختصرًا داخل نطاق الوادي', () async {
      final point = await CoordinatesParser.parse('9V83+WHF, El Oued');

      expect(point, isNotNull);
      expect(point!.latitude, inInclusiveRange(32.0, 34.5));
      expect(point.longitude, inInclusiveRange(6.0, 8.0));
    });

    test('يرفض المدخلات غير الصالحة بدل حفظ موقع خاطئ', () async {
      final point = await CoordinatesParser.parse('هذا ليس موقعًا');

      expect(point, isNull);
    });
  });
}
