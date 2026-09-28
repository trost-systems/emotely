import 'package:feature_account/src/l10n/account_localizations.dart';
import 'package:feature_account/src/profile/bloc/profile_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile_repository/profile_repository.dart';

/// The name, editable in place. It saves when it is left — the done key
/// leaves it too — so there is no button to find, and whatever the bloc
/// says next, it shows the name that stands: the new one once saved, the
/// last one when the new one was refused or did not save.
class const NameField({
  required final String? saved,
  required final Widget? helper,
  required final String hint,
  required final Key fieldKey,
  super.key,
}) extends StatefulWidget {
  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState() extends State<NameField> {
  late final _controller = TextEditingController(text: widget.saved);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_left);
  }

  /// Hands the name over once the field loses focus, and only while this
  /// screen is still there to hear the answer.
  void _left() {
    if (!_focus.hasFocus && mounted) {
      context.read<ProfileBloc>().add(
        ProfileEvent.nameSubmitted(_controller.text),
      );
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<ProfileBloc, ProfileState>(
    listenWhen: (previous, next) => previous.noticeCount != next.noticeCount,
    listener: (_, state) =>
        setState(() => _controller.text = state.profile?.displayName ?? ''),
    child: TextField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: _focus,
      // A tap anywhere else leaves the field, and so saves; on a phone the
      // platform would otherwise keep it focused, keyboard up.
      onTapOutside: (_) => _focus.unfocus(),
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.givenName],
      inputFormatters: const [_CodePointLimit()],
      // The counter is in code points, as the limit is; redraw it per key.
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: AccountLocalizations.of(context).profileNameLabel,
        // The label stays up so the empty field shows its question.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: widget.hint,
        helper: widget.helper,
        counterText: '${_controller.text.runes.length}/$maxDisplayNameLength',
      ),
    ),
  );
}

/// Stops the field at [maxDisplayNameLength] code points, the unit the
/// table counts. The platform's own limit counts graphemes, which would
/// let a name through that the table then refuses. A paste that runs over
/// keeps what fits.
class const _CodePointLimit() extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= maxDisplayNameLength) {
      return newValue;
    }
    final text = String.fromCharCodes(
      newValue.text.runes.take(maxDisplayNameLength),
    );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
