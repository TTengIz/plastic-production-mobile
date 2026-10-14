import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/violations_service.dart';

class ViolationsScreen extends StatefulWidget {
  const ViolationsScreen({super.key});

  @override
  State<ViolationsScreen> createState() => _ViolationsScreenState();
}

class _ViolationsScreenState extends State<ViolationsScreen> {
  final _authService = AuthService();
  final _violationsService = ViolationsService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _violations = [];

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  Future<void> _loadViolations() async {
    if (mounted) setState(() => _isLoading = true);

    final userId = _authService.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      _violations = await _violationsService.getViolations(userId: userId);
    } catch (e) {
      print('Ошибка загрузки нарушений: $e');
      _violations = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'Не указано';
    try {
      if (timeStr.contains(' ')) {
        final dateTime = DateTime.parse(timeStr);
        return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
      } else {
        return timeStr.substring(0, 5);
      }
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нарушения'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadViolations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _violations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Colors.green.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нарушений нет',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text('Отличная работа!'),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final violation = _violations[index];
                              final isLateStart = violation['violation_type'] == 'late_start';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isLateStart
                                        ? Colors.orange
                                        : Colors.red,
                                    child: Icon(
                                      isLateStart
                                          ? Icons.access_time
                                          : Icons.timer_off,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    isLateStart
                                        ? 'Опоздание'
                                        : 'Раннее завершение',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'На ${violation['violation_minutes']} минут',
                                        style: TextStyle(
                                          color: isLateStart
                                              ? Colors.orange
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Дата: ${_formatTime(violation['actual_time']?.toString())}',
                                      ),
                                      Text(
                                        'Зафиксировано: ${_formatTime(violation['created_at']?.toString())}',
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                            childCount: _violations.length,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}