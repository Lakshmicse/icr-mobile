import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../account_rules.dart';
import '../widgets/account_kit.dart';

/// The "country not in the list" choice: the typed text is the whole number.
const otherCountry = PhoneCountry('Other country', '', 0, 0);

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
    final dial = country == null ? 'Other' : '+${country.dial}';
    final border = widget.error != null ? AppColors.error : AppColors.slate300;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.required ? '${widget.label} *' : widget.label, style: AccountText.label),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Country code, $dial',
                excludeSemantics: true,
                child: Material(
                  color: widget.enabled ? Colors.white : AppColors.slate50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
                  child: InkWell(
                    key: widget.countryKey,
                    onTap: widget.enabled ? _pickCountry : null,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 46,
                      width: country == null ? 86 : 78,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dial, style: AccountText.input),
                          const SizedBox(width: 2),
                          const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.slate500),
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
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  maxLength: 30,
                  onChanged: _typed,
                  style: AccountText.input,
                  decoration: InputDecoration(
                    hintText: country == null ? '+44 7700 900123' : '98765 43210',
                    hintStyle: AccountText.hint,
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: widget.enabled ? Colors.white : AppColors.slate50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: widget.suffix,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.slate200)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.error != null ? AppColors.error : AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
