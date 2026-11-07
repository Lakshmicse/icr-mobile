import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import '../learning_exam/exam_format.dart' show dateTimeLabel;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'enquiries_controller.dart';
import 'enquiries_repository.dart';
import 'enquiry_models.dart';

/// The partner institute's Enquiries (the website's `/admin/learning/enquiries`, `LeadsPanel`): every enquiry from
/// its course pages and its own page, newest first, with the contact details the plan's monthly number reveals
/// and the rest masked; each row moves through New → Contacted → Converted → Closed and takes the institute's note.
/// A "New enquiry" notification opens it on that one ([focusId], the website's `?lead=`), brought into view and
/// tinted (owner, 7 Nov 2026: a tap on the notification said "staff tools" instead of showing the enquiry).
///
/// Rows the whole width, hairlines between, nothing boxed. [repository] is a seam for tests.
class PartnerEnquiriesScreen extends StatefulWidget {
  const PartnerEnquiriesScreen({super.key, required this.onBack, this.focusId, this.repository});

  final VoidCallback onBack;
  final String? focusId;
  final EnquiriesRepository? repository;

  @override
  State<PartnerEnquiriesScreen> createState() => _PartnerEnquiriesScreenState();
}

class _PartnerEnquiriesScreenState extends State<PartnerEnquiriesScreen> {
  late final EnquiriesController _controller;
  final _focused = GlobalKey();
  bool _scrolledToFocus = false;

  @override
  void initState() {
    super.initState();
    final repo =
        widget.repository ??
        (AppConfig.demo ? DemoEnquiriesRepository() : ApiEnquiriesRepository(api: context.read<ApiClient>()));
    _controller = EnquiriesController(repo)..start();
    _controller.addListener(_bringFocusIntoView);
  }

  @override
  void dispose() {
    _controller.removeListener(_bringFocusIntoView);
    _controller.dispose();
    super.dispose();
  }

