import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../rfq_format.dart';
import '../rfq_models.dart';
import '../rfq_styles.dart';
import 'rfq_widgets.dart';

/// A taxonomy key's name, as the repository knows it, else the key in words.
typedef CategoryNamer = String Function(String key);

String serviceLabelOf(Requirement r, CategoryNamer nameOf) {
  final key = r.serviceKey;
  return key == null ? '' : nameOf(key);
}

/// The top of a requirement's page: what it is, its title and where it stands.
class RequirementHeader extends StatelessWidget {
  const RequirementHeader({super.key, required this.rfq, required this.nameOf, required this.now, this.showStatus = true});

  final Requirement rfq;
  final CategoryNamer nameOf;
  final DateTime now;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final deadline = rfq.live ? deadlineOf(rfq, now) : null;
    final replies = rfq.quoteCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker(rfq, serviceLabelOf(rfq, nameOf)), style: RfqText.kicker),
          const SizedBox(height: 6),
          Text(rfq.title, style: RfqText.pageTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showStatus) StatusPill(rfq.status),
              if (rfq.createdAt != null) Text(postedAgo(rfq.createdAt, now), style: RfqText.small),
              if (deadline != null)
                TonePill('${deadline.label} ${deadline.relative}', tone: urgencyTone(deadline.urgency), icon: LucideIcons.clock),
              Text(
                rfq.isEnquiry ? '${plural(replies, 'reply', 'replies')} so far' : '${plural(replies, 'quote')} so far',
                style: RfqText.small,
              ),
              if (rfq.visibility == RfqVisibility.targeted) const TonePill('Private invite', icon: LucideIcons.lock),
            ],
          ),
        ],
      ),
    );
  }
}

Tone urgencyTone(Urgency u) => switch (u) {
  Urgency.neutral => Tone.slate,
  Urgency.soon => Tone.amber,
  Urgency.urgent => Tone.red,
  Urgency.past => Tone.slate,
};

/// The staged RFQ's five steps, the current one marked.
class StageStepper extends StatelessWidget {
  const StageStepper({super.key, required this.rfq});

  final Requirement rfq;

