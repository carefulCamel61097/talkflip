import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';

class TranslationException implements Exception {
  final String message;
  const TranslationException(this.message);

  @override
  String toString() => 'TranslationException: $message';
}

class TranslationService {
  final Dio _dio;

  TranslationService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.translationWorkerUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            ));

  Future<String> translate({
    required String text,
    required String source,
    required String target,
  }) async {
    try {
      final response = await _dio.post(
        '',
        data: {
          'text': text,
          'source': source,
          'target': target,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const TranslationException('Unexpected response shape');
      }
      final translatedText = data['translatedText'];
      if (translatedText is! String) {
        throw const TranslationException('No translation in response');
      }
      return translatedText;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('Translation DioException: ${e.message}');
      throw TranslationException(_userMessageFor(e));
    } on TranslationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('Translation unexpected error: $e');
      throw const TranslationException('Translation failed');
    }
  }

  String _userMessageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Translation timed out';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      default:
        return 'Translation failed';
    }
  }
}

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});
