import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TimeOffService {
  Future<List<Map<String, dynamic>>> getTimeOff() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getTimeOff),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['time_off']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения отпусков/больничных: $e');
      return [];
    }
  }

  Future<bool> addTimeOff({
    required int userId,
    required String type,
    required String startDate,
    required String endDate,
    required int createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.addTimeOff),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'type': type,
          'start_date': startDate,
          'end_date': endDate,
          'created_by': createdBy,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка добавления отпуска/больничного: $e');
      return false;
    }
  }

  Future<bool> deleteTimeOff(int timeOffId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteTimeOff),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'time_off_id': timeOffId,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка удаления отпуска/больничного: $e');
      return false;
    }
  }
}
