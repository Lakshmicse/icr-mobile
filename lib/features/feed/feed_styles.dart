import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// The Home feed is drawn like LinkedIn's Android home (owner's call, 27 Oct 2026): a warm grey canvas with
/// white, edge-to-edge cards 8 dp apart, Roboto throughout, near-black and 60 % black text, ICR blue where
/// LinkedIn uses its blue. Every colour and text style of that look lives here.
class HomeLook {
  HomeLook._();

  static const canvas = Color(0xFFF4F2EE);
  static const card = Colors.white;
  static const hairline = Color(0xFFE0DFDC);

  /// 90 % and 60 % black on white.
  static const ink = Color(0xE6000000);
  static const soft = Color(0x99000000);

  /// The search field's fill, a comment's bubble, a chip's active fill.
  static const searchFill = Color(0xFFEDF3F8);
  static const bubble = Color(0xFFF2F2F2);
  static const chipActive = Color(0xFF1F1F1F);
  static const blue = AppColors.primary;

  static const gap = 8.0;
  static const pad = 12.0;
}

/// Roboto at a size, weight and colour. The bundled `Roboto` is Android's variable font, so a weight above
/// Regular is asked for on its `wght` axis (a plain `fontWeight` alone would be drawn as a synthetic bold).
TextStyle roboto(double size, FontWeight weight, Color color, {double? lineHeight}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: lineHeight == null ? null : lineHeight / size,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
);

/// The Home feed's type: LinkedIn's Android sizes, in Roboto. They are read off LinkedIn's own screenshot
/// (27 Oct 2026, a 360 dp phone) by fitting Roboto's advance widths to the measured widths of the same kinds of
/// line: author name 16 sp, headline and "1d • Edited" 12 sp, body 14 sp on an 18 dp pitch, counts 12.5 sp,
/// the search hint 16 sp. The name, headline and meta lines sit 15 and 14.5 dp apart (baseline to baseline), so
/// their line heights are 18, 14.5 and 14.5.
class HomeType {
  HomeType._();

  // Header and composer.
  static final searchHint = roboto(16, FontWeight.w400, HomeLook.soft, lineHeight: 20);
  static final composerHint = roboto(14, FontWeight.w600, HomeLook.soft, lineHeight: 20);
  static final chip = roboto(13, FontWeight.w600, HomeLook.soft, lineHeight: 16);

  // A post.
  static final name = roboto(16, FontWeight.w600, HomeLook.ink, lineHeight: 18);
  static final headline = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
  static final meta = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
  static final topic = roboto(12, FontWeight.w600, HomeLook.blue, lineHeight: 14.5);
  static final follow = roboto(14, FontWeight.w600, HomeLook.blue, lineHeight: 18);
  static final title = roboto(14, FontWeight.w600, HomeLook.ink, lineHeight: 18);
  static final body = roboto(14, FontWeight.w400, HomeLook.ink, lineHeight: 18);
  static final more = roboto(14, FontWeight.w400, HomeLook.soft, lineHeight: 18);
  static final hashtag = roboto(14, FontWeight.w600, HomeLook.blue, lineHeight: 18);
  static final count = roboto(12.5, FontWeight.w500, HomeLook.soft, lineHeight: 16);
  static final imageCaption = roboto(12, FontWeight.w600, AppColors.onImage, lineHeight: 16);
  static final morePhotos = roboto(14, FontWeight.w600, AppColors.onImage, lineHeight: 18);

  // Comments under a post.
  static final replyName = roboto(14, FontWeight.w600, HomeLook.ink, lineHeight: 18);
  static final replyMeta = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
  static final replyBody = roboto(14, FontWeight.w400, HomeLook.ink, lineHeight: 18);
  static final replyAction = roboto(12, FontWeight.w600, HomeLook.soft, lineHeight: 16);
  static final morePill = roboto(12, FontWeight.w600, HomeLook.soft, lineHeight: 16);
  static final replyHint = roboto(14, FontWeight.w400, HomeLook.soft, lineHeight: 18);
  static final replyInput = roboto(14, FontWeight.w400, HomeLook.ink, lineHeight: 18);