  @override
  Widget build(BuildContext context) {
    final current = rfq.status == RfqStatus.awarded ? RfqStage.completed : (rfq.stage ?? RfqStage.prequalification);
    final index = RfqStage.values.indexOf(current);
    return Row(
      children: [
        for (final (i, s) in RfqStage.values.indexed) ...[
          if (i > 0)
            Expanded(
              child: Container(height: 2, color: i <= index ? AppColors.primary : AppColors.slate200),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= index ? AppColors.primary : Colors.white,
                  border: Border.all(color: i <= index ? AppColors.primary : AppColors.slate300),
                ),
                child: i < index
                    ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                    : Text('${i + 1}', style: RfqText.step.copyWith(color: i <= index ? Colors.white : AppColors.slate500)),
              ),
              const SizedBox(height: 4),
              Text(s.label, style: RfqText.small.copyWith(fontSize: 12, color: i == index ? AppColors.primary : AppColors.slate500)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Everything posted on a requirement: at a glance, what is needed, the line
/// items, the files and the supplier criteria. Owner and supplier read the same.
class RequirementBrief extends StatelessWidget {
  const RequirementBrief({
    super.key,
    required this.rfq,
    required this.nameOf,
    required this.onOpenFile,
    this.showContact = false,
  });

  final Requirement rfq;
  final CategoryNamer nameOf;

  /// A file of the buyer's was tapped: the phone's viewer opens it (requirement files are public uploads).
  final ValueChanged<RfqFile> onOpenFile;

  /// The contact snapshot, for the owner.
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    final services = [rfq.category, rfq.subcategory, rfq.service].whereType<String>().map(nameOf).join(' › ');
    final places = rfq.places;
    final region = rfq.serviceLocations.isNotEmpty
        ? ''
        : [rfq.state, if (rfq.country != null && rfq.country != 'India') rfq.country].whereType<String>().join(', ');
    final text = rfq.text;
    final c = rfq.criteria;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RfqCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('At a glance', style: RfqText.section),
              const SizedBox(height: 6),
              if (services.isNotEmpty) FactRow(icon: LucideIcons.layoutGrid, label: 'Service', value: services),
              if (rfq.facilityType != null) FactRow(icon: LucideIcons.building2, label: 'Facility type', value: rfq.facilityType!),
              if (places.isNotEmpty)
                FactRow(
                  icon: LucideIcons.mapPin,
                  label: region.isEmpty ? 'Locations' : 'Locations in $region',
                  value: rfq.serviceLocations.isNotEmpty
                      ? rfq.serviceLocations.map((p) => [p.label, if (p.hint.isNotEmpty) '(${p.hint})'].join(' ')).join('; ')
                      : places.join(', '),
                ),
              if (rfq.budget != null) FactRow(icon: LucideIcons.wallet, label: 'Budget', value: formatInr(rfq.budget!)),
              if (rfq.preQualEndDate != null)
                FactRow(icon: LucideIcons.hourglass, label: 'Pre-qual closes', value: fullDay(rfq.preQualEndDate!)),
              if (rfq.dueDate != null)
                FactRow(
                  icon: LucideIcons.calendar,
                  label: rfq.isEnquiry ? 'Replies close' : 'Quotes due',
                  value: fullDay(rfq.dueDate!),
                ),
              if (services.isEmpty && rfq.facilityType == null && places.isEmpty && rfq.budget == null && rfq.dueDate == null)
                Text('No details beyond the description.', style: RfqText.meta),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RfqCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rfq.isEnquiry ? 'What the buyer needs' : 'Scope of work', style: RfqText.section),
              const SizedBox(height: 8),
              Text(text == null ? 'No description given.' : plainText(text), style: RfqText.body),
            ],
          ),
        ),
        if (rfq.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          RfqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Line items', style: RfqText.section),
                const SizedBox(height: 6),
                for (final item in rfq.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: RfqText.bodyStrong),
                              if (item.specification != null) Text(item.specification!, style: RfqText.meta),
                            ],
                          ),
                        ),
                        Text('${item.quantity}${item.unit == null ? '' : ' ${item.unit}'}', style: RfqText.metaStrong),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (rfq.files.isNotEmpty) ...[
          const SizedBox(height: 12),
          RfqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rfq.files.length == 1 ? '1 file from the buyer' : '${rfq.files.length} files from the buyer', style: RfqText.section),
                const SizedBox(height: 6),
                for (final f in rfq.files)
                  InkWell(
                    key: ValueKey('brief-file-${f.id.isEmpty ? f.url : f.id}'),
                    onTap: () => onOpenFile(f),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          FileThumb(file: f),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.title, style: RfqText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(f.isImage ? 'Image' : 'Document', style: RfqText.small),
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.externalLink, size: 14, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (!c.isEmpty) ...[
          const SizedBox(height: 12),
          RfqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Supplier criteria', style: RfqText.section),
                const SizedBox(height: 2),
                Text('Suppliers must meet these to pre-qualify.', style: RfqText.small),
                const SizedBox(height: 6),
                if (c.minYearsInBusiness != null)
                  FactRow(icon: LucideIcons.history, label: 'Years in business', value: '${c.minYearsInBusiness}+ years'),
                if (c.minAnnualTurnover != null)
                  FactRow(icon: LucideIcons.trendingUp, label: 'Annual turnover', value: 'At least ${formatInr(c.minAnnualTurnover!)}'),
                if (c.minLast3YrTurnover != null)
                  FactRow(
                    icon: LucideIcons.chartColumn,
                    label: 'Last 3 years',
                    value: 'At least ${formatInr(c.minLast3YrTurnover!)}',
                  ),
                if (c.minEmployees != null) FactRow(icon: LucideIcons.users, label: 'Employees', value: sizeLabel(c.minEmployees!)),
                if (c.requiredPresence != null)
                  FactRow(icon: LucideIcons.globe, label: 'Presence', value: c.requiredPresence!.label),
                if (c.statutoryCompliance.isNotEmpty)
                  FactRow(
                    icon: LucideIcons.badgeCheck,
                    label: 'Compliance',
                    value: c.statutoryCompliance.map(complianceLabel).join(', '),
                  ),
              ],
            ),
          ),
        ],
        if (showContact && (rfq.contactName != null || rfq.contactPhone != null || rfq.companyName != null)) ...[
          const SizedBox(height: 12),
          RfqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact on this requirement', style: RfqText.section),
                const SizedBox(height: 2),
                Text('Suppliers see the company. The person and the numbers are shown only once they have bid, and only on a plan that includes them.', style: RfqText.small),
                const SizedBox(height: 6),
                if (rfq.companyName != null) FactRow(icon: LucideIcons.building, label: 'Company', value: rfq.companyName!),
                if (rfq.contactName != null) FactRow(icon: LucideIcons.user, label: 'Contact', value: rfq.contactName!),
                if (rfq.contactPhone != null) FactRow(icon: LucideIcons.phone, label: 'Phone', value: rfq.contactPhone!),
                if (rfq.contactEmail != null) FactRow(icon: LucideIcons.mail, label: 'Email', value: rfq.contactEmail!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Who posted a requirement, as the supplier's board shows it.
class BuyerLine extends StatelessWidget {
  const BuyerLine({super.key, required this.buyer, this.size = 32});

  final BuyerInfo buyer;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LogoTile(name: buyer.displayName, logoUrl: buyer.logoUrl, size: size),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(buyer.displayName, style: RfqText.metaStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (buyer.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
              Text(
                [if (buyer.verified) 'Verified buyer' else 'Buyer', if (buyer.gstVerified) 'GST on file'].join(' • '),
                style: RfqText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A file's thumbnail: the picture itself for a public image, else its glyph.
class FileThumb extends StatelessWidget {
  const FileThumb({super.key, required this.file, this.size = 40});

  final RfqFile file;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = file.isImage ? AppConfig.absoluteUrl(file.url) : null;
    final glyph = Icon(
      file.isImage ? LucideIcons.image : (file.mimeType == 'application/pdf' ? LucideIcons.fileText : LucideIcons.file),
      size: size * 0.45,
      color: AppColors.primary,
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: url == null
          ? glyph
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => glyph,
              placeholder: (_, _) => glyph,
            ),
    );
  }
}
