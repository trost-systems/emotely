import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The fewest characters a password the user chooses may have, and the only
/// rule there is (NIST SP 800-63B: length, no composition rules). The same
/// number as `minimum_password_length` in `supabase/config.toml`, which the
/// server enforces whenever a password is set; checking it here first only
/// saves the round trip.
const minimumPasswordLength = 10;

/// Whether [password] is long enough to choose.
bool longEnough(String password) =>
    password.characters.length >= minimumPasswordLength;

/// A password field, hidden as typed until its eye button shows it, never
/// corrected or suggested by the keyboard, pasteable from a password
/// manager. [choosing] says the user picks a new password here: the
/// keyboard offers to generate one, and the field says the one rule.
/// [fieldKey] keys the text field itself, for tests and the verification
/// CLI.
class const PasswordField({
  required final Key fieldKey,
  required final TextEditingController controller,
  required final String label,
  required final bool enabled,
  required final ValueChanged<String> onChanged,
  final bool choosing = false,
  final ValueChanged<String>? onSubmitted,
  super.key,
}) extends StatefulWidget {
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState() extends State<PasswordField> {
  var _shown = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: !_shown,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        if (widget.choosing)
          AutofillHints.newPassword
        else
          AutofillHints.password,
      ],
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.choosing
            ? strings.passwordRule(minimumPasswordLength)
            : null,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _shown ? strings.hidePassword : strings.showPassword,
          icon: Icon(_shown ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _shown = !_shown),
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
