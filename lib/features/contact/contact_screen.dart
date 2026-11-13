import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../chapters/community_kit.dart';
import 'api_contact_repository.dart';
import 'contact_controller.dart';
import 'contact_models.dart';
import 'demo_contact_repository.dart';

/// The Contact screen with its controller, for a route:
/// `Navigator.push(context, MaterialPageRoute(builder: (c) => contactRoute(c, subject: '…')))`.
///
/// * [subject] opens the message ("Host or propose an event") and picks the
///   topic; [topic] names the topic outright (the website's `?topic=`).
/// * [onRaiseRequest] is the support desk: a signed-in member is told a support
///   request serves them better (it has a reference and a thread), and the
///   button shows only when this is given.
/// * [onRequestQuote] is kept for the callers: the "Reach us directly" card that
///   pointed to the quote form was removed (owner, 12 Nov 2026), so nothing
///   reads it now.
/// * [onBell] opens the notifications; the website's page when left out.
Widget contactRoute(
  BuildContext context, {
  String? subject,
  ContactTopic? topic,
  VoidCallback? onRaiseRequest,
  VoidCallback? onRequestQuote,
  VoidCallback? onBell,
  bool? demo,
}) {
  final sample = demo ?? AppConfig.demo;
  return ChangeNotifierProvider<ContactController>(
    create: (c) => ContactController(
      sample ? DemoContactRepository() : ApiContactRepository(api: c.read<ApiClient>()),
      subject: subject,
      topic: topic,
    ),
    child: Builder(
      builder: (inner) => ContactScreen(
        subject: subject,
        onBack: () => Navigator.of(inner).maybePop(),
        onBell: onBell,
        onRaiseRequest: onRaiseRequest,
        onRequestQuote: onRequestQuote,
      ),
    ),
  );
}

/// `/contact`: the website's contact form in the app. It reads a
/// [ContactController] from `Provider` (see [contactRoute]).
class ContactScreen extends StatefulWidget {
  const ContactScreen({
    super.key,
    this.subject,
    this.onBack,
    this.onBell,
    this.onRaiseRequest,
    this.onRequestQuote,
    this.opener = openUrl,
  });

  /// What the message is about, as the screen that opened this one put it. The
  /// controller applies it once (when it was built without one).
  final String? subject;

  /// The arrow at the top left, and "Done" after a send; pops the route when left out.
  final VoidCallback? onBack;

  /// The bell; the website's notifications page when left out.
  final VoidCallback? onBell;

  /// A signed-in member is told a support request serves them better (it has a
  /// reference and a thread); the button shows when this is given.
  final VoidCallback? onRaiseRequest;

  /// Kept for the callers: the "Reach us directly" card that offered the quote
  /// form was removed (owner, 12 Nov 2026), so the screen no longer reads it.
  final VoidCallback? onRequestQuote;

  /// Hands a link to the phone (the website's notifications page, when [onBell] is left out).
  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _scroll = ScrollController();
  final _boxes = {for (final f in ContactField.values) f: GlobalKey()};
  final _errorBox = GlobalKey();

