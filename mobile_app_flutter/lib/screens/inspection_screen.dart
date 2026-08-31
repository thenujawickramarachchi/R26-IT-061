import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
  });

  final String baseUrl;
  final String apiKey;

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _inspectionIdController;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<XFile> _selectedImages = <XFile>[];
  final Map<String, bool> _checklist = <String, bool>{
    'Water containers checked': false,
    'Gutters checked': false,
    'Tyres checked': false,
    'Drains checked': false,
    'Waste accumulation checked': false,
    'Water tanks covered': false,
    'Mosquito larvae checked': false,
  };

  bool _loading = false;
  bool _gettingLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inspectionIdController = TextEditingController(
      text: 'PHI-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}',
    );
  }

  @override
  void dispose() {
    _inspectionIdController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _photoPreview(XFile image) {
    if (kIsWeb) {
      return Image.network(
        image.path,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Image.file(
      File(image.path),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Future<void> _pickCameraPhoto() async {
    try {
      if (_selectedImages.length >= 10) {
        setState(
          () => _error = 'Maximum 10 photos are allowed per inspection.',
        );
        return;
      }
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      setState(() {
        _selectedImages.add(image);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    }
  }

  Future<void> _pickGalleryPhotos() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (images.isEmpty || !mounted) return;
      final int remaining = 10 - _selectedImages.length;
      if (remaining <= 0) {
        setState(
          () => _error = 'Maximum 10 photos are allowed per inspection.',
        );
        return;
      }
      setState(() {
        _selectedImages.addAll(images.take(remaining));
        _error = images.length > remaining
            ? 'Only the first $remaining photo(s) were added. Maximum is 10.'
            : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gettingLocation = true;
      _error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiException('Enable location services on the phone.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException('Location permission was not granted.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _analyzePhotos() async {
    if (_selectedImages.isEmpty) {
      setState(
        () => _error = 'Capture or select at least one inspection photo.',
      );
      return;
    }
    if (_inspectionIdController.text.trim().isEmpty) {
      setState(() => _error = 'Enter an inspection ID.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> result =
          await ApiService(
            baseUrl: widget.baseUrl,
            apiKey: widget.apiKey,
          ).analyzeInspectionPhotos(
            images: List<XFile>.from(_selectedImages),
            inspectionId: _inspectionIdController.text,
            latitude: _latitudeController.text,
            longitude: _longitudeController.text,
            address: _addressController.text,
          );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => InspectionResultScreen(
            baseUrl: widget.baseUrl,
            apiKey: widget.apiKey,
            result: result,
            phoneNumber: _phoneController.text.trim(),
            checklist: Map<String, bool>.from(_checklist),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'PHI Field Inspection',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Multi-photo breeding-risk evidence',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Inspection history',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const InspectionHistoryScreen(),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
        children: <Widget>[
          AppSectionHeader(
            title: 'Capture field evidence',
            subtitle: _selectedImages.isEmpty
                ? 'Add several photos under the same inspection ID.'
                : '${_selectedImages.length} of 10 photo(s) ready for analysis.',
          ),
          const SizedBox(height: 16),
          if (_selectedImages.isEmpty)
            Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE3EFEC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB7CBC7)),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 38,
                        color: appTeal,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Add inspection photos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'JPEG, PNG or WebP • maximum 10',
                      style: TextStyle(color: Color(0xFF687A76)),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (BuildContext context, int index) {
                final XFile image = _selectedImages[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _photoPreview(image),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove photo',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _selectedImages.removeAt(index)),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCameraPhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickGalleryPhotos,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(_selectedImages.clear),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear all photos'),
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'Inspection details',
            icon: Icons.assignment_outlined,
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _inspectionIdController,
                  decoration: const InputDecoration(
                    labelText: 'Inspection ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address or field note',
                    prefixIcon: Icon(Icons.home_work_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Resident phone number (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'PHI inspection checklist',
            icon: Icons.checklist_rounded,
            child: Column(
              children: _checklist.entries.map((MapEntry<String, bool> entry) {
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: entry.value,
                  title: Text(entry.key),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) =>
                      setState(() => _checklist[entry.key] = value ?? false),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _gettingLocation ? null : _useCurrentLocation,
            icon: _gettingLocation
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _gettingLocation ? 'Getting location...' : 'Use current GPS',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            ErrorCard(message: _error!),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _analyzePhotos,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(
              _loading
                  ? 'Analysing ${_selectedImages.length} photo(s)...'
                  : 'Analyse all inspection photos',
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class InspectionHistoryScreen extends StatefulWidget {
  const InspectionHistoryScreen({super.key});

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String raw = preferences.getString('inspection_history_v1') ?? '[]';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        _items = decoded
            .whereType<Map>()
            .map((Map item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {
      _items = <Map<String, dynamic>>[];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clearHistory() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove('inspection_history_v1');
    if (mounted) setState(() => _items = <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inspection History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearHistory,
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No saved inspections yet.'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> item = _items[index];
                final String risk = textOrDash(item['risk_level']);
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: colorForRisk(
                        risk,
                      ).withValues(alpha: 0.14),
                      child: Icon(
                        Icons.fact_check_outlined,
                        color: colorForRisk(risk),
                      ),
                    ),
                    title: Text(
                      textOrDash(item['inspection_id']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '$risk • ${item['photo_count'] ?? 0} photo(s) • ${textOrDash(item['status'])}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: <Widget>[
                      ResultRow(
                        label: 'Saved',
                        value: formatApiDate(item['saved_at']),
                      ),
                      ResultRow(
                        label: 'Address',
                        value: textOrDash(item['address']),
                      ),
                      ResultRow(
                        label: 'Detections',
                        value: '${item['detection_count'] ?? 0}',
                      ),
                      ResultRow(
                        label: 'PHI action',
                        value: textOrDash(item['action_taken']),
                      ),
                      ResultRow(
                        label: 'Reinspection',
                        value: textOrDash(item['reinspection_date']),
                      ),
                      ResultRow(
                        label: 'Remarks',
                        value: textOrDash(item['phi_remarks']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class InspectionResultScreen extends StatefulWidget {
  const InspectionResultScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.result,
    required this.phoneNumber,
    required this.checklist,
  });

  final String baseUrl;
  final String apiKey;
  final Map<String, dynamic> result;
  final String phoneNumber;
  final Map<String, bool> checklist;

  @override
  State<InspectionResultScreen> createState() => _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  bool _fieldVerified = false;
  bool _saving = false;
  bool _saved = false;
  DateTime? _reinspectionDate;
  String? _actionTaken;
  final TextEditingController _remarksController = TextEditingController();

  static const List<String> _actions = <String>[
    'Remove stagnant water',
    'Destroy breeding container',
    'Larvicide treatment',
    'Fumigation required',
    'Community cleanup',
    'Public awareness required',
    'Reinspection only',
    'No immediate action',
  ];

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _photos {
    final dynamic raw = widget.result['photos'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[widget.result];
  }

  Future<void> _scheduleReinspection() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 7)),
    );
    if (selected != null && mounted) {
      setState(() => _reinspectionDate = selected);
    }
  }

  Future<void> _saveInspection() async {
    if (_saved) {
      showMessage(context, 'This inspection has already been saved.');
      return;
    }
    if (!_fieldVerified) {
      showMessage(
        context,
        'Verify the field condition before saving the completed inspection.',
      );
      return;
    }
    if (_actionTaken == null) {
      showMessage(context, 'Select the PHI action taken.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
      ).completeInspection(
        inspectionId: textOrDash(widget.result['inspection_id']),
        fieldVerified: _fieldVerified,
        actionTaken: _actionTaken!,
        remarks: _remarksController.text,
        checklist: Map<String, bool>.from(widget.checklist),
        reinspectionDate: _reinspectionDate,
      );

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String raw = preferences.getString('inspection_history_v1') ?? '[]';
      List<dynamic> history;
      try {
        final dynamic decoded = jsonDecode(raw);
        history = decoded is List ? List<dynamic>.from(decoded) : <dynamic>[];
      } catch (_) {
        history = <dynamic>[];
      }

      final Map<String, dynamic>? risk = mapOrNull(
        widget.result['risk_summary'],
      );
      final Map<String, dynamic>? location = mapOrNull(
        widget.result['location'],
      );
      history.insert(0, <String, dynamic>{
        'inspection_id': widget.result['inspection_id'],
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'address': location?['address'],
        'latitude': location?['latitude'],
        'longitude': location?['longitude'],
        'photo_count': widget.result['photo_count'] ?? _photos.length,
        'detection_count': widget.result['detection_count'] ?? 0,
        'risk_level': risk?['level'],
        'risk_score': risk?['score'],
        'field_verified': _fieldVerified,
        'action_taken': _actionTaken,
        'phi_remarks': _remarksController.text.trim(),
        'reinspection_date': _reinspectionDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_reinspectionDate!),
        'status': _reinspectionDate == null
            ? 'Verified'
            : 'Reinspection Required',
        'checklist': widget.checklist,
        'evidence_ids':
            widget.result['evidence_ids'] ??
            _photos.map((Map<String, dynamic> p) => p['evidence_id']).toList(),
      });
      if (history.length > 50) history = history.take(50).toList();
      await preferences.setString('inspection_history_v1', jsonEncode(history));
      if (mounted) {
        setState(() => _saved = true);
        showMessage(context, 'Inspection saved to Supabase and local history.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Could not save inspection: ${readableError(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendWarningSms() async {
    if (!_fieldVerified) {
      showMessage(
        context,
        'Verify the field condition before sending a warning.',
      );
      return;
    }
    if (widget.phoneNumber.trim().isEmpty) {
      showMessage(context, 'No resident phone number was entered.');
      return;
    }

    final Map<String, dynamic>? risk = mapOrNull(widget.result['risk_summary']);
    final String level = textOrDash(risk?['level']);
    final String inspectionId = textOrDash(widget.result['inspection_id']);
    final String action =
        _actionTaken ?? 'Remove confirmed breeding conditions';
    final String reinspection = _reinspectionDate == null
        ? ''
        : ' Reinspection: ${DateFormat('dd MMM yyyy').format(_reinspectionDate!)}.';
    final String message =
        'Dengue prevention notice: PHI inspection $inspectionId identified verified breeding-risk conditions ($level). Required action: $action.$reinspection';
    final String safePhoneNumber = widget.phoneNumber.trim().replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    final Uri smsUri = Uri.parse(
      'sms:$safePhoneNumber?body=${Uri.encodeComponent(message)}',
    );

    if (!await launchUrl(smsUri, mode: LaunchMode.externalApplication)) {
      if (mounted) showMessage(context, 'Could not open the SMS application.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? risk = mapOrNull(widget.result['risk_summary']);
    final Map<String, dynamic>? location = mapOrNull(widget.result['location']);
    final List<dynamic> detections = widget.result['detections'] is List
        ? List<dynamic>.from(widget.result['detections'] as List)
        : <dynamic>[];
    final String riskLevel = textOrDash(risk?['level']);
    final Color riskColor = colorForRisk(riskLevel);
    final List<Map<String, dynamic>> photos = _photos;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inspection Result',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
        children: <Widget>[
          AppSectionHeader(
            title: 'Evidence photos',
            subtitle:
                '${photos.length} photo(s) analysed under ${textOrDash(widget.result['inspection_id'])}',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: PageView.builder(
              itemCount: photos.length,
              controller: PageController(viewportFraction: 0.92),
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> photo = photos[index];
                final String evidenceId = textOrDash(photo['evidence_id']);
                final String annotatedUrl =
                    '${normalizeBaseUrl(widget.baseUrl)}/v1/inspection/evidence/$evidenceId/annotated';
                final Map<String, dynamic>? photoRisk = mapOrNull(
                  photo['risk_summary'],
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: Image.network(
                            annotatedUrl,
                            headers: <String, String>{
                              if (widget.apiKey.trim().isNotEmpty)
                                'X-API-Key': widget.apiKey.trim(),
                            },
                            fit: BoxFit.contain,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Text('Annotated image unavailable'),
                                ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Photo ${index + 1} • ${textOrDash(photoRisk?['level'])}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Open evidence',
                                onPressed: () =>
                                    openExternalLink(context, annotatedUrl),
                                icon: const Icon(Icons.open_in_new_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: riskColor),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  riskLevel.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: riskProgress(riskLevel),
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.result['detection_count'] ?? 0} potential breeding-risk object(s) across ${photos.length} photo(s)',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Detected objects',
            icon: Icons.center_focus_strong,
            child: detections.isEmpty
                ? const Text('No model-detected risk objects.')
                : Column(
                    children: detections.map((dynamic item) {
                      final Map<String, dynamic>? detection = mapOrNull(item);
                      if (detection == null) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE0F1ED),
                          child: Icon(
                            iconForDetection(textOrDash(detection['label'])),
                            color: appTeal,
                          ),
                        ),
                        title: Text(
                          prettyLabel(textOrDash(detection['label'])),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          percent(detection['confidence']),
                          style: const TextStyle(
                            color: appDarkTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Inspection details',
            icon: Icons.assignment_outlined,
            child: Column(
              children: <Widget>[
                ResultRow(
                  label: 'Inspection ID',
                  value: textOrDash(widget.result['inspection_id']),
                ),
                ResultRow(
                  label: 'Photos',
                  value: '${widget.result['photo_count'] ?? photos.length}',
                ),
                ResultRow(
                  label: 'Address',
                  value: textOrDash(location?['address']),
                ),
                ResultRow(
                  label: 'Coordinates',
                  value:
                      '${textOrDash(location?['latitude'])}, ${textOrDash(location?['longitude'])}',
                ),
                ResultRow(
                  label: 'Observed',
                  value: formatApiDate(widget.result['observed_at_utc']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Checklist completed',
            icon: Icons.checklist_rounded,
            child: Column(
              children: widget.checklist.entries
                  .map(
                    (MapEntry<String, bool> item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.value
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: item.value ? appTeal : Colors.grey,
                      ),
                      title: Text(item.key),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'AI recommended action',
            icon: Icons.fact_check_outlined,
            child: Text(textOrDash(risk?['recommended_action'])),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'PHI verification & action',
            icon: Icons.verified_user_outlined,
            child: Column(
              children: <Widget>[
                CheckboxListTile(
                  value: _fieldVerified,
                  onChanged: (bool? value) =>
                      setState(() => _fieldVerified = value ?? false),
                  title: const Text('Field condition verified by PHI officer'),
                  subtitle: const Text(
                    'AI findings must be confirmed before warning or follow-up action.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _actionTaken,
                  decoration: const InputDecoration(
                    labelText: 'Action taken',
                    prefixIcon: Icon(Icons.task_alt_rounded),
                  ),
                  items: _actions
                      .map(
                        (String action) => DropdownMenuItem<String>(
                          value: action,
                          child: Text(action),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) =>
                      setState(() => _actionTaken = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remarksController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'PHI remarks (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
          if (_reinspectionDate != null) ...<Widget>[
            const SizedBox(height: 12),
            ListTile(
              tileColor: const Color(0xFFE7F3F0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: const Icon(Icons.event_available, color: appTeal),
              title: const Text('Reinspection scheduled'),
              subtitle: Text(
                DateFormat('dd MMMM yyyy').format(_reinspectionDate!),
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _scheduleReinspection,
            icon: const Icon(Icons.event_repeat),
            label: const Text('Schedule reinspection'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _sendWarningSms,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Open warning SMS'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _saving ? null : _saveInspection,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_saved ? Icons.check_circle : Icons.save_outlined),
            label: Text(
              _saved ? 'Inspection saved' : 'Save inspection to history',
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
