import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import 'post_rfq_controller.dart';
import 'rfq_checklist.dart';
import 'rfq_format.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_rules.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'widgets/composer_parts.dart';
import 'widgets/rfq_widgets.dart';
import 'widgets/supplier_picker.dart';

/// Post RFQ: one guided page for an enquiry and for a staged RFQ (what kind of request, who to reply to, where,
/// what service, what suppliers need to know), then a review of what will be sent, and only then the post. The
/// website's composer, in the app's language.
///
/// The same screen edits a requirement ([editRfqId]) or starts from one posted before ([copyFromRfqId]). A refused
/// send keeps every value and shows the API's own sentence; the files go up as they are chosen.
class PostRfqScreen extends StatefulWidget {
  const PostRfqScreen({
    super.key,
    this.editRfqId,
    this.copyFromRfqId,
    this.initialKind,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
    this.onPosted,
    this.onCreateCompany,
  });

  final String? editRfqId;
  final String? copyFromRfqId;
  final RfqKind? initialKind;
  final RfqRepository? repository;
  final RfqLinks? links;
  final VoidCallback? onBack;
  final VoidCallback? onBell;
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;

  /// Called with what was posted or saved, as it happens (the screen itself stays to confirm it and pops with the
  /// same result when the person leaves).
  final ValueChanged<PostResult>? onPosted;

  /// Founds a company: someone posting as themselves has none, and a requirement is posted for a company. By
  /// default the website's page for it opens.
  final VoidCallback? onCreateCompany;

  @override
  State<PostRfqScreen> createState() => _PostRfqScreenState();
}

class _PostRfqScreenState extends State<PostRfqScreen> {
  late final RfqHooks _hooks;
  late final PostRfqController _c;
  final _scroll = ScrollController();
  final _text = TextEditingController();
  final _anchors = <String, GlobalKey>{
    for (final id in [
      'problems',
      'type',
      'details',
      'location',
      'service',
      'describe',
      'audience',
      'criteria',
      'timeline',
    ])
      id: GlobalKey(debugLabel: 'section-$id'),
  };
  bool _criteriaOpen = false;
  bool _showProblems = false;

