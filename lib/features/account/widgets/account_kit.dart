import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/detail_sheet.dart';

/// The account screens' parts, in the app's light language (the profile
/// menu's slate palette, Work Sans headings, IBM Plex Sans text, 12 dp cards
/// with a hairline border, the primary blue).

class AccountText {
  AccountText._();

  static final title = AppText.workSans(16, FontWeight.w700, AppColors.onSurface, lineHeight: 20);
  static final cardTitle = AppText.workSans(16, FontWeight.w700, AppColors.slate900, lineHeight: 22);
  static final name = AppText.workSans(21, FontWeight.w700, AppColors.slate900, lineHeight: 27);
  static final headline = AppText.workSans(14.5, FontWeight.w500, AppColors.slate700, lineHeight: 20);
  static final itemTitle = AppText.workSans(14.5, FontWeight.w600, AppColors.slate900, lineHeight: 20);
  static final body = AppText.plexSans(13.5, FontWeight.w400, AppColors.slate700, lineHeight: 20);
  static final meta = AppText.plexSans(12.5, FontWeight.w400, AppColors.slate500, lineHeight: 18);
  static final label = AppText.plexSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18);
  static final input = AppText.plexSans(15, FontWeight.w400, AppColors.onSurface, lineHeight: 20);
  static final hint = AppText.plexSans(15, FontWeight.w400, AppColors.slate400, lineHeight: 20);
  static final link = AppText.workSans(13.5, FontWeight.w600, AppColors.primary, lineHeight: 18);
  static final error = AppText.plexSans(12.5, FontWeight.w500, AppColors.error, lineHeight: 17);
  static final button = AppText.workSans(14, FontWeight.w700, Colors.white, lineHeight: 18);
  static final chip = AppText.plexSans(12.5, FontWeight.w500, AppColors.slate700, lineHeight: 16);
}

/// The bar at the top of an account screen: Back, the title, and actions.
class AccountBar extends StatelessWidget implements PreferredSizeWidget {
  const AccountBar({super.key, required this.title, this.onBack, this.actions = const []});

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56 + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Back',
            onPressed: onBack ?? () => Navigator.maybePop(context),
            icon: const Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title, style: AccountText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...actions,
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// A white card with a hairline border: a section of a profile or a list.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: Text(title!, style: AccountText.cardTitle)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// A round glyph button in a card's title row (the pencil, the plus).
class CardIconButton extends StatelessWidget {
  const CardIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 20, color: onPressed == null ? AppColors.slate300 : AppColors.slate600),
  );
}

/// A picture from the API (`/uploads/...`), a full URL, or a bundled sample
/// (`asset:...`), with [fallback] while it loads or when it fails.
class AccountImage extends StatelessWidget {
  const AccountImage({super.key, required this.source, required this.fallback, this.fit = BoxFit.cover});

  final String? source;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final s = source;
    if (s == null || s.isEmpty) return fallback;
    if (s.startsWith('asset:')) return Image.asset(s.substring(6), fit: fit);
    final url = AppConfig.absoluteUrl(s);
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// A round photo with the person's initials behind it.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.url, required this.initials, this.size = 48, this.ring = false});

  final String? url;
  final String initials;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFDCE6F2),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppText.workSans(size * 0.36, FontWeight.w600, AppColors.primary),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: ring ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))] : null,
      ),
      child: ClipOval(child: AccountImage(source: url, fallback: fallback)),
    );
  }
}

/// A company's logo in a rounded square, its first letter behind it.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.url, required this.name, this.size = 40});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.slate100,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: AppText.workSans(size * 0.42, FontWeight.w700, AppColors.slate500),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: AccountImage(source: url, fallback: fallback, fit: BoxFit.contain),
      ),
    );
  }
}

