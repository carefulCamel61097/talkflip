import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';

class TranslationException implements Exception {
  final String message;

  /// True when the Worker's free-tier monthly cap has been hit. This is a
  /// non-retryable state (retrying won't help until the month resets), so the
  /// UI surfaces it differently from a generic, retryable failure.
  final bool limitReached;

  const TranslationException(this.message, {this.limitReached = false});

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
      final data = e.response?.data;
      if (e.response?.statusCode == 429 &&
          data is Map &&
          data['code'] == 'MONTHLY_LIMIT') {
        throw const TranslationException(
          'Free translation limit reached this month',
          limitReached: true,
        );
      }
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
