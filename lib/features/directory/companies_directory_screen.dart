import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show CompanyLogo;

/// A company of the directory (`GET /companies`), as much of it as a row shows.
class DirectoryCompany {
  const DirectoryCompany({
    required this.id,
    required this.name,
    this.logoUrl,
    this.industry,
    this.city,
    this.country,
    this.openJobs = 0,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? industry;
  final String? city;
  final String? country;
  final int openJobs;
  final bool verified;

  factory DirectoryCompany.fromJson(Map<String, dynamic> j) => DirectoryCompany(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? 'Company',
    logoUrl: j['logoUrl'] as String?,
    industry: j['industry'] as String?,
    city: j['city'] as String?,
    country: j['country'] as String?,
    openJobs: (j['openJobs'] as num?)?.toInt() ?? 0,
    verified: j['verificationStatus'] == 'VERIFIED',
  );

  /// "FM services · Bengaluru, India".
  String get line => [
    if (industry != null && industry!.isNotEmpty) enumWords(industry!),
    [city, country].whereType<String>().where((s) => s.isNotEmpty).join(', '),
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// `FM_SERVICES` → "FM services": an enum value in words, its first letter capital and the known initialisms kept.
String enumWords(String value) {
  const keep = {'FM', 'IT', 'HR', 'MEP', 'HVAC', 'ESG', 'BMS', 'CRE'};
  final words = value.split('_').where((w) => w.isNotEmpty).toList();
  return [
    for (var i = 0; i < words.length; i++)
      keep.contains(words[i])
          ? words[i]
          : i == 0
          ? '${words[i][0]}${words[i].substring(1).toLowerCase()}'
          : words[i].toLowerCase(),
  ].join(' ');
}

/// The companies on ICR (the website's `/companies`): a search and the list, more as it scrolls; a company opens its
/// page in the app.
class CompaniesDirectoryScreen extends StatefulWidget {
  const CompaniesDirectoryScreen({super.key, required this.onOpenCompany, this.onBack, this.onBell, this.unread = 0});

  final void Function(String companyId) onOpenCompany;
  final VoidCallback? onBack;
  final VoidCallback? onBell;
  final int unread;

  @override
  State<CompaniesDirectoryScreen> createState() => _CompaniesDirectoryScreenState();
}

class _CompaniesDirectoryScreenState extends State<CompaniesDirectoryScreen> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <DirectoryCompany>[];
  Timer? _debounce;
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) unawaited(_more());
    });
    unawaited(_more());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _items.clear();
        _page = 0;
        _done = false;
        _error = null;
      });
      unawaited(_more());
    });
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = _search.text.trim();
    try {
      final res = await context.read<ApiClient>().dio.get<Map<String, dynamic>>(
        '/companies',
        queryParameters: {'page': _page + 1, 'limit': _pageSize, if (query.isNotEmpty) 'search': query},
      );
      if (!mounted || query != _search.text.trim()) return;
      final data = (res.data?['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      final meta = (res.data?['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
      setState(() {
        _items.addAll(data.map(DirectoryCompany.fromJson));
        _page += 1;
        _total = (meta['total'] as num?)?.toInt() ?? _items.length;
        _done = meta['hasNext'] != true;
      });
    } on DioException catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: 'Companies', onBack: widget.onBack, unread: widget.unread, onBell: widget.onBell ?? () {}),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                key: const ValueKey('companies-search'),
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search Companies',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _total == 1 ? '1 company' : '$_total companies',
                    style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant),
                  ),
                ),
              ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return _Message(text: _error!, onRetry: _more);
    if (_items.isEmpty) return const _Message(text: 'No companies match your search.');
    return ListView.separated(
      controller: _scroll,
      itemCount: _items.length + (_done ? 0 : 1),
      separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, indent: 72, color: AppColors.outlineVariant),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final c = _items[i];
        return InkWell(
          key: ValueKey('company-${c.id}'),
          onTap: () => widget.onOpenCompany(c.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CompanyLogo(url: c.logoUrl, name: c.name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.plexSans(15, FontWeight.w600, AppColors.onSurface),
                            ),
                          ),
                          if (c.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 16, color: AppColors.primary),
                          ],
                        ],
                      ),
                      if (c.line.isNotEmpty)
                        Text(
                          c.line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.plexSans(13, FontWeight.w400, AppColors.onSurfaceVariant),
                        ),
                      if (c.openJobs > 0)
                        Text(
                          c.openJobs == 1 ? '1 open job' : '${c.openJobs} open jobs',
                          style: AppText.plexSans(12, FontWeight.w500, AppColors.tertiary),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.icon),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.plexSans(14, FontWeight.w400, AppColors.onSurfaceVariant),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    ),
  );
}
