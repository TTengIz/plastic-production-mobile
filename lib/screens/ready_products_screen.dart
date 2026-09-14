import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class ReadyProductsScreen extends StatefulWidget {
  const ReadyProductsScreen({super.key});

  @override
  State<ReadyProductsScreen> createState() => _ReadyProductsScreenState();
}

class _ReadyProductsScreenState extends State<ReadyProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://api.crystal-box.ru/API/warehouse/get_ready.php'),
      ).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(data['products']);
          });
        }
      }
    } catch (e) {
      print('Ошибка загрузки: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final locController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить готовое изделие'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Наименование')),
            TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Количество'), keyboardType: TextInputType.number),
            TextField(controller: locController, decoration: const InputDecoration(labelText: 'Местонахождение (необязательно)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addProduct(nameController.text, int.tryParse(qtyController.text) ?? 0, locController.text);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct(String name, int qty, String location) async {
    if (name.isEmpty || qty <= 0) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await http.post(
        Uri.parse('http://api.crystal-box.ru/API/warehouse/add_ready.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'product_name': name, 'quantity': qty, 'location': location}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        Navigator.pop(context);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено'), backgroundColor: Colors.green));
          _loadProducts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сети'), backgroundColor: Colors.red));
        print(e);
      }
    }
  }

  Future<void> _showLocationDialog(String id, String currentLocation) async {
    final locController = TextEditingController(text: currentLocation);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить местонахождение'),
        content: TextField(controller: locController, decoration: const InputDecoration(labelText: 'Местонахождение')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateLocation(id, locController.text);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocation(String id, String location) async {
    try {
      final response = await http.post(
        Uri.parse('http://api.crystal-box.ru/API/warehouse/update_location.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'location': location}),
      );
      final data = jsonDecode(response.body);
      if (mounted && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Обновлено'), backgroundColor: Colors.green));
        _loadProducts();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _showTakeDialog(String id, String name, int currentQty) async {
    final qtyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Взять: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Доступно: $currentQty шт.'),
            const SizedBox(height: 10),
            TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Сколько взять?'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(context);
              await _takeProduct(id, int.tryParse(qtyController.text) ?? 0);
            },
            child: const Text('Взять'),
          ),
        ],
      ),
    );
  }

  Future<void> _takeProduct(String id, int takeQty) async {
    if (takeQty <= 0) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await http.post(
        Uri.parse('http://api.crystal-box.ru/API/warehouse/take_ready.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'take_quantity': takeQty}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        Navigator.pop(context);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Продукция взята'), backgroundColor: Colors.green));
          _loadProducts();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка сети'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Готовые изделия')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Добавить вручную'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('Склад пуст'))
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final item = _products[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(item['product_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Количество: ${item['quantity']} шт.'),
                              Text(
                                'Местонахождение: ${item['location']?.isEmpty ?? true ? "Не указано" : item['location']}',
                                style: TextStyle(color: (item['location']?.isEmpty ?? true) ? Colors.orange : Colors.green),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_location, color: Colors.blue),
                                tooltip: 'Изменить место',
                                onPressed: () => _showLocationDialog(item['id'].toString(), item['location'] ?? ''),
                              ),
                              IconButton(
                                icon: const Icon(Icons.inventory_2, color: Colors.orange),
                                tooltip: 'Взять со склада',
                                onPressed: () => _showTakeDialog(item['id'].toString(), item['product_name'], item['quantity']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