  @override
  void initState() {
    super.initState();
    final contact = context.read<ContactController>();
    contact.applySubject(widget.subject);
    if (!contact.started) contact.start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _back() => (widget.onBack ?? () => Navigator.of(context).maybePop())();

  Future<void> _send(ContactController contact) async {
    FocusScope.of(context).unfocus();
    final ok = await contact.send();
    if (!mounted) return;
    // After the frame that draws the reasons (or the sent card).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ok) {
        if (_scroll.hasClients) {
          _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
        return;
      }
      final invalid = contact.firstInvalid;
      final box = (invalid != null ? _boxes[invalid] : _errorBox)?.currentContext;
      if (box != null) {
        Scrollable.ensureVisible(
          box,
          alignment: 0.15,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contact = context.watch<ContactController>();
    return CommunityPage(
      title: 'Contact Us',
      onBack: _back,
      onBell: widget.onBell ?? () => widget.opener(context, AppConfig.sitePage('/notifications')),
      unread: contact.unread,
      onRefresh: contact.refresh,
      controller: _scroll,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The website's "Talk to the ICR team" heading with its blurb, and the "Reach us directly"
                  // card under the form, were removed (owner, 12 Nov 2026): the page is the form.
                  if (contact.signedIn && widget.onRaiseRequest != null && !contact.sent) ...[
                    _SignedInNote(onRaiseRequest: widget.onRaiseRequest!),
                    const SizedBox(height: 14),
                  ],
                  if (contact.sent)
                    _Sent(email: contact.sentTo ?? '', onAnother: contact.another, onDone: _back)
                  else
                    _Form(contact: contact, boxes: _boxes, errorBox: _errorBox, onSend: () => _send(contact)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.contact, required this.boxes, required this.errorBox, required this.onSend});

  final ContactController contact;
  final Map<ContactField, GlobalKey> boxes;
  final GlobalKey errorBox;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final idle = !contact.sending;
    return CommunityCard(
      radius: 12,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!contact.loaded && contact.loading)
            const _Note(key: ValueKey('contact-checking'), busy: true, text: 'Checking whether you are signed in…')
          else if (contact.senderError != null)
            _Note(
              key: const ValueKey('contact-identity-failed'),
              icon: LucideIcons.circleAlert,
              text:
                  'Unable to check whether you are signed in, so your details are not filled in. You can still '
                  'send a message.',
              action: 'Try Again',
              onAction: contact.loading ? null : contact.refresh,
            ),
          KeyedSubtree(
            key: boxes[ContactField.name],
            child: CommunityField(
              label: 'Your Name',
              fieldKey: const ValueKey('contact-name'),
              controller: contact.name,
              hint: 'Jane Doe',
              error: contact.nameError,
              enabled: idle,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => contact.edited(),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: boxes[ContactField.email],
            child: CommunityField(
              label: 'Email',
              fieldKey: const ValueKey('contact-email'),
              controller: contact.email,
              hint: 'you@company.com',
              error: contact.emailError,
              enabled: idle,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => contact.edited(),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: boxes[ContactField.phone],
            child: CommunityField(
              label: 'Mobile Number',
              fieldKey: const ValueKey('contact-phone'),
              controller: contact.phone,
              hint: '+91 98765 43210',
              error: contact.phoneError,
              enabled: idle,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => contact.edited(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Topic', style: CommunityText.fieldLabel),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in ContactTopic.values)
                IcrChip(
                  key: ValueKey('topic-${t.api}'),
                  label: t.label,
                  tone: contact.topic == t ? ChipTone.primary : ChipTone.outlined,
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: CommunityText.chip.copyWith(fontSize: 12),
                  onTap: idle ? () => contact.setTopic(t) : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: boxes[ContactField.message],
            child: CommunityField(
              label: 'Message',
              fieldKey: const ValueKey('contact-message'),
              controller: contact.message,
              hint: 'Describe how we can help.',
              error: contact.messageError,
              enabled: idle,
              minLines: 5,
              maxLines: 10,
              maxLength: ContactLimits.message,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => contact.edited(),
            ),
          ),
          if (contact.error != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Container(
                key: errorBox,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: CommunityColors.red50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(LucideIcons.circleAlert, size: 14, color: CommunityColors.red600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contact.error!,
                        key: const ValueKey('contact-error'),
                        style: CommunityText.body.copyWith(color: CommunityColors.red600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          CommunityButton(
            key: const ValueKey('contact-send'),
            label: contact.sending ? 'Sending…' : 'Send',
            icon: LucideIcons.send,
            busy: contact.sending,
            expand: true,
            height: 42,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

/// A line above the form about the sign-in check: in flight, or failed with a Retry.
class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, this.busy = false, this.icon, this.action, this.onAction});

  final String text;
  final bool busy;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(color: CommunityColors.tile, borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6))
            else if (icon != null)
              Icon(icon, size: 14, color: CommunityColors.amber700),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: CommunityText.fieldHelp.copyWith(fontSize: 12, height: 1.4))),
            if (action != null) ...[
              const SizedBox(width: 6),
              TextButton(
                key: const ValueKey('contact-identity-retry'),
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(action!, style: CommunityText.link),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.email, required this.onAnother, required this.onDone});

  final String email;
  final VoidCallback onAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: CommunityCard(
        key: const ValueKey('contact-sent'),
        radius: 12,
        color: CommunityColors.green50,
        borderColor: CommunityColors.green200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.circleCheck, size: 26, color: CommunityColors.green700),
            const SizedBox(height: 8),
            Text('Message Sent', style: CommunityText.cardTitleLarge),
            const SizedBox(height: 4),
            Text(
              'Thank you. We have received your message and will reply within one business day.',
              style: CommunityText.body,
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('We will reply to $email.', style: CommunityText.body.copyWith(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CommunityButton(
                  key: const ValueKey('contact-another'),
                  label: 'Send Another',
                  outlined: true,
                  height: 36,
                  onPressed: onAnother,
                ),
                CommunityButton(key: const ValueKey('contact-done'), label: 'Done', height: 36, onPressed: onDone),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInNote extends StatelessWidget {
  const _SignedInNote({required this.onRaiseRequest});

  final VoidCallback onRaiseRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: CommunityColors.blue50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(LucideIcons.info, size: 14, color: CommunityColors.blue700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are signed in. A support request gives you a reference number, a reply target and a thread '
                  'you can follow. This form does not.',
                  style: CommunityText.cardCopy.copyWith(color: CommunityColors.slate800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: CommunityButton(
              key: const ValueKey('contact-raise'),
              label: 'Raise a Request',
              onPressed: onRaiseRequest,
              height: 34,
            ),
          ),
        ],
      ),
    );
  }
}
