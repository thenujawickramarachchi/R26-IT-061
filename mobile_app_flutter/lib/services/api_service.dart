import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common_widgets.dart';

class ApiService {
  ApiService({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  Map<String, String> get _headers {
    return <String, String>{
      'Accept': 'application/json',
      if (apiKey.trim().isNotEmpty) 'X-API-Key': apiKey.trim(),
    };
  }

  Uri _uri(String path) => Uri.parse('${normalizeBaseUrl(baseUrl)}$path');

  Future<Map<String, dynamic>> health() async {
    final http.Response response = await http
        .get(_uri('/health'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> analyzeText({
    required String currentText,
    String? previousContext,
  }) async {
    final String normalizedPreviousContext = previousContext?.trim() ?? '';
    final Map<String, dynamic> body = <String, dynamic>{
      'text': currentText.trim(),
      'previous_context': normalizedPreviousContext.isEmpty
          ? null
          : normalizedPreviousContext,
    };

    final http.Response response = await http
        .post(
          _uri('/v1/analyze'),
          headers: <String, String>{
            ..._headers,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(minutes: 3));
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> analyzeInspectionPhoto({
    required XFile image,
    required String inspectionId,
    String? latitude,
    String? longitude,
    String? address,
  }) async {
    return analyzeInspectionPhotos(
      images: <XFile>[image],
      inspectionId: inspectionId,
      latitude: latitude,
      longitude: longitude,
      address: address,
      useSinglePhotoEndpoint: true,
    );
  }

  Future<Map<String, dynamic>> analyzeInspectionPhotos({
    required List<XFile> images,
    required String inspectionId,
    String? latitude,
    String? longitude,
    String? address,
    bool useSinglePhotoEndpoint = false,
  }) async {
    if (images.isEmpty) {
      throw const ApiException('Add at least one inspection photo.');
    }

    final bool single = useSinglePhotoEndpoint && images.length == 1;
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      _uri(
        single
            ? '/v1/inspection/analyze-photo'
            : '/v1/inspection/analyze-photos',
      ),
    );

    request.headers.addAll(_headers);
    request.fields.addAll(<String, String>{
      'inspection_id': inspectionId.trim(),
      if (latitude != null && latitude.trim().isNotEmpty)
        'latitude': latitude.trim(),
      if (longitude != null && longitude.trim().isNotEmpty)
        'longitude': longitude.trim(),
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
      'confidence_threshold': '0.25',
      'save_evidence': 'true',
    });

    for (final XFile image in images) {
      final String lowerImageName = image.name.toLowerCase();
      final MediaType imageMediaType = lowerImageName.endsWith('.png')
          ? MediaType('image', 'png')
          : lowerImageName.endsWith('.webp')
          ? MediaType('image', 'webp')
          : MediaType('image', 'jpeg');
      final List<int> bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          single ? 'file' : 'files',
          bytes,
          filename: image.name,
          contentType: imageMediaType,
        ),
      );
    }

    final http.StreamedResponse streamedResponse = await request.send().timeout(
      const Duration(minutes: 5),
    );
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> completeInspection({
    required String inspectionId,
    required bool fieldVerified,
    required String actionTaken,
    required String remarks,
    required Map<String, bool> checklist,
    DateTime? reinspectionDate,
    bool warningIssued = false,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'field_verified': fieldVerified,
      'action_taken': actionTaken.trim(),
      'remarks': remarks.trim().isEmpty ? null : remarks.trim(),
      'warning_issued': warningIssued,
      'reinspection_date': reinspectionDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(reinspectionDate),
      'checklist': checklist,
    };

    final String safeInspectionId = Uri.encodeComponent(inspectionId.trim());
    final http.Response response = await http
        .post(
          _uri('/v1/inspection/$safeInspectionId/complete'),
          headers: <String, String>{
            ..._headers,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = <String, dynamic>{'detail': response.body};
    }

    final Map<String, dynamic> data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'data': decoded};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final dynamic detail = data['detail'];
      final String validationMessage = detail is List
          ? detail
                .map((dynamic item) {
                  if (item is Map) {
                    final dynamic location = item['loc'];
                    final String field = location is List && location.isNotEmpty
                        ? location.last.toString()
                        : 'request';
                    return '$field: ${item['msg'] ?? 'Invalid value'}';
                  }
                  return item.toString();
                })
                .join('\n')
          : '';
      throw ApiException(
        detail is String
            ? detail
            : validationMessage.isNotEmpty
            ? validationMessage
            : 'Request failed (${response.statusCode}).',
      );
    }
    return data;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
