import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MaterialsService {
  Future<List<Map<String, dynamic>>> getMaterials() async {
    try {
      print('Запрос материалов: ${ApiConfig.getMaterials}');
      
      final response = await http.get(
        Uri.parse(ApiConfig.getMaterials),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус: ${response.statusCode}');
      print('Ответ: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['materials']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения материалов: $e');
      return [];
    }
  }

  Future<bool> addMaterial({
    required String name,
    String? thickness,
    String? color,
    int quantity = 0,
  }) async {
    try {
      print('Добавление материала: $name, количество: $quantity');
      
      final response = await http.post(
        Uri.parse(ApiConfig.addMaterial),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'thickness': thickness ?? '',
          'color': color ?? '',
          'quantity': quantity,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус добавления: ${response.statusCode}');
      print('Ответ добавления: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка добавления материала: $e');
      return false;
    }
  }

  Future<bool> updateMaterial({
    required int materialId,
    String? name,
    String? thickness,
    String? color,
    int? quantity,
  }) async {
    try {
      final Map<String, dynamic> body = {'material_id': materialId};
      
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (thickness != null) body['thickness'] = thickness;
      if (color != null) body['color'] = color;
      if (quantity != null) body['quantity'] = quantity;

      final response = await http.post(
        Uri.parse(ApiConfig.updateMaterial),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус обновления: ${response.statusCode}');
      print('Ответ обновления: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка обновления материала: $e');
      return false;
    }
  }

  Future<bool> deleteMaterial(int materialId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteMaterial),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'material_id': materialId,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка удаления материала: $e');
      return false;
    }
  }
}
