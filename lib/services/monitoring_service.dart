import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MonitoringService {
  Future<Map<String, dynamic>> getDailyActivity({required String date}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getDailyActivity}?date=$date'),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'activity': []};
    } catch (e) {
      print('Ошибка получения активности: $e');
      return {'success': false, 'activity': []};
    }
  }
}