  // The promoted card.
  static final promoted = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
  static final promoTitle = roboto(14, FontWeight.w600, HomeLook.ink, lineHeight: 18);
  static final promoBody = roboto(14, FontWeight.w400, HomeLook.ink, lineHeight: 18);
  static final promoCta = roboto(14, FontWeight.w600, HomeLook.blue, lineHeight: 18);

  // A poll.
  static final pollQuestion = roboto(14, FontWeight.w600, HomeLook.ink, lineHeight: 18);
  static final pollHint = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
  static final pollOption = roboto(14, FontWeight.w600, HomeLook.blue, lineHeight: 18);
  static final pollPercent = roboto(14, FontWeight.w600, HomeLook.ink, lineHeight: 18);
  static final pollFooter = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
  static final pollLink = roboto(12, FontWeight.w600, HomeLook.blue, lineHeight: 14.5);

  // Section cards, notices and the foot of the list.
  static final sectionTitle = roboto(16, FontWeight.w600, HomeLook.ink, lineHeight: 20);
  static final sectionAction = roboto(14, FontWeight.w600, HomeLook.blue, lineHeight: 18);
  static final noticeTitle = roboto(16, FontWeight.w600, HomeLook.ink, lineHeight: 20);
  static final noticeBody = roboto(14, FontWeight.w400, HomeLook.soft, lineHeight: 18);
  static final footer = roboto(12, FontWeight.w400, HomeLook.soft, lineHeight: 14.5);
}

/// The two looks a reply thread has. The Home feed draws [home], LinkedIn's comment look (a grey bubble beside
/// the photo, Roboto); the discussion page draws [section], the owner's "Branching Nested Replies Section"
/// (`docs/designs/hires/forum-replies.png`: pale-blue bubbles, 12.5 dp Plex, the author's role in a chip, a
/// connector that runs a little past its last branch). One argument on `ReplyThread` / `ReplyTile` /
/// `ThreadBranch` switches a screen from one to the other.
enum ReplyLook { home, section }

/// Where a look draws its connector line and avatars (dp from the thread's own left edge).
class ReplyGeometry {
  const ReplyGeometry({
    required this.lineX,
    required this.avatarLeft,
    required this.indentStep,
    required this.lineColor,
    required this.arcRadius,
    required this.roundedEnd,
    required this.inset,
  });

  /// The centre of the vertical line (2 dp wide).
  final double lineX;

  /// Where an avatar at the top level starts; a branch's arm ends one dp short of it.
  final double avatarLeft;

  /// A reply answering a reply sits this much further in.
  final double indentStep;
  final Color lineColor;

  /// The fillet where an arm leaves the line.
  final double arcRadius;

  /// The last branch curves the line into its arm (Home), instead of the line running a little past it.
  final bool roundedEnd;

  /// How far the thread's left edge sits from the screen's.
  final double inset;

  static const section = ReplyGeometry(
    lineX: ReplyDesign.lineX,
    avatarLeft: ReplyDesign.avatarLeft,
    indentStep: ReplyDesign.indentStep,
    lineColor: ReplyDesign.line,
    arcRadius: 4,
    roundedEnd: false,
    inset: ReplyDesign.homeInset,
  );

  /// The line runs under the centre of the top-level photos; an answer steps in one photo's width.
  static const home = ReplyGeometry(
    lineX: HomeReplyDesign.avatarLeft + HomeReplyDesign.avatar / 2,
    avatarLeft: HomeReplyDesign.avatarLeft,
    indentStep: HomeReplyDesign.avatar + 8,
    lineColor: HomeLook.hairline,
    arcRadius: 8,
    roundedEnd: true,
    inset: 0,
  );

  static ReplyGeometry of(ReplyLook look) => look == ReplyLook.home ? home : section;
}

