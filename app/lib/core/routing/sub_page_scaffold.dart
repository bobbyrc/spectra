import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The back affordance for a route pushed on top of a shell branch, in one
/// place.
///
/// `SpectraAppShell`'s own `AppBar` (`ShellScaffold`) sits above the branch
/// navigator and keeps showing the top-level section's title, so a pushed
/// sub-route has no way back on its own. Nesting a second `Scaffold`/
/// `AppBar` here, with a [BackButton] that pops the branch's navigator, is
/// that way back — used by `/tools/frame-log`, `/tools/update` and
/// `/slots/:index`.
///
/// This lives in `core/` because a feature may not import another feature's
/// internals (spec 8.4) and three copies of one `Scaffold` is exactly what
/// this file exists to prevent.
class SubPageScaffold extends StatelessWidget {
  const SubPageScaffold({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(title),
      ),
      body: body,
    );
  }
}
