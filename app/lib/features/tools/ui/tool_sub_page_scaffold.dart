import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The back-affordance the Task 10 review asked for, in one place.
///
/// The shell's own `AppBar` (`ShellScaffold`) sits above the branch
/// navigator and keeps showing the top-level section's title ("Tools"), so
/// a pushed sub-route has no way back on its own. Nesting a second
/// `Scaffold`/`AppBar` here, with a [BackButton] that pops the branch's own
/// navigator, is that way back — used by both `/tools/frame-log` and
/// `/tools/update`.
///
/// Phase 8 replaces `UpdatePage`'s body wholesale, not this wrapper — before
/// reusing it there (or anywhere else a sub-route is pushed), check whether
/// the shell has grown its own per-route title/back handling by then; a
/// third nested `Scaffold` copied without checking is exactly the situation
/// this file exists to avoid.
class ToolSubPageScaffold extends StatelessWidget {
  const ToolSubPageScaffold({
    required this.title,
    required this.body,
    super.key,
  });

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
