import 'dart:collection';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiredash/src/_wiredash_internal.dart';
import 'package:wiredash/src/core/wiredash_widget.dart';

// Prio #1
// TODO delete events when storage exceeds 1MB
// TODO how to handle when two instances of the app, with two different wiredash configurations are open. Where would events be sent to?
// TODO save events to local storage
// TODO send events every 30 seconds to the server (or 5min?)
// TODO wipe events older than 3 days
// TODO Save projectId together with event
// TODO save events individually with key "{projectId}_{timestamp}"
// TODO handle different isolates
// TODO validate event name and parameters
// TODO make the projectId "default" by default
// TODO check if we can replace Wiredash.of(context).method() with just Wiredash.method()
// TODO validate event key
// TODO send first_launch event with # in beginning.
// TODO don't allow # in the beginning

// Nice to have
// TODO send events directly on web

class WiredashAnalytics {
  /// Optional [projectId] in case multiple [Wiredash] widgets with different
  /// projectIds are used at the same time
  final String? projectId;

  WiredashAnalytics({
    this.projectId,
  });

  static final eventKeyRegex =
      RegExp(r'^io\.wiredash\.events\.(\w+)\|(\d+)\|(\w+)$');

  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?>? params,
  }) async {
    final event = Event.internal(
      name: eventName,
      params: params,
      timestamp: clock.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final project = projectId ?? "default";
    final millis = event.timestamp!.millisecondsSinceEpoch ~/ 1000;
    final discriminator = nanoid(
      length: 6,
      // \w in regex, ignores "-"
      alphabet: Alphabet.alphanumeric,
    );
    final key = "io.wiredash.events.$project|$millis|$discriminator";
    assert(eventKeyRegex.hasMatch(key), 'Invalid event key: $key');

    await prefs.setString(key, jsonEncode(serializeEvent(event)));
    print('Saved event $key to disk');

    final id = projectId;
    if (id != null) {
      // Inform correct Wiredash instance about event
      final state = WiredashRegistry.findByProjectId(id);
      if (state != null) {
        await state.newEventAdded();
      } else {
        // widget not found, it will upload the event when mounted the next time
      }
      return;
    }

    // Forward default events to the only Wiredash instance that is running
    final activeWiredashInstances = WiredashRegistry.referenceCount;
    if (activeWiredashInstances == 0) {
      // no Wiredash instance is running. Wait for next mount to send the event
      return;
    }
    if (activeWiredashInstances == 1) {
      // found a single Wiredash instance, notify about the new event
      await WiredashRegistry.forEach((wiredashState) async {
        await wiredashState.newEventAdded();
      });
      return;
    }

    assert(activeWiredashInstances > 1,
        "Expect multiple Wiredash instances to be running.");
    assert(projectId == null, "No projectId defined");
    debugPrint(
      "Multiple Wiredash instances are mounted! "
      "Please specify a projectId to avoid sending events to all instances, "
      "or use Wiredash.of(context).trackEvent() to send events to a specific instance.",
    );
  }
}

Map<String, Object?> serializeEvent(Event event) {
  final values = SplayTreeMap<String, Object?>.from({
    "name": event.name,
    "version": 1,
    "timestamp": event.timestamp?.toIso8601String(),
  });

  final paramsValidated = event.params?.map((key, value) {
    if (value == null) {
      return MapEntry(key, null);
    }
    try {
      // try encoding. We don't care about the actual encoded content because
      // it will be later by the http library encoded
      jsonEncode(value);
      // encoding worked, it's valid data
      return MapEntry(key, value);
    } catch (e, stack) {
      reportWiredashError(
        e,
        stack,
        'Could not serialize event property '
        '$key=$value',
      );
      return MapEntry(key, null);
    }
  });
  if (paramsValidated != null) {
    paramsValidated.removeWhere((key, value) => value == null);
    if (paramsValidated.isNotEmpty) {
      values.addAll({'params': paramsValidated});
    }
  }
  return values;
}

