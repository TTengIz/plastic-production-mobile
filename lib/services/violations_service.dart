import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ViolationsService {
  Future<Map<String, dynamic>> checkViolation({
    required int userId,
    required int shiftId,
    required String type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.checkViolations),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'shift_id': shiftId,
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

  Future<List<Map<String, dynamic>>> getViolations({int? userId}) async {
    try {
      String url = ApiConfig.getViolations;
      if (userId != null) {
        url += '?user_id=$userId';
      }
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
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
