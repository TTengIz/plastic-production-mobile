import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
  });
}

class UpdateService {
  static const String manifestUrl = 'http://api.crystal-box.ru/API/APP/version.json';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      print('🔍 Проверка обновлений: текущая=$currentCode');

      final response = await http
          .get(Uri.parse('$manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final serverCode = int.tryParse(data['version_code']?.toString() ?? '') ?? 0;

      print('🔍 Проверка обновлений: серверная=$serverCode');

      if (serverCode > currentCode) {
        print('🔍 Обновление доступно!');
        return UpdateInfo(
          versionCode: serverCode,
          versionName: data['version_name']?.toString() ?? '',
          apkUrl: data['apk_url']?.toString() ?? '',
          notes: data['notes']?.toString() ?? '',
        );
      }
      return null;
    } catch (e) {
      print('Проверка обновлений не удалась: $e');
      return null;
    }
  }

  Future<File> downloadApk(String url, Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/app-update.apk');
    if (await file.exists()) await file.delete();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}'));
      final response = await client.send(request);
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      final total = response.contentLength ?? -1;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  Future<void> openApk(File file) async {
    // Открываем системный установщик Android.
    // Приложение остаётся открытым; новая версия подхватится
    // при следующем запуске.
    await OpenFilex.open(file.path);
  }
}

bool _updateDialogShownThisSession = false;

/// Проверить обновления и показать диалог, если есть новая версия.
Future<void> showUpdateCheck(BuildContext context) async {
  if (_updateDialogShownThisSession) return;
  _updateDialogShownThisSession = true;

  final service = UpdateService();
  final update = await service.checkForUpdate();
  if (update == null || !context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UpdateDialog(update: update, service: service),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  final UpdateService service;

  const _UpdateDialog({required this.update, required this.service});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final file = await widget.service.downloadApk(widget.update.apkUrl, (p) {
        if (mounted) setState(() => _progress = p);
      });
      await widget.service.openApk(file);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'Не удалось загрузить обновление: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Доступна версия ${widget.update.versionName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.update.notes.isNotEmpty) Text(widget.update.notes),
          if (_progress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('Загрузка: ${((_progress ?? 0) * 100).toStringAsFixed(0)}%'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        if (_progress == null) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Позже')),
          ElevatedButton(onPressed: _startUpdate, child: const Text('Обновить')),
        ],
      ],
    );
  }
}