/// The Home feed's comment thread, in LinkedIn's look: a 32 dp photo, a grey bubble with the name, the time and
/// the words, and Like and Reply under it.
class HomeReplyDesign {
  HomeReplyDesign._();

  static const bubbleFill = HomeLook.bubble;
  static const bubbleRadius = 8.0;
  static const inputBorder = HomeLook.soft;

  static const avatar = 32.0;
  static const avatarLeft = HomeLook.pad;
  static const avatarTop = 0.0;
  static const bubbleGap = 8.0;

  /// The arm joins the line this far below a row's top: the photo's centre, the pill's, the box's.
  static const armTile = avatar / 2;
  static const armPill = pillHeight / 2;
  static const armBox = boxHeight / 2;

  static const gapTile = 8.0;
  static const gapPill = 8.0;
  static const gapBox = 8.0;

  static const pillHeight = 28.0;
  static const boxHeight = 40.0;
}

/// The reply section's own colours and type, measured from `docs/designs/hires/forum-replies.png` (a 4x export:
/// every figure below is px / 4). The discussion page's replies and the box under them all read from here, so a
/// reply looks the same in each place that draws the [ReplyLook.section] look.
class ReplyDesign {
  ReplyDesign._();

  // Colours.
  static const line = Color(0xFFDADDE4);
  static const bubbleFill = Color(0xFFF5F7FF);
  static const bubbleBorder = Color(0xFFEDF1F9);
  static const pillFill = Color(0xFFF0F3FF);
  static const inputBorder = Color(0xFFE6E9ED);
  static const roleFill = Color(0xFFDCE5F2);
  static const dotRing = Color(0xFFC0D1E6);
  static const accepted = Color(0xFF0C714D);
  static const acceptedFill = Color(0xFFECFDF5);
  static const acceptedBorder = Color(0xFFA7F3D0);

  // Geometry, in dp from the thread's own left edge (the crop's left edge: the line is 16 to 18).
  static const lineX = 17.0;
  static const lineWidth = 2.0;

  /// Where an avatar starts, and so where a branch's arm ends (one dp short of it).
  static const avatarLeft = 36.0;
  static const avatar = 24.0;

  /// A reply answering a reply sits this much further in.
  static const indentStep = 20.0;

  /// The farthest a thread steps in: past this a conversation is read flat.
  static const maxDepth = 3;

  /// Where the discussion page's thread begins from its screen's left edge.
  static const homeInset = 9.0;

  // Vertical metrics inside a reply tile, in dp from the bubble's outer top edge.
  static const bubbleRadius = 6.0;
  static const headerTop = 11.0;
  static const headerHeight = 28.0;
  static const nameBaseline = 18.5; // from the header's top
  static const metaSlot = 21.0;
  static const metaBaseline = 16.0; // from the slot's top
  static const bodyBaseline = 21.25; // from where the body slot begins
  static const actionsHeight = 36.9;
  static const bottomPad = 2.55;

  /// The branch arm joins the line this far below a bubble's top, a pill's top and a box's top.
  static const armTile = 11.0;
  static const armPill = 5.0;
  static const armBox = 10.0;

  // Gaps between the rows of a thread.
  static const gapTile = 10.0;
  static const gapPill = 10.0;
  static const gapBox = 9.0;

  // Type.
  static final name = AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16);
  static final role = AppText.plexSans(9, FontWeight.w700, AppColors.primary, lineHeight: 12);
  static final meta = AppText.plexSans(10, FontWeight.w500, AppColors.outline, lineHeight: 14);
  static final body = AppText.plexSans(12.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 20);
  static final action = AppText.plexSans(10.5, FontWeight.w500, AppColors.outline, lineHeight: 14);
  static final pill = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 16);
  static final hint = AppText.plexSans(12.5, FontWeight.w600, AppColors.outline, lineHeight: 16);
  static final input = AppText.plexSans(12.5, FontWeight.w500, AppColors.onSurface, lineHeight: 16);
}
