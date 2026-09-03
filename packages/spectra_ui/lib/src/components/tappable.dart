import 'package:material_ui/material_ui.dart';

import '../theme/spectra_theme.dart';
import '../tokens/motion.dart';

/// The one tappable primitive every interactive Spectra component sits on.
///
/// A bare `GestureDetector` is invisible to a keyboard and to a screen
/// reader's tap action: it cannot take focus, Enter and Space do nothing, and
/// a `Semantics(button: true)` wrapper around it advertises a button with no
/// [SemanticsAction.tap]. This wraps the gesture in a
/// [FocusableActionDetector] so the target is reachable with Tab, activates
/// on Enter and Space, shows a token focus ring and a hover tint on desktop,
/// and puts `onTap` on the semantics node itself.
///
/// It is deliberately unstyled apart from the focus and hover overlay: the
/// calling component owns its own fill, border and padding, and passes
/// [borderRadius] so the ring follows the shape it draws.
class SpectraTappable extends StatefulWidget {
  const SpectraTappable({
    required this.onTap,
    required this.child,
    this.semanticsLabel,
    this.enabled = true,
    this.excludeSemantics = true,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
    this.expanded,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Null (or [enabled] false) makes the target inert and unfocusable.
  final VoidCallback? onTap;

  final Widget child;

  /// The label the whole target announces. Null keeps the child's own
  /// semantics — pass [excludeSemantics] false in that case.
  final String? semanticsLabel;

  final bool enabled;

  /// Drops the child's semantics in favour of [semanticsLabel], so a tile
  /// announces one node rather than one per line of text.
  final bool excludeSemantics;

  final HitTestBehavior behavior;

  /// The shape of the focus ring; should match the child's own corners.
  final BorderRadius? borderRadius;

  /// Announces the target as expandable and says which way it currently
  /// sits. Null leaves the node without an expanded state.
  final bool? expanded;

  final FocusNode? focusNode;
  final bool autofocus;

  /// The focus ring's stroke width, in logical pixels.
  static const double focusRingWidth = 2;

  @override
  State<SpectraTappable> createState() => _SpectraTappableState();
}

class _SpectraTappableState extends State<SpectraTappable> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _handleTap() {
    if (!_active) return;
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    final SpectraTheme theme = SpectraTheme.of(context);
    final Color ring = _focused && _active
        ? theme.colors.accent
        : const Color(0x00000000);
    final Color hover = _hovered && _active
        ? theme.colors.accent.withValues(alpha: 0.06)
        : const Color(0x00000000);

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _active,
        label: widget.semanticsLabel,
        expanded: widget.expanded,
        onTap: _active ? _handleTap : null,
        child: FocusableActionDetector(
          enabled: _active,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          mouseCursor: _active
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (bool value) {
            if (value != _focused) setState(() => _focused = value);
          },
          onShowHoverHighlight: (bool value) {
            if (value != _hovered) setState(() => _hovered = value);
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                _handleTap();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (ButtonActivateIntent intent) {
                _handleTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: widget.behavior,
            onTap: _active ? _handleTap : null,
            // `foregroundDecoration` paints over the child without taking
            // part in layout, so the ring never shifts the content inside it.
            child: AnimatedContainer(
              duration: SpectraMotion.fast,
              curve: SpectraMotion.standard,
              foregroundDecoration: BoxDecoration(
                color: hover,
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: ring,
                  width: SpectraTappable.focusRingWidth,
                ),
              ),
              // The child's own semantics are dropped here rather than on the
              // outer `Semantics`, so the detector's focusable flag survives:
              // a node excluded at the top would advertise a button a screen
              // reader cannot focus.
              child: widget.excludeSemantics
                  ? ExcludeSemantics(child: widget.child)
                  : widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
