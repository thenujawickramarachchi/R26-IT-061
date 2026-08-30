$ErrorActionPreference = "Stop"

$ProjectRoot = (Get-Location).Path
$PubspecFile = Join-Path $ProjectRoot "pubspec.yaml"
$MainDartFile = Join-Path $ProjectRoot "lib\main.dart"
$ManifestFile = Join-Path $ProjectRoot "android\app\src\main\AndroidManifest.xml"

if (-not (Test-Path $PubspecFile)) {
    throw "pubspec.yaml was not found. Run this script from the Flutter project root."
}

if (-not (Test-Path $ManifestFile)) {
    throw "AndroidManifest.xml was not found."
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $ProjectRoot "frontend_patch_backups\before_complete_ui_$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

if (Test-Path $MainDartFile) {
    Copy-Item $MainDartFile (Join-Path $BackupDir "main.dart") -Force
}
Copy-Item $PubspecFile (Join-Path $BackupDir "pubspec.yaml") -Force
Copy-Item $ManifestFile (Join-Path $BackupDir "AndroidManifest.xml") -Force

$MainDart = @'
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const Color appTeal = Color(0xFF087F73);
const Color appDarkTeal = Color(0xFF075E57);
const String defaultBackendUrl = 'http://192.168.1.6:8000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  runApp(
    DengueHealthApp(
      initialBaseUrl:
          preferences.getString('backend_url') ?? defaultBackendUrl,
      initialApiKey: preferences.getString('api_key') ?? '',
    ),
  );
}

class DengueHealthApp extends StatefulWidget {
  const DengueHealthApp({
    super.key,
    required this.initialBaseUrl,
    required this.initialApiKey,
  });

  final String initialBaseUrl;
  final String initialApiKey;

  @override
  State<DengueHealthApp> createState() => _DengueHealthAppState();
}

class _DengueHealthAppState extends State<DengueHealthApp> {
  late String _baseUrl;
  late String _apiKey;

  @override
  void initState() {
    super.initState();
    _baseUrl = normalizeBaseUrl(widget.initialBaseUrl);
    _apiKey = widget.initialApiKey.trim();
  }

