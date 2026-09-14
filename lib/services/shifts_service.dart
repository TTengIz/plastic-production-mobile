import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ShiftsService {
  final AuthService _auth = AuthService();

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (_auth.token.isNotEmpty) 'Authorization': 'Bearer ${_auth.token}',
      };

  /// Приводим id к int безопасно (сервер может отдать строкой)
  int _toInt(dynamic value) => int.tryParse(value.toString()) ?? 0;

  Future<bool> startShift(dynamic userId) async {
    try {
      final uid = _toInt(userId);
      if (uid <= 0) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.startShift),
        headers: _jsonHeaders,
        body: jsonEncode({'user_id': uid}),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка начала смены: $e');
      return false;
    }
  }

  Future<bool> endShift(dynamic userId) async {
    try {
      final uid = _toInt(userId);
      if (uid <= 0) return false;

      final response = await http.post(
        Uri.parse(ApiConfig.endShift),
        headers: _jsonHeaders,
        body: jsonEncode({'user_id': uid}),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка завершения смены: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getShifts({dynamic userId}) async {
    try {
      String url = ApiConfig.getShifts;
      if (userId != null) {
        final uid = _toInt(userId);
        if (uid > 0) url += '?user_id=$uid';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _jsonHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['shifts'] is List) {
          return List<Map<String, dynamic>>.from(data['shifts']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения смен: $e');
      return [];
    }
  }
}