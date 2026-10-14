import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ViolationsService {
  final AuthService _auth = AuthService();

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (_auth.token.isNotEmpty) 'Authorization': 'Bearer ${_auth.token}',
      };

  Map<String, String> get _getHeaders => {
        if (_auth.token.isNotEmpty) 'Authorization': 'Bearer ${_auth.token}',
      };

  /// Безопасное приведение к int (сервер отдаёт id строками)
  int _toInt(dynamic value) => int.tryParse(value.toString()) ?? 0;

  Future<Map<String, dynamic>> checkViolation({
    required dynamic userId,
    required dynamic shiftId,
    required String type,
  }) async {
    try {
      final uid = _toInt(userId);
      final sid = _toInt(shiftId);
      if (uid <= 0 || sid <= 0) {
        return {'success': false, 'violation': false};
      }

      final response = await http.post(
        Uri.parse(ApiConfig.checkViolations),
        headers: _jsonHeaders,
        body: jsonEncode({
          'user_id': uid,
          'shift_id': sid,
          'type': type,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'violation': false};
    } catch (e) {
      print('Ошибка проверки нарушений: $e');
      return {'success': false, 'violation': false};
    }
  }

  Future<List<Map<String, dynamic>>> getViolations({dynamic userId}) async {
    try {
      String url = ApiConfig.getViolations;
      if (userId != null) {
        final uid = _toInt(userId);
        if (uid > 0) url += '?user_id=$uid';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['violations'] is List) {
          return List<Map<String, dynamic>>.from(data['violations']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения нарушений: $e');
      return [];
    }
  }
}