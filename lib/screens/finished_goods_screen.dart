import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/production_service.dart';

class FinishedGoodsScreen extends StatefulWidget {
  const FinishedGoodsScreen({super.key});

  @override
  State<FinishedGoodsScreen> createState() => _FinishedGoodsScreenState();
}

class _FinishedGoodsScreenState extends State<FinishedGoodsScreen> {
  final _productionService = ProductionService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _goods = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    _goods = await _productionService.getFinishedGoods();
    if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _goods.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет готовой продукции',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _goods.length,
                    itemBuilder: (context, index) {
                      final good = _goods[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.inventory,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            good['blank_name'] ?? 'Без названия',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Количество: ${good['quantity'] ?? 0} шт',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (good['created_by_name'] != null)
                                Text('Сдал: ${good['created_by_name']}'),
                              Text('Дата: ${_formatDateTime(good['created_at'])}'),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
