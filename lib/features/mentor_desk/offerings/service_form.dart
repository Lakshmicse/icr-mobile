import 'package:flutter/material.dart';

import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'offering_fields.dart';
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_repository.dart' show StoredUpload;
import 'offerings_rules.dart';

/// Creates or edits a service: a 1:1 session, a resource (with its file) or an
/// older group-seat listing (editable, never new). Validated as the API's
/// `UpsertMentorServiceDto` and its gatekeeper are; the sheet stays open, with
/// what was typed, when the API refuses.
class ServiceForm extends StatefulWidget {
  const ServiceForm({
    super.key,
    required this.controller,
    required this.pickFile,
    this.kind = ServiceKind.oneOnOne,
    this.existing,
    this.activate = false,
  });

  final OfferingsController controller;
  final OfferingFilePicker pickFile;

  /// Opens with Live switched on (resuming a resource whose file the API wants chosen again).
  final bool activate;

  /// The kind a new service is (an existing one keeps its own: the API refuses a change).
  final ServiceKind kind;
  final OfferedService? existing;

  @override
  State<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<ServiceForm> {
  late final ServiceKind _kind = widget.existing?.kind ?? widget.kind;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _blurb = TextEditingController(text: widget.existing?.blurb ?? '');
  late final _price = TextEditingController(
    text: rupeesOf(widget.existing?.pricePaisa == 0 ? null : widget.existing?.pricePaisa),
  );
  late final _compare = TextEditingController(text: rupeesOf(widget.existing?.compareAtPaisa));
  late final _minutes = TextEditingController(
    text: '${widget.existing?.durationMin ?? (_kind == ServiceKind.groupSeat ? 60 : 30)}',
  );
  late final _seats = TextEditingController(text: '${widget.existing?.seats ?? 12}');
  late bool _free = widget.existing != null && widget.existing!.pricePaisa == 0;
  late bool _active = widget.activate || (widget.existing?.active ?? true);

  StoredUpload? _newFile;
  late String? _fileName = widget.existing?.fileName;
  late int? _fileSize = widget.existing?.fileSize;
  late String? _cover = widget.existing?.coverUrl;
  bool _coverChanged = false;
  String? _coverName;

  String? _problem;
  bool _busy = false;
  bool _uploading = false;

  bool get _isCall => _kind == ServiceKind.oneOnOne;
  bool get _isResource => _kind == ServiceKind.resource;
  bool get _isSeat => _kind == ServiceKind.groupSeat;

  @override
  void dispose() {
    _title.dispose();
    _blurb.dispose();
    _price.dispose();
    _compare.dispose();
    _minutes.dispose();
    _seats.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _uploading = true);
    final stored = await pickAndUpload(
      pick: widget.pickFile,
      upload: (f) => widget.controller.upload(f, purpose: 'mentor-resource'),
      imageOnly: false,
      problem: (p) => setState(() => _problem = p),
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (stored != null) {
        _newFile = stored;
        _fileName = stored.name;
        _fileSize = stored.size;
      }
    });
  }

  Future<void> _pickCover() async {
    setState(() => _uploading = true);
    final stored = await pickAndUpload(
      pick: widget.pickFile,
      upload: (f) => widget.controller.upload(f, purpose: 'mentor-offering'),
      imageOnly: true,
      problem: (p) => setState(() => _problem = p),
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (stored != null) {
        _cover = stored.url;
        _coverName = stored.name;
        _coverChanged = true;
      }
    });
  }

  String? _validate() {
    final title = serviceTitleProblem(_title.text);
    if (title != null) return title;
    final blurb = blurbProblem(_blurb.text, max: maxServiceBlurb);
    if (blurb != null) return blurb;
    if (_isCall || _isSeat) {
      final m = minutesProblem(_minutes.text, what: _isCall ? 'A 1:1 call' : 'A group session');
      if (m != null) return m;
    }
    if (_isSeat) {
      final s = seatsProblem(_seats.text);
      if (s != null) return s;
    }
    final price = servicePriceProblem(free: _free, price: _price.text, compareAt: _compare.text);
    if (price != null) return price;
    if (_kind.retired && _active && !(widget.existing?.active ?? false)) {
      return 'Written consultations are no longer sold.';
    }
    if (_isResource && _active && _fileName == null) return fileNeededMessage;
    return null;
  }

  Map<String, Object?> _body() {
    final price = _free ? 0 : paisaOf(_price.text)!;
    final compare = _free || _compare.text.trim().isEmpty ? null : paisaOf(_compare.text);
    return {
      'type': _kind.api,
      'title': _title.text.trim(),
      if (_blurb.text.trim().isNotEmpty) 'blurb': _blurb.text.trim(),
      'pricePaisa': price,
      'compareAtPaisa': compare,
      if (_isCall || _isSeat) 'durationMin': int.parse(_minutes.text.trim()),
      if (_isSeat) 'seats': int.parse(_seats.text.trim()),
      if (_newFile != null) ...{'uploadId': _newFile!.uploadId, 'fileName': _newFile!.name, 'fileSize': _newFile!.size},
      if (!_isSeat && (_coverChanged || (widget.existing == null && _cover != null))) 'coverUrl': _cover,
      'active': _active,
    };
  }

  Future<void> _submit() async {
    final bad = _validate();
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.saveService(_body(), id: widget.existing?.id);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _busy = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return MentoringForm(
      title: editing ? 'Edit ${_kind.label.toLowerCase()}' : 'Add a ${_kind.label.toLowerCase()}',
      subtitle: switch (_kind) {
        ServiceKind.oneOnOne =>
          'Members ask for a time; you set it. A free session is booked at once, a paid one when they pay.',
        ServiceKind.resource =>
          'A file members download: a guide, a template, a checklist. Free works as a lead magnet.',
        ServiceKind.groupSeat => 'An older listing for a seat. New seats are sold from the group session itself.',
        ServiceKind.query => 'Written consultations are no longer sold. You can switch this one off or delete it.',
      },
      submitLabel: editing ? 'Save' : 'Add',
      busy: _busy,
      problem: _problem,
      onSubmit: _uploading ? null : _submit,
      children: [
        FieldBlock(
          label: 'Title',
          child: TextField(
            key: const ValueKey('offering-title'),
            controller: _title,
            maxLength: maxServiceTitle,
            style: MentoringText.formInput,
            decoration: fieldDecoration(_isResource ? 'Interview question bank' : 'Career clarity call'),
          ),
        ),
        FieldBlock(
          label: 'Description (optional)',
          child: TextField(
            key: const ValueKey('offering-blurb'),
            controller: _blurb,
            minLines: 2,
            maxLines: 5,
            maxLength: maxServiceBlurb,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What the person gets'),
          ),
        ),
        if (_isCall || _isSeat)
          FieldBlock(
            label: 'Length (minutes, $minSessionMinutes to $maxSessionMinutes)',
            child: TextField(
              key: const ValueKey('offering-minutes'),
              controller: _minutes,
              keyboardType: TextInputType.number,
              style: MentoringText.formInput,
              decoration: fieldDecoration('30'),
            ),
          ),
        if (_isSeat)
          FieldBlock(
            label: 'Seats ($minSeats to $maxSeats)',
            child: TextField(
              key: const ValueKey('offering-seats'),
              controller: _seats,
              keyboardType: TextInputType.number,
              style: MentoringText.formInput,
              decoration: fieldDecoration('12'),
            ),
          ),
        PriceBlock(
          free: _free,
          onFree: (v) => setState(() => _free = v),
          price: _price,
          compareAt: _compare,
          priceHelp: 'Charged services start at ₹499 and go up to ₹50,000. Free is always allowed.',
        ),
        if (_isResource)
          FileRow(
            label: 'The file',
            pickKey: 'offering-file',
            name: _fileName,
            size: _fileSize,
            busy: _uploading,
            help: 'A PDF or an image, up to 10 MB. It is needed before the resource can be live.',
            onPick: _pickFile,
          ),
        if (!_isSeat)
          FileRow(
            label: 'Cover image (optional)',
            pickKey: 'offering-cover',
            name: _cover == null ? null : (_coverName ?? 'Current cover'),
            busy: _uploading,
            pickLabel: _cover == null ? 'Choose an image' : 'Replace the image',
            onPick: _pickCover,
            onClear: () => setState(() {
              _cover = null;
              _coverName = null;
              _coverChanged = true;
            }),
          ),
        SwitchListTile.adaptive(
          key: const ValueKey('offering-active'),
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: Text('Live on your storefront', style: MentoringText.formLabel),
          subtitle: Text('Members see only what is live. Switch it off to pause it.', style: MentoringText.meta),
        ),
      ],
    );
  }
}
