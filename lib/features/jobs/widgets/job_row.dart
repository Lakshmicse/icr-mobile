import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../job_models.dart';
import '../jobs_styles.dart';

/// One job on the board: the company's logo in its tile, the title, the
/// company, where and how, and the bookmark. 71 dp, as the design's rows.
class JobRow extends StatelessWidget {
  const JobRow({super.key, required this.job, required this.onTap, required this.onSave, this.caption});

  static const height = 71.0;

  final Job job;
  final VoidCallback onTap;
  final VoidCallback onSave;

  /// Replaces the third line ("Mumbai, India • On-site") when the row says
  /// something else about the job, such as where an application stands.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final where = caption ?? [?job.place, ?job.workMode?.label].join(' • ');
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          child: Stack(
            children: [
              Positioned(left: 0, top: 0, child: CompanyLogoTile(company: job.company)),
              Positioned(
                left: 62,
                right: 36,
                top: 1.5,
                child: Text(job.title, style: JobsText.rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Positioned(
                left: 62,
                right: 36,
                top: 21.5,
                child: Text(job.company.name, style: JobsText.rowCompany, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (where.isNotEmpty)
                Positioned(
                  left: caption == null ? 60 : 62,
                  right: 36,
                  top: 39.5,
                  child: Row(
                    children: [
                      if (caption == null) ...[
                        const Icon(LucideIcons.mapPin, size: 12, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(where, style: JobsText.rowMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              Positioned(
                right: 0.25,
                top: 2.75,
                child: Semantics(
                  button: true,
                  label: job.saved ? 'Remove bookmark' : 'Save job',
                  child: InkResponse(
                    onTap: onSave,
                    radius: 20,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        job.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                        // 12 × 15 dp of ink, as the design's bookmark.
                        size: 17.7,
                        color: job.saved ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The company's logo on its light tile; its initials when it has none.
///
/// A logo from the API is drawn at half its pixel size (a 2x image) and shrunk
/// only to fit the tile, so artwork cut for the tile (the seeded logos, the
/// design's) fills it as the design draws it.
class CompanyLogoTile extends StatelessWidget {
  const CompanyLogoTile({
    super.key,
    required this.company,
    this.width = 57,
    this.height = 61,
    this.radius = 6,
    this.color = AppColors.surfaceContainerLow,
    this.picture,
  });

  final JobCompany company;
  final double width;
  final double height;
  final double radius;
  final Color color;

  /// Instead of the company's logo.
  final FeedPicture? picture;

  @override
  Widget build(BuildContext context) {
    final logo = picture ?? company.logo;
    Widget child;
    if (logo?.asset != null) {
      child = Image.asset(logo!.asset!, scale: 2, filterQuality: FilterQuality.high);
    } else if (logo?.url != null) {
      child = Image(
        image: CachedNetworkImageProvider(logo!.url!, scale: 2),
        fit: BoxFit.scaleDown,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _initials(),
      );
    } else {
      child = _initials();
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _initials() =>
      Text(company.initials, style: JobsText.rowTitle.copyWith(fontSize: 16, color: AppColors.outline, height: 1));
}
