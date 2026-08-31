import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const Color appTeal = Color(0xFF00796B);
const Color appDarkTeal = Color(0xFF0A5149);
const Color appInk = Color(0xFF1E2A2B);
const Color appEmerald = Color(0xFF15A57A);

String readableError(Object error) {
  if (error is String)
    return error.trim().isNotEmpty ? error.trim() : 'Something went wrong.';
  if (error is Exception)
    return error.toString().replaceFirst('Exception: ', '');
  if (error is Map && error['message'] is String) {
    final String message = error['message'] as String;
    if (message.trim().isNotEmpty) return message.trim();
  }
  if (error is Map && error['detail'] is String) {
    final String detail = error['detail'] as String;
    if (detail.trim().isNotEmpty) return detail.trim();
  }
  return 'Something went wrong. Please try again.';
}

String textOrDash(Object? value) {
  if (value == null) return '—';
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }
  return value.toString();
}

Map<String, dynamic>? mapOrNull(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
  }
  return null;
}

String normalizeBaseUrl(String baseUrl) {
  final String trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

String formatApiDate(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return '—';
  try {
    final DateTime parsed = DateTime.parse(value.toString());
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed.toLocal());
  } catch (_) {
    return value.toString();
  }
}

Color colorForRisk(String riskLevel) {
  final String normalized = riskLevel.toLowerCase();
  if (normalized.contains('high')) return Colors.red.shade700;
  if (normalized.contains('medium') || normalized.contains('moderate'))
    return Colors.orange.shade700;
  if (normalized.contains('low')) return Colors.green.shade700;
  return Colors.blueGrey;
}

double riskProgress(String riskLevel) {
  final String normalized = riskLevel.toLowerCase();
  if (normalized.contains('high')) return 0.9;
  if (normalized.contains('medium') || normalized.contains('moderate'))
    return 0.6;
  if (normalized.contains('low')) return 0.35;
  return 0.5;
}

String prettyLabel(String label) {
  final String trimmed = label.trim();
  if (trimmed.isEmpty) return '—';
  return trimmed
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .map((String segment) {
        if (segment.isEmpty) return segment;
        return segment[0].toUpperCase() + segment.substring(1).toLowerCase();
      })
      .join(' ');
}

IconData iconForDetection(String label) {
  final String normalized = label.toLowerCase();
  if (normalized.contains('container') || normalized.contains('bucket'))
    return Icons.inventory_2_outlined;
  if (normalized.contains('tyre') || normalized.contains('tire'))
    return Icons.directions_car_filled;
  if (normalized.contains('stagnant') || normalized.contains('water'))
    return Icons.water_drop_outlined;
  if (normalized.contains('gutter') || normalized.contains('drain'))
    return Icons.construction_outlined;
  if (normalized.contains('waste') || normalized.contains('trash'))
    return Icons.delete_outline_rounded;
  if (normalized.contains('larva') || normalized.contains('mosquito'))
    return Icons.bug_report_outlined;
  return Icons.search_rounded;
}

String percent(dynamic value) {
  if (value == null) return '—';
  final double? numeric = double.tryParse(value.toString());
  if (numeric == null) return textOrDash(value);
  return '${(numeric * 100).clamp(0, 100).toStringAsFixed(0)}%';
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> openExternalLink(BuildContext context, String? url) async {
  if (url == null || url.trim().isEmpty) {
    showMessage(context, 'No link is available.');
    return;
  }

  final Uri uri = Uri.tryParse(url.trim()) ?? Uri();
  if (uri.scheme.isEmpty || uri.host.isEmpty) {
    showMessage(context, 'The provided link is not valid.');
    return;
  }

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      showMessage(context, 'Could not open the link.');
    }
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
