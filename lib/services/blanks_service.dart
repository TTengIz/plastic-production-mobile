import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class BlanksService {
  Future<List<Map<String, dynamic>>> getBlanks() async {
    try {
      print('Запрос заготовок: ${ApiConfig.getBlanks}');
      
      final response = await http.get(
        Uri.parse(ApiConfig.getBlanks),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус: ${response.statusCode}');
      print('Ответ: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['blanks']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения заготовок: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addBlanks({
    required int recipeId,
    required int quantity,
    required int userId,
  }) async {
    try {
      print('Добавление заготовок: recipe_id=$recipeId, quantity=$quantity');
      
      final response = await http.post(
        Uri.parse(ApiConfig.addBlanks),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipe_id': recipeId,
          'quantity': quantity,
          'user_id': userId,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус добавления: ${response.statusCode}');
      print('Ответ добавления: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return jsonDecode(response.body);
    } catch (e) {
      print('Ошибка добавления заготовок: $e');
      return {'success': false, 'message': 'Ошибка подключения'};
    }
  }

  Future<Map<String, dynamic>> updateBlanks({
    required int blankId,
    required int newQuantity,
  }) async {
    try {
      print('Обновление заготовки: blank_id=$blankId, new_quantity=$newQuantity');
      
      final response = await http.post(
        Uri.parse(ApiConfig.updateBlanks),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'blank_id': blankId,
          'new_quantity': newQuantity,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус обновления: ${response.statusCode}');
      print('Ответ обновления: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 400) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Ошибка сервера'};
    } catch (e) {
      print('Ошибка обновления заготовки: $e');
      return {'success': false, 'message': 'Ошибка подключения'};
    }
  }

  Future<bool> deleteBlanks(int blankId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteBlanks),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'blank_id': blankId,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка удаления заготовки: $e');
      return false;
    }
  }
}
