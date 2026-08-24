import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/prediction_result.dart';
import '../models/area_risk_result.dart';

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
      final requestBody = jsonEncode({
        'year': year,
        'week': week,
      });

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
        final responseData = _decodeJsonObject(response.body);

        _validatePredictionResponse(responseData);

        debugPrint('JSON decoded successfully');
        debugPrint('Creating PredictionResult...');

        final result = PredictionResult.fromJson(responseData);

        debugPrint('PredictionResult created successfully');
        debugPrint(
          'Predicted outbreak level: ${result.predictedOutbreakLevel}',
        );
        debugPrint('========== DENGUE REQUEST COMPLETE ==========');

        return result;
      }

      debugPrint('Server returned an error response');

      if (response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504) {
        throw const PredictionApiException(
          'The hosted API may be waking up. '
          'Please try again in a few moments.',
        );
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
          'Please try again in a few moments.',
        );
      }

      final responseData = _tryDecodeJsonObject(response.body);
      final serverMessage = _extractErrorMessage(responseData);

      if (serverMessage != null) {
        debugPrint('Server message: $serverMessage');
        throw PredictionApiException(serverMessage);
      }

      throw PredictionApiException(
        'Unable to complete the prediction request '
        '(status ${response.statusCode}).',
      );
    } on TimeoutException {
      debugPrint(
        'ERROR: Request timed out after '
        '${_requestTimeout.inSeconds} seconds',
      );
      throw const PredictionApiException(
        'The prediction request timed out. '
        'The hosted API may be waking up. '
        'Please try again in a few moments.',
      );
    } on SocketException catch (error) {
      debugPrint('ERROR: SocketException');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'No internet connection. '
        'Please check your network and try again.',
      );
    } on HandshakeException catch (error) {
      debugPrint('ERROR: HandshakeException');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'Unable to establish a secure connection '
        'to the prediction server. '
        'Please try again.',
      );
    } on http.ClientException catch (error) {
      debugPrint('ERROR: HTTP ClientException');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'Unable to connect to the prediction server. '
        'Please check your internet connection and try again.',
      );
    } on FormatException catch (error) {
      debugPrint('ERROR: Invalid server response');
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

  Future<AreaRiskResult> predictAreaRisk({
    required int year,
    required int week,
    required String area,
  }) async {
    final uri = Uri.parse('$_baseUrl/predict-area-risk');

    debugPrint('========== AREA RISK PREDICTION REQUEST ==========');
    debugPrint('Request started');
    debugPrint('URL: $uri');
    debugPrint('Year: $year');
    debugPrint('Week: $week');
    debugPrint('Area: $area');

    try {
      final requestBody = jsonEncode({
        'year': year,
        'week': week,
        'area': area,
      });

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

      debugPrint('Area response received');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = _decodeJsonObject(response.body);

        _validateAreaRiskResponse(responseData);

        debugPrint('Area JSON decoded successfully');
        debugPrint('Creating AreaRiskResult...');

        final result = AreaRiskResult.fromJson(responseData);

        debugPrint('AreaRiskResult created successfully');
        debugPrint(
          'Predicted area risk level: ${result.predictedAreaRiskLevel}',
        );
        debugPrint('========== AREA RISK REQUEST COMPLETE ==========');

        return result;
      }

      debugPrint('Area risk server returned an error response');

      if (response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504) {
        throw const PredictionApiException(
          'The hosted API may be waking up. '
          'Please try again in a few moments.',
        );
      }

      if (response.statusCode == 404) {
        throw const PredictionApiException(
          'Area risk prediction service is currently unavailable.',
        );
      }

      if (response.statusCode == 422) {
        throw const PredictionApiException(
          'The selected year, week, or area could not be processed. '
          'Please check your selections and try again.',
        );
      }

      if (response.statusCode >= 500) {
        throw const PredictionApiException(
          'The area risk prediction server encountered a problem. '
          'Please try again in a few moments.',
        );
      }

      final responseData = _tryDecodeJsonObject(response.body);
      final serverMessage = _extractErrorMessage(responseData);

      if (serverMessage != null) {
        debugPrint('Area risk server message: $serverMessage');
        throw PredictionApiException(serverMessage);
      }

      throw PredictionApiException(
        'Unable to complete the area risk prediction request '
        '(status ${response.statusCode}).',
      );
    } on TimeoutException {
      debugPrint(
        'ERROR: Area risk request timed out after '
        '${_requestTimeout.inSeconds} seconds',
      );
      throw const PredictionApiException(
        'The area risk prediction request timed out. '
        'The hosted API may be waking up. '
        'Please try again in a few moments.',
      );
    } on SocketException catch (error) {
      debugPrint('ERROR: Area risk SocketException');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'No internet connection. '
        'Please check your network and try again.',
      );
    } on HandshakeException catch (error) {
      debugPrint('ERROR: Area risk HandshakeException');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'Unable to establish a secure connection '
        'to the prediction server. '
        'Please try again.',
      );
    } on http.ClientException catch (error) {
      debugPrint('ERROR: Area risk HTTP ClientException');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'Unable to connect to the area risk prediction server. '
        'Please check your internet connection and try again.',
      );
    } on FormatException catch (error) {
      debugPrint('ERROR: Invalid area risk server response');
      debugPrint(error.toString());
      throw const PredictionApiException(
        'The area risk prediction server returned an invalid response. '
        'Please try again.',
      );
    } on PredictionApiException catch (error) {
      debugPrint('Area risk API error: ${error.message}');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('UNEXPECTED AREA RISK ERROR: $error');
      debugPrint('Stack trace: $stackTrace');
      throw const PredictionApiException(
        'Unable to generate the area risk prediction. '
        'Please try again.',
      );
    }
  }

  void _validatePredictionResponse(
    Map<String, dynamic> data,
  ) {
    final hasRisk =
        data.containsKey('predicted_outbreak_level') ||
        data.containsKey('risk_level');

    final probabilities = data['probabilities'];

    if (!hasRisk || probabilities is! Map) {
      throw const FormatException(
        'Required prediction fields are missing.',
      );
    }
  }

  void _validateAreaRiskResponse(
    Map<String, dynamic> data,
  ) {
    final hasRisk =
        data.containsKey('predicted_area_risk_level') ||
        data.containsKey('area_risk_level') ||
        data.containsKey('risk_level');

    final probabilities = data['probabilities'];

    if (!hasRisk || probabilities is! Map) {
      throw const FormatException(
        'Required area risk prediction fields are missing.',
      );
    }
  }

  Map<String, dynamic> _decodeJsonObject(
    String body,
  ) {
    final decoded = jsonDecode(body);

    if (decoded is! Map) {
      throw const FormatException(
        'Expected a JSON object from the prediction server.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? _tryDecodeJsonObject(
    String body,
  ) {
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

  String? _extractErrorMessage(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return null;
    }

    final detail = data['detail'];
    final message = data['message'];
    final error = data['error'];

    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
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