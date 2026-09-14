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

  Future<Map<String, dynamic>> uploadFileMultipart({
    required String filePath,
    required String fileName,
    required String category,
    required int uploadedBy,
  }) async {
    try {
      final file = File(filePath);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://api.crystal-box.ru/API/media/upload_multipart.php'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ),
      );

      request.fields['category'] = category;
      request.fields['uploaded_by'] = uploadedBy.toString();

      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Ошибка загрузки: ${response.statusCode}'};
      }
    } catch (e) {
      print('Ошибка загрузки файла: $e');
      return {'success': false, 'message': 'Ошибка: $e'};
    }
  }

  Future<Map<String, dynamic>?> pickAndUploadImage({
    required String category,
    required int uploadedBy,
    required ImageSource source,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final fileName = pickedFile.name;

      return await uploadFileMultipart(
        filePath: pickedFile.path,
        fileName: fileName,
        category: category,
        uploadedBy: uploadedBy,
      );
    } catch (e) {
      print('Ошибка выбора и загрузки изображения: $e');
      return {'success': false, 'message': 'Ошибка: $e'};
    }
  }

  Future<Map<String, dynamic>?> pickAndUploadVideo({
    required String category,
    required int uploadedBy,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null) return null;

      // Сжимаем видео
      final MediaInfo? info = await VideoCompress.compressVideo(
        pickedFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (info == null) {
        return {'success': false, 'message': 'Ошибка сжатия видео'};
      }

      final fileName = pickedFile.name;
      final compressedFile = File(info.file!.path);

      final result = await uploadFileMultipart(
        filePath: compressedFile.path,
        fileName: fileName,
        category: category,
        uploadedBy: uploadedBy,
      );

      // Очищаем сжатый файл
      await compressedFile.delete();

      return result;
    } catch (e) {
      print('Ошибка выбора и загрузки видео: $e');
      return {'success': false, 'message': 'Ошибка: $e'};
    }
  }
    /// Удаление видео/файла (S3 + БД). Права: admin / manager.
  Future<Map<String, dynamic>> deleteMedia({required int mediaId}) async {
    try {
      final auth = AuthService();

      final response = await http
          .post(
            Uri.parse(ApiConfig.deleteMedia),
            headers: {
              'Content-Type': 'application/json',
              if (auth.token.isNotEmpty)
                'Authorization': 'Bearer ${auth.token}',
            },
            body: jsonEncode({'media_id': mediaId}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Ошибка удаления: ${response.statusCode}'};
    } catch (e) {
      print('Ошибка удаления файла: $e');
      return {'success': false, 'message': 'Ошибка: $e'};
    }
  }
}
