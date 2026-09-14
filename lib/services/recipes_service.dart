import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class RecipesService {
  Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      print('Запрос рецептов: ${ApiConfig.getRecipes}');
      
      final response = await http.get(
        Uri.parse(ApiConfig.getRecipes),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус: ${response.statusCode}');
      print('Ответ: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['recipes']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения рецептов: $e');
      return [];
    }
  }

  Future<bool> addRecipe({
    required String blankName,
    required int materialId,
    required int blanksPerSheet,
    int rivetsPerItem = 0,
  }) async {
    try {
      print('Добавление рецепта: $blankName');
      
      final response = await http.post(
        Uri.parse(ApiConfig.addRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'blank_name': blankName,
          'material_id': materialId,
          'blanks_per_sheet': blanksPerSheet,
          'rivets_per_item': rivetsPerItem,
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
      print('Ошибка добавления рецепта: $e');
      return false;
    }
  }

  Future<bool> updateRecipe({
    required int recipeId,
    String? blankName,
    int? materialId,
    int? blanksPerSheet,
    int? rivetsPerItem,
  }) async {
    try {
      final Map<String, dynamic> body = {'recipe_id': recipeId};
      
      if (blankName != null && blankName.isNotEmpty) body['blank_name'] = blankName;
      if (materialId != null) body['material_id'] = materialId;
      if (blanksPerSheet != null) body['blanks_per_sheet'] = blanksPerSheet;
      if (rivetsPerItem != null) body['rivets_per_item'] = rivetsPerItem;

      final response = await http.post(
        Uri.parse(ApiConfig.updateRecipe),
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
      print('Ошибка обновления рецепта: $e');
      return false;
    }
  }

  Future<bool> deleteRecipe(int recipeId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deleteRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipe_id': recipeId,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Ошибка удаления рецепта: $e');
      return false;
    }
  }

  // Метод для расчёта количества листов
  int calculateSheetsNeeded(int blanksToAdd, int blanksPerSheet) {
    if (blanksPerSheet <= 0) return 0;
    return (blanksToAdd / blanksPerSheet).ceil();
  }
}
