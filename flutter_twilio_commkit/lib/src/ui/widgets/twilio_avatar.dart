import 'package:flutter/material.dart';

/// Avatar helper — builds circular profile picture widgets.
///
/// Uses `https://i.pravatar.cc/150?u=<identity>` as the default image URL.
/// Pass [imageUrl] to override with a custom URL.
/// Shows a shimmer placeholder while loading.
/// Falls back to a coloured circle with a person icon on error.
class TwilioAvatar {
  TwilioAvatar._();

  static const _kColors = [
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00695C),
    Color(0xFFAD1457),
    Color(0xFF2E7D32),
    Color(0xFFE65100),
    Color(0xFF4E342E),
    Color(0xFF37474F),
    Color(0xFF880E4F),
    Color(0xFF1A237E),
  ];

  static Color _bg(String identity) {
    if (identity.isEmpty) return _kColors[0];
    final h = identity.codeUnits.fold(0, (int a, int b) => (a * 17 + b) & 0x7FFFFFFF);
    return _kColors[h % _kColors.length];
  }

  /// Builds a circular avatar for [identity].
  ///
  /// Loads the pravatar URL by default, or [imageUrl] if provided.
  /// Shows a loading shimmer while the image fetches.
  static Widget build({
    required String identity,
    double size = 80,
    String? imageUrl,
  }) {
    final url = (imageUrl != null && imageUrl.isNotEmpty)
        ? imageUrl
        : 'https://i.pravatar.cc/150?u=${Uri.encodeComponent(identity)}';
    final bg = _bg(identity);

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: _NetworkImageWithFallback(
          url: url,
          size: size,
          bg: bg,
        ),
      ),
    );
  }
}

// ─── Network image with loading shimmer and error fallback ────────────────────

class _NetworkImageWithFallback extends StatefulWidget {
  const _NetworkImageWithFallback({
    required this.url,
    required this.size,
    required this.bg,
  });
  final String url;
  final double size;
  final Color bg;

  @override
  State<_NetworkImageWithFallback> createState() =>
      _NetworkImageWithFallbackState();
}

class _NetworkImageWithFallbackState extends State<_NetworkImageWithFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child; // fully loaded
        // Shimmer placeholder while loading
        return AnimatedBuilder(
          animation: _shimmer,
          builder: (_, __) => Container(
            width: widget.size,
            height: widget.size,
            color: Color.lerp(
              widget.bg.withValues(alpha: 0.4),
              widget.bg.withValues(alpha: 0.75),
              _shimmer.value,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              size: widget.size * 0.45,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        width: widget.size,
        height: widget.size,
        color: widget.bg,
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          size: widget.size * 0.55,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}


/// Returns a deterministic background colour for [identity].
Color avatarColorFor(String identity) {
  const c = [
    Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFF00695C),
    Color(0xFFAD1457), Color(0xFF2E7D32), Color(0xFFE65100),
    Color(0xFF4E342E), Color(0xFF37474F), Color(0xFF880E4F),
    Color(0xFF1A237E),
  ];
  if (identity.isEmpty) return c[0];
  final h = identity.codeUnits.fold(0, (int a, int b) => (a * 17 + b) & 0x7FFFFFFF);
  return c[h % c.length];
}