/// The ready-made covers (`PROFILE_COVERS`): the site's picture over its band.
const profileCovers = <String, (String, List<Color>)>{
  'blueprint': ('Blueprint', [Color(0xFF0F2A4A), Color(0xFF13426D)]),
  'skyline': ('Skyline at dusk', [Color(0xFF1B2D57), Color(0xFF7A4C7E), Color(0xFFF2A65A)]),
  'campus': ('Campus', [Color(0xFFBFE0F5), Color(0xFFEAF4FA)]),
  'brand': ('ICR blue', [Color(0xFF13426D), Color(0xFF32629E), Color(0xFF2EB3FC)]),
  'teal': ('Teal', [Color(0xFF2FA8BE), Color(0xFF3B2A78)]),
  'waves': ('Waves', [Color(0xFFF08A3C), Color(0xFF8E2DE2)]),
  'marble': ('Marble', [Color(0xFFA9C6F5), Color(0xFF5B6FE0)]),
  'ink': ('Ink', [Color(0xFF0B4F6C), Color(0xFFE2582B)]),
};

const _svgCovers = {'blueprint', 'skyline', 'campus', 'brand'};

/// A profile's banner: an uploaded picture, a ready-made cover (the website's
/// file over its colour band), or the default band.
class CoverBand extends StatelessWidget {
  const CoverBand({super.key, required this.cover});

  final String? cover;

  /// Whether a ready-made cover's picture is fetched from the website over its
  /// colour band. Tests switch it off: they have no network.
  static bool loadArt = true;

  static const _defaultBand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF13426D), Color(0xFF1D63A3), Color(0xFF5B8CC4)],
  );

  @override
  Widget build(BuildContext context) {
    final c = cover;
    final preset = c == null ? null : profileCovers[c];
    if (preset != null) {
      final band = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: preset.$2.length == 1 ? [preset.$2.first, preset.$2.first] : preset.$2,
          ),
        ),
      );
      final src = '${AppConfig.siteUrl}/images/profile-covers/$c.${_svgCovers.contains(c) ? 'svg' : 'jpg'}';
      if (!loadArt) return band;
      return Stack(
        fit: StackFit.expand,
        children: [
          band,
          if (_svgCovers.contains(c))
            SvgPicture.network(
              src,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => const SizedBox.shrink(),
              // The colour band underneath stands in when the picture cannot be had.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else
            CachedNetworkImage(
              imageUrl: src,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
        ],
      );
    }
    const band = DecoratedBox(decoration: BoxDecoration(gradient: _defaultBand));
    return AccountImage(source: c, fallback: band);
  }
}

/// A small rounded label ("Verified", "Company Admin").
class AccountChip extends StatelessWidget {
  const AccountChip({super.key, required this.label, this.color = AppColors.slate100, this.ink = AppColors.slate700, this.icon});

  final String label;
  final Color color;
  final Color ink;
  final IconData? icon;

  static const green = (Color(0xFFECFDF5), Color(0xFF047857));
  static const amber = (Color(0xFFFFF7E6), Color(0xFF92400E));
  static const blue = (Color(0xFFE7EEFF), AppColors.primary);
  static const red = (Color(0xFFFFE4E6), Color(0xFFBE123C));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: ink), const SizedBox(width: 4)],
          Text(label, style: AccountText.chip.copyWith(color: ink, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

/// The blue button, full width or not, with a spinner while busy.
class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.outlined = false,
    this.danger = false,
    this.expand = true,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool outlined;
  final bool danger;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.rose600 : AppColors.primary;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? color : Colors.white),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: outlined ? color : Colors.white),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AccountText.button.copyWith(color: outlined ? color : Colors.white),
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final button = outlined
        ? OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              shape: shape,
              side: BorderSide(color: onPressed == null ? AppColors.slate300 : color),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: Size(0, height),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withValues(alpha: busy ? 0.75 : 0.4),
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: Size(0, height),
            ),
            child: child,
          );
    return expand ? SizedBox(width: double.infinity, height: height, child: button) : SizedBox(height: height, child: button);
  }
}

// --- states --------------------------------------------------------------------------------------------------

class AccountLoading extends StatelessWidget {
  const AccountLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2.4)));
}

