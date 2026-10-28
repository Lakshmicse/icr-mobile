import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../account/account_models.dart';
import '../account/account_repository.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'signup_rules.dart';
import 'signup_widgets.dart';

/// What the third screen collected.
class WorkAnswer {
  const WorkAnswer({
    required this.working,
    required this.title,
    required this.company,
    this.picked,
    this.askToJoin = true,
    this.since,
    this.city,
    this.readyNext = false,
  });

  /// "I'm working" (false: between roles).
  final bool working;
  final String title;

  /// The company as typed.
  final String company;

  /// The company page picked from the list, when it is one ICR knows.
  final CompanyHit? picked;
  final bool askToJoin;

  /// The year the role started.
  final int? since;
  final CityOption? city;

  /// Between roles: let recruiters know the person is ready for the next one.
  final bool readyNext;
}

/// Writes the answer where the profile keeps it, as the website's `YourWorkStep`
/// does: a current role in career history (`PUT /profile/experience`), the
/// headline (`PATCH /users/me {designation}`) and the résumé's title and place
/// (`PATCH /users/me/resume`); between roles only the résumé, with the "ready
/// for my next role" flag when asked for. Picking a company already on ICR can
/// also ask its admins to add the person.
///
/// Returns null when everything went through, or the sentence to show when the
/// profile was saved but the request to join was refused. Throws [ApiError] when
/// the profile itself could not be saved.
Future<String?> saveYourWork(AccountRepository account, WorkAnswer a) async {
  final title = a.title.trim();
  final place = a.city?.label;
  if (a.working) {
    final picked = a.picked;
    await account.saveExperience([
      Experience(
        title: title,
        organisation: picked?.name ?? a.company.trim(),
        company: picked == null ? null : LinkedCompany(id: picked.id, name: picked.name, logoUrl: picked.logoUrl),
        startYear: a.since!,
        isCurrent: true,
        city: a.city?.name,
      ),
    ]);
    await account.updateMe({'designation': title});
    await account.updateResume({'jobTitle': title, 'location': ?place});
    if (picked != null && a.askToJoin) {
      try {
        await account.requestToJoin(picked.id);
      } catch (e) {
        return 'Your profile is saved, but the request to join ${picked.name} did not go through: '
            '${ApiError.from(e).message}';
      }
    }
  } else if (title.isNotEmpty || place != null || a.readyNext) {
    await account.updateResume({
      if (title.isNotEmpty) 'jobTitle': title,
      'location': ?place,
      // Seen by companies hiring on ICR only; they can widen it on their profile.
      if (a.readyNext) 'nextRoleStatus': 'READY_NOW',
      if (a.readyNext) 'nextRoleVisibility': 'RECRUITERS',
    });
  }
  return null;
}

/// Sign-up's third screen, the website's `YourWorkStep`: LinkedIn's "most
/// recent job title and company". It writes where the profile keeps them — a
/// current role in career history (`PUT /profile/experience`), the headline
/// (`PATCH /users/me {designation}`) and the résumé's title and place
/// (`PATCH /users/me/resume`) — and, for a company already on ICR, can ask its
/// admins to add the person. "Between roles" asks only for a last title, a
/// place and whether recruiters may know they are ready. Skippable.
class YourWorkStep extends StatefulWidget {
  const YourWorkStep({super.key, required this.account, required this.onDone, this.searchDelay});

  final AccountRepository account;
  final VoidCallback onDone;

  /// How long typing must settle before ICR's companies are searched.
  final Duration? searchDelay;

  @override
  State<YourWorkStep> createState() => _YourWorkStepState();
}

class _YourWorkStepState extends State<YourWorkStep> {
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _titleFocus = FocusNode();
  final _companyFocus = FocusNode();

  bool _working = true;
  CompanyHit? _picked;
  bool _askToJoin = true;
  int? _since;
  CityOption? _city;
  bool _readyNext = false;

  List<String> _titles = const [];
  List<CityOption> _cities = const [];
  List<CompanyHit> _found = const [];
  Timer? _debounce;
  String _searched = '';

