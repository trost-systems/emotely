import 'package:emotely_web/components/confirm_waitlist.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de/confirm`: the German frame of the waitlist confirmation island.
class const ConfirmDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) =>
      const main_(classes: 'page prose', [ConfirmWaitlist(lang: 'de')]);
}
