import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../feed/feed_models.dart';
import '../../feed/widgets/feed_avatar.dart';
import 'mention_person.dart';

/// A company the Tags field's "@" list offers (`GET /companies?search=`, the public company list).
class TagCompany {
  const TagCompany({required this.id, required this.name, this.city, this.logo});

  factory TagCompany.fromJson(Map<String, dynamic> json, {String? apiBase}) {
    final logo = AppConfig.absoluteUrl(json['logoUrl'] as String?, apiBase: apiBase);
    final city = (json['city'] as String?)?.trim();
    return TagCompany(
      id: json['id'] as String,
      name: (json['name'] as String? ?? '').trim(),
      city: city == null || city.isEmpty ? null : city,
      logo: logo == null ? null : FeedPicture.network(logo),
    );
  }

  final String id;
  final String name;
  final String? city;
  final FeedPicture? logo;
}

/// Asks who or which company matches what was typed after the "@".
typedef TagCompanySearch = Future<List<TagCompany>> Function(String query);

/// The forum's own rule for a tag's characters, as `ComposerController.normaliseTag` and the API store one: lower
/// case, anything but letters and digits to one dash, at most 31 after the "@" (a tag is 32).
String tagHandleOf(String name) {
  final h = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return h.length > 31 ? h.substring(0, 31).replaceAll(RegExp(r'-+$'), '') : h;
}

/// The tag a pick from the "@" list adds: a person by their profile handle ("@vinay-kumar", which names them
/// exactly, so the API tells them and a tap opens their profile), else by their name; a company by its name
/// ("@acme-facility-services").
String tagForPerson(MentionPerson person) => '@${person.slug ?? tagHandleOf(person.name)}';
String tagForCompany(TagCompany company) => '@${tagHandleOf(company.name)}';

/// The "@" list behind a discussion's Tags field (owner, 3 Nov 2026: "@vinay" should offer the people and companies
/// it may mean). It watches the field: while what is typed starts with "@" (or "#@") and has two letters after it,
/// it asks for people and companies after a short pause, both at once, and holds what came back. Either search may
/// fail alone; the other's answers still show.
class TagSuggestController extends ChangeNotifier {
  TagSuggestController({
    required this.searchPeople,
    this.searchCompanies,
    this.debounce = const Duration(milliseconds: 250),
    this.maxEach = 5,
  });

  final MentionSearch searchPeople;
  final TagCompanySearch? searchCompanies;
  final Duration debounce;
  final int maxEach;

  TextEditingController? _field;
  String? _query;
  String? _resultsFor;
  List<MentionPerson> _people = const [];
  List<TagCompany> _companies = const [];
  bool _loading = false;
  bool _failed = false;
  Timer? _timer;
  int _ticket = 0;
  bool _disposed = false;

  /// The name typed after the "@", or null when the field holds no "@" tag being typed.
  String? get query => _query;

  /// The list shows: an "@" is being typed.
  bool get open => _query != null;
  bool get loading => _loading;

  /// Both searches failed.
  bool get failed => _failed;
  String? get resultsFor => _resultsFor;
  List<MentionPerson> get people => _people;
  List<TagCompany> get companies => _companies;

  /// The name after "@" in [text], or null: "@vinay" and "#@vinay" give "vinay"; anything else (a plain tag, two
  /// tags with a comma) gives null.
  static String? queryOf(String text) {
    var t = text.trimLeft();
    if (t.startsWith('#')) t = t.substring(1);
    if (!t.startsWith('@') || t.contains(',')) return null;
    return t.substring(1).trim();
  }

  void attach(TextEditingController field) {
    _field?.removeListener(_check);
    _field = field..addListener(_check);
    _check();
  }

  void _check() {
    final query = queryOf(_field?.text ?? '');
    if (query == _query) return;
    _query = query;
    _timer?.cancel();
    _ticket++;
    // From the first letter (bug sheet #3, 9 Nov 2026: "typing the first letter should auto-show matching names").
    if (query == null || query.isEmpty) {
      _loading = false;
      _failed = false;
      _people = const [];
      _companies = const [];
      _resultsFor = null;
      _notify();
      return;
    }
    _loading = true;
    _notify();
    final ticket = _ticket;
    _timer = Timer(debounce, () => _search(query, ticket));
  }

