import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../account/account_labels.dart' show companySizes, legalStructures;
import '../../account/account_models.dart' show CityOption, PickedPhoto;
import '../../account/companies/company_lookups.dart' show IndustryOption, industryName;
import '../../account/companies/create_company_controller.dart'
    show
        CompanyDocument,
        documentLabel,
        documentMaxBytes,
        documentUploadFailed,
        needsIncorporationProof,
        websiteProblem;
import '../../account/widgets/account_kit.dart';
import '../../account/widgets/photo_picker.dart' show PhotoPicker;
import '../company_controller.dart';
import '../company_fields.dart';
import '../company_models.dart';
import '../company_rules.dart';
import '../company_words.dart';
import 'company_kit.dart';

/// Edits one section of the company's identity in a sheet, the way the website's Identity tab edits them all in
/// one form: the same fields, the same rules and sentences, and only the fields that changed are sent. True when
/// something was saved.
Future<bool> showSectionSheet(
  BuildContext context,
  CompanyController controller,
  CompanyFieldSection section, {
  required PhotoPicker pickDocument,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => SectionSheet(controller: controller, section: section, pickDocument: pickDocument),
    ) ??
    false;

const _documentTypes = {'application/pdf', 'image/png', 'image/jpeg', 'image/webp'};

typedef _Doc = ({String url, String name});

class SectionSheet extends StatefulWidget {
  const SectionSheet({super.key, required this.controller, required this.section, required this.pickDocument});

  final CompanyController controller;
  final CompanyFieldSection section;
  final PhotoPicker pickDocument;

  @override
  State<SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends State<SectionSheet> {
  late final CompanyDetails? _company = widget.controller.company;

  /// Every field of the section as the form holds it: strings while being typed, '' for "not set".
  late final Map<CompanyFieldKey, String> _initial = {
    for (final spec in companyFieldsIn(widget.section))
      if (spec.key != CompanyFieldKey.logoUrl && documentOf(spec.key) == null) spec.key: _read(spec.key),
  };
  late final Map<CompanyFieldKey, String> _values = Map.of(_initial);
  late final Map<CompanyFieldKey, TextEditingController> _text = {
    for (final key in _initial.keys)
      if (!_pickers.contains(key)) key: TextEditingController(text: _initial[key]),
  };

  /// The documents the section carries: '' url means detached.
  late final Map<CompanyDocument, _Doc?> _initialDocs = {
    for (final doc in _documents)
      doc: () {
        final url = _company?.text(documentUrlColumn(doc));
        return url == null
            ? null
            : (url: url, name: _company?.text(documentNameColumn(doc)) ?? documentLabel(doc, _structure));
      }(),
  };
  late final Map<CompanyDocument, _Doc?> _docs = Map.of(_initialDocs);
  final Set<CompanyDocument> _docBusy = {};
  final Map<CompanyDocument, String> _docErrors = {};

  List<IndustryOption> _industries = const [];
  List<StateOption> _states = const [];
  List<CityOption> _cities = const [];
  bool _tried = false;
  bool _saving = false;
  String? _error;

  static const _pickers = {
    CompanyFieldKey.industry,
    CompanyFieldKey.size,
    CompanyFieldKey.legalStructure,
    CompanyFieldKey.presence,
    CompanyFieldKey.state,
  };

  List<CompanyDocument> get _documents => widget.section == CompanyFieldSection.registration
      ? const [CompanyDocument.incorporationDoc, CompanyDocument.panDoc, CompanyDocument.gstDoc]
      : const [];

  String _read(CompanyFieldKey key) {
    final c = _company;
    if (c == null) return key == CompanyFieldKey.country ? 'India' : '';
    return switch (key) {
      CompanyFieldKey.foundedYear => c.foundedYear?.toString() ?? '',
      CompanyFieldKey.country => c.country ?? 'India',
      _ => c.text(companyFieldColumn(key)) ?? '',
    };
  }

  String? get _structure {
    final v = _values[CompanyFieldKey.legalStructure] ?? _company?.legalStructure;
    return v == null || v.isEmpty ? null : v;
  }

  @override
  void initState() {
    super.initState();
    if (widget.section == CompanyFieldSection.details) {
      widget.controller.loadIndustries().then((rows) {
        if (mounted) setState(() => _industries = rows);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _locked(CompanyFieldKey key) => widget.controller.locked(key);

  bool get _dirty =>
      _values.entries.any((e) => e.value != _initial[e.key]) ||
      _docs.entries.any((e) => e.value?.url != _initialDocs[e.key]?.url);

  // --- the rules, field by field -----------------------------------------------------------------------------

  String? _problem(CompanyFieldKey key) {
    final v = _values[key] ?? '';
    final c = _company;
    switch (key) {
      case CompanyFieldKey.name:
        return companyNameProblem(v);
      case CompanyFieldKey.website:
        return websiteProblem(v);
      case CompanyFieldKey.foundedYear:
        return foundedYearProblem(v, widget.controller.now());
      case CompanyFieldKey.legalName:
        return legalNameProblem(v);
      case CompanyFieldKey.panNumber:
        // An unchanged PAN is not re-judged unless the type changed, as the website.
        if (v.trim().toUpperCase() == (c?.panNumber ?? '') && _structure == c?.legalStructure) return null;
        return panProblem(v, _structure);
      case CompanyFieldKey.gstNumber:
        final pan = _values[CompanyFieldKey.panNumber] ?? '';
        if (v.trim().toUpperCase() == (c?.gstNumber ?? '') && pan.trim().toUpperCase() == (c?.panNumber ?? '')) {
          return null;
        }
        return gstinProblem(v, pan: pan);
      case CompanyFieldKey.postalCode:
        return pinProblem(v, _values[CompanyFieldKey.country]);
      case CompanyFieldKey.email:
        return workEmailProblem(v, saved: c?.email);
      case CompanyFieldKey.phone:
      case CompanyFieldKey.contactAltPhone:
        return contactPhoneProblem(v);
      default:
        return null;
    }
  }

  Map<CompanyFieldKey, String> get _problems => {for (final key in _values.keys) key: ?_problem(key)};

  // --- the patch: only what changed ----------------------------------------------------------------------------

  Map<String, Object?> _patch() {
    final patch = <String, Object?>{};
    for (final e in _values.entries) {
      if (e.value == _initial[e.key]) continue;
      final trimmed = e.value.trim();
      // '' after a change is left out, as the website's form leaves it: a cleared text is "not sent".
      if (trimmed.isEmpty) continue;
      patch[e.key.name] = switch (e.key) {
        CompanyFieldKey.foundedYear => int.parse(trimmed),
        CompanyFieldKey.panNumber || CompanyFieldKey.gstNumber => trimmed.toUpperCase(),
        _ => trimmed,
      };
    }
    for (final e in _docs.entries) {
      if (e.value?.url == _initialDocs[e.key]?.url) continue;
      patch[documentUrlColumn(e.key)] = e.value?.url;
      patch[documentNameColumn(e.key)] = e.value?.name;
    }
    return patch;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    if (_problems.isNotEmpty) return;
    final patch = _patch();
    if (patch.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveDetails(patch);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- the pickers ---------------------------------------------------------------------------------------------

  void _set(CompanyFieldKey key, String value) => setState(() => _values[key] = value);

  Future<void> _pickIndustry() async {
    final options = _industries.isEmpty ? await widget.controller.loadIndustries() : _industries;
    if (!mounted) return;
    final picked = await showAccountPicker<IndustryOption>(
      context,
      title: 'Industry',
      items: options,
      labelOf: (o) => o.$2,
      selected: options.where((o) => o.$1 == _values[CompanyFieldKey.industry]).firstOrNull,
    );
    if (picked != null) _set(CompanyFieldKey.industry, picked.$1);
  }

  Future<void> _pickSize() async {
    final picked = await showAccountPicker<(String, String)>(
      context,
      title: 'Company Size',
      items: companySizes,
      labelOf: (o) => '${o.$2} employees',
      selected: companySizes.where((o) => o.$1 == _values[CompanyFieldKey.size]).firstOrNull,
    );
    if (picked != null) _set(CompanyFieldKey.size, picked.$1);
  }

  Future<void> _pickStructure() async {
    final picked = await showAccountPicker<(String, String)>(
      context,
      title: 'Organisation Type',
      items: legalStructures,
      labelOf: (o) => o.$2,
      selected: legalStructures.where((o) => o.$1 == _values[CompanyFieldKey.legalStructure]).firstOrNull,
    );
    if (picked == null) return;
    // Changing the type usually changes which certificate applies, so the file attached for the old one is dropped
    // rather than submitted under the wrong name. Compared on the document, not the structure.
    final from = _structure;
    final sameDocument =
        needsIncorporationProof(from) &&
        needsIncorporationProof(picked.$1) &&
        documentLabel(CompanyDocument.incorporationDoc, from) ==
            documentLabel(CompanyDocument.incorporationDoc, picked.$1);
    setState(() {
      _values[CompanyFieldKey.legalStructure] = picked.$1;
      if (!sameDocument && _docs[CompanyDocument.incorporationDoc] != null) {
        _docs[CompanyDocument.incorporationDoc] = null;
      }
    });
  }

  Future<void> _pickPresence() async {
    final picked = await showAccountPicker<(String, String)>(
      context,
      title: 'Operating Regions',
      items: presenceOptions,
      labelOf: (o) => o.$2,
      selected: presenceOptions.where((o) => o.$1 == _values[CompanyFieldKey.presence]).firstOrNull,
    );
    if (picked != null) _set(CompanyFieldKey.presence, picked.$1);
  }

  Future<void> _pickState() async {
    if (_states.isEmpty) _states = await widget.controller.loadStates();
    if (!mounted) return;
    if (_states.isEmpty) {
      showMessage(context, 'Unable to load the list of states. Enter the state instead.');
      return;
    }
    final picked = await showAccountPicker<StateOption>(
      context,
      title: 'State',
      items: _states,
      labelOf: (o) => o.name,
      searchable: true,
      selected: _states.where((o) => o.name == _values[CompanyFieldKey.state]).firstOrNull,
    );
    if (picked != null) _set(CompanyFieldKey.state, picked.name);
  }

  Future<void> _pickCity() async {
    if (_cities.isEmpty) _cities = await widget.controller.loadCities();
    if (!mounted) return;
    final state = _values[CompanyFieldKey.state] ?? '';
    final shown = state.isEmpty ? _cities : _cities.where((c) => c.state == state).toList();
    if (shown.isEmpty) return;
    final picked = await showAccountPicker<CityOption>(
      context,
      title: 'City',
      items: shown,
      labelOf: (o) => o.name,
      subtitleOf: (o) => o.state ?? '',
      searchable: true,
    );
    if (picked != null) {
      setState(() {
        _values[CompanyFieldKey.city] = picked.name;
        _text[CompanyFieldKey.city]?.text = picked.name;
        if (picked.state != null) _values[CompanyFieldKey.state] = picked.state!;
      });
    }
  }

  // --- the documents -------------------------------------------------------------------------------------------

  Future<void> _uploadDocument(CompanyDocument doc) async {
    final file = await widget.pickDocument();
    if (file == null || !mounted) return;
    setState(() => _docErrors.remove(doc));
    if (!_documentTypes.contains(file.contentType) || file.bytes.length > documentMaxBytes) {
      setState(() => _docErrors[doc] = documentUploadFailed);
      return;
    }
    setState(() => _docBusy.add(doc));
    try {
      final uploaded = await widget.controller.upload(file, purpose: 'employer-kyc');
      if (mounted) setState(() => _docs[doc] = (url: uploaded.url, name: uploaded.name));
    } catch (e) {
      if (mounted) setState(() => _docErrors[doc] = _uploadSentence(e));
    } finally {
      if (mounted) setState(() => _docBusy.remove(doc));
    }
  }

  static String _uploadSentence(Object e) {
    final error = ApiError.from(e);
    return error.isOffline ? error.message : documentUploadFailed;
  }

  // --- build ---------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final problems = _tried ? _problems : const <CompanyFieldKey, String>{};
    return EditSheet(
      title: switch (widget.section) {
        CompanyFieldSection.details => CompanyWords.detailsTitle,
        CompanyFieldSection.registration => CompanyWords.legalTitle,
        CompanyFieldSection.location => CompanyWords.locationTitle,
        CompanyFieldSection.contact => CompanyWords.contactTitle,
      },
      subtitle: switch (widget.section) {
        CompanyFieldSection.details => CompanyWords.detailsBlurb,
        CompanyFieldSection.registration => CompanyWords.legalBlurb,
        CompanyFieldSection.location => CompanyWords.locationBlurb,
        CompanyFieldSection.contact => CompanyWords.contactBlurb,
      },
      saving: _saving,
      error: _error,
      dirty: _dirty,
      saveLabel: CompanyWords.saveChanges,
      onSave: _save,
      children: switch (widget.section) {
        CompanyFieldSection.details => _details(problems),
        CompanyFieldSection.registration => _registration(problems),
        CompanyFieldSection.location => _location(problems),
        CompanyFieldSection.contact => _contact(problems),
      },
    );
  }

  Widget _field(
    CompanyFieldKey key, {
    required String label,
    String? helper,
    String? hint,
    Map<CompanyFieldKey, String> problems = const {},
    bool required = false,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool upper = false,
  }) {
    final locked = _locked(key);
    return AccountField(
      fieldKey: ValueKey('field-${key.name}'),
      label: label,
      controller: _text[key]!,
      required: required,
      hint: hint,
      helper: locked
          ? (key == CompanyFieldKey.panNumber || key == CompanyFieldKey.gstNumber
                ? CompanyWords.taxIdsLocked
                : companyFields[key]!.lockedMessage)
          : helper,
      error: problems[key],
      enabled: !locked,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : null,
      keyboardType: keyboardType,
      textCapitalization: upper ? TextCapitalization.characters : capitalization,
      onChanged: (v) => _set(key, upper ? v.toUpperCase() : v),
    );
  }

  List<Widget> _details(Map<CompanyFieldKey, String> problems) => [
    _field(
      CompanyFieldKey.name,
      label: 'Company Name',
      required: true,
      helper: 'Your brand name as displayed on ICR.',
      problems: problems,
      maxLength: 120,
      capitalization: TextCapitalization.words,
    ),
    _field(
      CompanyFieldKey.website,
      label: 'Company Website',
      helper: 'Enter your official website URL.',
      hint: 'https://…',
      problems: problems,
      keyboardType: TextInputType.url,
      capitalization: TextCapitalization.none,
    ),
    AccountSelectField(
      key: const ValueKey('field-industry'),
      label: 'Industry',
      hint: 'Select your primary industry.',
      value: (_values[CompanyFieldKey.industry] ?? '').isEmpty
          ? null
          : industryName(_values[CompanyFieldKey.industry], _industries),
      onTap: _pickIndustry,
    ),
    AccountSelectField(
      key: const ValueKey('field-size'),
      label: 'Company Size',
      hint: 'Select your employee strength.',
      value: companySizeLabel((_values[CompanyFieldKey.size] ?? '').isEmpty ? null : _values[CompanyFieldKey.size]),
      onTap: _pickSize,
    ),
    _field(
      CompanyFieldKey.foundedYear,
      label: 'Year of Establishment',
      helper: 'Enter the year your company was established. ${foundedYearHint(widget.controller.now())}',
      hint: 'e.g. 2014',
      problems: problems,
      maxLength: 4,
      keyboardType: TextInputType.number,
    ),
    _field(
      CompanyFieldKey.description,
      label: 'Company Description',
      helper:
          'Briefly describe your business, services and expertise. This introduction appears on your public company profile.',
      maxLines: 4,
      maxLength: 2000,
    ),
  ];

  List<Widget> _registration(Map<CompanyFieldKey, String> problems) {
    final structure = _structure;
    final pan = _values[CompanyFieldKey.panNumber] ?? '';
    final gst = _values[CompanyFieldKey.gstNumber] ?? '';
    return [
      _field(
        CompanyFieldKey.legalName,
        label: 'Registered Legal Name',
        helper: 'Enter the legal name as shown on your PAN card.',
        problems: problems,
        maxLength: 200,
        capitalization: TextCapitalization.words,
      ),
      AccountSelectField(
        key: const ValueKey('field-legalStructure'),
        label: 'Organisation Type',
        hint: 'Select your registered business structure.',
        value: legalStructures.where((o) => o.$1 == structure).firstOrNull?.$2,
        helper: _locked(CompanyFieldKey.legalStructure)
            ? companyFields[CompanyFieldKey.legalStructure]!.lockedMessage
            : 'Select your registered business structure.',
        onTap: _locked(CompanyFieldKey.legalStructure) ? null : _pickStructure,
      ),
      if (needsIncorporationProof(structure))
        _documentField(
          CompanyDocument.incorporationDoc,
          caption: _docs[CompanyDocument.incorporationDoc] == null
              ? requiredForStructure(structure!)
              : companyFields[CompanyFieldKey.incorporationDoc]!.helper,
        ),
      _field(
        CompanyFieldKey.panNumber,
        label: 'PAN',
        helper: 'Enter your company’s PAN.',
        hint: panExample(structure),
        problems: problems,
        maxLength: 10,
        upper: true,
      ),
      _documentField(
        CompanyDocument.panDoc,
        caption:
            _docs[CompanyDocument.panDoc] != null || !companyDocumentRequired(CompanyDocument.panDoc, panNumber: pan)
            ? companyFields[CompanyFieldKey.panDoc]!.helper
            : requiredWithTaxId('PAN'),
      ),
      _field(
        CompanyFieldKey.gstNumber,
        label: 'GSTIN',
        helper: 'Enter your GST registration number.',
        problems: problems,
        maxLength: 15,
        upper: true,
      ),
      _documentField(
        CompanyDocument.gstDoc,
        caption:
            _docs[CompanyDocument.gstDoc] != null || !companyDocumentRequired(CompanyDocument.gstDoc, gstNumber: gst)
            ? companyFields[CompanyFieldKey.gstDoc]!.helper
            : requiredWithTaxId('GSTIN'),
      ),
    ];
  }

  Widget _documentField(CompanyDocument doc, {String? caption}) {
    final c = widget.controller;
    final key = fieldOfDocument(doc);
    final locked = _locked(key);
    final reverifyOpen = c.reverifyOpen && c.unlocked.contains(key);
    final file = _docs[doc];
    final busy = _docBusy.contains(doc);
    final error = _docErrors[doc];
    final structure = _structure;
    final text = reverifyOpen
        ? CompanyWords.reverifyDocument(dayOf(c.reverify!.dueAt))
        : locked
        ? CompanyWords.taxIdsLocked
        : caption;
    return Padding(
      key: ValueKey('doc-${doc.name}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(documentLabel(doc, structure), style: AccountText.label),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                file == null ? Symbols.upload_file : Symbols.task,
                size: 20,
                color: file == null ? AppColors.slate400 : AppColors.emerald700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file?.name ?? CompanyWords.notUploaded,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: file == null ? AccountText.meta : AccountText.body,
                ),
              ),
              if (!locked) ...[
                if (file != null)
                  TextButton(
                    key: ValueKey('doc-${doc.name}-remove'),
                    onPressed: busy ? null : () => setState(() => _docs[doc] = null),
                    child: const Text(CompanyWords.remove),
                  ),
                AccountButton(
                  key: ValueKey('doc-${doc.name}-upload'),
                  label: busy ? CompanyWords.uploading : (file == null ? CompanyWords.upload : CompanyWords.replace),
                  icon: Icons.upload_file_outlined,
                  outlined: true,
                  expand: false,
                  height: 36,
                  busy: busy,
                  onPressed: busy ? null : () => _uploadDocument(doc),
                ),
              ],
            ],
          ),
          if (error != null || text != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(error ?? text!, style: error != null ? AccountText.error : AccountText.meta),
            ),
        ],
      ),
    );
  }

  List<Widget> _location(Map<CompanyFieldKey, String> problems) => [
    _field(CompanyFieldKey.addressLine, label: 'Registered / Office Address', maxLength: 300),
    AccountSelectField(
      key: const ValueKey('field-state'),
      label: 'State',
      hint: 'Select State',
      value: (_values[CompanyFieldKey.state] ?? '').isEmpty ? null : _values[CompanyFieldKey.state],
      onTap: _pickState,
      onClear: () => _set(CompanyFieldKey.state, ''),
    ),
    AccountField(
      fieldKey: const ValueKey('field-city'),
      label: 'City',
      controller: _text[CompanyFieldKey.city]!,
      hint: 'Enter City',
      helper: 'Where the head office is.',
      textCapitalization: TextCapitalization.words,
      onChanged: (v) => _set(CompanyFieldKey.city, v),
      suffix: IconButton(
        key: const ValueKey('field-city-pick'),
        tooltip: 'Select a city',
        onPressed: _pickCity,
        icon: const Icon(Icons.search_rounded, color: AppColors.slate500),
      ),
    ),
    _field(
      CompanyFieldKey.postalCode,
      label: 'PIN Code',
      hint: 'Enter PIN Code',
      problems: problems,
      maxLength: 20,
      keyboardType: TextInputType.number,
    ),
    _field(
      CompanyFieldKey.country,
      label: 'Country',
      hint: 'India',
      maxLength: 80,
      capitalization: TextCapitalization.words,
    ),
    AccountSelectField(
      key: const ValueKey('field-presence'),
      label: 'Operating Regions',
      hint: 'Where does your company operate?',
      value: (_values[CompanyFieldKey.presence] ?? '').isEmpty
          ? null
          : presenceLabel(_values[CompanyFieldKey.presence]),
      onTap: _pickPresence,
    ),
  ];

  List<Widget> _contact(Map<CompanyFieldKey, String> problems) => [
    _field(
      CompanyFieldKey.email,
      label: 'Work Email',
      helper: 'Use your official company email address.',
      problems: problems,
      keyboardType: TextInputType.emailAddress,
      capitalization: TextCapitalization.none,
    ),
    _field(
      CompanyFieldKey.phone,
      label: 'Phone',
      helper: 'Primary business contact number.',
      problems: problems,
      maxLength: 25,
      keyboardType: TextInputType.phone,
    ),
    _field(
      CompanyFieldKey.contactName,
      label: 'Contact Person',
      helper: 'Name of the authorised representative.',
      maxLength: 120,
      capitalization: TextCapitalization.words,
    ),
    _field(
      CompanyFieldKey.contactDesignation,
      label: 'Designation',
      helper: 'Official designation.',
      hint: 'Head of Procurement',
      maxLength: 100,
      capitalization: TextCapitalization.words,
    ),
    _field(
      CompanyFieldKey.contactAltPhone,
      label: 'Alternative Contact Number',
      helper: 'Add a secondary contact number, if available.',
      problems: problems,
      maxLength: 25,
      keyboardType: TextInputType.phone,
    ),
  ];
}

/// Picks a logo and saves it on the company at once: a PNG, JPG or WEBP up to 5 MB (the phone's picker shrinks a
/// bigger photo first). Null when done, else the sentence to show.
Future<String?> changeLogo(CompanyController controller, PickedPhoto? photo) async {
  if (photo == null) return null;
  if (!photo.contentType.startsWith('image/')) return 'This file is not an image. Select a PNG, JPG or WEBP file.';
  if (photo.bytes.length > 5 * 1024 * 1024) return 'This image is over 5 MB. Compress it or select a smaller one.';
  try {
    await controller.saveLogo(photo);
    return null;
  } catch (e) {
    final error = ApiError.from(e);
    return error.isOffline ? error.message : 'Upload failed. Try again.';
  }
}