/// A read that failed: the API's sentence and "Try again".
class AccountError extends StatelessWidget {
  const AccountError({super.key, required this.message, required this.onRetry, this.title = 'Something went wrong'});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.cloud_off, size: 40, color: AppColors.slate400),
            const SizedBox(height: 12),
            Text(title, style: AccountText.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AccountText.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AccountButton(key: const Key('account.retry'), label: 'Try again', onPressed: onRetry, expand: false),
          ],
        ),
      ),
    );
  }
}

/// A section with nothing in it yet: a grey sentence and, when it can be
/// filled, an outlined "+ Add …".
class AccountEmpty extends StatelessWidget {
  const AccountEmpty({super.key, required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: AccountText.meta.copyWith(fontSize: 14)),
        if (action != null) ...[
          const SizedBox(height: 10),
          AccountButton(label: action!, onPressed: onAction, outlined: true, expand: false, icon: Icons.add_rounded, height: 38),
        ],
      ],
    );
  }
}

// --- forms ---------------------------------------------------------------------------------------------------

OutlineInputBorder _border(Color color, [double width = 1]) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color, width: width));

/// A label over a rounded field, its problem or helper under it.
class AccountField extends StatelessWidget {
  const AccountField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint,
    this.helper,
    this.error,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.enabled = true,
    this.onChanged,
    this.suffix,
    this.counter = false,
    this.required = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hint;
  final String? helper;
  final String? error;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  /// "n / 2,000" under a long field.
  final bool counter;
  final bool required;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(required ? '$label *' : label, style: AccountText.label),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            maxLength: maxLength,
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
            textCapitalization: textCapitalization,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            style: AccountText.input,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AccountText.hint,
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: enabled ? Colors.white : AppColors.slate50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: suffix,
              enabledBorder: _border(error != null ? AppColors.error : AppColors.slate300),
              disabledBorder: _border(AppColors.slate200),
              focusedBorder: _border(error != null ? AppColors.error : AppColors.primary, 2),
            ),
          ),
          if (error != null || helper != null || (counter && maxLength != null))
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(error ?? helper ?? '', style: error != null ? AccountText.error : AccountText.meta),
                  ),
                  if (counter && maxLength != null)
                    ListenableBuilder(
                      listenable: controller,
                      builder: (_, _) => Text(
                        '${controller.text.length} / ${_grouped(maxLength!)}',
                        style: AccountText.meta,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _grouped(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

/// A field that opens a list: the choice (or a hint) and a chevron.
class AccountSelectField extends StatelessWidget {
  const AccountSelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
    this.error,
    this.helper,
    this.onClear,
    this.required = false,
  });

  final String label;
  final String hint;
  final String? value;
  final VoidCallback? onTap;
  final String? error;
  final String? helper;
  final VoidCallback? onClear;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(required ? '$label *' : label, style: AccountText.label),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            label: '$label, ${value ?? hint}',
            excludeSemantics: true,
            child: Material(
              color: onTap == null ? AppColors.slate50 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: error != null ? AppColors.error : AppColors.slate300),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value ?? hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: value == null ? AccountText.hint : AccountText.input,
                        ),
                      ),
                      if (value != null && onClear != null)
                        IconButton(
                          tooltip: 'Clear $label',
                          onPressed: onClear,
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(Icons.expand_more_rounded, color: AppColors.slate500),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (error != null || helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(error ?? helper!, style: error != null ? AccountText.error : AccountText.meta),
            ),
        ],
      ),
    );
  }
}

/// A list to choose one from, in a sheet; a search box when it is long.
Future<T?> showAccountPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  String Function(T)? subtitleOf,
  bool searchable = false,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => _Picker<T>(
      title: title,
      items: items,
      labelOf: labelOf,
      subtitleOf: subtitleOf,
      searchable: searchable,
      selected: selected,
    ),
  );
}