  Future<void> _saveConnection(String baseUrl, String apiKey) async {
    final String normalizedUrl = normalizeBaseUrl(baseUrl);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString('backend_url', normalizedUrl);
    await preferences.setString('api_key', apiKey.trim());

    if (!mounted) return;
    setState(() {
      _baseUrl = normalizedUrl;
      _apiKey = apiKey.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: appTeal,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dengue Health SL',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F8F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: appDarkTeal,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB7CBC7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: appTeal, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: AppShell(
        baseUrl: _baseUrl,
        apiKey: _apiKey,
        onConnectionSaved: _saveConnection,
      ),
    );
  }
}

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
    final Map<String, dynamic> body = <String, dynamic>{
      'current_text': currentText.trim(),
      if (previousContext != null && previousContext.trim().isNotEmpty)
        'previous_context': previousContext.trim(),
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
    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      _uri('/v1/inspection/analyze-photo'),
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
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    final http.StreamedResponse streamedResponse = await request
        .send()
        .timeout(const Duration(minutes: 3));
    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );
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
      throw ApiException(
        detail is String ? detail : 'Request failed (${response.statusCode}).',
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

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onConnectionSaved,
  });

  final String baseUrl;
  final String apiKey;
  final Future<void> Function(String baseUrl, String apiKey)
  onConnectionSaved;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = <Widget>[
      HomeScreen(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
        onOpenNlp: () => setState(() => _selectedIndex = 1),
        onOpenInspection: () => setState(() => _selectedIndex = 2),
      ),
      NlpScreen(baseUrl: widget.baseUrl, apiKey: widget.apiKey),
      InspectionScreen(baseUrl: widget.baseUrl, apiKey: widget.apiKey),
      SettingsScreen(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
        onConnectionSaved: widget.onConnectionSaved,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int value) {
          setState(() => _selectedIndex = value);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Dengue AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Inspect',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onOpenNlp,
    required this.onOpenInspection,
  });

  final String baseUrl;
  final String apiKey;
  final VoidCallback onOpenNlp;
  final VoidCallback onOpenInspection;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checking = false;
  bool? _serverOnline;
  String _serverMessage = 'Connection not checked';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkServer());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl ||
        oldWidget.apiKey != widget.apiKey) {
      _checkServer();
    }
  }

  Future<void> _checkServer() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final Map<String, dynamic> result = await ApiService(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
      ).health();
      if (!mounted) return;
      setState(() {
        _serverOnline = result['status'] == 'ok';
        _serverMessage = _serverOnline == true
            ? 'Backend and AI components are available'
            : 'Backend returned an unexpected status';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverOnline = false;
        _serverMessage = readableError(error);
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar(
          pinned: true,
          expandedHeight: 150,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Dengue Health SL'),
            background: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[appDarkTeal, appTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 24, top: 24),
                  child: Icon(
                    Icons.coronavirus_outlined,
                    size: 72,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              Text(
                'Public-health intelligence and PHI field inspection',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              StatusCard(
                online: _serverOnline,
                loading: _checking,
                message: _serverMessage,
                baseUrl: widget.baseUrl,
                onRefresh: _checkServer,
              ),
              const SizedBox(height: 18),
              FeatureCard(
                icon: Icons.chat_bubble_outline,
                title: 'Dengue Health Intelligence',
                description:
                    'Ask Sinhala, Singlish or English questions, verify claims, identify misinformation and analyse severity.',
                buttonText: 'Open Dengue AI',
                onPressed: widget.onOpenNlp,
              ),
              const SizedBox(height: 14),
              FeatureCard(
                icon: Icons.document_scanner_outlined,
                title: 'PHI Breeding-Risk Inspection',
                description:
                    'Capture field evidence, detect breeding-risk objects, record GPS details and schedule follow-up action.',
                buttonText: 'Start Inspection',
                onPressed: widget.onOpenInspection,
              ),
              const SizedBox(height: 18),
              const SafetyNotice(),
            ]),
          ),
        ),
      ],
    );
  }
}

class NlpScreen extends StatefulWidget {
  const NlpScreen({super.key, required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  @override
  State<NlpScreen> createState() => _NlpScreenState();
}

class _NlpScreenState extends State<NlpScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _previousController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _previousController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final String currentText = _currentController.text.trim();
    if (currentText.isEmpty) {
      setState(() => _error = 'Enter a dengue question or claim.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final Map<String, dynamic> result = await ApiService(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
      ).analyzeText(
        currentText: currentText,
        previousContext: _previousController.text,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dengue Health Intelligence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Ask in Sinhala, Singlish or English',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: appDarkTeal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The backend automatically selects question answering, claim verification, current-data retrieval or severity analysis.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _previousController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Previous context (optional)',
              hintText: 'Example: මදුරු බෝවන ස්ථාන වාර්තා කිරීම',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _currentController,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Dengue question, report or claim',
              hintText: 'Example: මදුරු බෝවන ස්ථාන ඉවත් කිරීම ප්‍රයෝජනවත් නැහැ',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_loading ? 'Analysing...' : 'Analyse dengue text'),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            ErrorCard(message: _error!),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 18),
            NlpResultCard(result: _result!),
          ],
          const SizedBox(height: 16),
          const SafetyNotice(),
        ],
      ),
    );
  }
}

