import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
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
import 'widgets/composer_rail.dart';
import 'widgets/rfq_widgets.dart';

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
    this.onSwitchCompany,
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

  /// Founds a company: someone acting as themselves may send an enquiry, but an RFQ is a company's. By default the
  /// website's page for it opens.
  final VoidCallback? onCreateCompany;

  /// Makes the account act for one of its companies, from "Posting for" (the account screens' switch). Without it
  /// "Posting for" offers only the names an enquiry may carry.
  final Future<void> Function(String companyId)? onSwitchCompany;

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
      onCreateCompany: widget.onCreateCompany,
      onSwitchCompany: widget.onSwitchCompany,
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
        title: 'Leave Without Sending?',
        body: 'Nothing you have entered is sent or saved. Leaving discards it.',
        confirm: 'Leave',
        keep: 'Keep Editing',
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

  /// Editing a draft: it can be saved again as a draft, or published. A new requirement is posted at once, as on the
  /// website, which has no "Save draft".
  bool get _editingDraft => _c.editing && _c.source?.status == RfqStatus.draft;

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
      title: _c.draft.isRfq ? 'Review Your RFQ' : 'Review Your Enquiry',
      confirmLabel: _c.draft.isRfq ? 'Publish RFQ' : 'Submit Enquiry',
      note: _sendNote,
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

  /// What sending does, under the send bar and in the review (the website's words).
  String get _sendNote => _c.draft.isRfq
      ? 'It goes live to matching suppliers as soon as it is created.'
      : 'Matching suppliers are alerted as soon as it is posted.';

  /// The review before a new requirement is sent: the website's rows, in its order.
  List<ReviewRow> _reviewRows() {
    final d = _c.draft;
    final text = withoutEmptyPrompts(d.text);
    final files = d.attachments.map((f) => f.title.trim()).where((t) => t.isNotEmpty);
    return [
      ReviewRow(label: 'Request Type', value: d.isRfq ? 'Request for Quotation' : 'Enquiry', section: 'type'),
      ReviewRow(
        label: 'Contact',
        value: [
          _c.companyFromAccount ?? d.companyName,
          d.contactName,
          d.contactPhone,
        ].where((s) => s.trim().isNotEmpty).join(' · '),
        section: 'details',
      ),
      ReviewRow(label: 'Facility / Property Type', value: d.facilityType, section: 'location'),
      ReviewRow(label: 'Locations', value: d.places.map((p) => p.label).join(' · '), section: 'location'),
      ReviewRow(label: 'Service', value: _c.servicePath, section: 'service'),
      ReviewRow(
        label: d.isRfq ? 'Scope' : 'Description',
        value: text.length > 300 ? '${text.substring(0, 300)}…' : text,
        section: 'describe',
      ),
      ReviewRow(
        label: 'Attachments',
        value: files.isEmpty ? 'None' : '${files.length} file${files.length == 1 ? '' : 's'}: ${files.join(', ')}',
        section: 'describe',
      ),
      if (d.isRfq) ...[
        ReviewRow(
          label: 'Supplier Criteria',
          value: d.criteriaCount == 0
              ? 'None: any matched supplier can pre-qualify'
              : '${d.criteriaCount} ${d.criteriaCount == 1 ? 'criterion' : 'criteria'} set',
          section: 'criteria',
        ),
        ReviewRow(
          label: 'Deadlines',
          value: d.preQualEndDate != null && d.dueDate != null
              ? 'Pre-qualification until ${pickedDay(d.preQualEndDate!)} · quotes by ${pickedDay(d.dueDate!)}'
              : '',
          section: 'timeline',
        ),
      ],
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
      title: 'Facility / Property Type',
      options: options,
      labelOf: (s) => s,
      selected: d.facilityType.isEmpty ? null : d.facilityType,
    );
    if (picked?.value != null) _c.update((d) => d.facilityType = picked!.value!);
  }

  Future<void> _pickCategory() async {
    final picked = await pickOne<CategoryNode>(
      context,
      title: 'Select Service Category',
      options: _c.categories,
      labelOf: (n) => n.name,
      selected: _c.categories.where((n) => n.key == _c.draft.category).firstOrNull,
    );
    if (picked?.value != null) _c.setCategory(picked!.value!.key);
  }

  Future<void> _pickSubcategory() async {
    final picked = await pickOne<CategoryNode>(
      context,
      title: 'Sub-Category',
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

  Future<void> _pickDay({required bool preQual}) async {
    final d = _c.draft;
    final picked = await pickDay(
      context,
      current: preQual ? d.preQualEndDate : d.dueDate,
      after: preQual ? null : d.preQualEndDate,
      help: preQual ? 'Pre-Qualification Deadline' : (d.isRfq ? 'Quote Deadline' : 'Reply By'),
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

  /// "Posting for", for someone acting for no company with more than one choice: the employers an enquiry may name,
  /// and the companies they may post for, which switch the account to that company (the website's dropdown).
  Future<void> _pickPostingFor() async {
    final options = _c.posting;
    final canSwitch = widget.onSwitchCompany != null;
    final choice = await showModalBottomSheet<(String, bool)>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Posting for', style: RfqText.section),
            ),
            for (final name in options.names)
              ListTile(
                key: ValueKey('posting-name-$name'),
                leading: LogoTile(name: name, size: 30),
                title: Text(name, style: RfqText.bodyStrong),
                trailing: name == _c.postingFor
                    ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheet).pop((name, false)),
              ),
            if (canSwitch)
              for (final company in options.companies)
                ListTile(
                  key: ValueKey('posting-company-${company.id}'),
                  leading: LogoTile(name: company.name, size: 30),
                  title: Text(company.name, style: RfqText.bodyStrong),
                  subtitle: Text('Switch to this company and post for it', style: RfqText.small),
                  onTap: () => Navigator.of(sheet).pop((company.id, true)),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final (value, switching) = choice;
    if (!switching) {
      _c.setPostingFor(value);
      return;
    }
    try {
      await widget.onSwitchCompany!(value);
      // The account now acts for that company: read who is posting again (what was typed stays).
      await _c.retry();
    } catch (e) {
      if (mounted) showMessage(context, ApiError.from(e).message);
    }
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
            title: _c.editing ? 'Edit Requirement' : 'Post Requirement',
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
    if (!_c.started || _c.loading || _c.loadError != null || _c.result != null || _c.roleCannotPost) {
      return null;
    }
    final d = _c.draft;
    final primary = _c.editing
        ? (_c.source?.status == RfqStatus.draft ? 'Publish' : 'Save Changes')
        : (d.isRfq ? 'Publish RFQ' : 'Submit Enquiry');
    final busy = _c.sending;
    return BottomActionBar(
      children: [
        if (_editingDraft)
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('save-draft'),
              onPressed: busy ? null : () => _send(publish: false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.slate200),
              ),
              child: Text('Save Draft', style: RfqText.tab.copyWith(color: AppColors.primary)),
            ),
          ),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            key: const ValueKey('send'),
            label: _c.uploading ? 'Waiting for uploads…' : (busy ? 'Sending…' : primary),
            // An RFQ from someone acting for no company is not sent: the form says why (the website disables it too).
            onPressed: busy || _c.uploading || _c.rfqNeedsCompany ? null : () => _send(publish: true),
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
        title: 'Unable to Open the Form',
        body: _c.loadError,
        action: 'Try Again',
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
          onBrowse: () => _hooks.openSite(context, '/vendors'),
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
        title: "Requirements Aren't Part of Your Role",
        body: _c.roleCannotPostMessage,
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
    final text = withoutEmptyPrompts(d.text).length;
    // Which sections are complete: the website's rules, which tick each section's number and the progress card.
    final detailsDone =
        d.contactName.trim().isNotEmpty &&
        contactPhonePattern.hasMatch(d.contactPhone.trim()) &&
        (!c.askCompany || d.companyName.trim().isNotEmpty);
    final locationDone = d.facilityType.isNotEmpty && d.places.isNotEmpty;
    final serviceDone = d.category.isNotEmpty;
    final describeDone =
        text >= RfqLimits.descriptionMin &&
        text <= RfqLimits.descriptionMax &&
        d.attachments.every((a) => a.title.trim().isNotEmpty) &&
        !c.uploading;
    final timelineDone = d.preQualEndDate != null && d.dueDate != null && d.dueDate!.isAfter(d.preQualEndDate!);
    final postingFor = _postingFor();

    final children = <Widget>[
      if (problems.isNotEmpty)
        KeyedSubtree(
          key: _anchors['problems'],
          child: ProblemsCard(problems: problems, onGo: _goToProblem),
        ),
      if (c.error != null) RfqBanner(c.error!),
      ?postingFor,
      // The kind of request: the website's first card, with no number or heading of its own.
      KeyedSubtree(
        key: _anchors['type'],
        child: RfqCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KindPicker(value: d.kind, locked: c.editing, onChanged: c.setKind),
              if (c.editing) ...[
                const SizedBox(height: 8),
                Text('A requirement’s type cannot be changed after it is posted.', style: RfqText.formHelp),
              ],
              if (c.rfqNeedsCompany) ...[const SizedBox(height: 12), _rfqNeedsCompany()],
            ],
          ),
        ),
      ),
      SectionCard(
        key: _anchors['details'],
        step: next(),
        title: 'Buyer Details',
        caption: 'Who suppliers reply to.',
        done: detailsDone,
        child: _details(problem),
      ),
      SectionCard(
        key: _anchors['location'],
        step: next(),
        title: 'Location Details',
        caption: 'The kind of facility, and every city the work covers.',
        done: locationDone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickerField(
              key: const ValueKey('facility-field'),
              label: 'Facility / Property Type',
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
        title: 'Service Details',
        caption: 'Suppliers are matched by this category, so select the closest.',
        done: serviceDone,
        child: _service(problem),
      ),
      SectionCard(
        key: _anchors['describe'],
        step: next(),
        title: 'Requirement Specifications',
        caption: 'Include scope, quantity, frequency, timelines and any specific requirements.',
        done: describeDone,
        child: _describe(problem),
      ),
      if (d.isRfq)
        SectionCard(
          key: _anchors['criteria'],
          step: next(),
          title: 'Supplier Criteria',
          caption: 'The minimum a supplier must meet to pre-qualify. Leave any criterion blank to skip it.',
          optional: true,
          child: _criteria(problem),
        ),
      if (d.isRfq)
        SectionCard(
          key: _anchors['timeline'],
          step: next(),
          title: 'Timeline',
          caption: "When pre-qualification closes, and when the shortlist's quotes are due.",
          done: timelineDone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DateField(
                key: const ValueKey('prequal-date'),
                label: 'Pre-Qualification Deadline',
                value: d.preQualEndDate,
                onTap: () => _pickDay(preQual: true),
                error: problem('preQualEndDate'),
                help: 'Suppliers send pre-qualification responses until the end of this day.',
              ),
              const SizedBox(height: 14),
              DateField(
                key: const ValueKey('due-date'),
                label: 'Quote Deadline',
                value: d.dueDate,
                onTap: () => _pickDay(preQual: false),
                error: problem('dueDate'),
                help: 'Shortlisted suppliers send quotes until the end of this day.',
              ),
            ],
          ),
        )
      // An enquiry posted before carries its reply-by day, and editing it keeps it (the website's composer, which
      // posts and never edits, asks none).
      else if (c.editing)
        SectionCard(
          key: _anchors['timeline'],
          step: next(),
          title: 'Reply By',
          caption: 'Replies are accepted until the end of this day. After that, the enquiry closes automatically.',
          optional: true,
          child: DateField(
            key: const ValueKey('due-date'),
            label: 'Reply-By Date',
            value: d.dueDate,
            optional: true,
            onTap: () => _pickDay(preQual: false),
            onClear: () => c.update((d) => d.dueDate = null),
            error: problem('dueDate'),
          ),
        ),
      if (!c.editing) ...[
        // The website's send bar says this beside its button; here the button is pinned below.
        RfqCard(
          key: const ValueKey('send-note'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You will see a summary to check before anything is sent.', style: RfqText.bodyStrong),
              const SizedBox(height: 2),
              Text(_sendNote, style: RfqText.small),
            ],
          ),
        ),
        ComposerProgress(
          steps: [
            ProgressStep(id: 'details', label: 'Buyer Details', done: detailsDone),
            ProgressStep(id: 'location', label: 'Service Location', done: locationDone),
            ProgressStep(id: 'service', label: 'Service Details', done: serviceDone),
            ProgressStep(id: 'describe', label: 'Requirement Specifications', done: describeDone),
            if (d.isRfq) ProgressStep(id: 'timeline', label: 'Timeline', done: timelineDone),
          ],
          onGo: _goTo,
        ),
        WhatHappensNext(kind: d.kind, preQualEnd: d.preQualEndDate, dueDate: d.dueDate),
        const WhyIcrCard(),
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

  /// An RFQ chosen by someone acting for no company (the website's `rfqNeedsCompany`), with its "Create a company"
  /// and, for someone who belongs to companies, "Switch company".
  Widget _rfqNeedsCompany() {
    final canSwitch = widget.onSwitchCompany != null && _c.posting.companies.isNotEmpty;
    return Container(
      key: const ValueKey('rfq-needs-company'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(color: Tone.amber.fill, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(LucideIcons.building2, size: 16, color: Tone.amber.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'An RFQ is posted for a registered company, so suppliers know who is buying. '
                  'An enquiry needs no registration.',
                  style: RfqText.meta.copyWith(color: Tone.amber.ink),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                key: const ValueKey('rfq-create-company'),
                onPressed: widget.onCreateCompany ?? () => _hooks.openSite(context, '/account/companies/new'),
                child: Text('Create a Company', style: RfqText.link),
              ),
              if (canSwitch)
                TextButton(
                  key: const ValueKey('rfq-switch-company'),
                  onPressed: _pickPostingFor,
                  child: Text('Switch Company', style: RfqText.link),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Who the requirement is for: the company the account acts for; for someone acting for no company, the employer
  /// their enquiry names, a choice when there are several (the website's `PostingForEmployer`), and nothing at all
  /// when there is none (the form then asks the company's name).
  Widget? _postingFor() {
    final c = _c;
    final String shown;
    var choosable = false;
    if (c.personal) {
      final options = c.posting;
      final companies = widget.onSwitchCompany == null ? const <PostingCompany>[] : options.companies;
      if (options.names.isEmpty && companies.isEmpty) return null;
      shown = c.postingFor ?? (options.names.isNotEmpty ? options.names.first : companies.first.name);
      choosable = options.names.length + companies.length > 1 || (options.names.isEmpty && companies.isNotEmpty);
    } else {
      shown =
          c.companyFromAccount ?? (c.askCompany ? 'ICR (you name the company below)' : (c.poster?.name ?? 'Yourself'));
    }
    return RfqCard(
      key: const ValueKey('posting-for-card'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: choosable ? _pickPostingFor : null,
      child: Row(
        children: [
          LogoTile(name: shown, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.editing ? 'Requirement of' : 'Posting for', style: RfqText.small),
                Text(shown, key: const ValueKey('posting-for'), style: RfqText.cardTitle),
              ],
            ),
          ),
          if (choosable) const Icon(LucideIcons.chevronsUpDown, size: 16, color: AppColors.slate500),
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
            label: 'Company / Organisation Name',
            value: d.companyName,
            maxLength: RfqLimits.companyName,
            showCounter: false,
            help: 'The name suppliers will see on this requirement.',
            error: problem('companyName'),
            onChanged: (v) => _c.update((d) => d.companyName = v),
          ),
          const SizedBox(height: 14),
        ],
        RfqField(
          fieldKey: const ValueKey('contact-name'),
          label: 'Contact Person',
          value: d.contactName,
          maxLength: RfqLimits.contactName,
          showCounter: false,
          error: problem('contactName'),
          onChanged: (v) => _c.update((d) => d.contactName = v),
        ),
        const SizedBox(height: 14),
        RfqField(
          fieldKey: const ValueKey('contact-phone'),
          label: 'Mobile Number',
          value: d.contactPhone,
          hint: 'e.g. +91 98765 43210',
          keyboardType: TextInputType.phone,
          maxLength: RfqLimits.phoneMax,
          showCounter: false,
          error: problem('contactPhone'),
          onChanged: (v) => _c.update((d) => d.contactPhone = v),
        ),
        const SizedBox(height: 14),
        RfqField(
          fieldKey: const ValueKey('contact-email'),
          label: 'Business Email',
          value: d.email,
          readOnly: true,
          suffixIcon: LucideIcons.lock,
          help:
              'From your account. Suppliers see your contact details only after they respond, on plans that '
              'include them.',
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
          Text('Unable to load the list of services.', style: RfqText.error),
          TextButton(
            onPressed: c.reloadCategories,
            child: Text('Try Again', style: RfqText.link),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerField(
          key: const ValueKey('category-field'),
          label: 'Select Service Category',
          value: d.category.isEmpty ? null : c.nameOf(d.category),
          hint: 'Select a service category',
          error: problem('category'),
          onTap: _pickCategory,
        ),
        if (d.category.isNotEmpty && c.subcategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          PickerField(
            key: const ValueKey('subcategory-field'),
            label: 'Sub-Category',
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
        if (problem('category') == null) ...[
          const SizedBox(height: 6),
          Text(
            'Narrow it to a sub-category and specialisation if one fits. Suppliers listed under it are matched first.',
            style: RfqText.formHelp,
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
        // A new requirement's title is made from what it asks for, as the website makes it ("Hospital — Housekeeping",
        // "Bharat Facilities — Housekeeping RFQ"); a requirement posted before keeps its own, and editing shows it.
        if (c.editing) ...[
          RfqField(
            fieldKey: const ValueKey('title'),
            label: 'Title',
            value: c.titleEdited ? d.title : '',
            hint: c.suggestedTitle,
            optional: true,
            maxLength: RfqLimits.title,
            help: 'What suppliers see first. If left blank, it reads "${c.suggestedTitle}".',
            error: problem('title'),
            onChanged: c.setTitle,
          ),
          const SizedBox(height: 14),
        ],
        FieldLabel(d.isRfq ? 'Scope of Services' : 'Detailed Requirement Description'),
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
            'Suppliers see this exactly as you write it. Specific details get more accurate quotes. '
            '($n so far, at least ${RfqLimits.descriptionMin})',
            style: RfqText.formHelp,
          ),
        const SizedBox(height: 10),
        DescriptionChecklist(text: d.text, onAdd: _addPrompt),
        // The website's composer asks no budget; a requirement posted with one keeps it, and editing shows it.
        if (c.editing) ...[
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
        ],
        const SizedBox(height: 16),
        const FieldLabel('Supporting Documents', optional: true),
        const SizedBox(height: 2),
        Text('Upload scope documents, specifications, photographs or other relevant files.', style: RfqText.formHelp),
        const SizedBox(height: 8),
        AttachmentsPanel(
          addLabel: 'Upload Files',
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
                  ? 'Hide Supplier Criteria'
                  : (count > 0 ? '$count ${count == 1 ? 'criterion' : 'criteria'} set: edit' : 'Add Supplier Criteria'),
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
                label: 'Years in Business',
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
                label: 'Annual Turnover',
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
                label: 'Turnover Over the Last 3 Years',
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
              const FieldLabel('Statutory Compliance', optional: true),
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
}