  ({String? title, String? company, String? since}) _errors = (title: null, company: null, since: null);
  String? _error;
  String? _warning;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_refresh);
    _companyFocus.addListener(_refresh);
    _loadLookups();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLookups() async {
    // Both are aids; the step works without them.
    try {
      final titles = await widget.account.jobTitles();
      if (mounted) setState(() => _titles = titles);
    } catch (_) {}
    try {
      final cities = await widget.account.cities();
      if (mounted) setState(() => _cities = cities);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _company.dispose();
    _titleFocus.dispose();
    _companyFocus.dispose();
    super.dispose();
  }

  void _companyTyped(String value) {
    // Typing after a pick means it is no longer that page.
    if (_picked != null && value != _picked!.name) setState(() => _picked = null);
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _found = const [];
        _searched = '';
      });
      return;
    }
    _debounce = Timer(widget.searchDelay ?? const Duration(milliseconds: 300), () async {
      try {
        final hits = await widget.account.searchCompanies(query);
        if (!mounted || _company.text.trim() != query) return;
        setState(() {
          _found = hits;
          _searched = query;
        });
      } catch (_) {
        // A failed search leaves the name as typed, which saves as a plain name.
      }
    });
  }

  List<String> get _titleSuggestions {
    final q = _title.text.trim().toLowerCase();
    if (!_titleFocus.hasFocus || q.isEmpty) return const [];
    return _titles.where((t) => t.toLowerCase().contains(q) && t.toLowerCase() != q).take(6).toList();
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final problems = workProblems(working: _working, title: _title.text, company: _company.text, since: _since);
    setState(() {
      _errors = problems;
      _error = null;
    });
    if (problems.title != null || problems.company != null || problems.since != null) return;
    setState(() => _busy = true);
    try {
      final warning = await saveYourWork(
        widget.account,
        WorkAnswer(
          working: _working,
          title: _title.text,
          company: _company.text,
          picked: _picked,
          askToJoin: _askToJoin,
          since: _since,
          city: _city,
          readyNext: _readyNext,
        ),
      );
      if (warning != null) {
        // The profile is saved either way; say what did not happen.
        if (mounted) setState(() => _warning = warning);
        return;
      }
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickYear() async {
    final year = await showAuthPicker<int>(
      context,
      title: 'Year you started',
      items: careerYears(),
      labelOf: (y) => '$y',
    );
    if (year != null && mounted) setState(() => _since = year);
  }

  Future<void> _pickCity() async {
    if (_cities.isEmpty) {
      try {
        final cities = await widget.account.cities();
        if (mounted) setState(() => _cities = cities);
      } catch (e) {
        if (mounted) setState(() => _error = ApiError.from(e).message);
        return;
      }
    }
    if (!mounted) return;
    final city = await showAuthPicker<CityOption>(
      context,
      title: 'Where you are based',
      items: _cities,
      labelOf: (c) => c.name,
      subtitleOf: (c) => c.state ?? '',
      searchable: true,
      searchHint: 'Search cities',
    );
    if (city != null && mounted) setState(() => _city = city);
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    if (_warning != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthNotice(warning: true, child: Text(_warning!, key: const Key('work.warning'))),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            key: const Key('work.continue'),
            label: 'Continue',
            busyLabel: 'Continue',
            busy: false,
            onPressed: widget.onDone,
          ),
        ],
      );
    }
    final picked = _picked;
    final showCompanies =
        _companyFocus.hasFocus && picked == null && _found.isNotEmpty && _searched == _company.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[AuthErrorLine(message: _error!), const SizedBox(height: 12)],
        AuthSegmented<bool>(
          value: _working,
          semanticLabel: 'What you do now',
          options: const [(true, 'I’m working'), (false, 'Between roles')],
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  _working = v;
                  _errors = (title: null, company: null, since: null);
                }),
        ),
        const SizedBox(height: 6),
        AuthField(
          fieldKey: const Key('work.title'),
          label: _working ? 'Job title' : 'Most recent job title (optional)',
          controller: _title,
          focusNode: _titleFocus,
          icon: Icons.badge_outlined,
          hint: 'e.g. Facilities Manager',
          enabled: !_busy,
          maxLength: 160,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _working ? _companyFocus.requestFocus() : null,
        ),
        ListenableBuilder(
          listenable: _title,
          builder: (context, _) => AuthSuggestions<String>(
            key: const Key('work.titleSuggestions'),
            items: _titleSuggestions,
            labelOf: (t) => t,
            onPick: (t) {
              _title.text = t;
              _title.selection = TextSelection.collapsed(offset: t.length);
              setState(() => _errors = (title: null, company: _errors.company, since: _errors.since));
              if (_working) _companyFocus.requestFocus();
            },
          ),
        ),
        AuthHelperLine(error: _errors.title),
        if (_working) ...[
          const SizedBox(height: 6),
          AuthField(
            fieldKey: const Key('work.company'),
            label: 'Company',
            controller: _company,
            focusNode: _companyFocus,
            icon: Icons.apartment_rounded,
            hint: 'Where you work now',
            enabled: !_busy,
            maxLength: 160,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: _companyTyped,
          ),
          if (showCompanies)
            AuthSuggestions<CompanyHit>(
              key: const Key('work.companySuggestions'),
              items: _found,
              labelOf: (c) => c.name,
              subtitleOf: (c) => c.city == null ? 'On ICR' : '${c.city} · on ICR',
              onPick: (c) {
                _company.text = c.name;
                FocusScope.of(context).unfocus();
                setState(() {
                  _picked = c;
                  _askToJoin = true;
                  _errors = (title: _errors.title, company: null, since: _errors.since);
                });
              },
            ),
          AuthHelperLine(
            error: _errors.company,
            helper: picked == null ? 'Pick it from the list if it is already on ICR.' : null,
          ),
          if (picked != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AuthCheckLine(
                key: const Key('work.askToJoin'),
                value: _askToJoin,
                label: 'Ask to join ${picked.name}’s team',
                onChanged: _busy ? null : (v) => setState(() => _askToJoin = v),
                child: Text(
                  'Ask to join ${picked.name}’s team on ICR. Its admins decide.',
                  style: AuthType.small(p).copyWith(color: p.text, fontSize: 14),
                ),
              ),
            ),
          const SizedBox(height: 6),
          AuthPickerField(
            key: const Key('work.since'),
            label: 'Since',
            hint: 'Year you started',
            value: _since?.toString(),
            icon: Icons.event_outlined,
            error: _errors.since,
            onTap: _busy ? null : _pickYear,
          ),
        ],
        const SizedBox(height: 6),
        AuthPickerField(
          key: const Key('work.city'),
          label: 'City (optional)',
          hint: 'Where you are based',
          value: _city?.label,
          icon: Icons.place_outlined,
          onTap: _busy ? null : _pickCity,
          onClear: _busy ? null : () => setState(() => _city = null),
        ),
        if (!_working) ...[
          const SizedBox(height: 10),
          AuthCheckLine(
            key: const Key('work.readyNext'),
            value: _readyNext,
            label: 'Let recruiters know I’m ready for my next role',
            onChanged: _busy ? null : (v) => setState(() => _readyNext = v),
            child: Text(
              'Let recruiters know I’m ready for my next role',
              style: AuthType.small(p).copyWith(color: p.text, fontSize: 14),
            ),
          ),
        ],
        const SizedBox(height: 20),
        AuthPrimaryButton(
          key: const Key('work.save'),
          label: 'Continue',
          busyLabel: 'Saving…',
          busy: _busy,
          onPressed: _save,
        ),
        const SizedBox(height: 4),
        Center(
          child: AuthLink(
            key: const Key('work.skip'),
            label: 'Skip for now',
            style: AuthType.link(p).copyWith(fontSize: 16),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            onTap: _busy ? () {} : widget.onDone,
          ),
        ),
      ],
    );
  }
}
