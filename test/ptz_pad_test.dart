import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

void main() {
  group('HubSightPtzPad Widget Tests', () {
    testWidgets('renders all PTZ buttons and presets correctly',
        (tester) async {
      final presets = [
        const PresetItem(token: 'preset_1', name: 'Preset One'),
        const PresetItem(token: 'preset_2', name: 'Preset Two'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HubSightPtzPad(
              cameraId: 'cam_01',
              presets: presets,
            ),
          ),
        ),
      );

      // Verify direction icons and stop icon
      expect(find.byIcon(Icons.north_west), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.north_east), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
      expect(find.byIcon(Icons.south_west), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.south_east), findsOneWidget);

      // Verify zoom buttons
      expect(find.text('Zoom +'), findsOneWidget);
      expect(find.text('Zoom -'), findsOneWidget);

      // Verify presets
      expect(find.text('Preset One'), findsOneWidget);
      expect(find.text('Preset Two'), findsOneWidget);
    });

    testWidgets('invokes onAction with continuous move and stop on release',
        (tester) async {
      final actions = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HubSightPtzPad(
              cameraId: 'cam_01',
              onAction: ({
                required String action,
                double pan = 0.0,
                double tilt = 0.0,
                double zoom = 0.0,
              }) async {
                actions.add({
                  'action': action,
                  'pan': pan,
                  'tilt': tilt,
                  'zoom': zoom,
                });
              },
            ),
          ),
        ),
      );

      // Press down Up arrow
      final upFinder = find.byIcon(Icons.keyboard_arrow_up);
      final gesture = await tester.startGesture(tester.getCenter(upFinder));
      await tester.pump();

      expect(actions.length, equals(1));
      expect(actions[0]['action'], equals('continuous'));
      expect(actions[0]['pan'], equals(0.0));
      expect(actions[0]['tilt'], equals(0.7));

      // Release finger
      await gesture.up();
      await tester.pump();

      expect(actions.length, equals(2));
      expect(actions[1]['action'], equals('stop'));
    });

    testWidgets('invokes onAction with stop when center button is pressed',
        (tester) async {
      final actions = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HubSightPtzPad(
              cameraId: 'cam_01',
              onAction: ({
                required String action,
                double pan = 0.0,
                double tilt = 0.0,
                double zoom = 0.0,
              }) async {
                actions.add({'action': action});
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(actions.length, equals(1));
      expect(actions[0]['action'], equals('stop'));
    });

    testWidgets('triggers onPresetSelected when preset chip is clicked',
        (tester) async {
      PresetItem? selected;
      final presets = [
        const PresetItem(token: 'p1', name: 'Door'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HubSightPtzPad(
              cameraId: 'cam_01',
              presets: presets,
              onPresetSelected: (preset) {
                selected = preset;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Door'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.token, equals('p1'));
      expect(selected!.name, equals('Door'));
    });
  });
}