class NlpResultCard extends StatelessWidget {
  const NlpResultCard({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? contextResult = mapOrNull(result['context']);
    final Map<String, dynamic>? truthResult = mapOrNull(result['truth']);
    final Map<String, dynamic>? severityResult = mapOrNull(result['severity']);
    final List<dynamic> evidence = result['evidence'] is List
        ? List<dynamic>.from(result['evidence'] as List)
        : <dynamic>[];
    final String status = textOrDash(result['status']);
    final String answer = textOrDash(result['answer']);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFC7DAD6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.analytics_outlined, color: appTeal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Analysis result',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: appDarkTeal,
                    ),
                  ),
                ),
                StatusChip(text: status),
              ],
            ),
            const Divider(height: 28),
            ResultRow(label: 'Route', value: textOrDash(result['route'])),
            ResultRow(
              label: 'Language',
              value: textOrDash(result['language']),
            ),
            if (contextResult != null)
              ResultRow(
                label: 'Context',
                value:
                    '${textOrDash(contextResult['label'])} (${percent(contextResult['confidence'])})',
              ),
            if (truthResult != null)
              ResultRow(
                label: 'Truth',
                value:
                    '${textOrDash(truthResult['label'])} (${percent(truthResult['confidence'])})',
              ),
            if (severityResult != null)
              ResultRow(
                label: 'Severity',
                value:
                    '${textOrDash(severityResult['label'])} (${percent(severityResult['confidence'])})',
              ),
            const SizedBox(height: 12),
            Text(
              'Verified answer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(answer),
            if (evidence.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Text(
                'Evidence',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...evidence.take(3).map((dynamic item) {
                final Map<String, dynamic>? source = mapOrNull(item);
                if (source == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F8F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(textOrDash(source['text'])),
                      const SizedBox(height: 5),
                      Text(
                        textOrDash(source['source_url']),
                        style: const TextStyle(
                          color: appTeal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (result['safety_message'] != null) ...<Widget>[
              const Divider(height: 28),
              Text(
                textOrDash(result['safety_message']),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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

  XFile? _selectedImage;
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      setState(() {
        _selectedImage = image;
        _error = null;
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

  Future<void> _analyzePhoto() async {
    if (_selectedImage == null) {
      setState(() => _error = 'Capture or select an inspection photo.');
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
      final Map<String, dynamic> result = await ApiService(
        baseUrl: widget.baseUrl,
        apiKey: widget.apiKey,
      ).analyzeInspectionPhoto(
        image: _selectedImage!,
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
      appBar: AppBar(title: const Text('PHI Field Inspection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Breeding-risk photo evidence',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appDarkTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Capture a clear site photo. AI detections must be verified by the PHI officer.',
          ),
          const SizedBox(height: 16),
          Container(
            height: 220,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFE3EFEC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFB7CBC7)),
            ),
            child: _selectedImage == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 54,
                          color: appTeal,
                        ),
                        SizedBox(height: 8),
                        Text('No inspection photo selected'),
                      ],
                    ),
                  )
                : Image.file(
                    File(_selectedImage!.path),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
            onPressed: _loading ? null : _analyzePhoto,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(
              _loading ? 'Analysing photo...' : 'Analyse inspection photo',
            ),
          ),
          const SizedBox(height: 14),
          const SafetyNotice(),
        ],
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
  });

  final String baseUrl;
  final String apiKey;
  final Map<String, dynamic> result;
  final String phoneNumber;

  @override
  State<InspectionResultScreen> createState() =>
      _InspectionResultScreenState();
}

class _InspectionResultScreenState extends State<InspectionResultScreen> {
  bool _fieldVerified = false;
  DateTime? _reinspectionDate;

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

  Future<void> _sendWarningSms() async {
    if (!_fieldVerified) {
      showMessage(context, 'Verify the field condition before sending a warning.');
      return;
    }
    if (widget.phoneNumber.trim().isEmpty) {
      showMessage(context, 'No resident phone number was entered.');
      return;
    }

    final Map<String, dynamic>? risk = mapOrNull(
      widget.result['risk_summary'],
    );
    final String level = textOrDash(risk?['level']);
    final String evidenceId = textOrDash(widget.result['evidence_id']);
    final String message =
        'Dengue prevention notice: A PHI inspection identified verified breeding-risk conditions ($level). Please remove stagnant water and breeding sites before the follow-up inspection. Reference: $evidenceId.';
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: widget.phoneNumber.trim(),
      queryParameters: <String, String>{'body': message},
    );

    if (!await launchUrl(smsUri, mode: LaunchMode.externalApplication)) {
      if (mounted) showMessage(context, 'Could not open the SMS application.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? risk = mapOrNull(
      widget.result['risk_summary'],
    );
    final Map<String, dynamic>? location = mapOrNull(widget.result['location']);
    final List<dynamic> detections = widget.result['detections'] is List
        ? List<dynamic>.from(widget.result['detections'] as List)
        : <dynamic>[];
    final String evidenceId = textOrDash(widget.result['evidence_id']);
    final String riskLevel = textOrDash(risk?['level']);
    final Color riskColor = colorForRisk(riskLevel);
    final String annotatedUrl =
        '${normalizeBaseUrl(widget.baseUrl)}/v1/inspection/evidence/$evidenceId/annotated';

    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                annotatedUrl,
                headers: <String, String>{
                  if (widget.apiKey.trim().isNotEmpty)
                    'X-API-Key': widget.apiKey.trim(),
                },
                fit: BoxFit.contain,
                color: const Color(0xFFE7EFED),
                colorBlendMode: BlendMode.dstOver,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Annotated image could not be loaded. Check the backend URL and Wi-Fi connection.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
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
                const SizedBox(height: 5),
                Text(
                  '${widget.result['detection_count'] ?? 0} potential breeding-risk object(s) detected',
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
                ResultRow(label: 'Evidence ID', value: evidenceId),
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
                const ResultRow(label: 'Evidence saved', value: 'Yes'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Recommended action',
            icon: Icons.fact_check_outlined,
            child: Text(textOrDash(risk?['recommended_action'])),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _fieldVerified,
            onChanged: (bool? value) {
              setState(() => _fieldVerified = value ?? false);
            },
            title: const Text('Field condition verified by PHI officer'),
            subtitle: const Text(
              'Required before sending a warning or initiating follow-up action.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (_reinspectionDate != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available, color: appTeal),
              title: const Text('Reinspection scheduled'),
              subtitle: Text(
                DateFormat('dd MMMM yyyy').format(_reinspectionDate!),
              ),
            ),
          FilledButton.icon(
            onPressed: _sendWarningSms,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Open warning SMS'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _scheduleReinspection,
            icon: const Icon(Icons.event_repeat),
            label: const Text('Schedule reinspection'),
          ),
          const SizedBox(height: 14),
          const SafetyNotice(),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onConnectionSaved,
  });

  final String baseUrl;
  final String apiKey;
  final Future<void> Function(String baseUrl, String apiKey)
  onConnectionSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _saving = false;
  bool _testing = false;
  String? _message;
  bool? _success;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.baseUrl);
    _keyController = TextEditingController(text: widget.apiKey);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl) {
      _urlController.text = widget.baseUrl;
    }
    if (oldWidget.apiKey != widget.apiKey) {
      _keyController.text = widget.apiKey;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _success = false;
        _message = 'Enter the backend URL.';
      });
      return;
    }
    setState(() => _saving = true);
    await widget.onConnectionSaved(
      _urlController.text,
      _keyController.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _success = true;
      _message = 'Connection settings saved.';
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      final Map<String, dynamic> result = await ApiService(
        baseUrl: _urlController.text,
        apiKey: _keyController.text,
      ).health();
      if (!mounted) return;
      setState(() {
        _success = result['status'] == 'ok';
        _message = _success == true
            ? 'Backend connection successful.'
            : 'Backend returned an unexpected response.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = readableError(error);
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Backend connection',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appDarkTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The phone and backend computer must use the same Wi-Fi network for local testing.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Backend server URL',
              hintText: 'http://192.168.1.6:8000',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key (optional)',
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? 'Testing...' : 'Test connection'),
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _success == true
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _success == true ? Icons.check_circle : Icons.error,
                    color: _success == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_message!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SafetyNotice(),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFC7DAD6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE0F1ED),
              child: Icon(icon, color: appTeal, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: appDarkTeal,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 14),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.online,
    required this.loading,
    required this.message,
    required this.baseUrl,
    required this.onRefresh,
  });

  final bool? online;
  final bool loading;
  final String message;
  final String baseUrl;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final Color color = online == true
        ? Colors.green
        : online == false
        ? Colors.red
        : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          loading
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  online == true ? Icons.cloud_done : Icons.cloud_off,
                  color: color,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  baseUrl,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(onPressed: loading ? null : onRefresh, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFC7DAD6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: appTeal),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: appDarkTeal,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F1ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: appDarkTeal,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: Color(0xFF9A6500)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Research prototype only. It does not replace professional medical advice or official PHI decisions. Urgent warning signs require prompt medical assessment.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

String normalizeBaseUrl(String value) {
  String normalized = value.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

Map<String, dynamic>? mapOrNull(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

String textOrDash(dynamic value) {
  if (value == null) return '-';
  final String text = value.toString().trim();
  return text.isEmpty ? '-' : text;
}

String percent(dynamic value) {
  final double? number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return number == null ? '-' : '${(number * 100).toStringAsFixed(1)}%';
}

String readableError(Object error) {
  if (error is ApiException) return error.message;
  final String text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Cannot reach the backend. Confirm the server URL, Wi-Fi connection and Windows firewall.';
  }
  if (text.contains('TimeoutException')) {
    return 'The backend request timed out. The first CPU model request may take longer.';
  }
  return text.replaceFirst('Exception: ', '');
}

String prettyLabel(String value) {
  return value
      .split('_')
      .map(
        (String word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

IconData iconForDetection(String label) {
  switch (label) {
    case 'tire':
      return Icons.album_outlined;
    case 'water_storage':
      return Icons.water_drop_outlined;
    case 'drain_inlet':
      return Icons.grid_on_outlined;
    case 'coconut_shell':
      return Icons.eco_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

Color colorForRisk(String level) {
  final String normalized = level.toLowerCase();
  if (normalized.contains('high') || normalized.contains('emergency')) {
    return Colors.red.shade700;
  }
  if (normalized.contains('moderate')) return Colors.orange.shade800;
  if (normalized.contains('low')) return Colors.amber.shade800;
  return Colors.green.shade700;
}

String formatApiDate(dynamic value) {
  final DateTime? date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return textOrDash(value);
  return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
'@

Set-Content -Path $MainDartFile -Value $MainDart -Encoding UTF8

$Manifest = Get-Content $ManifestFile -Raw
$Permissions = @(
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.CAMERA" />',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />'
)

foreach ($Permission in $Permissions) {
    $PermissionName = [regex]::Match($Permission, 'android:name="([^"]+)"').Groups[1].Value
    if ($Manifest -notmatch [regex]::Escape($PermissionName)) {
        $Manifest = $Manifest -replace '(<manifest[^>]*>)', "`$1`r`n    $Permission"
    }
}

if ($Manifest -match 'android:label="[^"]*"') {
    $Manifest = $Manifest -replace 'android:label="[^"]*"', 'android:label="Dengue Health SL"'
} else {
    $Manifest = $Manifest -replace '<application', '<application android:label="Dengue Health SL"'
}

if ($Manifest -match 'android:usesCleartextTraffic="[^"]*"') {
    $Manifest = $Manifest -replace 'android:usesCleartextTraffic="[^"]*"', 'android:usesCleartextTraffic="true"'
} else {
    $Manifest = $Manifest -replace '<application', '<application android:usesCleartextTraffic="true"'
}

Set-Content -Path $ManifestFile -Value $Manifest -Encoding UTF8

Write-Host "Installing Flutter packages..." -ForegroundColor Cyan
flutter pub add http image_picker shared_preferences intl geolocator url_launcher
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub add failed."
}

dart format lib\main.dart
if ($LASTEXITCODE -ne 0) {
    throw "dart format failed."
}

Write-Host "Running Flutter analysis..." -ForegroundColor Cyan
flutter analyze
$AnalyzeExitCode = $LASTEXITCODE

Write-Host ""
if ($AnalyzeExitCode -eq 0) {
    Write-Host "COMPLETE DENGUE FLUTTER FRONTEND APPLIED SUCCESSFULLY" -ForegroundColor Green
} else {
    Write-Host "FRONTEND FILES APPLIED, BUT FLUTTER ANALYZE REPORTED ISSUES" -ForegroundColor Yellow
}
Write-Host "Project: $ProjectRoot"
Write-Host "Backup: $BackupDir"
Write-Host "Default backend: http://192.168.1.6:8000"
Write-Host "Modules: Home + Dengue NLP + PHI Inspection + Settings"
Write-Host ""
Write-Host "Next: review the Flutter analysis output, connect the phone, and run the app."
