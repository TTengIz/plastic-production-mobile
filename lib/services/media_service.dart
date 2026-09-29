import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();
  final AuthService _auth = AuthService();

  Map<String, String> get _headers => {
        if (_auth.token.isNotEmpty) 'Authorization': 'Bearer ${_auth.token}',
      };

  int _toInt(dynamic value) => int.tryParse(value.toString()) ?? 0;

  // ============ ЗАГРУЗКА ============

  Future<Map<String, dynamic>> uploadFileMultipart({
    required String filePath,
    required String fileName,
    required String category,
    required dynamic uploadedBy,
    int? folderId,
  }) async {
    try {
      final file = File(filePath);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://api.crystal-box.ru/API/media/upload_multipart.php'),
      );

      // Заголовки токена (MultipartRequest использует отдельный метод)
      request.headers.addAll(_headers);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ),
      );

      request.fields['category'] = category;
      request.fields['uploaded_by'] = _toInt(uploadedBy).toString();
      if (folderId != null && folderId > 0) {
        request.fields['folder_id'] = folderId.toString();
      }

      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        try {
          return jsonDecode(response.body);
        } catch (_) {
          return {'success': false, 'error': 'Ошибка загрузки: ${response.statusCode}'};
        }
      }
    } catch (e) {
      print('Ошибка загрузки файла: $e');
      return {'success': false, 'error': 'Ошибка: $e'};
    }
  }

  Future<Map<String, dynamic>?> pickAndUploadImage({
    required String category,
    required dynamic uploadedBy,
    required ImageSource source,
    int? folderId,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return await uploadFileMultipart(
        filePath: pickedFile.path,
        fileName: pickedFile.name,
        category: category,
        uploadedBy: uploadedBy,
        folderId: folderId,
      );
    } catch (e) {
      print('Ошибка выбора и загрузки изображения: $e');
      return {'success': false, 'error': 'Ошибка: $e'};
    }
  }

  Future<Map<String, dynamic>?> pickAndUploadVideo({
    required String category,
    required dynamic uploadedBy,
    int? folderId,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null) return null;

      final MediaInfo? info = await VideoCompress.compressVideo(
        pickedFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (info == null) {
        return {'success': false, 'error': 'Ошибка сжатия видео'};
      }

      final compressedFile = File(info.file!.path);

      final result = await uploadFileMultipart(
        filePath: compressedFile.path,
        fileName: pickedFile.name,
        category: category,
        uploadedBy: uploadedBy,
        folderId: folderId,
      );

      await compressedFile.delete();
      return result;
    } catch (e) {
      print('Ошибка выбора и загрузки видео: $e');
      return {'success': false, 'error': 'Ошибка: $e'};
    }
  }

  // ============ УДАЛЕНИЕ ФАЙЛА ============

  Future<Map<String, dynamic>> deleteMedia({required int mediaId}) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.deleteMedia),
            headers: {
              'Content-Type': 'application/json',
              ..._headers,
            },
            body: jsonEncode({'media_id': mediaId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Ошибка удаления: ${response.statusCode}'};
    } catch (e) {
      print('Ошибка удаления файла: $e');
      return {'success': false, 'error': 'Ошибка: $e'};
    }
  }

  // ============ ПАПКИ ============

  Future<Map<String, dynamic>> createFolder({
    required String name,
    required String category,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://api.crystal-box.ru/API/media/create_folder.php'),
            headers: {
              'Content-Type': 'application/json',
              ..._headers,
            },
            body: jsonEncode({
              'name': name.trim(),
              'category': category,
            }),
          )
          .timeout(const Duration(seconds: 30));

      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {'success': false, 'error': 'Ошибка: HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('Ошибка создания папки: $e');
      return {'success': false, 'error': 'Ошибка подключения'};
    }
  }

  Future<List<Map<String, dynamic>>> getFolders({required String category}) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://api.crystal-box.ru/API/media/get_folders.php?category=$category'),
            headers: _headers,
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['folders'] is List) {
          return List<Map<String, dynamic>>.from(data['folders']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения папок: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> deleteFolder({required int folderId}) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://api.crystal-box.ru/API/media/delete_folder.php'),
            headers: {
              'Content-Type': 'application/json',
              ..._headers,
            },
            body: jsonEncode({'folder_id': folderId}),
          )
          .timeout(const Duration(seconds: 30));

      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {'success': false, 'error': 'Ошибка: HTTP ${response.statusCode}'};
      }
    } catch (e) {
      print('Ошибка удаления папки: $e');
      return {'success': false, 'error': 'Ошибка подключения'};
    }
  }

  // ============ ПОЛУЧЕНИЕ ФАЙЛОВ ============

  Future<List<Map<String, dynamic>>> getMedia({
    required String category,
    int? folderId,
  }) async {
    try {
      String url = 'http://api.crystal-box.ru/API/media/get_media.php?category=$category';
      if (folderId != null && folderId > 0) {
        url += '&folder_id=$folderId';
      }

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['media'] is List) {
          return List<Map<String, dynamic>>.from(data['media']);
        }
      }
      return [];
    } catch (e) {
      print('Ошибка получения медиа: $e');
      return [];
    }
  }
}