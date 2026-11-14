import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_session.dart';
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'catalog_controller.dart';
import 'catalog_models.dart';
import 'catalog_parts.dart';
import 'catalog_repository.dart';
import 'catalog_words.dart';

/// The catalogue calls for a screen: the API through the app's client, or the sample catalogue in demo mode
/// (`FEED_SOURCE=demo`).
CatalogRepository catalogRepositoryOf(BuildContext context) =>
    AppConfig.demo ? DemoCatalogRepository() : ApiCatalogRepository(api: context.read<ApiClient>());

/// Who is looking, from the signed-in session; nobody (no company, no role) without one.
CatalogViewer catalogViewerOf(BuildContext context) {
  final user = maybeAuth(context)?.user;
  return user == null ? const CatalogViewer(role: '') : CatalogViewer(role: user.role, companyId: user.companyId);
}

/// The frame both catalogue pages share: the title bar, and in place of the list the notes a page shows to someone
/// with no company or a role that does not manage the catalogue, the loading and failed reads, and otherwise the
/// list (pull to refresh) with the bulk bar under it while a selection is open.
class CatalogScaffold<T extends CatalogRow> extends StatelessWidget {
  const CatalogScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.controller,
    required this.couldNotLoad,
    required this.children,
    this.onCreateCompany,
    this.bulkBar,
  });

  final String title;
  final VoidCallback onBack;
  final CatalogController<T> controller;
  final String couldNotLoad;

  /// The list's content, once there is a list to show.
  final List<Widget> Function(BuildContext context) children;
  final VoidCallback? onCreateCompany;
  final Widget? bulkBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: title, onBack: onBack, onBell: () => openNotifications(context)),
            Expanded(child: _body(context)),
            ?bulkBar,
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final viewer = controller.viewer;
    if (!viewer.hasCompany) return NoCompanyNote(onCreateCompany: onCreateCompany);
    if (!viewer.canManage) {
      return const CatalogNote(
        key: Key('catalog.notYours'),
        icon: Symbols.lock,
        title: CatalogWords.notYoursTitle,
        text: CatalogWords.notYoursBody,
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        if (c.loading && !c.loaded) return const SiteLoading();
        if (!c.loaded) {
          return SiteError(
            key: const Key('catalog.loadError'),
            message: c.loadError ?? couldNotLoad,
            onRetry: () => c.load(),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => c.load(refresh: true),
          child: ListView(
            key: const Key('catalog.list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            children: children(context),
          ),
        );
      },
    );
  }
}

/// The list's own notice while filters hide every row.
class NothingMatches extends StatelessWidget {
  const NothingMatches({super.key, required this.text, required this.onClear});

  final String text;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        key: const Key('catalog.nothingMatches'),
        children: [
          const Icon(Symbols.search, size: 32, color: AppColors.slate300),
          const SizedBox(height: 8),
          Text(text, style: SiteText.subheading, textAlign: TextAlign.center),
          TextButton(
            key: const Key('catalog.clearFilters'),
            onPressed: onClear,
            child: Text(CatalogWords.clearFilters, style: SiteText.link),
          ),
        ],
      ),
    );
  }
}

/// The hairline between rows.
const catalogRule = Divider(height: 1, thickness: 1, color: SiteColors.hairline);
