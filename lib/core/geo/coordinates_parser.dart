import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// نقطة جغرافية بسيطة (بديل خفيف عن الاعتماد على حزمة خرائط كاملة).
class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);

  bool get isValid =>
      latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
}

/// أداة استخراج الإحداثيات من مدخلات المستخدم: رابط خرائط جوجل (كامل أو
/// مختصر)، إحداثيات عشرية ملصوقة مباشرة، أو رمز موقع مفتوح (Plus Code).
///
/// نقطة مرجعية ثابتة لولاية الوادي — تُستخدم فقط لاسترجاع رموز الموقع
/// المختصرة (Plus Codes) التي لا تحمل الأحرف الأولى، تماماً كما تفعل خرائط
/// جوجل عند عرض رمز محلي مثل "V75V+8Q الوادي".
class CoordinatesParser {
  CoordinatesParser._();

  static const GeoPoint _regionReference = GeoPoint(33.368, 6.867);

  static const String _plusCodeAlphabet = '23456789CFGHJMPQRVWX';
  static const int _separatorPosition = 8;

  /// المحاولة الرئيسية: تُعيد نقطة صالحة أو null إن تعذّر الفهم.
  /// قد تحتاج إلى اتصال بالإنترنت في حال كان المدخل رابطاً مختصراً.
  static Future<GeoPoint?> parse(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    // 1) إحداثيات عشرية مباشرة أو ضمن نص/رابط (يشمل صيغ !3d..!4d.. و@lat,lng)
    final direct = _extractFromText(input);
    if (direct != null) return direct;

    // 2) رمز موقع مفتوح (Plus Code)
    final plusCode = _extractPlusCode(input);
    if (plusCode != null) return plusCode;

    // 3) رابط مختصر (maps.app.goo.gl، goo.gl، أو أي رابط لا يحمل الإحداثيات
    // في نصه) — نحاول حل التحويلات عبر الشبكة ثم نعيد المحاولة.
    if (_looksLikeUrl(input)) {
      final resolved = await _resolveAndExtract(input);
      if (resolved != null) return resolved;
    }

    return null;
  }