Event deserializeEvent(Map<String, Object?> map) {
  final version = map['version'] as int?;
  if (version == 1) {
    final name = map['name'] as String?;
    final params = map['params'] as Map<String, Object?>?;
    final timestampRaw = map['timestamp'] as String?;
    return Event.internal(
      name: name!,
      params: params,
      timestamp: DateTime.parse(timestampRaw!),
    );
  }

  throw UnimplementedError("Unknown event version $version");
}

Future<void> trackEvent(
  String eventName, {
  Map<String, Object?>? params,
  String? projectId,
}) async {
  final analytics = WiredashAnalytics(projectId: projectId);
  await analytics.trackEvent(eventName, params: params);
}

class WiredashAnalyticsServices {
  // TODO create service locator
}

class Event {
  final String name;
  final Map<String, Object?>? params;
  final DateTime? timestamp;

  Event({
    required this.name,
    required this.params,
  }) : timestamp = null;

  Event.internal({
    required this.name,
    required this.params,
    required this.timestamp,
  });
}

abstract class EventSubmitter {
  Future<void> submitEvents(String projectId);
}

class PendingEventSubmitter implements EventSubmitter {
  final Future<SharedPreferences> Function() sharedPreferences;
  final WiredashApi api;

  PendingEventSubmitter({
    required this.sharedPreferences,
    required this.api,
  });

  @override
  Future<void> submitEvents(String projectId) async {
    // TODO check last sent event call.
    //  If is was less than 30 seconds ago, start timer
    //  else kick of sending events to backend for this projectId
    final prefs = await sharedPreferences();
    await prefs.reload();
    final keys = prefs.getKeys();
    print('Found $keys events on disk');

    final now = clock.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    final int unixThreeDaysAgo = threeDaysAgo.millisecondsSinceEpoch ~/ 1000;
    final Map<String, Event> toBeSubmitted = {};
    for (final key in keys) {
      print('Checking key $key');
      final match = WiredashAnalytics.eventKeyRegex.firstMatch(key);
      if (match == null) continue;
      final eventProjectId = match.group(1);
      final millis = int.parse(match.group(2)!);

      if (eventProjectId == 'default' || eventProjectId == projectId) {
        if (millis < unixThreeDaysAgo) {
          // event is too old, ignore and remove
          await prefs.remove(key);
          continue;
        }

        final eventJson = prefs.getString(key);
        if (eventJson != null) {
          try {
            final Event event = deserializeEvent(jsonDecode(eventJson));
            print('Found event $key for submission');
            toBeSubmitted[key] = event;
          } catch (e, stack) {
            debugPrint('Error when parsing event $key: $e\n$stack');
            await prefs.remove(key);
          }
        }
      }
    }

    print('processed events');

    // Send all events to the backend
    final events = toBeSubmitted.values.toList();
    print('Found ${events.length} events for submission');
    if (events.isNotEmpty) {
      print('Sending ${events.length} events to backend');
      await api.sendEvents(events);
      for (final key in toBeSubmitted.keys) {
        await prefs.remove(key);
      }
    }
  }
}

void main() async {
  final BuildContext context = RootElement(const RootWidget());

  // plain arguments
  await trackEvent('test_event', params: {'param1': 'value1'});

  // Event object
  // final event = Event(name: 'test_event', params: {'param1': 'value1'});
  // await trackEvent2(event);

  // WiredashAnalytics instance
  final analytics = WiredashAnalytics();
  await analytics.trackEvent('test_event', params: {'param1': 'value1'});

  // state instance method (will always work)
  await Wiredash.of(context)
      .trackEvent('test_event', params: {'param1': 'value1'});

  await trackEvent('test_event', params: {'param1': 'value1'});
}

//
//
//
//
// final Wiredash wiredash = Wiredash(
//     projectId: 'YOUR-PROJECT-ID',
//     secret: 'YOUR-SECRET',
// );
//
//
// void main() {
//   wiredash.trackEvent('test_event');
//
//   void build(BuildContext context) {
//     return wiredash.widget(
//         config: wiredashConfig,
//         child: MyApp();
//     );
//   }
// }
