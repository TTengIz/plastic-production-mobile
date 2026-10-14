import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/shifts_service.dart';
import '../services/violations_service.dart';
import 'violations_screen.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _authService = AuthService();
  final _shiftsService = ShiftsService();
  final _violationsService = ViolationsService();
  bool _isLoading = false;
  bool _hasActiveShift = false;
  List<Map<String, dynamic>> _shifts = [];

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userId = _authService.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _shifts = await _shiftsService.getShifts(userId: userId);
    _hasActiveShift = _shifts.any((shift) => shift['status'] == 'active');

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _startShift() async {
    final userId = _authService.userId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    final success = await _shiftsService.startShift(userId);

    if (!success) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка начала смены'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Один запрос — обновляем список смен
    _shifts = await _shiftsService.getShifts(userId: userId);
    _hasActiveShift = _shifts.any((s) => s['status'] == 'active');

    final activeShift = _shifts.firstWhere(
      (s) => s['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Смена начата'), backgroundColor: Colors.green),
      );
    }

    // === Проверка нарушения в фоне (не блокирует UI) ===
    if (activeShift.isNotEmpty) {
      _violationsService.checkViolation(
        userId: userId,
        shiftId: activeShift['id'],
        type: 'late_start',
      ).then((result) {
        if (result['violation'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Зафиксировано опоздание'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _endShift() async {
    final userId = _authService.userId;
    if (userId == null) return;

    // === Берём активную смену из локального кеша (НЕ запрашиваем сервер) ===
    final activeShift = _shifts.firstWhere(
      (s) => s['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    setState(() => _isLoading = true);

    final success = await _shiftsService.endShift(userId);

    if (!success) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка завершения смены'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Один запрос — обновляем список смен
    await _loadShifts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Смена завершена'), backgroundColor: Colors.green),
      );
    }

    // === Проверка нарушения в фоне ===
    if (activeShift.isNotEmpty) {
      _violationsService.checkViolation(
        userId: userId,
        shiftId: activeShift['id'],
        type: 'early_end',
      ).then((result) {
        if (result['violation'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Раннее завершение смены'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Не указано';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _calculateDuration(String? startTime, String? endTime) {
    if (startTime == null) return '0ч 0м';
    try {
      final start = DateTime.parse(startTime);
      final end = endTime != null ? DateTime.parse(endTime) : DateTime.now();
      final duration = end.difference(start);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}ч ${minutes}м';
    } catch (e) {
      return '0ч 0м';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadShifts,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Карточка управления сменой
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Управление сменой',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_hasActiveShift)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Смена активна',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Смена не начата',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : (_hasActiveShift ? _endShift : _startShift),
                              icon: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(_hasActiveShift ? Icons.stop : Icons.play_arrow),
                              label: Text(_hasActiveShift ? 'Завершить смену' : 'Начать смену'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasActiveShift ? Colors.red : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Кнопка просмотра нарушений
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ViolationsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning),
                    label: const Text('Мои нарушения'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Заголовок истории
                  Row(
                    children: [
                      Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'История смен',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Список смен
                  if (_isLoading && _shifts.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (_shifts.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Нет смен',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ..._shifts.take(10).map((shift) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: shift['status'] == 'active'
                                  ? Colors.green
                                  : Colors.grey,
                              child: Icon(
                                shift['status'] == 'active'
                                    ? Icons.play_arrow
                                    : Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              shift['status'] == 'active' ? 'Активная смена' : 'Завершена',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: shift['status'] == 'active' ? Colors.green : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16),
                                    const SizedBox(width: 4),
                                    Text('Начало: ${_formatDateTime(shift['start_time'])}'),
                                  ],
                                ),
                                if (shift['end_time'] != null) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.flag, size: 16),
                                      const SizedBox(width: 4),
                                      Text('Конец: ${_formatDateTime(shift['end_time'])}'),
                                    ],
                                  ),
                                ],
                                Row(
                                  children: [
                                    const Icon(Icons.timer, size: 16),
                                    const SizedBox(width: 4),
                                    Text('Длительность: ${_calculateDuration(shift['start_time'], shift['end_time'])}'),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}