  /// Once the list holds the enquiry the notification named, scroll to it (once).
  void _bringFocusIntoView() {
    if (_scrolledToFocus || widget.focusId == null) return;
    if (!_controller.rows.any((r) => r.id == widget.focusId)) return;
    _scrolledToFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focused.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.1);
      }
    });
  }

  Future<void> _pickStatus(Enquiry e) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Status', style: SiteText.subheading),
              ),
            ),
            for (final s in enquiryStatuses)
              ListTile(
                key: ValueKey('status-option-$s'),
                title: Text(enquiryStatusLabel(s), style: SiteText.body),
                trailing: s == e.status ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(sheet).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == e.status || !mounted) return;
    final refusal = await _controller.setLeadStatus(e.id, picked);
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  Future<void> _saveNote(Enquiry e, String note) async {
    if ((e.note ?? '') == note.trim()) return;
    final refusal = await _controller.saveNote(e.id, note);
    if (!mounted) return;
    showMessage(context, refusal ?? 'Note saved.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                TitleBar(title: 'Enquiries', onBack: widget.onBack, onBell: () => openNotifications(context)),
                Expanded(child: _body(c)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(EnquiriesController c) {
    if (c.loading && c.rows.isEmpty && c.error == null) return const SiteLoading();
    if (c.error != null && c.rows.isEmpty) {
      return SiteError(key: const ValueKey('enquiries-error'), message: c.error!, onRetry: c.refresh);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: c.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) c.loadMore();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The website's Status filter, as chips.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(label: 'All', on: c.status.isEmpty, onTap: () => c.setStatus('')),
                        for (final s in enquiryStatuses)
                          _FilterChip(
                            key: ValueKey('filter-$s'),
                            label: enquiryStatusLabel(s),
                            on: c.status == s,
                            onTap: () => c.setStatus(s),
                          ),
                      ],
                    ),
                    if (c.reveal?.sentence case final sentence?) ...[
                      const SizedBox(height: 12),
                      Row(
                        key: const ValueKey('enquiries-reveal'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            c.reveal!.overPlan ? LucideIcons.lock : LucideIcons.info,
                            size: 16,
                            color: c.reveal!.overPlan ? AppColors.amber800 : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(sentence, style: SiteText.secondary)),
                        ],
                      ),
                    ],
                    if (c.error != null) ...[
                      const SizedBox(height: 12),
                      Text(c.error!, key: const ValueKey('enquiries-inline-error'), style: SiteText.secondary),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (c.rows.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Text(
                    key: const ValueKey('enquiries-empty'),
                    c.status.isEmpty
                        ? 'No enquiries yet. The form is on every course page of yours and on your institute page.'
                        : 'No enquiries with that status.',
                    style: SiteText.secondary,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 28),
                sliver: SliverList.separated(
                  itemCount: c.rows.length + (c.loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
                  itemBuilder: (context, i) {
                    if (i == c.rows.length) return const Padding(padding: EdgeInsets.all(16), child: SiteLoading());
                    final e = c.rows[i];
                    final focused = e.id == widget.focusId;
                    return EnquiryRow(
                      key: focused ? _focused : ValueKey('enquiry-${e.id}'),
                      enquiry: e,
                      focused: focused,
                      busy: c.busy(e.id),
                      onStatus: () => _pickStatus(e),
                      onSaveNote: (note) => _saveNote(e, note),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18),
      onTap: onTap,
    );
  }
}

/// One enquiry, as the website's row: who (name, company and size, the kind and the course), the contact details
/// (masked past the plan, with the website's sentence), when, the message, then the status and the note.
class EnquiryRow extends StatefulWidget {
  const EnquiryRow({
    super.key,
    required this.enquiry,
    required this.onStatus,
    required this.onSaveNote,
    this.focused = false,
    this.busy = false,
  });

  final Enquiry enquiry;
  final bool focused;
  final bool busy;
  final VoidCallback onStatus;
  final ValueChanged<String> onSaveNote;

  @override
  State<EnquiryRow> createState() => _EnquiryRowState();
}

class _EnquiryRowState extends State<EnquiryRow> {
  late final TextEditingController _note = TextEditingController(text: widget.enquiry.note ?? '');
  final _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Saved when the person leaves the field, as the website's note is.
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) widget.onSaveNote(_note.text);
    });
  }

  @override
  void didUpdateWidget(covariant EnquiryRow old) {
    super.didUpdateWidget(old);
    final note = widget.enquiry.note ?? '';
    if (note != (old.enquiry.note ?? '') && note != _note.text && !_noteFocus.hasFocus) _note.text = note;
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enquiry;
    final who = [if (e.company != null) e.company!, if (e.headcount != null) '~${e.headcount} people'].join(' · ');
    return Container(
      color: widget.focused ? SiteColors.blueTint : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: SiteText.strong),
                    if (who.isNotEmpty) Text(who, style: SiteText.meta),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(dateTimeLabel(e.createdAt), style: SiteText.meta),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              IcrChip(label: enquiryKindLabel(e.kind), tone: ChipTone.outlined, height: 24),
              if (e.courseCode != null) IcrChip(label: e.courseCode!, tone: ChipTone.outlined, height: 24),
            ],
          ),
          const SizedBox(height: 10),
          _Contact(enquiry: e),
          if (e.message != null) ...[const SizedBox(height: 10), Text(e.message!, style: SiteText.body)],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Status', style: SiteText.meta),
              const SizedBox(width: 8),
              IcrChip(
                key: ValueKey('status-${e.id}'),
                label: enquiryStatusLabel(e.status),
                tone: _tone(e.status),
                height: 30,
                trailing: widget.busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more, size: 16),
                onTap: widget.busy ? null : widget.onStatus,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: ValueKey('note-${e.id}'),
            controller: _note,
            focusNode: _noteFocus,
            maxLines: null,
            maxLength: 4000,
            style: SiteText.body,
            decoration: InputDecoration(
              hintText: 'Your note',
              hintStyle: SiteText.secondary,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
            onSubmitted: widget.onSaveNote,
          ),
        ],
      ),
    );
  }

  static ChipTone _tone(String status) => switch (status) {
    'NEW' => ChipTone.primary,
    'CONVERTED' => ChipTone.tinted,
    _ => ChipTone.outlined,
  };
}

/// The email and phone: open, or greyed with a lock and the website's reason when the plan's number is past.
class _Contact extends StatelessWidget {
  const _Contact({required this.enquiry});

  final Enquiry enquiry;

  static const masked = "Past this month's number on your plan. The details open with a larger plan, or next month.";

  @override
  Widget build(BuildContext context) {
    final e = enquiry;
    final style = e.revealed ? SiteText.body : SiteText.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!e.revealed) ...[
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(LucideIcons.lock, size: 14, color: AppColors.slate400),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.email, key: ValueKey('email-${e.id}'), style: style),
                  if (e.phone != null) Text(e.phone!, style: style),
                ],
              ),
            ),
          ],
        ),
        if (!e.revealed) ...[
          const SizedBox(height: 4),
          Text(masked, key: ValueKey('masked-${e.id}'), style: SiteText.meta),
        ],
      ],
    );
  }
}
