import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../account_models.dart';
import '../widgets/account_kit.dart';
import 'company_words.dart';

/// Sends the request; null when it went, else the API's sentence.
typedef SendJoinRequest = Future<String?> Function(String companyId, String? note);

/// "Ask to join a company": find the organisation by name, then say why in a
/// line (optional) and send. The company's admins decide; nothing changes for
/// the person until they do. The website's `RequestToJoinButton` dialog, with
/// the company search of the sign-up's "Your work" step in front of it.
///
/// Pass [initial] to open on a company already chosen (a suggestion on the
/// create page). Resolves to the company asked, or null when closed unsent.
Future<CompanyHit?> showAskToJoinSheet(
  BuildContext context, {
  required Future<List<CompanyHit>> Function(String query) search,
  required SendJoinRequest send,
  CompanyHit? initial,
  Set<String> memberOf = const {},
  Set<String> requested = const {},
  Duration searchDelay = const Duration(milliseconds: 300),
}) {
  return showEditSheet<CompanyHit>(
    context,
    builder: (_) => AskToJoinSheet(
      search: search,
      send: send,
      initial: initial,
      memberOf: memberOf,
      requested: requested,
      searchDelay: searchDelay,
    ),
  );
}

class AskToJoinSheet extends StatefulWidget {
  const AskToJoinSheet({
    super.key,
    required this.search,
    required this.send,
    this.initial,
    this.memberOf = const {},
    this.requested = const {},
    this.searchDelay = const Duration(milliseconds: 300),
  });

  final Future<List<CompanyHit>> Function(String query) search;
  final SendJoinRequest send;
  final CompanyHit? initial;

  /// Companies the person already belongs to: shown, but not offered.
  final Set<String> memberOf;

  /// Companies with a request already waiting.
  final Set<String> requested;
  final Duration searchDelay;

  @override
  State<AskToJoinSheet> createState() => _AskToJoinSheetState();
}

class _AskToJoinSheetState extends State<AskToJoinSheet> {
  final _query = TextEditingController();
  final _note = TextEditingController();
  Timer? _debounce;

  CompanyHit? _picked;
  List<CompanyHit> _found = const [];
  String _searched = '';
  bool _searching = false;
  String? _searchError;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _note.dispose();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _found = const [];
        _searched = '';
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(widget.searchDelay, () async {
      try {
        final hits = await widget.search(q);
        // A slower answer to an older query must not overwrite a newer one.
        if (!mounted || _query.text.trim() != q) return;
        setState(() {
          _found = hits;
          _searched = q;
          _searching = false;
          _searchError = null;
        });
      } catch (e) {
        if (!mounted || _query.text.trim() != q) return;
        setState(() {
          _searching = false;
          _searchError = ApiError.from(e).message;
        });
      }
    });
  }

  Future<void> _send() async {
    final picked = _picked;
    if (picked == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await widget.send(picked.id, _note.text.trim().isEmpty ? null : _note.text.trim());
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(picked);
      return;
    }
    // The note stays as typed.
    setState(() {
      _sending = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return EditSheet(
      title: picked == null ? CompanyWords.askToJoinTitle : 'Ask to join ${picked.name}',
      saveLabel: 'Send request',
      saving: _sending,
      error: _error,
      dirty: _note.text.trim().isNotEmpty,
      onSave: picked == null ? null : _send,
      children: picked == null ? _searchStep() : _noteStep(picked),
    );
  }

  // --- step 1: find the company ------------------------------------------------------------------------------

  List<Widget> _searchStep() {
    return [
      Text(CompanyWords.askToJoinLead, style: AccountText.body),
      const SizedBox(height: 14),
      AccountField(
        label: 'Company name',
        controller: _query,
        fieldKey: const Key('join.search'),
        hint: 'Search for your company',
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.search,
        onChanged: _typed,
        suffix: _searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : const Icon(Icons.search_rounded, color: AppColors.slate400),
      ),
      if (_searchError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(_searchError!, key: const Key('join.searchError'), style: AccountText.error),
        )
      else if (_searched.isNotEmpty && _found.isEmpty && !_searching)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'No company called “$_searched” is on ICR yet. You can create it instead.',
            key: const Key('join.none'),
            style: AccountText.meta,
          ),
        ),
      for (final hit in _found) _hitRow(hit),
    ];
  }

  Widget _hitRow(CompanyHit hit) {
    final member = widget.memberOf.contains(hit.id);
    final sent = widget.requested.contains(hit.id);
    final offered = !member && !sent;
    return InkWell(
      key: Key('join.hit.${hit.id}'),
      onTap: offered ? () => setState(() => _picked = hit) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CompanyLogo(url: hit.logoUrl, name: hit.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hit.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                  if (hit.city != null)
                    Text(hit.city!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AccountText.meta),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (member)
              const AccountChip(label: 'Member', color: AppColors.emerald50, ink: AppColors.emerald700)
            else if (sent)
              const AccountChip(label: 'Request sent')
            else
              Text('Ask to join', style: AccountText.link),
          ],
        ),
      ),
    );
  }

  // --- step 2: say why, and send -----------------------------------------------------------------------------

  List<Widget> _noteStep(CompanyHit picked) {
    return [
      Row(
        children: [
          CompanyLogo(url: picked.logoUrl, name: picked.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(picked.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AccountText.itemTitle),
                if (picked.city != null) Text(picked.city!, style: AccountText.meta),
              ],
            ),
          ),
          if (widget.initial == null)
            TextButton(
              key: const Key('join.change'),
              onPressed: _sending ? null : () => setState(() => _picked = null),
              child: const Text('Change'),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        'An admin at ${picked.name} decides. Until then nothing changes for you, and they choose the role you join with.',
        style: AccountText.body,
      ),
      const SizedBox(height: 14),
      AccountField(
        label: 'Anything they should know (optional)',
        controller: _note,
        fieldKey: const Key('join.note'),
        hint: 'I run facilities at your Pune site.',
        maxLength: 500,
        maxLines: 4,
        minLines: 3,
        counter: true,
        onChanged: (_) => setState(() {}),
      ),
    ];
  }
}
