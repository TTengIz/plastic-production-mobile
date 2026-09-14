import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class FinanceService {
  final AuthService _auth = AuthService();

  /// Заголовки с Bearer-токеном (если пользователь авторизован)
  Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_auth.token.isNotEmpty) 'Authorization': 'Bearer ${_auth.token}',
      };

  /// Получение списка ставок
  Future<List<Map<String, dynamic>>> getRates() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.getRates),
            headers: _jsonHeaders,
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = _decodeJsonObject(response.body);

      if (response.statusCode == 200 && data?['success'] == true) {
        final rates = data!['rates'];

        if (rates is List) {
          return rates
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }

      return [];
    } catch (e) {
      debugPrint('FinanceService.getRates error: $e');
      return [];
    }
  }

  /// Установка ставки пользователю
  Future<bool> setRate({
    required int userId,
    required String rateType,
    required double rateValue,
  }) async {
    try {
      final type = rateType.trim();

      if (userId <= 0 || type.isEmpty || rateValue.isNaN || rateValue < 0) {
        debugPrint('FinanceService.setRate: некорректные данные');
        return false;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.setRate),
            headers: _jsonHeaders,
            body: jsonEncode({
              'user_id': userId,
              'rate_type': type,
              'rate_value': rateValue,
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = _decodeJsonObject(response.body);

      return response.statusCode == 200 && data?['success'] == true;
    } catch (e) {
      debugPrint('FinanceService.setRate error: $e');
      return false;
    }
  }

  /// Получение заработка пользователя
  Future<Map<String, dynamic>> getEarnings({
    required int userId,
    String period = 'month',
  }) async {
    try {
      final safePeriod = period.trim().isEmpty ? 'month' : period.trim();

      final uri = Uri.parse(ApiConfig.getEarnings).replace(
        queryParameters: {
          'user_id': userId.toString(),
          'period': safePeriod,
        },
      );

      final response = await http
          .get(
            uri,
            headers: _jsonHeaders,
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = _decodeJsonObject(response.body);

      if (response.statusCode == 200 && data != null) {
        return data;
      }

      return {
        'success': false,
        'message': data?['message'] ??
            'Ошибка получения заработка (HTTP ${response.statusCode})',
      };
    } catch (e) {
      debugPrint('FinanceService.getEarnings error: $e');
      return {
        'success': false,
        'message': 'Ошибка подключения к серверу',
      };
    }
  }

  /// Безопасный парсинг JSON-объекта
  Map<String, dynamic>? _decodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}