import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Stands in for the web view plugin, the one leaf `flutter test` cannot
/// host: every web view the code creates is recorded with what it loaded
/// and the channels it opened, so a test can answer as the page would.
/// Installing it restores the previous platform when the test ends.
class WebViewFake.install()
    extends WebViewPlatform
    with MockPlatformInterfaceMixin {
  this {
    final original = WebViewPlatform.instance;
    WebViewPlatform.instance = this;
    // An instance cannot be unset: with none before, the next test's
    // install replaces this one.
    if (original != null) {
      addTearDown(() => WebViewPlatform.instance = original);
    }
  }

  final views = <FakeWebView>[];

  /// The web view created last.
  FakeWebView get last => views.last;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final view = FakeWebView(params);
    views.add(view);
    return view;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

/// One web view: what it was told, and its page's side of the channels.
class FakeWebView(super.params) extends PlatformWebViewController {
  this : super.implementation();

  String? html;
  String? baseUrl;
  JavaScriptMode? javaScriptMode;
  Color? background;
  final channels = <String, JavaScriptChannelParams>{};

  /// What the page posts to the channel [name].
  void post(String name, String message) =>
      channels[name]!.onMessageReceived(JavaScriptMessage(message: message));

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    this.html = html;
    this.baseUrl = baseUrl;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      this.javaScriptMode = javaScriptMode;

  @override
  Future<void> setBackgroundColor(Color color) async => background = color;

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async => channels[javaScriptChannelParams.name] = javaScriptChannelParams;
}

class _FakeWebViewWidget(super.params) extends PlatformWebViewWidget {
  this : super.implementation();

  /// Found by tests as the web view on screen.
  static const key = Key('fake_web_view');

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: key);
}
