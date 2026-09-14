import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ProductionService {
  final AuthService _auth = AuthService();

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (_auth.token.isNotEmpty) 'Authorization': 'Bearer ${_auth.token}',
      };

  /// Приводим id к int безопасно (сервер может отдать строкой)
  int _toInt(dynamic value) => int.tryParse(value.toString()) ?? 0;

  Future<Map<String, dynamic>> submitReport({
    required dynamic userId,
    required int recipeId,
    required int blanksTaken,
    required int itemsSubmitted,
    required String productName,
    required String startTime,
    String? defectReason,
  }) async {
    try {
      final uid = _toInt(userId);
      if (uid <= 0) {
        return {'success': false, 'message': 'Некорректный пользователь'};
      }

      print('Отчёт производства: recipe=$recipeId, взял=$blanksTaken, сдал=$itemsSubmitted');

      final Map<String, dynamic> body = {
        'user_id': uid,
        'recipe_id': recipeId,
        'blanks_taken': blanksTaken,
        'items_submitted': itemsSubmitted,
        'product_name': productName,
        'start_time': startTime,
      };

      if (defectReason != null && defectReason.isNotEmpty) {
        body['defect_reason'] = defectReason;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.productionReport),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectionTimeout);

      print('Статус: ${response.statusCode}');
      print('Ответ: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Добавляем в готовые изделия (локальное зеркало на сервере add_ready.php)
        await addToReadyProducts(
          productName: productName,
          quantity: itemsSubmitted,
        );
        return jsonDecode(response.body);
      }

      // Возвращаем ошибку сервера
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {
          'success': false,
          'message': 'Ошибка сервера (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      print('Ошибка отчёта: $e');
      return {'success': false, 'message': 'Ошибка подключения'};
    }
  }

  Future<List<Map<String, dynamic>>> getReports({dynamic userId}) async {
    try {
      String url = ApiConfig.getProductionReports;
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
        if (data['success'] == true && data['reports'] is List) {
          return List<Map<String, dynamic>>.from(data['reports']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения отчётов: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFinishedGoods() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getFinishedGoods),
        headers: _jsonHeaders,
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['goods'] is List) {
          return List<Map<String, dynamic>>.from(data['goods']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения готовой продукции: $e');
      return [];
    }
  }

  Future<void> addToReadyProducts({
    required String productName,
    required int quantity,
    String location = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://api.crystal-box.ru/API/warehouse/add_ready.php'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'product_name': productName,
          'quantity': quantity,
          'location': location,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Добавлено в готовые: ${data['success']}');
      }
    } catch (e) {
      print('Ошибка добавления в готовые: $e');
    }
  }
}