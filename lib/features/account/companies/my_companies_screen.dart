import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../account_repository.dart';
import '../widgets/account_kit.dart';
import '../widgets/account_session.dart';
import 'ask_to_join_sheet.dart';
import 'companies_controller.dart';
import 'company_rows.dart';
import 'company_words.dart';
import 'create_company_screen.dart';
import 'leave_company_dialog.dart';

/// The website's `/account/companies`: the companies the person belongs to,
/// which one they are acting for, and what they can do about it: act for
/// another (or for themselves), leave one, take back a request, ask to join a
/// company, or create one.
///
/// A switch, a leave or a create hands back a fresh token pair; the screen
/// adopts it through the app's [AuthController] (read from `Provider`) and
/// calls [onSessionChanged] so the app can reset what it cached for the
/// previous company.
class MyCompaniesScreen extends StatefulWidget {
  const MyCompaniesScreen({
    super.key,
    this.repository,
    this.onBack,
    this.onSessionChanged,
    this.onOpenCompany,
    this.onCreated,
    this.pickPhoto,
    this.onNextStep,
    this.searchDelay,
  });

  /// Where the calls go; the API (or the sample member in demo mode) when null.
  final AccountRepository? repository;

  /// Back from the title bar; defaults to popping the route.
  final VoidCallback? onBack;

  /// The company being acted for changed (a switch, a leave, a create): reset
  /// cached answers, as the website resets every query.
  final VoidCallback? onSessionChanged;

  /// Opens a company's public page (`/companies/:id`). "View page" is hidden without it.
  final void Function(String companyId)? onOpenCompany;

  /// A company was created from this screen (after [onSessionChanged]).
  final void Function(MyCompany company)? onCreated;

  /// Chooses a logo for a new company; the logo row is hidden without it.
  final Future<PickedPhoto?> Function()? pickPhoto;

  /// What the welcome state's next steps do on the created company (team,
  /// verification, selling, details); the steps are plain notes without it.
  final void Function(CompanyNextStep step, MyCompany company)? onNextStep;

  /// How long typing settles before a company search or lookalike check runs.
  final Duration? searchDelay;

  @override
  State<MyCompaniesScreen> createState() => _MyCompaniesScreenState();
}

class _MyCompaniesScreenState extends State<MyCompaniesScreen> {
  late final CompaniesController _controller;
  final _search = TextEditingController();

  /// Search appears once the list is long enough to need it (the website's rule).
  static const _searchFrom = 6;