  @override
  void initState() {
    super.initState();
    _hooks = RfqHooks(
      repository: widget.repository ?? rfqRepositoryOf(context),
      links: widget.links ?? const SystemRfqLinks(),
      onOpenConversation: widget.onOpenConversation,
      onOpenSupplier: widget.onOpenSupplier,
    );
    _c = PostRfqController(
      repository: _hooks.repository,
      editingId: widget.editRfqId,
      copyFromId: widget.copyFromRfqId,
      initialKind: widget.initialKind,
    );
    _c.start().then((_) {
      if (!mounted) return;
      _text.text = _c.draft.text;
      if (_c.draft.criteriaCount > 0) setState(() => _criteriaOpen = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  // ---- Leaving ---------------------------------------------------------------------------------------

  /// Something was typed or chosen that has not been saved.
  bool get _dirty {
    final d = _c.draft;
    return _c.result == null &&
        !_c.editing &&
        (d.title.isNotEmpty ||
            d.text.trim().isNotEmpty ||
            d.places.isNotEmpty ||
            d.category.isNotEmpty ||
            d.facilityType.isNotEmpty ||
            d.attachments.isNotEmpty ||
            d.items.isNotEmpty ||
            d.budget.isNotEmpty);
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    if (_c.result == null && _dirty) {
      final leave = await confirmMove(
        context,
        title: 'Leave without saving?',
        body: 'What you have typed is not saved yet. Save it as a draft to keep it.',
        confirm: 'Leave',
        keep: 'Keep editing',
        destructive: true,
      );
      if (!leave || !mounted) return;
    }
    navigator.pop(_c.result);
  }

  // ---- Moving around the form --------------------------------------------------------------------------

  static String _sectionOf(String field) => switch (field) {
    'companyName' || 'contactName' || 'contactPhone' => 'details',
    'facilityType' || 'locations' => 'location',
    'category' => 'service',
    'invited' => 'audience',
    'minYears' || 'minAnnualTurnover' || 'minLast3YrTurnover' => 'criteria',
    'preQualEndDate' || 'dueDate' => 'timeline',
    _ => 'describe',
  };

  Future<void> _goTo(String section) async {
    if (section == 'criteria' && !_criteriaOpen) {
      setState(() => _criteriaOpen = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final target = _anchors[section]?.currentContext;
    if (target == null) return;
    // The anchor's own context, read after the frame: it is not this State's.
    // ignore: use_build_context_synchronously
    await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 250), alignment: 0.05);
  }

  void _goToProblem(String field) => _goTo(_sectionOf(field));

  // ---- Sending ---------------------------------------------------------------------------------------------

  bool get _isDraftOrNew => !_c.editing || _c.source?.status == RfqStatus.draft;

  Future<void> _send({required bool publish}) async {
    FocusScope.of(context).unfocus();
    if (_c.uploading) {
      showMessage(context, 'Wait for the files to finish uploading.');
      return;
    }
    setState(() => _showProblems = true);
    if (!_c.review(publish: publish)) {
      await WidgetsBinding.instance.endOfFrame;
      await _goTo('problems');
      return;
    }
    if (!publish || _c.editing) {
      final ok = await _c.submit(publish: publish);
      if (ok) _posted();
      return;
    }
    await showReviewSheet(
      context,
      title: _c.draft.isRfq ? 'Review your RFQ' : 'Review your enquiry',
      confirmLabel: _c.draft.isRfq ? 'Create RFQ' : 'Send enquiry',
      note: _c.draft.isRfq
          ? 'It goes live to matching suppliers as soon as it is created.'
          : (_c.draft.audience == Audience.invited
                ? 'Only the suppliers you chose are told, and only they can reply.'
                : 'Matching suppliers are alerted as soon as it is posted.'),
      rows: _reviewRows(),
      onEdit: _goTo,
      errorOf: () => _c.error,
      onConfirm: () async {
        final ok = await _c.submit(publish: true);
        if (ok) _posted();
        return ok;
      },
    );
  }

  void _posted() {
    final result = _c.result;
    if (result != null) widget.onPosted?.call(result);
    if (mounted) {
      setState(() => _showProblems = false);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  List<ReviewRow> _reviewRows() {
    final d = _c.draft;
    final text = withoutEmptyPrompts(d.text);
    final files = d.attachments.map((f) => f.title.trim()).where((t) => t.isNotEmpty);
    final budget = parseRupees(d.budget);
    return [
      ReviewRow(label: 'Request type', value: d.isRfq ? 'Request for quotation' : 'Enquiry', section: 'type'),
      ReviewRow(label: 'Title', value: _c.effectiveTitle, section: 'describe'),
      ReviewRow(
        label: 'Contact',
        value: [
          _c.companyFromAccount ?? d.companyName,
          d.contactName,
          d.contactPhone,
        ].where((s) => s.trim().isNotEmpty).join(' · '),
        section: 'details',
      ),
      ReviewRow(label: 'Facility type', value: d.facilityType, section: 'location'),
      ReviewRow(label: 'Locations', value: d.places.map((p) => p.label).join(' · '), section: 'location'),
      ReviewRow(label: 'Service', value: _c.servicePath, section: 'service'),
      ReviewRow(
        label: d.isRfq ? 'Scope' : 'Description',
        value: text.length > 300 ? '${text.substring(0, 300)}…' : text,
        section: 'describe',
      ),
      if (budget != null && !budget.isNaN) ReviewRow(label: 'Budget', value: formatInr(budget), section: 'describe'),
      if (d.items.isNotEmpty)
        ReviewRow(
          label: 'Line items',
          value: d.items.map((i) => '${i.name} × ${i.quantity}').join(', '),
          section: 'describe',
        ),
      ReviewRow(
        label: 'Files',
        value: files.isEmpty ? '' : '${files.length} file${files.length == 1 ? '' : 's'}: ${files.join(', ')}',
        section: 'describe',
      ),
      if (!d.isRfq)
        ReviewRow(
          label: 'Who can reply',
          value: d.audience == Audience.invited
              ? 'Only ${d.invited.map((s) => s.name).join(', ')}'
              : 'Every supplier that matches',
          section: 'audience',
        ),
      if (d.isRfq) ...[
        ReviewRow(
          label: 'Criteria',
          value: d.criteriaCount == 0 ? 'None: any matched supplier can pre-qualify' : '${d.criteriaCount} set',
          section: 'criteria',
        ),
        ReviewRow(
          label: 'Deadlines',
          value: d.preQualEndDate != null && d.dueDate != null
              ? 'Pre-qualification until ${pickedDay(d.preQualEndDate!)} · quotes by ${pickedDay(d.dueDate!)}'
              : '',
          section: 'timeline',
        ),
      ] else if (d.dueDate != null)
        ReviewRow(label: 'Reply by', value: pickedDay(d.dueDate!), section: 'timeline'),
    ];
  }

  // ---- Choosing ---------------------------------------------------------------------------------------

  Future<void> _pickFacility() async {
    final d = _c.draft;
    final options = [
      ...facilityTypes,
      if (d.facilityType.isNotEmpty && !facilityTypes.contains(d.facilityType)) d.facilityType,
    ];
    final picked = await pickOne<String>(
      context,
      title: 'Facility type',
      options: options,
      labelOf: (s) => s,
      selected: d.facilityType.isEmpty ? null : d.facilityType,
    );
    if (picked?.value != null) _c.update((d) => d.facilityType = picked!.value!);
  }

  Future<void> _pickCategory() async {
    final picked = await pickOne<CategoryNode>(
      context,
      title: 'Service category',
      options: _c.categories,
      labelOf: (n) => n.name,
      selected: _c.categories.where((n) => n.key == _c.draft.category).firstOrNull,
    );
    if (picked?.value != null) _c.setCategory(picked!.value!.key);
  }

  Future<void> _pickSubcategory() async {
    final picked = await pickOne<CategoryNode>(
      context,
      title: 'Sub-category',
      options: _c.subcategories,
      labelOf: (n) => n.name,
      selected: _c.subcategories.where((n) => n.key == _c.draft.subcategory).firstOrNull,
      clearLabel: 'No sub-category',
    );
    if (picked == null) return;
    await _c.setSubcategory(picked.value?.key ?? '');
  }

  Future<void> _pickSpecialisation() async {
    final picked = await pickOne<CategoryNode>(
      context,
      title: 'Specialisation',
      options: _c.specialisations,
      labelOf: (n) => n.name,
      selected: _c.specialisations.where((n) => n.key == _c.draft.service).firstOrNull,
      clearLabel: 'No specialisation',
    );
    if (picked != null) _c.setService(picked.value?.key ?? '');
  }

  Future<void> _addItem() async {
    final item = await showItemSheet(context);
    if (item != null) _c.addItem(item);
  }

  Future<void> _editItem(int index) async {
    final item = await showItemSheet(context, item: _c.draft.items[index]);
    if (item != null) _c.replaceItem(index, item);
  }

  Future<void> _pickDay({required bool preQual}) async {
    final d = _c.draft;
    final picked = await pickDay(
      context,
      current: preQual ? d.preQualEndDate : d.dueDate,
      after: preQual ? null : d.preQualEndDate,
      help: preQual ? 'Pre-qualification deadline' : (d.isRfq ? 'Quote deadline' : 'Reply by'),
    );
    if (picked == null) return;
    _c.update((d) {
      if (preQual) {
        d.preQualEndDate = picked;
        if (d.dueDate != null && !d.dueDate!.isAfter(picked)) d.dueDate = null;
      } else {
        d.dueDate = picked;
      }
    });
  }

  Future<void> _pickEmployees() async {
    final picked = await pickOne<String>(
      context,
      title: 'Employees',
      options: companySizes,
      labelOf: sizeLabel,
      selected: _c.draft.minEmployees.isEmpty ? null : _c.draft.minEmployees,
      clearLabel: 'No minimum',
    );
    if (picked != null) _c.update((d) => d.minEmployees = picked.value ?? '');
  }

  Future<void> _pickFiles() async {
    final files = await _hooks.links.pickFiles();
    if (files.isNotEmpty) await _c.addFiles(files);
  }

  Future<void> _chooseSuppliers() {
    return showSupplierPicker(
      context,
      title: 'Suppliers to invite',
      confirmLabel: 'Use these suppliers',
      search: _c.findSuppliers,
      selected: _c.draft.invited,
      max: RfqLimits.maxInvites,
      onConfirm: (chosen) async {
        _c.update((d) => d.invited = chosen);
        return null;
      },
    );
  }

  void _addPrompt(String label) {
    final next = withPromptLine(_text.text, label);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _c.update((d) => d.text = next);
  }

  // ---- The page ------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: RfqScaffold(
            title: _c.editing ? 'Edit requirement' : 'Post RFQ',
            onBack: widget.onBack ?? _leave,
            onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
            bottomBar: _bar(),
            body: _body(),
          ),
        );
      },
    );
  }

  Widget? _bar() {
    if (!_c.started ||
        _c.loading ||
        _c.loadError != null ||
        _c.result != null ||
        _c.mustRegisterCompany ||
        _c.roleCannotPost) {
      return null;
    }
    final d = _c.draft;
    final primary = _c.editing
        ? (_c.source?.status == RfqStatus.draft ? 'Publish' : 'Save changes')
        : (d.isRfq ? 'Create RFQ' : 'Send enquiry');
    final busy = _c.sending;
    return BottomActionBar(
      children: [
        if (_isDraftOrNew)
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('save-draft'),
              onPressed: busy ? null : () => _send(publish: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.slate200),
              ),
              child: Text('Save draft', style: RfqText.tab.copyWith(color: AppColors.primary)),
            ),
          ),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            key: const ValueKey('send'),
            label: _c.uploading ? 'Waiting for uploads…' : (busy ? 'Sending…' : primary),
            onPressed: busy || _c.uploading ? null : () => _send(publish: true),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (!_c.started || _c.loading) return const RfqSpinner();
    if (_c.loadError != null) {
      return RfqNotice(
        icon: LucideIcons.cloudOff,
        title: "Couldn't open the form",
        body: _c.loadError,
        action: 'Try again',
        onAction: _c.retry,
      );
    }
    final result = _c.result;
    if (result != null) {
      return SingleChildScrollView(
        child: PostedPanel(
          result: result,
          editing: _c.editing,
          preQualEnd: _c.draft.preQualEndDate,
          onView: _viewPosted,
          onPostAnother: () {
            _c.reset();
            _text.clear();
            setState(() => _criteriaOpen = false);
          },
          onDone: () => Navigator.of(context).pop(_c.result),
        ),
      );
    }
    if (_c.roleCannotPost) {
      return RfqNotice(
        key: const ValueKey('role-cannot-post'),
        icon: LucideIcons.lock,
        title: "Requirements aren't part of your role",
        body: _c.roleCannotPostMessage,
      );
    }
    if (_c.mustRegisterCompany) {
      return RfqNotice(
        icon: LucideIcons.building2,
        title: 'Requirements are posted for a company',
        body:
            'Requirements are posted for a company. Register your company, or switch to one you belong to, then post again.',
        action: 'Create a company',
        onAction: widget.onCreateCompany ?? () => _hooks.openSite(context, '/account/companies/new'),
      );
    }
    return _form();
  }

