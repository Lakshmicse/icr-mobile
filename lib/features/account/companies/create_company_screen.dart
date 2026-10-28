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
import 'company_lookups.dart';
import 'create_company_controller.dart';
import 'lookalikes_card.dart';

/// What the welcome state offers once the page exists, each on the screen that
/// already does it: the team, the company check, a supplier listing, the details.
enum CompanyNextStep { team, verify, sell, details }

/// The website's `/account/companies/new`: one screen, like a LinkedIn page.
/// Asks who the company is (name, industry, head-office city, size and
/// organisation type) and for a tick that the person may act for it; website,
/// logo, tagline and a different registered legal name are optional. Any member
/// may; they become its admin and act for it. Tax IDs, documents, address and
/// contact are not asked here: the company check asks them the first time an
/// action needs trust.
///
/// While the form is filled in, companies already on ICR that look alike are
/// offered ("Ask to join"): a suggestion, never a block. Create hands back a
/// fresh token pair; the screen adopts it through the app's [AuthController]
/// (read from `Provider`), calls [onSessionChanged], then [onCreated] with the
/// new company, and turns into a welcome state.
class CreateCompanyScreen extends StatefulWidget {
  const CreateCompanyScreen({
    super.key,
    this.repository,
    this.onBack,
    this.onSessionChanged,
    this.onCreated,
    this.pickPhoto,
    this.onNextStep,
    this.onViewCompany,
    this.searchDelay,
  });

  /// Where the calls go; the API (or the sample member in demo mode) when null.
  final AccountRepository? repository;

  /// Back from the title bar and "Done"; defaults to popping the route.
  final VoidCallback? onBack;

  /// The company being acted for changed: reset cached answers.
  final VoidCallback? onSessionChanged;

  /// The company exists (after [onSessionChanged]).
  final void Function(MyCompany company)? onCreated;

  /// Chooses a logo image on the phone; the logo row is hidden without it.
  final Future<PickedPhoto?> Function()? pickPhoto;

  /// A welcome-state step was tapped. The steps are plain notes without it.
  final void Function(CompanyNextStep step, MyCompany company)? onNextStep;

  /// Opens a company's public page, from a suggestion. "View page" is hidden without it.
  final void Function(String companyId)? onViewCompany;

  /// How long typing settles before companies that look alike are asked for.
  final Duration? searchDelay;

  @override
  State<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends State<CreateCompanyScreen> {
  late final CreateCompanyController _c;
  final _name = TextEditingController();
  final _legalName = TextEditingController();
  final _website = TextEditingController();
  final _description = TextEditingController();
  final _nameFocus = FocusNode();
  final _legalFocus = FocusNode();
  final _websiteFocus = FocusNode();
  final _anchors = {for (final f in CompanyField.values) f: GlobalKey()};

  static const _descriptionMax = 500;

  late final AccountRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? accountRepositoryOf(context);
    final auth = context.read<AuthController>();
    _c = CreateCompanyController(
      repository: _repository,
      adopt: (t) => auth.adoptSession(accessToken: t.accessToken, refreshToken: t.refreshToken, user: t.user),
      onSessionChanged: widget.onSessionChanged,
      lookalikeDelay: widget.searchDelay ?? const Duration(milliseconds: 400),
    )..start();
  }

  @override
  void dispose() {
    _c.dispose();
    for (final x in [_name, _legalName, _website, _description]) {
      x.dispose();
    }
    for (final x in [_nameFocus, _legalFocus, _websiteFocus]) {
      x.dispose();
    }
    super.dispose();
  }

  void _leave() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _back() async {
    if (_c.dirty) {
      final discard = await confirmAction(
        context,
        title: 'Discard this company page?',
        message: 'What you entered has not been saved.',
        confirm: 'Discard',
      );
      if (!discard || !mounted) return;
    }
    _leave();
  }

