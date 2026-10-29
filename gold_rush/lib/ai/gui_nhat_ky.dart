import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Gửi nhật ký ván chơi về máy chủ `gold_rush_ai` (FastAPI, `POST /api/nhat-ky`).
///
/// Địa chỉ máy chủ KHÔNG viết cứng trong mã mà truyền lúc chạy — cùng tinh thần
/// "cấu hình bằng biến môi trường" của notebook AI Web Apps:
///
///     flutter run -d chrome --web-port 5000 --dart-define=GOLD_RUSH_API=http://localhost:8000
///     flutter run --dart-define=GOLD_RUSH_API=http://10.0.2.2:8000     # máy ảo Android
///
/// Không truyền gì thì game chạy offline như bản gốc, không gửi gì cả.
class GuiNhatKy {
  GuiNhatKy._();

  static const String mayChu = String.fromEnvironment('GOLD_RUSH_API');

  static bool get daCauHinh => mayChu.isNotEmpty;

  /// Gửi một ván. Lỗi mạng KHÔNG BAO GIỜ được làm hỏng trải nghiệm chơi:
  /// mọi ngoại lệ đều bị nuốt và ghi log.
  static Future<bool> gui(Map<String, Object> nhatKy) async {
    if (!daCauHinh) return false;
    try {
      final r = await http
          .post(
            Uri.parse('$mayChu/api/nhat-ky'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(nhatKy),
          )
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 201) {
        debugPrint('Máy chủ từ chối nhật ký (${r.statusCode}): ${r.body}');
      }
      return r.statusCode == 201;
    } catch (e) {
      debugPrint('Không gửi được nhật ký: $e');
      return false;
    }
  }
}
