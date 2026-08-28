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

const Color appTeal = Color(0xFF0A7C70);
const Color appDarkTeal = Color(0xFF075A52);
const Color appEmerald = Color(0xFF0F927F);
const Color appAmber = Color(0xFFF2A72B);
const Color appInk = Color(0xFF17332F);
const Color appCanvas = Color(0xFFF3F7F6);
// Android local development uses ADB reverse, so the backend remains reachable
// even when the PC's Wi-Fi address changes.
const String defaultBackendUrl = 'http://127.0.0.1:8000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final String? savedBackendUrl = preferences.getString('backend_url');
  final String initialBackendUrl = resolveInitialBackendUrl(savedBackendUrl);
  if (savedBackendUrl != initialBackendUrl) {
    await preferences.setString('backend_url', initialBackendUrl);
  }

  runApp(
    DengueHealthApp(
      initialBaseUrl: initialBackendUrl,
      initialApiKey: preferences.getString('api_key') ?? '',
    ),
  );
}

String resolveInitialBackendUrl(String? savedUrl) {
  final String candidate = savedUrl == null || savedUrl.trim().isEmpty
      ? defaultBackendUrl
      : normalizeBaseUrl(savedUrl);

  if (kIsWeb) return candidate;
  if (kIsWeb) return candidate;
  if (!Platform.isAndroid) return candidate;

  try {
    final String host = Uri.parse(candidate).host.toLowerCase();
    if (host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '0.0.0.0' ||
        host == '192.168.1.6') {
      return defaultBackendUrl;
    }
  } on FormatException {
    return defaultBackendUrl;
  }
  return candidate;
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
    ).copyWith(primary: appTeal, secondary: appAmber, surface: Colors.white);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dengue Health SL',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: appCanvas,
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: appInk, displayColor: appInk),
        appBarTheme: const AppBarTheme(
          backgroundColor: appDarkTeal,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFB7CBC7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: appTeal, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDDF2ED),
          elevation: 8,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? appDarkTeal
                  : const Color(0xFF60736F),
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: 12,
            );
          }),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFD8E4E1)),
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

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onConnectionSaved,
  });

  final String baseUrl;
  final String apiKey;
  final Future<void> Function(String baseUrl, String apiKey) onConnectionSaved;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = <Widget>[
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final Animation<Offset> slide = Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: screens[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x190B423B),
              blurRadius: 24,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int value) {
            if (value != _selectedIndex) {
              setState(() => _selectedIndex = value);
            }
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
              label: 'Dengue NLP',
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
            ? 'Backend and analysis components are available'
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
        SliverAppBar(
          pinned: true,
          expandedHeight: 205,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            title: const Text(
              'Dengue Health SL',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF064F49), appTeal, appEmerald],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned(
                    right: -20,
                    top: 28,
                    child: Icon(
                      Icons.hub_outlined,
                      size: 150,
                      color: Color(0x18FFFFFF),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 62,
                    right: 84,
                    child: EntranceAnimation(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          Text(
                            'Ayubowan!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'NLP-based dengue intelligence and computer-vision PHI field inspections.',
                            style: TextStyle(
                              color: Color(0xDFFFFFFF),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              EntranceAnimation(
                delay: const Duration(milliseconds: 40),
                child: StatusCard(
                  online: _serverOnline,
                  loading: _checking,
                  message: _serverMessage,
                  baseUrl: widget.baseUrl,
                  onRefresh: _checkServer,
                ),
              ),
              const SizedBox(height: 24),
              const AppSectionHeader(
                title: 'Core system modules',
                subtitle: 'Select a complete working component',
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GridView.count(
                    crossAxisCount: constraints.maxWidth > 700 ? 2 : 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: constraints.maxWidth > 700 ? 1.45 : 1.7,
                    children: <Widget>[
                      EntranceAnimation(
                        delay: const Duration(milliseconds: 90),
                        child: FeatureCard(
                          icon: Icons.manage_search_rounded,
                          title: 'Dengue NLP Intelligence',
                          description:
                              'Analyse Sinhala, Singlish and English dengue text, answer health questions, verify claims, detect misinformation and present supporting evidence.',
                          buttonText: 'Open NLP module',
                          onPressed: widget.onOpenNlp,
                        ),
                      ),
                      EntranceAnimation(
                        delay: const Duration(milliseconds: 160),
                        child: FeatureCard(
                          icon: Icons.document_scanner_rounded,
                          title: 'PHI Field Inspection',
                          description:
                              'Capture inspection photos, detect mosquito breeding-risk objects, preserve GPS evidence and support verified follow-up action.',
                          buttonText: 'Start inspection',
                          accent: appAmber,
                          onPressed: widget.onOpenInspection,
                        ),
                      ),
                    ],
                  );
                },
              ),
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
      final Map<String, dynamic> result =
          await ApiService(
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
  Widget build(BuildContext context) => _buildAdvanced(context);

  Widget _buildAdvanced(BuildContext context) {
    const List<String> suggestions = <String>[
      '\u0DA9\u0DD9\u0D82\u0D9C\u0DD4 \u0DBB\u0DDD\u0D9C\u0DBA\u0DDA \u0D85\u0DB1\u0DAD\u0DD4\u0DBB\u0DD4 \u0DC3\u0D82\u0DA5\u0DCF \u0DB8\u0DDC\u0DB1\u0DC0\u0DCF\u0DAF?',
      '\u0DB8\u0DAF\u0DD4\u0DBB\u0DD4 \u0DB6\u0DDD\u0DC0\u0DB1 \u0DC3\u0DCA\u0DAE\u0DCF\u0DB1 \u0D89\u0DC0\u0DAD\u0DCA \u0D9A\u0DD2\u0DBB\u0DD3\u0DB8 \u0DB4\u0DCA\u200D\u0DBB\u0DBA\u0DDD\u0DA2\u0DB1\u0DC0\u0DAD\u0DCA \u0DB1\u0DD0\u0DC4\u0DD0',
      'When should a dengue patient go to hospital?',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dengue NLP Intelligence',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Evidence-backed multilingual text analysis',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: CircleAvatar(
              backgroundColor: Color(0x24FFFFFF),
              child: Icon(Icons.analytics_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: <Widget>[
          const EntranceAnimation(
            child: _NlpInformationPanel(
              text:
                  'Enter a dengue question, report or claim in Sinhala, Singlish or English. The NLP pipeline analyses its context, retrieves relevant evidence and returns a verified result.',
            ),
          ),
          const SizedBox(height: 16),
          const AppSectionHeader(
            title: 'Suggested test inputs',
            subtitle: 'Select an example or enter your own dengue text',
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: suggestions.map((String text) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.bolt_rounded, size: 17),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(text, maxLines: 2),
                    ),
                    onPressed: () {
                      _currentController.text = text;
                      setState(() {});
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          EntranceAnimation(
            delay: const Duration(milliseconds: 80),
            child: SectionCard(
              title: 'Conversation context',
              icon: Icons.account_tree_outlined,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Add previous context (optional)'),
                subtitle: const Text(
                  'Useful for short follow-up questions such as \u201CIs that correct?\u201D',
                ),
                children: <Widget>[
                  TextField(
                    controller: _previousController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Example: \u0DB8\u0DAF\u0DD4\u0DBB\u0DD4 \u0DB6\u0DDD\u0DC0\u0DB1 \u0DC3\u0DCA\u0DAE\u0DCF\u0DB1 \u0DC0\u0DCF\u0DBB\u0DCA\u0DAD\u0DCF \u0D9A\u0DD2\u0DBB\u0DD3\u0DB8',
                      prefixIcon: Icon(Icons.history_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          EntranceAnimation(
            delay: const Duration(milliseconds: 130),
            child: SectionCard(
              title: 'Your question or claim',
              icon: Icons.chat_bubble_outline_rounded,
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _currentController,
                    minLines: 4,
                    maxLines: 8,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          '\u0DC3\u0DD2\u0D82\u0DC4\u0DBD, Singlish or English \u0DC0\u0DBD\u0DD2\u0DB1\u0DCA dengue question \u0D91\u0D9A \u0DBD\u0DD2\u0DBA\u0DB1\u0DCA\u0DB1\u2026',
                      alignLabelWithHint: true,
                      suffixIcon: _currentController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _currentController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _analyze,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _loading
                          ? 'Analysing evidence\u2026'
                          : 'Analyse dengue text',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              );
            },
            child: _error != null
                ? Padding(
                    key: const ValueKey<String>('error'),
                    padding: const EdgeInsets.only(top: 14),
                    child: ErrorCard(message: _error!),
                  )
                : _result != null
                ? Padding(
                    key: ValueKey<String>(textOrDash(_result!['request_id'])),
                    padding: const EdgeInsets.only(top: 18),
                    child: NlpResultCard(result: _result!),
                  )
                : const SizedBox.shrink(key: ValueKey<String>('empty')),
          ),
          const SizedBox(height: 18),
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
            ResultRow(label: 'Language', value: textOrDash(result['language'])),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(answer),
            if (evidence.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Text(
                'Evidence',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              openExternalLink(context, source['source_url']),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Open official source'),
                          style: TextButton.styleFrom(
                            foregroundColor: appTeal,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onConnectionSaved,
  });

  final String baseUrl;
  final String apiKey;
  final Future<void> Function(String baseUrl, String apiKey) onConnectionSaved;

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
    await widget.onConnectionSaved(_urlController.text, _keyController.text);
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
              hintText: 'http://127.0.0.1:8000',
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
        ],
      ),
    );
  }
}

class EntranceAnimation extends StatefulWidget {
  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.055),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: widget.onTap,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: appInk,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF687A76), fontSize: 13),
        ),
      ],
    );
  }
}

class _NlpInformationPanel extends StatelessWidget {
  const _NlpInformationPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[appTeal, appEmerald],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x120A5149),
                  blurRadius: 18,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Text(text, style: const TextStyle(height: 1.45)),
          ),
        ),
      ],
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
    this.accent = appTeal,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      child: Card(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: appInk,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF61736F),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text(
                      buttonText,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
                  ],
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x100A5149),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 21,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      online == true
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: color,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  baseUrl,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
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
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFD8E4E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F2EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: appTeal, size: 20),
                ),
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

double riskProgress(String level) {
  final String normalized = level.toLowerCase();
  if (normalized.contains('emergency')) return 1;
  if (normalized.contains('high')) return 0.78;
  if (normalized.contains('moderate')) return 0.55;
  if (normalized.contains('low')) return 0.3;
  return 0.12;
}

String formatApiDate(dynamic value) {
  final DateTime? date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return textOrDash(value);
  return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> openExternalLink(BuildContext context, dynamic rawUrl) async {
  final String value = rawUrl?.toString().trim() ?? '';
  final Uri? uri = Uri.tryParse(value);

  if (uri == null ||
      (uri.scheme.toLowerCase() != 'http' &&
          uri.scheme.toLowerCase() != 'https')) {
    showMessage(context, 'A valid evidence link is not available.');
    return;
  }

  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showMessage(context, 'Could not open the evidence link.');
    }
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not open the evidence link.');
    }
  }
}