  Future<void> _search(String query, int ticket) async {
    Future<T?> attempt<T>(Future<T> Function() run) async {
      try {
        return await run();
      } catch (_) {
        return null;
      }
    }

    final companySearch = searchCompanies;
    final found = await Future.wait<Object?>([
      attempt(() => searchPeople(query)),
      if (companySearch != null) attempt(() => companySearch(query)),
    ]);
    if (_disposed || ticket != _ticket) return;
    final people = found[0] as List<MentionPerson>?;
    final companies = found.length > 1 ? found[1] as List<TagCompany>? : const <TagCompany>[];
    _loading = false;
    _failed = people == null && companies == null;
    _people = (people ?? const []).take(maxEach).toList();
    _companies = (companies ?? const []).take(maxEach).toList();
    _resultsFor = query;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _field?.removeListener(_check);
    super.dispose();
  }
}

/// The people and companies the "@" in the Tags field may mean, under the field: each with its photo or logo and
/// a line under the name (headline, city), in two short lists split by a hairline. A row adds the tag. Draws nothing
/// while no "@" is being typed.
class TagSuggestions extends StatelessWidget {
  const TagSuggestions({super.key, required this.controller, required this.onPerson, required this.onCompany});

  final TagSuggestController controller;
  final ValueChanged<MentionPerson> onPerson;
  final ValueChanged<TagCompany> onCompany;

  static final _label = AppText.plexSans(12, FontWeight.w600, AppColors.outline, lineHeight: 16);
  static final _name = AppText.plexSans(14, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final _sub = AppText.plexSans(12, FontWeight.w400, AppColors.outline, lineHeight: 16);
  static final _note = AppText.plexSans(13, FontWeight.w500, AppColors.outline, lineHeight: 18);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.open) return const SizedBox.shrink();
        final c = controller;
        final children = <Widget>[];
        if ((c.query ?? '').length < 2) {
          children.add(
            const _Note(key: ValueKey('tag-suggest-hint'), text: 'Type a name to tag a person or a company.'),
          );
        } else if (c.loading || c.resultsFor == null) {
          children.add(const _Note(key: ValueKey('tag-suggest-loading'), text: 'Searching…', spinner: true));
        } else if (c.failed) {
          children.add(const _Note(key: ValueKey('tag-suggest-failed'), text: 'Unable to search. Try again.'));
        } else if (c.people.isEmpty && c.companies.isEmpty) {
          children.add(const _Note(key: ValueKey('tag-suggest-empty'), text: 'No one found.'));
        } else {
          if (c.people.isNotEmpty) {
            children.add(_Label('People', style: _label));
            for (final p in c.people) {
              final a = p.author;
              children.add(
                _Option(
                  key: ValueKey('tag-person:${p.id}'),
                  label: 'Tag ${a.name}',
                  leading: FeedAvatar(photo: a.photo, initials: a.initials, size: 32, label: a.name),
                  title: a.name,
                  subtitle: a.headline,
                  onTap: () => onPerson(p),
                ),
              );
            }
          }
          if (c.companies.isNotEmpty) {
            if (c.people.isNotEmpty)
              children.add(const Divider(height: 1, thickness: 1, color: AppColors.outlineVariant));
            children.add(_Label('Companies', style: _label));
            for (final co in c.companies) {
              children.add(
                _Option(
                  key: ValueKey('tag-company:${co.id}'),
                  label: 'Tag ${co.name}',
                  leading: FeedAvatar(
                    photo: co.logo,
                    initials: co.name.isEmpty ? '?' : co.name.substring(0, 1).toUpperCase(),
                    size: 32,
                    label: co.name,
                  ),
                  title: co.name,
                  subtitle: co.city,
                  onTap: () => onCompany(co),
                ),
              );
            }
          }
        }
        // Taps in the list belong to the field's own tap region, so the field keeps its focus (and the keyboard).
        return TextFieldTapRegion(
          child: Padding(
            key: const ValueKey('tag-suggestions'),
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Colors.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
    child: Text(text, style: style),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TagSuggestions._name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Text(subtitle!, style: TagSuggestions._sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, this.spinner = false});

  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          if (spinner) ...[
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: TagSuggestions._note)),
        ],
      ),
    );
  }
}
