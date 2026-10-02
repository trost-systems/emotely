/// The server entrypoint: runs once per route at build time (static mode)
/// and writes plain HTML. Nothing here runs in the browser.
library;

import 'package:emotely_web/main.server.options.dart';
import 'package:emotely_web/site_document.dart';
import 'package:jaspr/server.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(siteDocument());
}
