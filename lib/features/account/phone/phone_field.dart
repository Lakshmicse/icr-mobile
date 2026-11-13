import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../account_rules.dart';
import '../widgets/account_kit.dart';

/// The "country not in the list" choice: the typed text is the whole number.
const otherCountry = PhoneCountry('Other country', '', 0, 0);

/// How [AccountPhoneField] is drawn where it is not on an account screen: the
/// sign-up card wears the sign-in fields' colours, in light and in dark. With a
/// look the field draws only its row (the country and the number); the label
/// and the line under it are the caller's.
class PhoneFieldLook {
  const PhoneFieldLook({
    required this.fill,
    required this.border,
    required this.disabledBorder,
    required this.focus,
    required this.error,
    required this.input,
    required this.hint,
    required this.chevron,
    this.radius = 12,
    this.height = 59,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 14, 18),
  });

  final Color fill;
  final Color border;
  final Color disabledBorder;

  /// The focused number box's ring.
  final Color focus;
  final Color error;
  final TextStyle input;
  final TextStyle hint;

  /// The arrow beside the dialling code.
  final Color chevron;
  final double radius;

  /// The country button's height, to match the number box.
  final double height;
  final EdgeInsets padding;
}

/// A phone number as two parts (the website's `PhoneNumberField`): the country,
/// from ICR's markets with its code beside it, and the number after the code.
/// [onChanged] carries the whole number (`joinPhone`: "+971501234567"), or ''
/// when no digits are typed.
///
/// Pasting or typing a full number ("+44 7700 900123", "0044…") switches the
/// country by itself, so old habits keep working; "Other country" takes the
/// number with its code, for anyone outside the list.
class AccountPhoneField extends StatefulWidget {
  const AccountPhoneField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.helper,
    this.enabled = true,
    this.required = false,
    this.fieldKey,
    this.countryKey,
    this.suffix,
    this.pickerTitle = 'Country',
    this.look,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;

  /// The whole number as stored or last composed.
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;

  /// Under the field when there is no [error].
  final String? helper;
  final bool enabled;
  final bool required;

  /// The number box's key, and the country button's.
  final Key? fieldKey;
  final Key? countryKey;

  /// Drawn at the end of the number box (a "Verified" tick).
  final Widget? suffix;
  final String pickerTitle;

  /// Another screen's colours; the account look, with its label and helper, when null.
  final PhoneFieldLook? look;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AccountPhoneField> createState() => _AccountPhoneFieldState();
}

class _AccountPhoneFieldState extends State<AccountPhoneField> {
  late PhoneCountry? _country;
  late final TextEditingController _controller;
  String _sent = '';

  @override
  void initState() {
    super.initState();
    final start = splitPhone(widget.value);
    _country = start.country ?? (start.national.isNotEmpty ? null : phoneCountries.first);
    _controller = TextEditingController(text: start.national);
    _sent = widget.value;
  }

  @override
  void didUpdateWidget(AccountPhoneField old) {
    super.didUpdateWidget(old);
    // A new value from outside (the form was reset) is split again; what this
    // field just sent is left alone, so typing is never rewritten under the finger.
    if (widget.value != _sent) {
      _sent = widget.value;
      final next = splitPhone(widget.value);
      if (next.country != null || next.national.isNotEmpty) _country = next.country;
      _controller.text = next.national;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(PhoneCountry? country, String national) {
    final joined = joinPhone(country, national);
    _sent = joined;
    widget.onChanged(joined);
  }

  void _typed(String text) {
    final full = RegExp(r'^\s*(\+|00)').hasMatch(text);
    if (full) {
      final found = splitPhone(text);
      if (found.country != null) {
        setState(() => _country = found.country);
        _controller.value = TextEditingValue(
          text: found.national,
          selection: TextSelection.collapsed(offset: found.national.length),
        );
        _emit(found.country, found.national);
        return;
      }
      setState(() => _country = null);
    }
    _emit(full ? null : _country, text);
  }

  Future<void> _pickCountry() async {
    final picked = await showAccountPicker<PhoneCountry>(
      context,
      title: widget.pickerTitle,
      items: [...phoneCountries, otherCountry],
      labelOf: (c) => c.dial.isEmpty ? c.country : '${c.country}  +${c.dial}',
      searchable: true,
      selected: _country ?? otherCountry,
    );
    if (picked == null || !mounted) return;
    final next = picked.dial.isEmpty ? null : picked;
    setState(() => _country = next);
    _emit(next, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.fieldKey;
    final country = _country;
    final look = widget.look;
    final dial = country == null ? 'Other' : '+${country.dial}';
    final hasError = widget.error != null;
    final errorColor = look?.error ?? AppColors.error;
    final border = hasError ? errorColor : (look?.border ?? AppColors.slate300);
    final radius = BorderRadius.circular(look?.radius ?? 10);
    final fill = look?.fill ?? (widget.enabled ? Colors.white : AppColors.slate50);
    final input = look?.input ?? AccountText.input;
    OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Country code, $dial',
          excludeSemantics: true,
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: border),
            ),
            child: InkWell(
              key: widget.countryKey,
              onTap: widget.enabled ? _pickCountry : null,
              borderRadius: radius,
              child: SizedBox(
                height: look?.height ?? 46,
                width: (country == null ? 86 : 78) + (look == null ? 0 : 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dial, style: input),
                    const SizedBox(width: 2),
                    Icon(Icons.expand_more_rounded, size: 20, color: look?.chevron ?? AppColors.slate500),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: key,
            controller: _controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            textInputAction: widget.textInputAction,
            autofillHints: const [AutofillHints.telephoneNumber],
            maxLength: 30,
            onChanged: _typed,
            onSubmitted: widget.onSubmitted,
            style: input,
            cursorColor: look?.focus,
            decoration: InputDecoration(
              hintText: country == null ? '+44 7700 900123' : '98765 43210',
              hintStyle: look?.hint ?? AccountText.hint,
              counterText: '',
              isDense: look == null,
              filled: true,
              fillColor: fill,
              contentPadding: look?.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              suffixIcon: widget.suffix,
              suffixIconConstraints: look == null ? null : const BoxConstraints(),
              enabledBorder: outline(border),
              disabledBorder: outline(look?.disabledBorder ?? AppColors.slate200),
              focusedBorder: outline(hasError ? errorColor : (look?.focus ?? AppColors.primary), 2),
            ),
          ),
        ),
      ],
    );
    if (look != null) return row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.required ? '${widget.label} *' : widget.label, style: AccountText.label),
          const SizedBox(height: 6),
          row,
          if (widget.error != null || widget.helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                widget.error ?? widget.helper!,
                style: widget.error != null ? AccountText.error : AccountText.meta,
              ),
            ),
        ],
      ),
    );
  }
}
