import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:underlab_camera/camera_api.dart';

http.Response okResponse([Map<String, Object?> extra = const {}]) =>
    http.Response(jsonEncode({'ok': true, ...extra}), 200);

void main() {
  test('actions carry stable trace and unique command identity', () async {
    late http.Request captured;
    final api = CameraApi(
      client: MockClient((request) async {
        captured = request;
        return okResponse({'sessionId': 42});
      }),
    );
    final traceId = api.newTraceId('field-shot');

    await api.action('shutter', traceId: traceId);

    expect(captured.headers['x-d810-trace'], traceId);
    expect(captured.headers['x-d810-command-id'], startsWith('$traceId-'));
    expect(captured.headers['x-d810-client'], 'flutter-camera');
    expect(captured.headers['x-d810-action'], 'shutter');
    expect(captured.headers['x-d810-ui-at'], isNotEmpty);
    await api.close();
  });

  test('runtime status mirrors authoritative camera and live-view state',
      () async {
    final api = CameraApi(
      client: MockClient((request) async => okResponse({
            'status': 'ready',
            'cameraDetected': true,
            'connected': true,
            'transportReady': true,
            'liveView': false,
            'batteryPercent': 87,
          })),
    );

    final status = await api.runtimeStatus();

    expect(status.cameraReady, isTrue);
    expect(status.liveView, isFalse);
    expect(status.batteryPercent, 87);
    await api.close();
  });

  test('rapid changes to one setting are coalesced to the latest value',
      () async {
    final requests = <Uri>[];
    final api = CameraApi(
      client: MockClient((request) async {
        requests.add(request.url);
        return okResponse(
            {'value': int.parse(request.url.queryParameters['value']!)});
      }),
    );

    final results = await Future.wait([
      api.setManualSetting('aperture', 320),
      api.setManualSetting('aperture', 350),
      api.setManualSetting('aperture', 400),
    ]);

    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['value'], '400');
    expect(results, [400, 400, 400]);
    await api.close();
  });

  test('AF jumps ahead of a settled setting after the active request',
      () async {
    final actions = <String>[];
    final liveGate = Completer<void>();
    final liveStarted = Completer<void>();
    final api = CameraApi(
      client: MockClient((request) async {
        final action = request.url.queryParameters['action']!;
        actions.add(action);
        if (action == 'live-on') {
          liveStarted.complete();
          await liveGate.future;
        }
        return okResponse({'value': 400});
      }),
    );

    final live = api.action('live-on');
    await liveStarted.future;
    final setting = api.setManualSetting('iso', 400);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final af = api.action('af');
    liveGate.complete();

    await Future.wait<Object>([live, setting, af]);
    expect(actions, ['live-on', 'af', 'manual-set']);
    await api.close();
  });

  test('STOP jumps ahead of every queued camera operation', () async {
    final actions = <String>[];
    final activeGate = Completer<void>();
    final activeStarted = Completer<void>();
    final api = CameraApi(
      client: MockClient((request) async {
        final action = request.url.queryParameters['action']!;
        actions.add(action);
        if (action == 'maintain') {
          activeStarted.complete();
          await activeGate.future;
        }
        return okResponse();
      }),
    );

    final active = api.action('maintain');
    await activeStarted.future;
    final live = api.action('live-on');
    final af = api.action('af');
    final stop = api.action('live-off');
    activeGate.complete();

    await Future.wait([active, live, af, stop]);
    expect(actions, ['maintain', 'live-off', 'af', 'live-on']);
    await api.close();
  });
}
