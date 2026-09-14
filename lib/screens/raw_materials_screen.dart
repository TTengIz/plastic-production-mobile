import 'package:flutter/material.dart';
import '../services/materials_service.dart';
import '../services/role_service.dart';
import '../services/auth_service.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final _materialsService = MaterialsService();
  final _authService = AuthService();
  late final RoleService _roleService;
  bool _isLoading = false;
  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _roleService = RoleService(_authService);
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    _materials = await _materialsService.getMaterials();
    setState(() => _isLoading = false);
  }

  void _showAddMaterialDialog() {
    final nameController = TextEditingController();
    final thicknessController = TextEditingController();
    final colorController = TextEditingController();
    final quantityController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить материал'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thicknessController,
                decoration: const InputDecoration(
                  labelText: 'Толщина',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Цвет',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Количество',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Введите название')),
                );
                return;
              }

              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final success = await _materialsService.addMaterial(
                name: nameController.text.trim(),
                thickness: thicknessController.text.trim(),
                color: colorController.text.trim(),
                quantity: int.tryParse(quantityController.text) ?? 0,
              );

              setState(() => _isLoading = false);

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Материал добавлен'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                await _loadMaterials();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка добавления'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _showEditMaterialDialog(Map<String, dynamic> material) {
    final nameController = TextEditingController(text: material['name']);
    final thicknessController = TextEditingController(text: material['thickness']);
    final colorController = TextEditingController(text: material['color']);
    final quantityController = TextEditingController(text: material['quantity']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактировать материал'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thicknessController,
                decoration: const InputDecoration(
                  labelText: 'Толщина',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Цвет',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Количество',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final success = await _materialsService.updateMaterial(
                materialId: material['id'],
                name: nameController.text.trim(),
                thickness: thicknessController.text.trim(),
                color: colorController.text.trim(),
                quantity: int.tryParse(quantityController.text) ?? 0,
              );

              setState(() => _isLoading = false);

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Материал обновлен'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                await _loadMaterials();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка обновления'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int materialId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить материал'),
        content: Text('Вы уверены, что хотите удалить "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final success = await _materialsService.deleteMaterial(materialId);

              setState(() => _isLoading = false);

              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Материал удален'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                await _loadMaterials();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка удаления'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _roleService.isAdmin || _roleService.isManager;

    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _showAddMaterialDialog,
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadMaterials,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _materials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 80,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет материалов',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 8),
                          const Text('Нажмите "Добавить" чтобы создать'),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final material = _materials[index];
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
                            material['name'] ?? 'Без названия',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (material['thickness'] != null && material['thickness'].toString().isNotEmpty)
                                Text('Толщина: ${material['thickness']}'),
                              if (material['color'] != null && material['color'].toString().isNotEmpty)
                                Text('Цвет: ${material['color']}'),
                              Text(
                                'Количество: ${material['quantity'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          trailing: canEdit
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditMaterialDialog(material);
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(material['id'], material['name']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Редактировать'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Удалить', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