  Future<void> _viewPosted() async {
    final result = _c.result;
    if (result == null) return;
    final navigator = Navigator.of(context);
    // The composer is replaced by the requirement, and whoever opened the composer still hears what was posted.
    await navigator.pushReplacement<void, PostResult>(
      MaterialPageRoute<void>(builder: (_) => rfqDetailFor(result.id, _hooks)),
      result: result,
    );
  }

  Widget _form() {
    final c = _c;
    final d = c.draft;
    final problems = _showProblems ? c.problems : const <String, String>{};
    String? problem(String field) => problems[field];
    var step = 0;
    int next() => ++step;

    final children = <Widget>[
      if (problems.isNotEmpty)
        KeyedSubtree(
          key: _anchors['problems'],
          child: ProblemsCard(problems: problems, onGo: _goToProblem),
        ),
      if (c.error != null) RfqBanner(c.error!),
      _postingFor(),
      SectionCard(
        key: _anchors['type'],
        step: next(),
        title: 'What kind of request',
        caption: c.editing ? 'A requirement keeps its kind once posted.' : 'Pick how you want to source.',
        done: true,
        child: KindPicker(value: d.kind, locked: c.editing, onChanged: c.setKind),
      ),
      SectionCard(
        key: _anchors['details'],
        step: next(),
        title: 'Your details',
        caption: 'Who suppliers reply to.',
        done: d.contactName.trim().isNotEmpty && contactPhonePattern.hasMatch(d.contactPhone.trim()),
        child: _details(problem),
      ),
      SectionCard(
        key: _anchors['location'],
        step: next(),
        title: 'Service location',
        caption: 'The kind of facility, and every city the work covers.',
        done: d.facilityType.isNotEmpty && d.places.isNotEmpty,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerField(
              key: const ValueKey('facility-field'),
              label: 'Facility type',
              value: d.facilityType.isEmpty ? null : d.facilityType,
              hint: 'Select a facility type',
              help: 'The kind of site the service is for.',
              error: problem('facilityType'),
              onTap: _pickFacility,
            ),
            const SizedBox(height: 14),
            PlacesField(
              places: d.places,
              error: problem('locations'),
              onAdd: () => showPlaceSheet(context, c),
              onRemove: c.removePlace,
            ),
          ],
        ),
      ),
      SectionCard(
        key: _anchors['service'],
        step: next(),
        title: 'Service needed',
        caption: 'Suppliers are matched on this: pick the closest category.',
        done: d.category.isNotEmpty,
        child: _service(problem),
      ),
      SectionCard(
        key: _anchors['describe'],
        step: next(),
        title: 'Tell suppliers what you need',
        caption: 'Include scope, quantity, frequency, timelines and any specific requirements.',
        done: withoutEmptyPrompts(d.text).length >= RfqLimits.descriptionMin && !c.uploading,
        child: _describe(problem),
      ),
      if (d.isRfq)
        SectionCard(
          key: _anchors['criteria'],
          step: next(),
          title: 'Supplier criteria',
          caption: 'The minimum a supplier must meet to pre-qualify. Leave any criterion blank to skip it.',
          optional: true,
          child: _criteria(problem),
        ),
      if (d.isRfq)
        SectionCard(
          key: _anchors['timeline'],
          step: next(),
          title: 'Timeline',
          caption: 'Pre-qualification runs to the first date, detailed quotes to the second.',
          done: d.preQualEndDate != null && d.dueDate != null && d.dueDate!.isAfter(d.preQualEndDate!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DateField(
                key: const ValueKey('prequal-date'),
                label: 'Pre-qualification deadline',
                value: d.preQualEndDate,
                onTap: () => _pickDay(preQual: true),
                error: problem('preQualEndDate'),
                help: 'Suppliers send pre-qualification responses until the end of this day.',
              ),
              const SizedBox(height: 14),
              DateField(
                key: const ValueKey('due-date'),
                label: 'Quote deadline',
                value: d.dueDate,
                onTap: () => _pickDay(preQual: false),
                error: problem('dueDate'),
                help: 'Shortlisted suppliers send quotes until the end of this day.',
              ),
            ],
          ),
        )
      else ...[
        SectionCard(
          key: _anchors['timeline'],
          step: next(),
          title: 'Reply by',
          caption: 'Replies are taken until the end of this day; after it the enquiry closes by itself.',
          optional: true,
          child: DateField(
            key: const ValueKey('due-date'),
            label: 'Reply-by date',
            value: d.dueDate,
            optional: true,
            onTap: () => _pickDay(preQual: false),
            onClear: () => c.update((d) => d.dueDate = null),
            error: problem('dueDate'),
          ),
        ),
        if (!c.editing)
          SectionCard(
            key: _anchors['audience'],
            step: next(),
            title: 'Who can reply',
            caption: 'An enquiry is shown to every matching supplier, or only to the ones you name.',
            child: _audience(problem),
          ),
      ],
      const SizedBox(height: 8),
    ];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView.separated(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => children[i],
      ),
    );
  }

  Widget _postingFor() {
    final name = _c.companyFromAccount;
    return RfqCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          LogoTile(name: name ?? 'ICR', size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_c.editing ? 'Requirement of' : 'Posting for', style: RfqText.small),
                Text(
                  name ?? (_c.askCompany ? 'ICR (you name the company below)' : (_c.poster?.name ?? 'Yourself')),
                  key: const ValueKey('posting-for'),
                  style: RfqText.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(String? Function(String) problem) {
    final d = _c.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_c.askCompany) ...[
          RfqField(
            fieldKey: const ValueKey('company-name'),
            label: 'Company name',
            value: d.companyName,
            maxLength: RfqLimits.companyName,
            help: 'The name suppliers see.',
            error: problem('companyName'),
            onChanged: (v) => _c.update((d) => d.companyName = v),
          ),
          const SizedBox(height: 14),
        ],
        RfqField(
          fieldKey: const ValueKey('contact-name'),
          label: 'Contact person',
          value: d.contactName,
          maxLength: RfqLimits.contactName,
          error: problem('contactName'),
          onChanged: (v) => _c.update((d) => d.contactName = v),
        ),
        const SizedBox(height: 14),
        RfqField(
          fieldKey: const ValueKey('contact-phone'),
          label: 'Phone',
          value: d.contactPhone,
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          maxLength: RfqLimits.phoneMax,
          error: problem('contactPhone'),
          onChanged: (v) => _c.update((d) => d.contactPhone = v),
        ),
        const SizedBox(height: 14),
        RfqField(
          fieldKey: const ValueKey('contact-email'),
          label: 'Email',
          value: d.email,
          readOnly: true,
          help: 'From your account. Suppliers see the company; the person and numbers only through their plan.',
          onChanged: (_) {},
        ),
      ],
    );
  }

  Widget _service(String? Function(String) problem) {
    final c = _c;
    final d = c.draft;
    if (c.categories.isEmpty && c.categoriesLoading) {
      return Text('Loading the list of services…', key: const ValueKey('services-loading'), style: RfqText.formHelp);
    }
    if (c.categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The list of services could not load.', style: RfqText.error),
          TextButton(
            onPressed: c.reloadCategories,
            child: Text('Try again', style: RfqText.link),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerField(
          key: const ValueKey('category-field'),
          label: 'Service category',
          value: d.category.isEmpty ? null : c.nameOf(d.category),
          hint: 'Select a service category',
          error: problem('category'),
          onTap: _pickCategory,
        ),
        if (d.category.isNotEmpty && c.subcategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          PickerField(
            key: const ValueKey('subcategory-field'),
            label: 'Sub-category',
            optional: true,
            value: d.subcategory.isEmpty ? null : c.nameOf(d.subcategory),
            hint: 'Select a sub-category',
            onTap: _pickSubcategory,
          ),
        ],
        if (d.subcategory.isNotEmpty && c.specialisations.isNotEmpty) ...[
          const SizedBox(height: 14),
          PickerField(
            key: const ValueKey('specialisation-field'),
            label: 'Specialisation',
            optional: true,
            value: d.service.isEmpty ? null : c.nameOf(d.service),
            hint: 'Select a specialisation',
            onTap: _pickSpecialisation,
          ),
        ],
      ],
    );
  }

  Widget _describe(String? Function(String) problem) {
    final c = _c;
    final d = c.draft;
    final n = withoutEmptyPrompts(d.text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RfqField(
          fieldKey: const ValueKey('title'),
          label: 'Title',
          value: c.titleEdited ? d.title : '',
          hint: c.suggestedTitle,
          optional: true,
          maxLength: RfqLimits.title,
          help: 'What suppliers see first. Left blank it reads "${c.suggestedTitle}".',
          error: problem('title'),
          onChanged: c.setTitle,
        ),
        const SizedBox(height: 14),
        FieldLabel(d.isRfq ? 'Scope of services' : 'Tell suppliers what you need'),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('text'),
          controller: _text,
          onChanged: (v) => c.update((d) => d.text = v),
          minLines: 6,
          maxLines: 12,
          maxLength: RfqLimits.descriptionMax,
          keyboardType: TextInputType.multiline,
          style: RfqText.formInput,
          decoration: rfqInputDecoration(
            hint: d.isRfq
                ? 'Areas covered, headcount or frequency, SLAs, current setup, transition constraints…'
                : 'What you need, roughly how much or how often, and anything suppliers should know…',
            error: problem('text'),
          ),
        ),
        const SizedBox(height: 4),
        if (problem('text') == null)
          Text(
            'Suppliers see this exactly as you write it. Specific details get sharper quotes. '
            '($n so far, at least ${RfqLimits.descriptionMin})',
            style: RfqText.formHelp,
          ),
        const SizedBox(height: 10),
        DescriptionChecklist(text: d.text, onAdd: _addPrompt),
        const SizedBox(height: 16),
        RfqField(
          fieldKey: const ValueKey('budget'),
          label: 'Budget',
          value: d.budget,
          optional: true,
          prefixText: '₹ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          help: d.isRfq ? 'Your estimate for the whole contract.' : 'What you expect to spend, if you know.',
          error: problem('budget'),
          onChanged: (v) => c.update((d) => d.budget = v),
        ),
        if (!c.editing) ...[
          const SizedBox(height: 16),
          const FieldLabel('Line items', optional: true),
          const SizedBox(height: 6),
          ItemsList(
            items: d.items,
            error: problem('items'),
            onAdd: _addItem,
            onEdit: _editItem,
            onRemove: c.removeItem,
          ),
        ],
        const SizedBox(height: 16),
        const FieldLabel('Photos and documents', optional: true),
        const SizedBox(height: 2),
        Text(
          d.isRfq
              ? 'Drawings, floor plans, site photos or a scope document suppliers should quote against.'
              : 'Site photos, drawings or a scope document help suppliers quote accurately.',
          style: RfqText.formHelp,
        ),
        const SizedBox(height: 8),
        AttachmentsPanel(
          files: d.attachments,
          uploads: c.uploads,
          max: RfqLimits.maxAttachments,
          busy: c.uploading,
          error: problem('attachments'),
          notice: c.uploadNotice,
          onDismissNotice: c.dismissUploadNotice,
          onPick: _pickFiles,
          onTitle: c.setAttachmentTitle,
          onRemove: c.removeAttachment,
          onRetry: c.retryUpload,
          onDismiss: c.dismissUpload,
        ),
      ],
    );
  }

  Widget _criteria(String? Function(String) problem) {
    final d = _c.draft;
    final open = _criteriaOpen;
    final count = d.criteriaCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('criteria-toggle'),
            onPressed: () => setState(() => _criteriaOpen = !_criteriaOpen),
            icon: Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16),
            label: Text(
              open
                  ? 'Hide supplier criteria'
                  : (count > 0 ? '$count ${count == 1 ? 'criterion' : 'criteria'} set: edit' : 'Add supplier criteria'),
              style: RfqText.link,
            ),
          ),
        ),
        // Kept mounted while closed, so a criterion that is set is still sent and still checked.
        Offstage(
          offstage: !open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              RfqField(
                fieldKey: const ValueKey('min-years'),
                label: 'Years in business',
                value: d.minYears,
                optional: true,
                keyboardType: TextInputType.number,
                suffixText: 'years',
                error: problem('minYears'),
                onChanged: (v) => _c.update((d) => d.minYears = v),
              ),
              const SizedBox(height: 14),
              RfqField(
                fieldKey: const ValueKey('min-turnover'),
                label: 'Annual turnover',
                value: d.minAnnualTurnover,
                optional: true,
                prefixText: '₹ ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                error: problem('minAnnualTurnover'),
                onChanged: (v) => _c.update((d) => d.minAnnualTurnover = v),
              ),
              const SizedBox(height: 14),
              RfqField(
                fieldKey: const ValueKey('min-turnover-3'),
                label: 'Turnover over the last 3 years',
                value: d.minLast3YrTurnover,
                optional: true,
                prefixText: '₹ ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                help: 'Cannot be less than one year\'s.',
                error: problem('minLast3YrTurnover'),
                onChanged: (v) => _c.update((d) => d.minLast3YrTurnover = v),
              ),
              const SizedBox(height: 14),
              PickerField(
                key: const ValueKey('min-employees'),
                label: 'Employees',
                optional: true,
                value: d.minEmployees.isEmpty ? null : sizeLabel(d.minEmployees),
                hint: 'No minimum',
                onTap: _pickEmployees,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Presence', optional: true),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in Presence.values)
                    ToggleChip(
                      key: ValueKey('presence-${p.wire}'),
                      label: p.label,
                      on: d.presence == p,
                      onTap: () => _c.update((d) => d.presence = d.presence == p ? null : p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldLabel('Statutory compliance', optional: true),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in statutoryCompliance.entries)
                    ToggleChip(
                      key: ValueKey('compliance-${e.key}'),
                      label: e.value,
                      on: d.compliance.contains(e.key),
                      onTap: () => _c.toggleCompliance(e.key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _audience(String? Function(String) problem) {
    final d = _c.draft;
    Widget option(Audience a, String title, String body) {
      final on = d.audience == a;
      return Semantics(
        button: true,
        selected: on,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          key: ValueKey('audience-${a.name}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _c.setAudience(a),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: on ? AppColors.primary : AppColors.slate200, width: on ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  on ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 18,
                  color: on ? AppColors.primary : AppColors.slate300,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: RfqText.bodyStrong),
                      Text(body, style: RfqText.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        option(Audience.open, 'Every matching supplier', 'It is on the open board and alerts the suppliers that fit.'),
        const SizedBox(height: 8),
        option(
          Audience.invited,
          'Only suppliers I invite',
          'A private enquiry: only the suppliers you choose can see it or reply.',
        ),
        if (d.audience == Audience.invited) ...[
          const SizedBox(height: 10),
          if (d.invited.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in d.invited)
                  Container(
                    key: ValueKey('invited-${s.vendorId}'),
                    padding: const EdgeInsets.only(left: 10, right: 2),
                    decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.name, style: RfqText.pill.copyWith(color: AppColors.primary)),
                        IconButton(
                          tooltip: 'Remove ${s.name}',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                          onPressed: () => _c.toggleInvited(s),
                          icon: const Icon(LucideIcons.x, size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('invite-choose'),
              onPressed: _chooseSuppliers,
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: Text(d.invited.isEmpty ? 'Choose suppliers' : 'Change suppliers', style: RfqText.link),
            ),
          ),
          if (problem('invited') != null) Text(problem('invited')!, style: RfqText.error),
        ],
      ],
    );
  }
}