  void _jump(CompanyField field) {
    final context = _anchors[field]!.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, alignment: 0.1, duration: const Duration(milliseconds: 250));
    }
    switch (field) {
      case CompanyField.name:
        _nameFocus.requestFocus();
      case CompanyField.legalName:
        _legalFocus.requestFocus();
      case CompanyField.website:
        _websiteFocus.requestFocus();
      default:
        break;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await _c.submit();
    if (!mounted) return;
    if (ok) {
      widget.onCreated?.call(_c.created!);
    } else if (_c.firstProblem != null) {
      // Take them to the first problem once its message has drawn.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _c.firstProblem != null) _jump(_c.firstProblem!);
      });
    }
  }

  // --- pickers -------------------------------------------------------------------------------------------------

  Future<void> _pickIndustry() async {
    final options = _c.industryOptions.isEmpty ? industries : _c.industryOptions;
    final picked = await showAccountPicker<IndustryOption>(
      context,
      title: 'Industry',
      items: options,
      labelOf: (o) => o.$2,
      selected: options.where((o) => o.$1 == _c.industry).firstOrNull,
    );
    if (picked != null) _c.setIndustry(picked.$1);
  }

  Future<void> _pickStructure() async {
    final picked = await showAccountPicker<(String, String)>(
      context,
      title: 'Organisation type',
      items: legalStructures,
      labelOf: (o) => o.$2,
      selected: legalStructures.where((o) => o.$1 == _c.legalStructure).firstOrNull,
    );
    if (picked != null) _c.setLegalStructure(picked.$1);
  }

  Future<void> _pickCity() async {
    await _c.loadCities();
    if (!mounted || _c.cities.isEmpty) return;
    final picked = await showAccountPicker<CityOption>(
      context,
      title: 'Where is the head office?',
      items: _c.cities,
      labelOf: (o) => o.label,
      searchable: true,
      selected: _c.city,
    );
    if (picked != null) _c.setCity(picked);
  }

  Future<void> _pickLogo() async {
    final pick = widget.pickPhoto;
    if (pick == null) return;
    final photo = await pick();
    if (photo != null) await _c.setLogo(photo);
  }

  Future<void> _askToJoin(CompanyLookalike company) async {
    await showAskToJoinSheet(
      context,
      search: _repository.searchCompanies,
      send: _c.askToJoin,
      initial: hitOf(company),
    );
  }

  // --- build ---------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final created = _c.created;
        return PopScope(
          canPop: !_c.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            backgroundColor: AppColors.surfaceContainer,
            appBar: AccountBar(title: 'Create a company page', onBack: _back),
            body: created != null ? _Welcome(company: created, onNextStep: widget.onNextStep, onDone: _leave) : _form(),
          ),
        );
      },
    );
  }

  Widget _form() {
    final c = _c;
    final label = c.name.trim().isEmpty ? 'this company' : c.name.trim();
    return SingleChildScrollView(
      key: const Key('create.form'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Give your company one home on ICR for hiring, buying and selling. It takes about a minute. '
              'Documents are optional here; we ask for them when you first post a job, bid or sell.',
              style: AccountText.body,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AccountChip(
                label: 'About a minute · ${c.requiredCount} required details',
                icon: Symbols.schedule,
              ),
            ),
          ),
          if (c.errors.isNotEmpty) _summary(),
          AccountCard(
            title: 'Company identity',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('How members find and recognise it.', style: AccountText.meta),
                const SizedBox(height: 12),
                Container(
                  key: _anchors[CompanyField.name],
                  child: AccountField(
                    label: 'Company name',
                    required: true,
                    controller: _name,
                    fieldKey: const Key('create.name'),
                    focusNode: _nameFocus,
                    hint: 'Acme Facility Services',
                    helper: 'The brand buyers and candidates know you by.',
                    error: c.errors[CompanyField.name],
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: c.setName,
                  ),
                ),
                AccountCheck(
                  key: const Key('create.legalDiffers'),
                  value: c.legalNameDiffers,
                  onChanged: c.setLegalNameDiffers,
                  label: 'Registered under a different legal name',
                ),
                if (c.legalNameDiffers)
                  Container(
                    key: _anchors[CompanyField.legalName],
                    padding: const EdgeInsets.only(top: 6),
                    child: AccountField(
                      label: 'Registered legal name',
                      controller: _legalName,
                      fieldKey: const Key('create.legalName'),
                      focusNode: _legalFocus,
                      hint: 'Acme Facility Services Private Limited',
                      helper: 'Exactly as on the PAN card. It is not shown on the page; the company check uses it.',
                      error: c.errors[CompanyField.legalName],
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      onChanged: c.setLegalName,
                    ),
                  )
                else
                  SizedBox(key: _anchors[CompanyField.legalName]),
                LookalikesCard(
                  companies: c.lookalikes,
                  asked: c.askedToJoin,
                  onAsk: _askToJoin,
                  onView: widget.onViewCompany,
                ),
                Container(
                  key: _anchors[CompanyField.website],
                  child: AccountField(
                    label: 'Company website',
                    controller: _website,
                    fieldKey: const Key('create.website'),
                    focusNode: _websiteFocus,
                    hint: 'www.yourcompany.com',
                    helper: 'Optional — acme.com or https://acme.com',
                    error: c.errors[CompanyField.website],
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                    onChanged: c.setWebsite,
                  ),
                ),
              ],
            ),
          ),
          AccountCard(
            title: 'Company details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Used to match it with the right jobs, buyers and suppliers.', style: AccountText.meta),
                const SizedBox(height: 12),
                Container(
                  key: _anchors[CompanyField.industry],
                  child: AccountSelectField(
                    key: const Key('create.industry'),
                    label: 'Industry',
                    required: true,
                    hint: 'Select your industry',
                    value: c.industry == null ? null : industryName(c.industry, c.industryOptions),
                    error: c.errors[CompanyField.industry],
                    onTap: _pickIndustry,
                  ),
                ),
                Container(
                  key: _anchors[CompanyField.city],
                  child: AccountSelectField(
                    key: const Key('create.city'),
                    label: 'Where is the head office?',
                    required: true,
                    hint: c.citiesLoading ? 'Loading cities…' : 'Choose a city',
                    value: c.city?.label,
                    error: c.errors[CompanyField.city] ?? c.citiesError,
                    onTap: c.citiesLoading ? null : _pickCity,
                  ),
                ),
                Container(key: _anchors[CompanyField.size], child: _sizeChoice()),
                Container(
                  key: _anchors[CompanyField.legalStructure],
                  child: AccountSelectField(
                    key: const Key('create.structure'),
                    label: 'Organisation type',
                    required: true,
                    hint: 'Choose how it is set up',
                    value: legalStructures.where((o) => o.$1 == c.legalStructure).firstOrNull?.$2,
                    helper: 'Decides which documents verification asks for.',
                    error: c.errors[CompanyField.legalStructure],
                    onTap: _pickStructure,
                  ),
                ),
              ],
            ),
          ),
          AccountCard(
            title: 'Logo and tagline',
            trailing: const AccountChip(label: 'Optional'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pages with a logo and a line about the work get noticed. Add them now or later.',
                  style: AccountText.meta,
                ),
                const SizedBox(height: 12),
                if (widget.pickPhoto != null) ...[_logo(), const SizedBox(height: 14)],
                AccountField(
                  label: 'Tagline',
                  controller: _description,
                  fieldKey: const Key('create.description'),
                  hint: 'What the company does, in a sentence',
                  helper: 'Buyers and candidates read this first.',
                  maxLength: _descriptionMax,
                  maxLines: 4,
                  minLines: 3,
                  counter: true,
                  onChanged: c.setDescription,
                ),
              ],
            ),
          ),
          AccountCard(
            child: Container(
              key: _anchors[CompanyField.authorised],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccountCheck(
                    key: const Key('create.authorised'),
                    value: c.authorised,
                    onChanged: c.setAuthorised,
                    label: 'I’m an authorised representative of $label and may create and manage its page on ICR.',
                    error: c.errors[CompanyField.authorised],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'ICR checks these details, and any documents you add, when the company is verified.',
                      style: AccountText.meta,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (c.submitError != null)
            Container(
              key: const Key('create.error'),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(c.submitError!, style: AccountText.error.copyWith(fontSize: 14)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Symbols.shield, size: 16, color: AppColors.slate500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You become the page’s admin. Everything here can be changed later.',
                    style: AccountText.meta,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountButton(
                  key: const Key('create.submit'),
                  label: c.submitting ? 'Creating…' : 'Create page',
                  busy: c.submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),
                AccountButton(
                  key: const Key('create.cancel'),
                  label: 'Cancel',
                  outlined: true,
                  onPressed: c.submitting ? null : _back,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "3 details need attention" with a link to each, like the website's summary.
  Widget _summary() {
    final open = [
      for (final f in CompanyField.values)
        if (_c.errors.containsKey(f)) f,
    ];
    return Container(
      key: const Key('create.summary'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open.length == 1 ? '1 detail needs attention' : '${open.length} details need attention',
            style: AccountText.error.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              for (final f in open)
                InkWell(
                  key: Key('create.summary.${f.name}'),
                  onTap: () => _jump(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(f.label, style: AccountText.link),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizeChoice() {
    final c = _c;
    final error = c.errors[CompanyField.size];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: AccountText.label,
              children: [
                const TextSpan(text: 'Company size *'),
                TextSpan(text: '  · employees', style: AccountText.meta),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (key, label) in companySizes)
                Semantics(
                  button: true,
                  selected: c.size == key,
                  label: 'Company size $label',
                  excludeSemantics: true,
                  child: InkWell(
                    key: Key('create.size.$key'),
                    onTap: () => c.setSize(key),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: c.size == key ? AppColors.chipEmphasis : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.size == key ? AppColors.primary : (error != null ? AppColors.error : AppColors.slate300),
                          width: c.size == key ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: AccountText.label.copyWith(color: c.size == key ? AppColors.primary : AppColors.slate700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (error != null)
            Padding(padding: const EdgeInsets.only(top: 5), child: Text(error, style: AccountText.error)),
        ],
      ),
    );
  }

  Widget _logo() {
    final c = _c;
    if (c.logoUrl != null) {
      return Column(
        key: const Key('create.logo'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Logo', style: AccountText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: c.logoPreview == null
                      // Material Icons, not Symbols: a release build's subset of the
                      // Symbols font left these two glyphs out (27 Oct 2026).
                      ? const Icon(Icons.image_outlined, color: AppColors.slate400)
                      : Image.memory(
                          c.logoPreview!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: AppColors.slate400),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logo uploaded. It appears on your company page, job posts and supplier card.',
                  style: AccountText.meta,
                ),
              ),
              TextButton(key: const Key('create.logo.remove'), onPressed: c.removeLogo, child: const Text('Remove')),
            ],
          ),
        ],
      );
    }
    return Column(
      key: const Key('create.logo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Logo', style: AccountText.label),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AccountButton(
            key: const Key('create.logo.add'),
            label: c.logoBusy ? 'Uploading…' : 'Add logo',
            icon: Icons.add_photo_alternate_outlined,
            outlined: true,
            expand: false,
            busy: c.logoBusy,
            onPressed: _pickLogo,
          ),
        ),
        const SizedBox(height: 6),
        Text('PNG, JPG or WEBP — up to 2MB', style: AccountText.meta),
        if (c.logoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(c.logoError!, key: const Key('create.logo.error'), style: AccountText.error),
          ),
      ],
    );
  }
}

/// The first view of a page its founder just created, like the website's
/// `NewCompanyWelcome`: the form asked only who the company is, so this is
/// where the rest is offered, each on the screen that already does it.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.company, required this.onNextStep, required this.onDone});

  final MyCompany company;
  final void Function(CompanyNextStep step, MyCompany company)? onNextStep;
  final VoidCallback onDone;

  static const _steps = <(CompanyNextStep, IconData, String, String, String)>[
    (
      CompanyNextStep.team,
      Symbols.group_add,
      'Bring your team',
      'Invite colleagues by email, or approve the people who ask to join.',
      'Invite people',
    ),
    (
      CompanyNextStep.verify,
      Symbols.verified,
      'Get verified',
      'Needed to publish jobs, contact candidates and bid. Have the PAN, GSTIN and registration certificate to hand.',
      'Start verification',
    ),
    (
      CompanyNextStep.sell,
      Symbols.storefront,
      'Sell on ICR',
      'Start selling to appear in Supplier Mart and answer buyers’ requirements. Your listing is filled from your '
          'company and its services.',
      'Start selling',
    ),
    (
      CompanyNextStep.details,
      Symbols.edit,
      'Finish the details',
      'Description, founding year, address and contact — what buyers and candidates read.',
      'Edit details',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('create.welcome'),
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CompanyLogo(url: company.logoUrl, name: company.name, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${company.name} is on ICR',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AccountText.name.copyWith(fontSize: 22, height: 1.25),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'You are its admin and acting for it now. Here is what to do next, in any order, whenever you are '
                  'ready.',
                  style: AccountText.body,
                ),
              ],
            ),
          ),
          for (final (step, icon, title, body, cta) in _steps)
            AccountCard(
              child: Column(
                key: Key('welcome.${step.name}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 22, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title, style: AccountText.itemTitle)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: AccountText.meta),
                  if (onNextStep != null) ...[
                    const SizedBox(height: 10),
                    AccountButton(
                      key: Key('welcome.go.${step.name}'),
                      label: cta,
                      outlined: true,
                      expand: false,
                      height: 38,
                      onPressed: () => onNextStep!(step, company),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AccountButton(key: const Key('create.done'), label: 'Done', onPressed: onDone),
          ),
        ],
      ),
    );
  }
}
