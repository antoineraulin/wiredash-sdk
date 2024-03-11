import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// TODO explicit analytics import should not be necessary
import 'package:wiredash/src/analytics/analytics.dart';
import 'package:wiredash/wiredash.dart';

import '../util/robot.dart';
import '../util/wiredash_tester.dart';

void main() {
  testWidgets('sendEvent (static)', (tester) async {
    final robot = WiredashTestRobot(tester);
    await robot.launchApp(
      builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () {
              Wiredash.trackEvent('test_event', params: {'param1': 'value1'});
            },
            child: const Text('Send Event'),
          ),
        );
      },
    );

    await robot.tapText('Send Event');
    await tester.pumpSmart();

    robot.mockServices.mockApi.sendEventsInvocations.verifyInvocationCount(1);
    final lastEvents = robot.mockServices.mockApi.sendEventsInvocations.latest;
    final events = lastEvents[0] as List<Event>?;
    expect(events, hasLength(1));
    final event = events![0];
    expect(event.name, 'test_event');
    expect(event.params, {'param1': 'value1'});
  });

  testWidgets('sendEvent (instance)', (tester) async {
    final robot = WiredashTestRobot(tester);
    await robot.launchApp(
      builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () {
              final analytics = WiredashAnalytics();
              analytics.trackEvent('test_event', params: {'param1': 'value1'});
            },
            child: const Text('Send Event'),
          ),
        );
      },
    );

    await robot.tapText('Send Event');
    await tester.pumpSmart();
    print('pump end');

    robot.mockServices.mockApi.sendEventsInvocations.verifyInvocationCount(1);
    final lastEvents = robot.mockServices.mockApi.sendEventsInvocations.latest;
    final events = lastEvents[0] as List<Event>?;
    expect(events, hasLength(1));
    final event = events![0];
    expect(event.name, 'test_event');
    expect(event.params, {'param1': 'value1'});
  });

  testWidgets('sendEvent is blocked by ad blocker', (tester) async {
    final robot = WiredashTestRobot(tester);
    await robot.launchApp(
      builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () {
              final analytics = WiredashAnalytics();
              analytics.trackEvent('test_event', params: {'param1': 'value1'});
            },
            child: const Text('Send Event'),
          ),
        );
      },
    );
    robot.mockServices.mockApi.sendEventsInvocations.interceptor =
        (invocation) async {
      throw 'Blocked by ad blocker';
    };

    await robot.tapText('Send Event');
    await tester.pumpSmart();
    await robot.tapText('Send Event');
    await tester.pumpSmart();

    robot.mockServices.mockApi.sendEventsInvocations.verifyInvocationCount(2);

    final pending = await getPendingEvents();
    expect(pending, hasLength(2));
  });
}

Future<List<String>> getPendingEvents() async {
  final prefs = await SharedPreferences.getInstance();
  final events = prefs
      .getKeys()
      .where((key) => WiredashAnalytics.eventKeyRegex.hasMatch(key))
      .toList();
  return events;
}
