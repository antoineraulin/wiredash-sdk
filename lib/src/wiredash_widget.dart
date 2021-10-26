import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiredash/src/capture/capture.dart';
import 'package:wiredash/src/common/device_info/device_info_generator.dart';
import 'package:wiredash/src/common/options/wiredash_options.dart';
import 'package:wiredash/src/common/options/wiredash_options_data.dart';
import 'package:wiredash/src/common/theme/wiredash_theme.dart';
import 'package:wiredash/src/common/theme/wiredash_theme_data.dart';
import 'package:wiredash/src/common/translation/wiredash_localizations.dart';
import 'package:wiredash/src/common/utils/build_info.dart';
import 'package:wiredash/src/common/widgets/wiredash_scaffold.dart';
import 'package:wiredash/src/feedback/data/pending_feedback_item_storage.dart';
import 'package:wiredash/src/feedback/data/retrying_feedback_submitter.dart';
import 'package:wiredash/src/feedback/feedback_model.dart';
import 'package:wiredash/src/wiredash_controller.dart';
import 'package:wiredash/src/wiredash_provider.dart';

/// Capture in-app user feedback, wishes, ratings and much more
///
/// 1. Setup
/// Wrap you Application in [Wiredash] and pass in the apps [Navigator]
///
/// ```dart
/// class MyApp extends StatefulWidget {
///   @override
///   _MyAppState createState() => _MyAppState();
/// }
///
/// class _MyAppState extends State<MyApp> {
///   /// Share the app [Navigator] with Wiredash
///   final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
///
///   @override
///   Widget build(BuildContext context) {
///     return Wiredash(
///       theme: WiredashThemeData(),
///       navigatorKey: _navigatorKey,
///       child: MaterialApp(
///         navigatorKey: _navigatorKey,
///         title: 'Wiredash Demo',
///         home: DemoHomePage(),
///       ),
///     );
///   }
/// }
/// ```
///
/// 2. Start Wiredash
///
/// ```dart
/// Wiredash.of(context).show();
/// ```
class Wiredash extends StatefulWidget {
  /// Creates a new [Wiredash] Widget which allows users to send feedback,
  /// wishes, ratings and much more
  const Wiredash({
    Key? key,
    required this.navigatorKey,
    this.options,
    this.theme,
    required this.child,
  }) : super(key: key);

  /// Reference to the app [Navigator] to show the Wiredash bottom sheet
  final GlobalKey<NavigatorState> navigatorKey;

  /// Customize Wiredash's behaviour and language
  final WiredashOptionsData? options;

  /// Default visual properties, like colors and fonts for the Wiredash bottom
  /// sheet and the screenshot capture UI.
  ///
  /// Dark and light themes are supported, try it!
  ///
  /// ```dart
  /// return Wiredash(
  ///   theme: WiredashThemeData(brightness: Brightness.dark),
  ///   projectId: "...",
  ///   secret: "...",
  ///   child: MyApp(),
  /// );
  /// ```
  final WiredashThemeData? theme;

  /// Your application
  final Widget child;

  @override
  WiredashState createState() => WiredashState();

  /// The [WiredashController] from the closest [Wiredash] instance that
  /// encloses the given context.
  ///
  /// Use it to start Wiredash
  ///
  /// ```dart
  /// Wiredash.of(context).show();
  /// ```
  static WiredashController? of(BuildContext context) {
    final state = context.findAncestorStateOfType<WiredashState>();
    if (state == null) return null;
    return WiredashController(state);
  }
}

class WiredashState extends State<Wiredash> {
  late GlobalKey<CaptureState> captureKey;
  late GlobalKey<NavigatorState> navigatorKey;

  late FeedbackModel _feedbackModel;

  late WiredashOptionsData _options;
  late WiredashThemeData _theme;

  @override
  void initState() {
    super.initState();

    captureKey = GlobalKey<CaptureState>();
    navigatorKey = widget.navigatorKey;

    _updateDependencies();

    const fileSystem = LocalFileSystem();
    final storage = PendingFeedbackItemStorage(
      fileSystem,
      SharedPreferences.getInstance,
      () async => (await getApplicationDocumentsDirectory()).path,
    );

    // final feedbackSubmitter = RetryingFeedbackSubmitter(fileSystem, storage)
    // ..submitPendingFeedbackItems();

    _feedbackModel = FeedbackModel(
      captureKey,
      navigatorKey,
      DeviceInfoGenerator(
        getDeviceInfo(),
        WidgetsBinding.instance!.window,
      ),
    );
  }

  @override
  void dispose() {
    _feedbackModel.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Wiredash oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDependencies();
  }

  void _updateDependencies() {
    setState(() {
      _options = widget.options ?? WiredashOptionsData();
      _theme = widget.theme ?? WiredashThemeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WiredashProvider(
      feedbackModel: _feedbackModel,
      child: WiredashOptions(
        data: _options,
        child: WiredashLocalizations(
          child: WiredashTheme(
            data: _theme,
            child: WiredashScaffold(
              child: Capture(
                key: captureKey,
                initialColor: _theme.firstPenColor,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void show({String? attachmentPath}) {
    _feedbackModel.show(attachmentPath: attachmentPath);
  }
}
