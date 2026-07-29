import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/prediction_result.dart';

class PredictionApiService {
  static const String baseUrl =
      'https://sahan-kaveesha-r26-it-061-dengue-api.hf.space';

  Future<PredictionResult> predictFuture({
    required int year,
    required int week,
  }) async {
    final uri = Uri.parse('$baseUrl/predict-future');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'year': year,
              'week': week,
            }),
          )
          .timeout(const Duration(seconds: 90));

      Map<String, dynamic>? responseData;

      try {
        responseData =
            jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        responseData = null;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData != null) {
        return PredictionResult.fromJson(responseData);
      }

      final errorMessage =
          responseData?['detail']?.toString() ??
          responseData?['message']?.toString() ??
          'Request failed. Status code: ${response.statusCode}';

      throw PredictionApiException(errorMessage);
    } on SocketException {
      throw const PredictionApiException(
        'No internet connection.',
      );
    } on TimeoutException {
      throw const PredictionApiException(
        'The prediction server is taking too long to respond. Please try again.',
      );
    } on FormatException {
      throw const PredictionApiException(
        'The server returned an invalid response.',
      );
    } on PredictionApiException {
      rethrow;
    } catch (error) {
      throw PredictionApiException(
        'Prediction failed: $error',
      );
    }
  }
}

class PredictionApiException implements Exception {
  final String message;

  const PredictionApiException(this.message);

  @override
  String toString() => message;
}