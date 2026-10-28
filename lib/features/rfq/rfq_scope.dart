import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/widgets/title_bar.dart';
import 'api_rfq_repository.dart';
import 'demo_rfq_repository.dart';
import 'rfq_links.dart';
import 'rfq_repository.dart';

final _apiRepositories = Expando<ApiRfqRepository>('rfq');
DemoRfqRepository? _demo;

/// The repository the requirements screens use when none is passed: one
/// provided above them (`Provider<RfqRepository>`), else one per signed-in API
/// client (so the taxonomy is fetched once), else the sample content in a
/// demo build (one for the whole app, so what is done on one screen shows on
/// the next).
RfqRepository rfqRepositoryOf(BuildContext context) {
  final provided = Provider.of<RfqRepository?>(context, listen: false);
  if (provided != null) return provided;
  if (AppConfig.demo) return _demo ??= DemoRfqRepository();
  final api = context.read<ApiClient>();
  return _apiRepositories[api] ??= ApiRfqRepository(api: api);
}

/// "My RFQ's 3" and "Alerts 2 new" for the Marketplace's chips, read once.
Future<({int myRfqs, int newAlerts})> readRfqCounts(BuildContext context) async {
  final counts = await rfqRepositoryOf(context).counts();
  return (myRfqs: counts.myRfqs, newAlerts: counts.newAlerts);
}

/// What every requirements screen carries to the next: the data source, the
/// way out to the website, and the lead's callbacks for messaging and supplier
/// profiles (each falls back to the website's page when not wired).
class RfqHooks {
  const RfqHooks({
    required this.repository,
    this.links = const SystemRfqLinks(),
    this.onOpenConversation,
    this.onOpenSupplier,
    this.onCreateCompany,
    this.onSeePlans,
  });

  final RfqRepository repository;
  final RfqLinks links;
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;

  /// Founds a company (the account screens'): posting a requirement needs one.
  final VoidCallback? onCreateCompany;

  /// Opens the supplier plans (the lead's): offered beside a refusal that is about the plan.
  final VoidCallback? onSeePlans;

  Future<void> openSite(BuildContext context, String path) => links.openUri(context, repository.sitePage(path));

  /// A thread: the app's messaging when wired, else the website's inbox on it.
  Future<void> openConversation(BuildContext context, String conversationId) async {
    final open = onOpenConversation;
    if (open != null) {
      open(conversationId);
      return;
    }
    await openSite(context, '/messaging?c=$conversationId');
  }

  /// A supplier's profile: the app's when wired, else the website's.
  Future<void> openSupplier(BuildContext context, String vendorId) async {
    final open = onOpenSupplier;
    if (open != null) {
      open(vendorId);
      return;
    }
    await openSite(context, '/vendors/$vendorId');
  }
}

/// The hooks a screen carries to the next one, from what its constructor was
/// given: the repository [rfqRepositoryOf] finds when none was passed, the
/// system links, and the lead's callbacks.
RfqHooks rfqHooksFor(
  BuildContext context, {
  RfqRepository? repository,
  RfqLinks? links,
  ValueChanged<String>? onOpenConversation,
  ValueChanged<String>? onOpenSupplier,
  VoidCallback? onCreateCompany,
  VoidCallback? onSeePlans,
}) => RfqHooks(
  repository: repository ?? rfqRepositoryOf(context),
  links: links ?? const SystemRfqLinks(),
  onOpenConversation: onOpenConversation,
  onOpenSupplier: onOpenSupplier,
  onCreateCompany: onCreateCompany,
  onSeePlans: onSeePlans,
);

/// The page frame every requirements screen shares: the title bar (back, the
/// title, the bell) over the body, and an optional bar pinned at the foot.
class RfqScaffold extends StatelessWidget {
  const RfqScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onBell,
    this.onBack,
    this.unread = 0,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback onBell;
  final int unread;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: bottomBar,
        body: SafeArea(
          bottom: bottomBar == null,
          child: Stack(
            children: [
              Positioned.fill(top: TitleBar.height, child: body),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(title: title, onBack: onBack, unread: unread, onBell: onBell),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
