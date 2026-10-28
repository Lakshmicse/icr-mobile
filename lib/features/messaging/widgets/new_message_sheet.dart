import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../messaging_models.dart';
import '../messaging_repository.dart';
import '../messaging_styles.dart';
import 'chat_avatar.dart';
import 'states.dart';

/// "New message": search people and suppliers, tap one, and the thread opens
/// (a person's plain thread is reused when the two already share one; a
/// supplier's sales inbox answers). Returns the conversation's id, or null.
Future<String?> showNewMessage(BuildContext context, MessagingRepository repository) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: NewMessageSheet(repository: repository)),
  );
}

class NewMessageSheet extends StatefulWidget {
  const NewMessageSheet({super.key, required this.repository});

  final MessagingRepository repository;

  @override
  State<NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<NewMessageSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  Recipients _found = const Recipients();
  bool _loading = false;
  String? _error;
  String? _starting;
  String? _startError;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _run);
  }

  Future<void> _run() async {
    final term = _search.text.trim();
    final generation = ++_generation;
    if (term.length < 2) {
      setState(() {
        _found = const Recipients();
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await widget.repository.recipients(term);
      if (!mounted || generation != _generation) return;
      setState(() => _found = found);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _found = const Recipients();
        _error = ApiError.from(e).message;
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _start(String key, Future<String> Function() open) async {
    if (_starting != null) return;
    setState(() {
      _starting = key;
      _startError = null;
    });
    try {
      final id = await open();
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = null;
          _startError = ApiError.from(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('New message', style: ChatText.sheetTitle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const ValueKey('recipient-search'),
              controller: _search,
              autofocus: true,
              onChanged: _typed,
              style: ChatText.composer,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search a person or a supplier',
                hintStyle: ChatText.composerHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.slate200),
                ),
              ),
            ),
          ),
          if (_startError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _startError!,
                  key: const ValueKey('start-error'),
                  style: ChatText.lead.copyWith(color: AppColors.onErrorContainer),
                ),
              ),
            ),
          const Divider(height: 1, color: ChatColors.rule),
          Expanded(
            child: _loading && _found.isEmpty
                ? const ChatSpinner()
                : _error != null
                ? ChatNotice(
                    icon: LucideIcons.cloudOff,
                    title: "Couldn't search.",
                    body: _error,
                    action: 'Retry',
                    onAction: _run,
                  )
                : term.length < 2
                ? const ChatNotice(
                    icon: LucideIcons.users,
                    title: 'Who would you like to message?',
                    body: 'Type at least two letters of a name or a company.',
                  )
                : _found.isEmpty
                ? const ChatNotice(
                    icon: LucideIcons.userX,
                    title: 'No one found',
                    body: 'People with a private profile do not appear here.',
                  )
                : ListView(
                    children: [
                      if (_found.people.isNotEmpty) const _Heading('People'),
                      for (final r in _found.people)
                        ListTile(
                          key: ValueKey('person-${r.person.id}'),
                          leading: ChatAvatar(picture: r.person.photo, name: r.person.fullName, size: 40),
                          title: Text(r.person.fullName, style: ChatText.rowName),
                          subtitle: Text(
                            [?r.headline, ?r.companyName].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ChatText.rowAbout,
                          ),
                          trailing: _starting == 'p-${r.person.id}'
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                          onTap: () => _start('p-${r.person.id}', () => widget.repository.startWithPerson(r.person.id)),
                        ),
                      if (_found.suppliers.isNotEmpty) const _Heading('Suppliers'),
                      for (final s in _found.suppliers)
                        ListTile(
                          key: ValueKey('supplier-${s.vendorId}'),
                          leading: ChatAvatar(picture: s.logo, name: s.name, size: 40, company: true),
                          title: Text(s.name, style: ChatText.rowName),
                          subtitle: Text(
                            [if (s.city != null) s.city!, 'Sales team replies'].join(' · '),
                            style: ChatText.rowAbout,
                          ),
                          trailing: _starting == 's-${s.vendorId}'
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                          onTap: () => _start('s-${s.vendorId}', () => widget.repository.startWithSupplier(s.vendorId)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text.toUpperCase(), style: ChatText.section),
  );
}
