import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config.dart';
import '../../core/util/links.dart';
import 'mentor_profile_controller.dart';
import 'mentor_profile_format.dart';
import 'mentor_profile_models.dart';
import 'request_sheets.dart';
import 'widgets/profile_hero.dart';

/// What an offering's button does: ask for a session, or buy/request/open it
/// on the website where the app does not take payment yet. Resolves true when
/// something was sent or completed, so a sheet can close behind it.
Future<bool> runOfferingAction(BuildContext context, MentorProfileController c, MentorOffering o) async {
  // A session or programme already asked for is followed up in My mentoring's Purchases (the mentor's answer,
  // then the payment), not asked for a second time.
  if (o.isRequested && o.myOpenRequestId != null) {
    await c.navigation.purchases(context);
    return false;
  }
  switch (o.kind) {
    case OfferingKind.oneOnOne:
    case OfferingKind.query:
      return showSessionRequestSheet(context, c, o);
    case OfferingKind.resource:
    case OfferingKind.plan:
    case OfferingKind.program:
    case OfferingKind.groupSession:
      String? phone;
      final sharesPhone = o.kind == OfferingKind.program || (o.kind == OfferingKind.plan && o.free);
      if (sharesPhone && await c.needsPhone()) {
        if (!context.mounted) return false;
        phone = await _askPhone(context);
        if (phone == null) return false;
      }
      var outcome = await c.buy(o, phone: phone);
      // The API can still find the number missing (cleared on the website since the
      // profile loaded): ask for it once and send the request again.
      if (outcome.state == CheckoutState.refused && phone == null && sharesPhone && isPhoneRefusal(outcome.message)) {
        if (!context.mounted) return false;
        phone = await _askPhone(context);
        if (phone == null) return false;
        outcome = await c.buy(o, phone: phone);
      }
      if (!context.mounted) return false;
      if (outcome.message != null) showMessage(context, outcome.message!);
      if (outcome.state == CheckoutState.website && outcome.sitePath != null) {
        // The checkout runs on the website (PayU); the app's own screen for that address is this profile.
        await openExternal(context, AppConfig.sitePage(outcome.sitePath!));
        return false;
      }
      return outcome.state == CheckoutState.completed || outcome.state == CheckoutState.requested;
  }
}

Future<String?> _askPhone(BuildContext context) => showPhoneSheet(
  context,
  title: 'Add your mobile number',
  help: 'A plan or programme puts you in touch with the mentor, who needs a way to reach you.',
);

/// The two big buttons of the hero and the pinned bar, for this viewer. The
/// order follows the website's: owner, a free session, a live pairing, a
/// request in play, then what stops them asking, then the free request.
HeroActions heroActionsFor(BuildContext context, MentorProfileController c) {
  final p = c.profile!;
  final v = p.viewer;
  final trial = c.trialOffering;

  VoidCallback? onMessage;
  if (v?.isOwner != true) {
    onMessage = () async {
      if (v?.mentorshipId != null) {
        final id = await c.openConversation();
        if (!context.mounted) return;
        await c.navigation.conversation(context, id);
      } else if (v == null || v.canRequest) {
        await showMentoringRequestSheet(context, c);
      } else {
        showMessage(context, v.blockedReason ?? "You can't message this mentor yet.");
      }
    };
  }

  if (v?.isOwner == true) {
    return HeroActions(
      primaryLabel: 'Edit My Profile',
      barLabel: 'Edit My Profile',
      primaryIcon: LucideIcons.pencil,
      onPrimary: () => c.navigation.editMentorProfile(context),
    );
  }
  if (trial != null) {
    return HeroActions(
      primaryLabel: trial.myOpenRequestId != null ? 'Trial Requested' : 'Book Trial (₹0)',
      barLabel: trial.myOpenRequestId != null ? 'Trial Requested' : 'Book Free Trial',
      onPrimary: trial.myOpenRequestId != null ? null : () => runOfferingAction(context, c, trial),
      onMessage: onMessage,
    );
  }
  if (v?.mentorshipId != null) {
    return HeroActions(
      primaryLabel: 'Open Our Mentorship',
      barLabel: 'Open Our Mentorship',
      onPrimary: () => c.navigation.pairing(context, v!.mentorshipId!),
      onMessage: onMessage,
    );
  }
  if (v?.pendingRequestId != null) {
    return HeroActions(primaryLabel: 'Request Pending', barLabel: 'Request Pending', onMessage: onMessage);
  }
  return switch (v?.blocker) {
    AskBlocker.noMenteeProfile => HeroActions(
      primaryLabel: 'Tell Us Your Goals First',
      barLabel: 'Tell Us Your Goals First',
      onPrimary: () => c.navigation.goals(context),
      onMessage: onMessage,
    ),
    AskBlocker.planLimit => HeroActions(
      primaryLabel: 'See Plans',
      barLabel: 'See Plans',
      onPrimary: () => openSitePage(context, '/career/plans'),
      onMessage: onMessage,
    ),
    AskBlocker.atCapacity => HeroActions(primaryLabel: 'At Capacity', barLabel: 'At Capacity', onMessage: onMessage),
    _ => HeroActions(
      primaryLabel: 'Request Mentoring',
      barLabel: 'Request Mentoring',
      onPrimary: () => showMentoringRequestSheet(context, c),
      onMessage: onMessage,
    ),
  };
}