  static bool _looksLikeUrl(String input) {
    final uri = Uri.tryParse(input);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// يبحث عن إحداثيات ضمن نص حر (رابط أو نص عادي)، بترتيب أولوية من
  /// الأكثر دقة (نقطة المعلم الفعلية) إلى الأعم (مركز الخريطة).
  static GeoPoint? _extractFromText(String text) {
    // أ) صيغة إحداثيات نقطة المعلم الدقيقة داخل روابط أماكن جوجل
    final placePattern = RegExp(r'!3d(-?\d{1,3}\.\d+)!4d(-?\d{1,3}\.\d+)');
    final placeMatch = placePattern.firstMatch(text);
    if (placeMatch != null) {
      final p = _toPoint(placeMatch.group(1), placeMatch.group(2));
      if (p != null) return p;
    }

    // ب) مركز الخريطة @lat,lng ضمن رابط جوجل مابس
    final atPattern = RegExp(r'@(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)');
    final atMatch = atPattern.firstMatch(text);
    if (atMatch != null) {
      final p = _toPoint(atMatch.group(1), atMatch.group(2));
      if (p != null) return p;
    }

    // ج) معاملات q= أو ll= أو daddr= في الرابط
    final paramPattern =
        RegExp(r'[?&](?:q|ll|daddr|query)=(-?\d{1,3}\.\d+),\s*(-?\d{1,3}\.\d+)');
    final paramMatch = paramPattern.firstMatch(text);
    if (paramMatch != null) {
      final p = _toPoint(paramMatch.group(1), paramMatch.group(2));
      if (p != null) return p;
    }

    // د) زوج إحداثيات ملصوق مباشرة، مثل: 33.3448, 6.8422
    final rawPattern =
        RegExp(r'(-?\d{1,3}\.\d{3,})\s*[,،]\s*(-?\d{1,3}\.\d{3,})');
    final rawMatch = rawPattern.firstMatch(text);
    if (rawMatch != null) {
      final p = _toPoint(rawMatch.group(1), rawMatch.group(2));
      if (p != null) return p;
    }

    return null;
  }

  static GeoPoint? _toPoint(String? latStr, String? lngStr) {
    if (latStr == null || lngStr == null) return null;
    final lat = double.tryParse(latStr.replaceAll(',', '.'));
    final lng = double.tryParse(lngStr.replaceAll(',', '.'));
    if (lat == null || lng == null) return null;
    final point = GeoPoint(lat, lng);
    return point.isValid ? point : null;
  }

  /// يتبع تحويلات الروابط المختصرة (مثل maps.app.goo.gl) يدوياً حتى الوصول
  /// إلى الرابط النهائي، ثم يبحث عن الإحداثيات فيه (وفي محتوى الصفحة إن
  /// لزم الأمر).
  static Future<GeoPoint?> _resolveAndExtract(String url) async {
    final client = http.Client();
    try {
      var current = url;
      for (var i = 0; i < 6; i++) {
        final uri = Uri.tryParse(current);
        if (uri == null) return null;

        http.StreamedResponse response;
        try {
          final request = http.Request('GET', uri)..followRedirects = false;
          response = await client.send(request).timeout(const Duration(seconds: 8));
        } catch (_) {
          return null;
        }

        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          await response.stream.drain<void>().catchError((_) {});
          if (location == null || location.isEmpty) return null;
          current = uri.resolve(location).toString();
          final found = _extractFromText(current);
          if (found != null) return found;
          continue;
        }

        // وصلنا لصفحة نهائية (وليست تحويلاً): افحص الرابط النهائي أولاً،
        // ثم محتوى الصفحة كحل أخير.
        final fromFinalUrl = _extractFromText(current);
        if (fromFinalUrl != null) return fromFinalUrl;

        try {
          final body = await response.stream.bytesToString();
          final fromBody = _extractFromText(body);
          if (fromBody != null) return fromBody;
        } catch (_) {
          // تجاهل: قد يكون المحتوى ثنائياً غير قابل للقراءة كنص
        }
        return null;
      }
      return null;
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------
  // Open Location Code (Plus Code)
  // ---------------------------------------------------------------------

  static GeoPoint? _extractPlusCode(String input) {
    final pattern = '[${_plusCodeAlphabet}0]{2,8}\\+[$_plusCodeAlphabet]{0,3}';
    final match = RegExp(pattern, caseSensitive: false).firstMatch(input.toUpperCase());
    if (match == null) return null;
    final code = match.group(0)!;
    if (!_isValidPlusCode(code)) return null;

    if (_isShortPlusCode(code)) {
      return _recoverShortPlusCode(code, _regionReference);
    }
    return _decodePlusCode(code);
  }

  static bool _isValidPlusCode(String code) {
    final plusIndex = code.indexOf('+');
    if (plusIndex < 2 || plusIndex > _separatorPosition) return false;
    if (plusIndex.isOdd) return false;
    final digits = code.replaceAll('+', '');
    if (digits.isEmpty) return false;
    for (final ch in digits.split('')) {
      if (!_plusCodeAlphabet.contains(ch) && ch != '0') return false;
    }
    return true;
  }

  static bool _isShortPlusCode(String code) =>
      code.indexOf('+') < _separatorPosition;

  static GeoPoint? _decodePlusCode(String code) {
    var digits = code.toUpperCase().replaceAll('+', '');
    if (digits.length < _separatorPosition) return null;
    digits = digits.padRight(15, '0');

    double latLo = -90.0;
    double lngLo = -180.0;
    double latResolution = 400.0;
    double lngResolution = 400.0;

    for (var i = 0; i < 10; i += 2) {
      latResolution /= 20.0;
      lngResolution /= 20.0;
      final latDigit = _plusCodeAlphabet.indexOf(digits[i]);
      final lngDigit = _plusCodeAlphabet.indexOf(digits[i + 1]);
      if (latDigit < 0 || lngDigit < 0) return null;
      latLo += latDigit * latResolution;
      lngLo += lngDigit * lngResolution;
    }

    var rowResolution = latResolution;
    var colResolution = lngResolution;
    for (var i = 10; i < 15; i++) {
      final ch = digits[i];
      if (ch == '0') break;
      final digit = _plusCodeAlphabet.indexOf(ch);
      if (digit < 0) break;
      rowResolution /= 5.0;
      colResolution /= 4.0;
      final row = digit ~/ 4;
      final col = digit % 4;
      latLo += row * rowResolution;
      lngLo += col * colResolution;
    }

    final point = GeoPoint(latLo + rowResolution / 2, lngLo + colResolution / 2);
    return point.isValid ? point : null;
  }

  /// يُشفّر أول [length] رمزاً من زوج الإحداثيات (لإعادة بناء الجزء
  /// الناقص من رمز مختصر انطلاقاً من نقطة مرجعية).
  static String _encodePairsPrefix(double lat, double lng, int length) {
    var remLat = lat + 90.0;
    var remLng = lng + 180.0;
    var latResolution = 400.0;
    var lngResolution = 400.0;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i += 2) {
      latResolution /= 20.0;
      lngResolution /= 20.0;
      var latDigit = (remLat / latResolution).floor();
      var lngDigit = (remLng / lngResolution).floor();
      latDigit = latDigit.clamp(0, 19);
      lngDigit = lngDigit.clamp(0, 19);
      buffer.write(_plusCodeAlphabet[latDigit]);
      buffer.write(_plusCodeAlphabet[lngDigit]);
      remLat -= latDigit * latResolution;
      remLng -= lngDigit * lngResolution;
    }
    return buffer.toString();
  }

  static GeoPoint? _recoverShortPlusCode(String shortCode, GeoPoint reference) {
    final code = shortCode.toUpperCase();
    final plusIndex = code.indexOf('+');
    if (plusIndex < 0) return null;
    final paddingLength = _separatorPosition - plusIndex;
    if (paddingLength <= 0 || paddingLength.isOdd) return null;

    final resolution = math.pow(20.0, 2 - paddingLength / 2).toDouble();
    final digitsOnly = code.replaceAll('+', '');

    GeoPoint? best;
    var bestDistance = double.infinity;

    // نجرّب المربعات المجاورة أيضاً تفادياً لخطأ التقريب قرب حدود الشبكة.
    for (final latShift in [0.0, resolution, -resolution]) {
      for (final lngShift in [0.0, resolution, -resolution]) {
        final baseLat =
            (reference.latitude / resolution).floor() * resolution + latShift;
        final baseLng =
            (reference.longitude / resolution).floor() * resolution + lngShift;
        final prefix = _encodePairsPrefix(
          baseLat + resolution / 2,
          baseLng + resolution / 2,
          paddingLength,
        );
        final fullDigits = prefix + digitsOnly;
        if (fullDigits.length < _separatorPosition) continue;
        final fullCode =
            '${fullDigits.substring(0, _separatorPosition)}+${fullDigits.substring(_separatorPosition)}';
        final decoded = _decodePlusCode(fullCode);
        if (decoded == null) continue;
        final distance = _roughDistance(decoded, reference);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = decoded;
        }
      }
    }
    return best;
  }

  static double _roughDistance(GeoPoint a, GeoPoint b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }
}
