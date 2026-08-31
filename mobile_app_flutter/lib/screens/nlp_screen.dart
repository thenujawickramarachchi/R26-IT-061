import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

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
