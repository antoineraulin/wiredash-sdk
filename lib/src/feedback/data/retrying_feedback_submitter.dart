import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wiredash/src/common/utils/error_report.dart';
import 'package:wiredash/src/feedback/data/feedback_item.dart';
import 'package:wiredash/src/feedback/data/feedback_submitter.dart';
import 'package:wiredash/src/feedback/data/pending_feedback_item.dart';
import 'package:wiredash/src/feedback/data/pending_feedback_item_storage.dart';
import 'package:wiredash/src/common/utils/uuid.dart';

/// A class that knows how to "eventually send" a [FeedbackItem] and an associated
/// screenshot file, retrying appropriately when sending fails.
class RetryingFeedbackSubmitter implements FeedbackSubmitter {
  RetryingFeedbackSubmitter(
    this.fs,
  );

  final FileSystem fs;

  // Ensures that we're not starting multiple "submitPendingFeedbackItems()" jobs
  // in parallel.
  bool _submitting = false;

  // Whether or not "submit()" / "submitPendingFeedbackItems()" was called while
  // submitting feedback was already in progress.
  bool _hasLeftoverItems = false;

  /// Persists [item] and [screenshot], then tries to send them.
  ///
  /// If sending fails, uses exponential backoff and tries again up to 7 times.
  @override
  Future<void> submit(FeedbackItem item, Uint8List? screenshot) async {
    // await _pendingFeedbackItemStorage.addPendingItem(item, screenshot);

    // Intentionally not "await"-ed. Since we've persisted the pending feedback
    // item, we can pretty safely assume it's going to be eventually sent, so the
    // future can complete after persisting the item.
    submitPendingFeedbackItems(item: item, screenshot: screenshot);
  }

  /// Checks if there are any pending feedback items stored in persistent storage.
  /// If there are, tries to send all of them.
  ///
  /// Can be called whenever there's a good time to try sending pending feedback
  /// items, such as in "initState()" of the Wiredash widget, or when network
  /// connection comes back online.
  Future<void> submitPendingFeedbackItems(
          {required FeedbackItem item, Uint8List? screenshot}) =>
      _submitPendingFeedbackItems(item: item, screenshot: screenshot);

  Future<void> _submitPendingFeedbackItems({
    bool submittingLeftovers = false,
    required FeedbackItem item,
    Uint8List? screenshot,
  }) async {
    if (_submitting) {
      _hasLeftoverItems = true;
      return;
    }

    _submitting = true;
    // final items = await _pendingFeedbackItemStorage.retrieveAllPendingItems();
    String? screenshotPath;

    if (screenshot != null) {
      final directory = (await getApplicationDocumentsDirectory()).path;
      final file = await LocalFileSystem()
          .file('$directory/${uuidV4.generate()}.png')
          .writeAsBytes(screenshot);
      screenshotPath = file.path;
    }

    final pendingItem = PendingFeedbackItem(
      id: uuidV4.generate(),
      feedbackItem: item,
      screenshotPath: screenshotPath,
    );

    await _submitWithRetry(pendingItem).catchError((_) {
      // ignore when a single item couldn't be submitted
      return null;
    });

    _submitting = false;

    if (_hasLeftoverItems) {
      // "submitPendingFeedbackItems()" was called at least once while we were
      // already submitting pending items. This means that there might be some
      // new items to submit.
      _hasLeftoverItems = false;

      if (submittingLeftovers) {
        // We're already submitting leftover items. Let's not get into infinite
        // recursion mode. That would not be fun.
        return;
      }

      // await _submitPendingFeedbackItems(submittingLeftovers: true);
    }
  }

  Future<void> _submitWithRetry<T>(PendingFeedbackItem item) async {
    var attempt = 0;

    // ignore: literal_only_boolean_expressions
    while (true) {
      attempt++;
      try {
        final screenshotPath = item.screenshotPath;
        final List<String> attachments = [];
        if (item.feedbackItem.attachmentPath != null) {
          attachments.add(item.feedbackItem.attachmentPath!);
        }
        if (screenshotPath != null) {
          attachments.add(screenshotPath);
        }
        final MailOptions mailOptions = MailOptions(
          body: """
${item.feedbackItem.message}



Détails techniques :
\tInformations sur l'appareil :
\t mode debug : ${item.feedbackItem.deviceInfo.appIsDebug}
\t app version : ${item.feedbackItem.deviceInfo.appVersion}
\t build number : ${item.feedbackItem.deviceInfo.buildNumber}
\t uuid : ${item.feedbackItem.deviceInfo.uuid}
\t langue : ${item.feedbackItem.deviceInfo.locale}
\t taille de l'écran : ${item.feedbackItem.deviceInfo.physicalSize}
\t pixel ratio : ${item.feedbackItem.deviceInfo.pixelRatio}
\t OS : ${item.feedbackItem.deviceInfo.platformOS}
\t version OS : ${item.feedbackItem.deviceInfo.platformOSBuild}
\t version dart Runtime : ${item.feedbackItem.deviceInfo.platformVersion}
\t version SDK : ${item.feedbackItem.sdkVersion}
\t échelle du texte : ${item.feedbackItem.deviceInfo.textScaleFactor}
\t modèle : ${item.feedbackItem.deviceInfo.model}
\t marque : ${item.feedbackItem.deviceInfo.brand}
          """,
          subject: 'myDevinci Support - ${item.feedbackItem.type}',
          recipients: ['mydevinci-support@devinci.fr'],
          attachments: attachments,
        );
        await FlutterMailer.send(mailOptions);
        // await _pendingFeedbackItemStorage.clearPendingItem(item.id);
        break;
      } catch (e, stack) {
        if (attempt >= _maxAttempts) {
          // Exit after max attempts
          reportWiredashError(
            e,
            stack,
            'Could not send feedback after $attempt retries',
          );
          break;
        }

        // Report error and retry with exponential backoff
        reportWiredashError(
          e,
          stack,
          'Could not send feedback to server after $attempt retries. Retrying...',
          debugOnly: true,
        );
        await Future.delayed(_exponentialBackoff(attempt));
      }
    }
  }
}

const _delayFactor = Duration(seconds: 1);
const _maxDelay = Duration(seconds: 30);
const _maxAttempts = 8;

Duration _exponentialBackoff(int attempt) {
  if (attempt <= 0) return Duration.zero;
  final exp = math.min(attempt, 31);
  final delay = _delayFactor * math.pow(2.0, exp);
  return delay < _maxDelay ? delay : _maxDelay;
}
