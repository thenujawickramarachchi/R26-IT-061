import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/prediction_result.dart';

class PredictionApiService {
  static const String _baseUrl =
      'https://sahan-kaveesha-r26-it-061-dengue-api.hf.space';

  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<PredictionResult> predictFuture({
    required int year,
    required int week,
  }) async {
    final uri = Uri.parse('$_baseUrl/predict-future');

    debugPrint('========== DENGUE PREDICTION REQUEST ==========');
    debugPrint('Request started');
    debugPrint('URL: $uri');
    debugPrint('Year: $year');
    debugPrint('Week: $week');

    try {
      final requestBody = jsonEncode({'year': year, 'week': week});

      debugPrint('Request body: $requestBody');
      debugPrint('Sending POST request...');

      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(_requestTimeout);

      debugPrint('Response received');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('HTTP request successful');

        final responseData = _decodeJsonObject(response.body);

        debugPrint('JSON decoded successfully');
        debugPrint('Creating PredictionResult...');

        final result = PredictionResult.fromJson(responseData);

        debugPrint('PredictionResult created successfully');
        debugPrint(
          'Predicted outbreak level: ${result.predictedOutbreakLevel}',
        );
        debugPrint('========== REQUEST COMPLETE ==========');

        return result;
      }

      debugPrint('Server returned an error response');

      final responseData = _tryDecodeJsonObject(response.body);
      final serverMessage = _extractErrorMessage(responseData);

      if (serverMessage != null) {
        debugPrint('Server message: $serverMessage');

        throw PredictionApiException(serverMessage);
      }

      if (response.statusCode == 404) {
        throw const PredictionApiException(
          'The prediction service is currently unavailable.',
        );
      }

      if (response.statusCode == 422) {
        throw const PredictionApiException(
          'The selected year or week could not be processed. '
          'Please check your selections and try again.',
        );
      }

      if (response.statusCode >= 500) {
        throw const PredictionApiException(
          'The prediction server encountered a problem. '
          'Please try again.',
        );
      }

      throw PredictionApiException(
        'Unable to complete the prediction request '
        '(status ${response.statusCode}).',
      );
    } on TimeoutException {
      debugPrint('ERROR: Request timed out after 30 seconds');

      throw const PredictionApiException(
        'The prediction server is taking too long to respond. '
        'Please try again.',
      );
    } on SocketException catch (error) {
      debugPrint('ERROR: SocketException');
      debugPrint(error.toString());

      throw const PredictionApiException(
        'No internet connection. '
        'Please check your network and try again.',
      );
    } on http.ClientException catch (error) {
      debugPrint('ERROR: HTTP ClientException');
      debugPrint(error.toString());

      throw const PredictionApiException(
        'Unable to connect to the prediction server. '
        'Please check your internet connection and try again.',
      );
    } on FormatException catch (error) {
      debugPrint('ERROR: Invalid JSON response');
      debugPrint(error.toString());

      throw const PredictionApiException(
        'The prediction server returned an invalid response. '
        'Please try again.',
      );
    } on PredictionApiException catch (error) {
      debugPrint('Prediction API error: ${error.message}');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('UNEXPECTED ERROR: $error');
      debugPrint('Stack trace: $stackTrace');

      throw const PredictionApiException(
        'Unable to generate the prediction. '
        'Please try again.',
      );
    }
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);

    if (decoded is! Map) {
      throw const FormatException(
        'Expected a JSON object from the prediction server.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      debugPrint('Could not decode error response JSON: $error');
    }

    return null;
  }

  String? _extractErrorMessage(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    final detail = data['detail'];
    final message = data['message'];

    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return null;
  }
}

class PredictionApiException implements Exception {
  final String message;

  const PredictionApiException(this.message);

  @override
  String toString() => message;
}