  late final AccountRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? accountRepositoryOf(context);
    final auth = context.read<AuthController>();
    _controller = CompaniesController(
      repository: _repository,
      adopt: (t) => auth.adoptSession(accessToken: t.accessToken, refreshToken: t.refreshToken, user: t.user),
      onSessionChanged: widget.onSessionChanged,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _switch(String? companyId, String name) async {
    final ok = await _controller.switchTo(companyId);
    if (ok && mounted) _say(companyId == null ? 'Now acting as yourself.' : 'Now acting for $name.');
  }

  Future<void> _leave(MyCompany company) async {
    final left = await showLeaveCompanyDialog(context, company: company, leave: () => _controller.leave(company));
    if (left && mounted) _say('You left ${company.name}.');
  }

  Future<void> _withdraw(JoinRequest request) async {
    final ok = await _controller.withdraw(request.companyId);
    if (ok && mounted) _say('Request to join ${request.name} withdrawn.');
  }

  Future<void> _askToJoin() async {
    final data = _controller.data;
    final asked = await showAskToJoinSheet(
      context,
      search: _repository.searchCompanies,
      send: _controller.requestToJoin,
      memberOf: {for (final c in data?.companies ?? const <MyCompany>[]) c.companyId},
      requested: {for (final r in data?.requests ?? const <JoinRequest>[]) r.companyId},
      searchDelay: widget.searchDelay ?? const Duration(milliseconds: 300),
    );
    if (asked != null && mounted) _say('Request sent to ${asked.name}.');
  }

  Future<void> _create() async {
    final auth = context.read<AuthController>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: CreateCompanyScreen(
            repository: _repository,
            onSessionChanged: widget.onSessionChanged,
            onCreated: (company) {
              widget.onCreated?.call(company);
              _controller.load(refresh: true);
            },
            pickPhoto: widget.pickPhoto,
            onNextStep: widget.onNextStep,
            onViewCompany: widget.onOpenCompany,
            searchDelay: widget.searchDelay,
          ),
        ),
      ),
    );
    if (mounted) _controller.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainer,
      appBar: AccountBar(title: CompanyWords.listTitle, onBack: widget.onBack),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final c = _controller;
          if (c.loading && c.data == null) return const AccountLoading();
          final data = c.data;
          if (data == null) {
            return AccountError(
              message: c.loadError ?? CompanyWords.couldNotLoad,
              onRetry: c.load,
              title: CompanyWords.couldNotLoad,
            );
          }
          return RefreshIndicator(
            onRefresh: () => c.load(refresh: true),
            child: _list(context, c, data),
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, CompaniesController c, MyCompanies data) {
    if (!data.canJoinCompanies) {
      return ListView(
        key: const Key('companies.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          _Intro(),
          AccountCard(
            child: Row(
              key: const Key('companies.staff'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.shield, size: 22, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(CompanyWords.staffNote, style: AccountText.body)),
              ],
            ),
          ),
        ],
      );
    }

    final query = _search.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? data.companies
        : [
            for (final co in data.companies)
              if ([co.name, co.city, co.state, roleLabel(co.role)].any((v) => v?.toLowerCase().contains(query) ?? false))
                co,
          ];
    final personalActive = !data.companies.any((co) => co.active);
    final busy = c.busy;

    return ListView(
      key: const Key('companies.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        if (c.actionError != null) _ErrorBanner(message: c.actionError!, onClose: c.dismissError),
        const _Intro(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountButton(
                key: const Key('companies.create'),
                label: 'Create a company',
                icon: Symbols.add_business,
                onPressed: busy ? null : _create,
              ),
              const SizedBox(height: 8),
              AccountButton(
                key: const Key('companies.join'),
                label: 'Ask to join a company',
                icon: Symbols.group_add,
                outlined: true,
                onPressed: busy ? null : _askToJoin,
              ),
            ],
          ),
        ),
        if (data.requests.isNotEmpty) _requests(c, data),
        _workspaces(c, data, shown, personalActive),
        const PrinciplesCard(),
      ],
    );
  }

  Widget _requests(CompaniesController c, MyCompanies data) {
    return Container(
      key: const Key('companies.requests'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(CompanyWords.awaitingApproval, style: AccountText.cardTitle),
                  const SizedBox(width: 6),
                  Text('(${data.requests.length})', style: AccountText.meta),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(CompanyWords.awaitingExplain, style: AccountText.meta),
            ),
            for (final (i, r) in data.requests.indexed)
              JoinRequestRow(
                request: r,
                first: i == 0,
                withdrawing: c.withdrawing == r.companyId,
                disabled: c.busy,
                onWithdraw: () => _withdraw(r),
              ),
          ],
        ),
      ),
    );
  }

  Widget _workspaces(CompaniesController c, MyCompanies data, List<MyCompany> shown, bool personalActive) {
    final searching = data.companies.length >= _searchFrom;
    return Container(
      key: const Key('companies.workspaces'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(CompanyWords.workspaces, style: AccountText.cardTitle),
                      const SizedBox(width: 8),
                      AccountChip(label: '${data.companies.length + 1}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(CompanyWords.workspacesLead, style: AccountText.meta),
                  if (searching) ...[
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('companies.search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: AccountText.input,
                      decoration: InputDecoration(
                        hintText: 'Search companies',
                        hintStyle: AccountText.hint,
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.slate300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (data.companies.isEmpty)
              _Empty(onCreate: _create, onJoin: _askToJoin, busy: c.busy)
            else if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text('No companies match “${_search.text.trim()}”.', key: const Key('companies.noMatch'), style: AccountText.meta),
              ),
            for (final co in shown)
              CompanyWorkspaceRow(
                company: co,
                switchingHere: c.switching == co.companyId,
                disabled: c.busy,
                onSwitch: () => _switch(co.companyId, co.name),
                onLeave: () => _leave(co),
                onOpen: widget.onOpenCompany == null ? null : () => widget.onOpenCompany!(co.companyId),
              ),
            PersonalWorkspaceRow(
              personalRole: data.personalRole,
              active: personalActive,
              switchingHere: c.switching == CompaniesController.personal,
              disabled: c.busy,
              onSwitch: () => _switch(null, ''),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(CompanyWords.listIntro, style: AccountText.body),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('companies.error'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message, style: AccountText.error.copyWith(fontSize: 14)),
            ),
          ),
          IconButton(
            key: const Key('companies.error.close'),
            tooltip: 'Dismiss',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate, required this.onJoin, required this.busy});

  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('companies.empty'),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.slate200))),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Symbols.business, size: 26, color: AppColors.slate500),
          ),
          const SizedBox(height: 12),
          Text(CompanyWords.emptyTitle, style: AccountText.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(CompanyWords.emptyBody, style: AccountText.body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AccountButton(
            key: const Key('companies.empty.create'),
            label: 'Create a company',
            icon: Symbols.add_business,
            onPressed: busy ? null : onCreate,
          ),
          const SizedBox(height: 8),
          AccountButton(
            key: const Key('companies.empty.join'),
            label: 'Find your company',
            icon: Symbols.group_add,
            outlined: true,
            onPressed: busy ? null : onJoin,
          ),
        ],
      ),
    );
  }
}