class _Picker<T> extends StatefulWidget {
  const _Picker({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.subtitleOf,
    required this.searchable,
    required this.selected,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final bool searchable;
  final T? selected;

  @override
  State<_Picker<T>> createState() => _PickerState<T>();
}

class _PickerState<T> extends State<_Picker<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items
              .where(
                (i) =>
                    widget.labelOf(i).toLowerCase().contains(q) ||
                    (widget.subtitleOf?.call(i) ?? '').toLowerCase().contains(q),
              )
              .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * (widget.searchable || widget.items.length > 8 ? 0.75 : 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(rule: false, height: 24, top: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(widget.title, style: AccountText.cardTitle),
          ),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('accountPicker.search'),
                onChanged: (v) => setState(() => _q = v),
                style: AccountText.input,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AccountText.hint,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate400),
                  enabledBorder: _border(AppColors.slate300),
                  focusedBorder: _border(AppColors.primary, 2),
                ),
              ),
            ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text('Nothing matches “$_q”.', style: AccountText.meta))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      final sub = widget.subtitleOf?.call(item);
                      return ListTile(
                        title: Text(widget.labelOf(item), style: AccountText.input),
                        subtitle: sub == null || sub.isEmpty ? null : Text(sub, style: AccountText.meta),
                        trailing: item == widget.selected
                            ? const Icon(Icons.check_rounded, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A tick with words beside it.
class AccountCheck extends StatelessWidget {
  const AccountCheck({super.key, required this.value, required this.onChanged, required this.label, this.error});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: value,
                  onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(label, style: AccountText.body),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(error!, style: AccountText.error),
            ),
        ],
      ),
    );
  }
}

/// Asks before something that cannot be taken back. True when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: AccountText.cardTitle),
      content: Text(message, style: AccountText.body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          key: const Key('confirm.ok'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: danger ? AppColors.rose600 : AppColors.primary),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// --- the edit sheet ------------------------------------------------------------------------------------------

/// Opens an edit sheet the way the website opens a `SectionDialog`: a title,
/// the form, and Cancel / Save at the foot (Delete at the left when given).
/// Leaving with unsaved changes asks first ("Discard your changes?").
Future<T?> showEditSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return Navigator.of(context).push<T>(
    BlurredSheetRoute<T>(
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: builder(context),
      ),
    ),
  );
}

/// The frame inside an edit sheet.
class EditSheet extends StatelessWidget {
  const EditSheet({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.subtitle,
    this.saving = false,
    this.error,
    this.dirty = false,
    this.saveLabel = 'Save',
    this.onDelete,
    this.deleteLabel = 'Delete',
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;

  /// What the API refused, shown above the buttons; the form keeps what was typed.
  final String? error;

  /// Something was changed: leaving asks first.
  final bool dirty;
  final String saveLabel;
  final VoidCallback? onDelete;
  final String deleteLabel;

  /// The main button is the red one (deleting an account).
  final bool danger;

  Future<void> _leave(BuildContext context) async {
    if (saving) return;
    if (dirty) {
      final discard = await confirmAction(
        context,
        title: 'Discard your changes?',
        message: 'What you changed here has not been saved.',
        confirm: 'Discard',
      );
      if (!discard || !context.mounted) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Material(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(height: 24, top: 10, rule: false),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppText.workSans(18, FontWeight.w700, AppColors.slate900, lineHeight: 24)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(subtitle!, style: AccountText.meta),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => _leave(context),
                        icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.slate100),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ),
                if (error != null)
                  Container(
                    key: const Key('sheet.error'),
                    margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Text(error!, style: AccountText.error.copyWith(fontSize: 14)),
                  ),
                const Divider(height: 1, thickness: 1, color: AppColors.slate100),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                    child: Row(
                      children: [
                        if (onDelete != null)
                          TextButton(
                            key: const Key('sheet.delete'),
                            onPressed: saving ? null : onDelete,
                            style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
                            child: Text(deleteLabel),
                          ),
                        const Spacer(),
                        TextButton(
                          key: const Key('sheet.cancel'),
                          onPressed: saving ? null : () => _leave(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        AccountButton(
                          key: const Key('sheet.save'),
                          label: saving ? 'Saving…' : saveLabel,
                          busy: saving,
                          danger: danger,
                          onPressed: onSave,
                          expand: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
