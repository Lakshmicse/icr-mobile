import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../workspaces/workspaces.dart' show actsAsMentor;
import 'api_assistant_repository.dart';
import 'assistant_controller.dart';
import 'assistant_models.dart';
import 'assistant_screen.dart';
import 'demo_assistant_repository.dart';

/// Where Saathi's answers come from: the API beside the API's everything else, the sample answers in the demo.
AssistantController assistantControllerFor(BuildContext context) => AssistantController(
  AppConfig.demo ? DemoAssistantRepository() : ApiAssistantRepository(api: context.read<ApiClient>()),
);

/// Opens Saathi over whatever is showing — the launcher on the shell, a `/ai` link — for the person signed in (or
/// not) and the page [path] stands for. The app keeps one conversation (`AssistantController` above the shell);
/// without one, as in a test, a fresh conversation opens.
Future<void> openAssistant(BuildContext context, {String? path}) {
  final controller = Provider.of<AssistantController?>(context, listen: false) ?? assistantControllerFor(context);
  final user = Provider.of<AuthController?>(context, listen: false)?.user;
  final ctx = AssistantContext(
    path: path ?? '/',
    signedIn: user != null,
    role: user?.role,
    hasCompany: user == null ? null : user.companyId != null,
    mentor: user == null ? null : actsAsMentor(user),
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AssistantScreen(controller: controller, context: ctx, user: user)),
  );
}

/// The launcher: Saathi's mark as a round button, bottom-right over the tabs (the website's floating one).
class SaathiLauncher extends StatelessWidget {
  const SaathiLauncher({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open $assistantName, the ICR Assistant',
      child: Material(
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x66134A7A),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('saathi-launcher'),
          onTap: onTap,
          child: const SaathiMark(size: 52),
        ),
      ),
    );
  }
}
