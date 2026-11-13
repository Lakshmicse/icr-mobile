import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../account/account_rules.dart';
import '../account/phone/phone_field.dart';
import 'auth_palette.dart';
import 'auth_widgets.dart';
import 'signup_widgets.dart';

/// The mobile number sign-up asks for on "About you", as the website's
/// `PhoneVerifyInline` with `acceptUntextable` does (the API refuses a sign-up
/// without a number since 29 Oct 2026):
///
/// * a **+91** number is confirmed before the account is made: **Send code**
///   (`POST /auth/phone/send-otp`), the six texted digits, **Verify**
///   (`POST /auth/phone/verify-otp`). `POST /auth/register` then spends that proof;
/// * **any other country's** number is accepted after its format check, with no
///   code: the gateway reaches only Indian numbers, and the emailed code is what
///   proves the account.
///
/// Editing a confirmed number drops it back to unconfirmed.
class SignupPhoneController extends ChangeNotifier {
  SignupPhoneController({required this.sendCode, required this.verifyCode});

  /// Sends the code; answers with it when the API showed it instead (test mode).
  final Future<String?> Function(String phone) sendCode;
  final Future<void> Function(String phone, String code) verifyCode;

  final code = TextEditingController();

  /// The whole number as the field composed it ("+919876543210"), or ''.
  String phone = '';
  bool verified = false;

  /// The code has been sent and is being asked for.
  bool codeStep = false;
  bool busy = false;
  String? devCode;

  /// A refused send (under the number), or a refused code (under the code).
  String? sendError;
  String? codeError;

  /// What the API is sent: E.164 when the app can read the number.
  String get number => normalizePhone(phone) ?? phone.trim();

  /// A whole Indian number: the one kind a code can reach.
  bool get textable => phone.trim().isNotEmpty && canTextPhone(phone);

  /// Why the typed number cannot be read, or null (also for none typed).
  String? get unreadable => phone.trim().isEmpty ? null : phoneError(phone);

  /// The six digits are typed and waiting to be checked.
  bool get codeTyped => codeStep && !verified && RegExp(r'^\d{6}$').hasMatch(code.text.trim());

  void setPhone(String value) {
    if (value == phone) return;
    phone = value;
    verified = false;
    codeStep = false;
    devCode = null;
    sendError = null;
    codeError = null;
    code.clear();
    notifyListeners();
  }

  void useCode(String value) {
    code.text = value;
    codeError = null;
    notifyListeners();
  }

  void codeChanged() {
    codeError = null;
    notifyListeners();
  }

  Future<bool> send() async {
    if (busy || !textable) return false;
    busy = true;
    sendError = null;
    codeError = null;
    notifyListeners();
    try {
      devCode = await sendCode(number);
      codeStep = true;
      code.clear();
      return true;
    } catch (e) {
      final message = ApiError.from(e).message;
      // A new code refused while one is being asked for belongs under the code.
      if (codeStep) {
        codeError = message;
      } else {
        sendError = message;
      }
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Checks the typed code. False, with the reason under the code, when refused.
  Future<bool> verify() async {
    if (busy) return false;
    final typed = code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(typed)) {
      codeError = 'Enter the 6-digit code from the text';
      notifyListeners();
      return false;
    }
    busy = true;
    codeError = null;
    notifyListeners();
    try {
      await verifyCode(number, typed);
      verified = true;
      codeStep = false;
      devCode = null;
      return true;
    } catch (e) {
      codeError = ApiError.from(e).message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }
}

/// "Mobile number" on the sign-up card: the app's phone field
/// ([AccountPhoneField]: country picker, the number, a pasted full number
/// switching the country) in the card's colours, then what a +91 number needs.
class SignupPhoneField extends StatelessWidget {
  const SignupPhoneField({
    super.key,
    required this.controller,
    this.error,
    this.enabled = true,
    this.focusNode,
    this.onSubmitted,
  });

  final SignupPhoneController controller;

  /// The screen's own refusal ("Enter your mobile number"), shown first.
  final String? error;
  final bool enabled;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

  static const _verified = Color(0xFF059669);
  static const _verifiedDark = Color(0xFF34D399);

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final live = enabled && !c.busy;
        final problem = error ?? c.unreadable ?? c.sendError;
        final tick = p.isDark ? _verifiedDark : _verified;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 34),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Mobile number', style: AuthType.label(p)),
              ),
            ),
            const SizedBox(height: 2.5),
            AccountPhoneField(
              fieldKey: const Key('signup.phone'),
              countryKey: const Key('signup.phoneCountry'),
              label: 'Mobile number',
              value: c.phone,
              enabled: live,
              error: problem,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => c.textable && !c.verified && !c.codeStep ? c.send() : onSubmitted?.call(),
              look: PhoneFieldLook(
                fill: p.fieldFill,
                border: p.fieldBorder,
                disabledBorder: p.fieldBorder.withValues(alpha: 0.5),
                focus: p.accent,
                error: p.error,
                input: AuthType.input(p),
                hint: AuthType.hint(p),
                chevron: p.fieldIcon,
              ),
              suffix: c.verified
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        Icons.check_circle_rounded,
                        key: const Key('signup.phoneVerified'),
                        color: tick,
                        size: 22,
                      ),
                    )
                  : null,
              onChanged: c.setPhone,
            ),
            AuthHelperLine(error: problem, helper: c.verified ? 'This number is verified.' : null),
            if (c.textable && !c.verified && !c.codeStep) ...[
              const SizedBox(height: 10),
              _SendCodeButton(busy: c.busy, onPressed: enabled ? c.send : null),
            ],
            if (c.codeStep && !c.verified) ...[
              const SizedBox(height: 8),
              AuthField(
                fieldKey: const Key('signup.phoneCode'),
                label: 'Code from your text',
                controller: c.code,
                icon: Icons.sms_outlined,
                hint: '6-digit code',
                enabled: live,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                letterSpacing: 4,
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton(
                    key: const Key('signup.phoneVerify'),
                    onPressed: live ? c.verify : null,
                    style: TextButton.styleFrom(foregroundColor: p.accent, minimumSize: const Size(64, 44)),
                    child: Text(c.busy ? 'Checking…' : 'Verify', style: AuthType.link(p).copyWith(fontSize: 15.5)),
                  ),
                ),
                onChanged: (_) => c.codeChanged(),
                onFieldSubmitted: (_) => c.verify(),
              ),
              AuthHelperLine(error: c.codeError, helper: 'We texted a code to ${formatPhone(c.phone)}.'),
              DevCodeNote(name: 'phone', code: c.devCode, onUse: c.useCode),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('No text? ', style: AuthType.small(p)),
                    AuthLink(
                      key: const Key('signup.phoneResend'),
                      label: 'send a new one',
                      style: AuthType.link(p).copyWith(fontSize: 14, color: live ? p.accent : p.muted),
                      onTap: live ? c.send : () {},
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "Send code" under a whole +91 number: never an idle button beside a
/// half-typed one, as on the website.
class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        key: const Key('signup.phoneSend'),
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          side: BorderSide(color: p.accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          busy ? 'Sending your code…' : 'Send code',
          style: AuthType.button.copyWith(color: p.accent, fontSize: 16),
        ),
      ),
    );
  }
}
