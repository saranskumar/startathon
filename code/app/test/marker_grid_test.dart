import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/inputs/marker_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('buildMarkerLevel', () {
    test('5 or fewer options are all leaves at the top level', () {
      final level = buildMarkerLevel(['a', 'b', 'c']);
      expect(level.length, 3);
      expect(level.every((n) => n.isLeaf), isTrue);
      expect(level.map((n) => n.value), ['a', 'b', 'c']);
    });

    test('more than 5 options split into at most 5 groups', () {
      final options = List.generate(12, (i) => 'opt$i');
      final level = buildMarkerLevel(options);
      expect(level.length, lessThanOrEqualTo(kMaxMarkersPerLevel));
      // Every original option is reachable somewhere in the tree.
      final reachable = <String>{};
      void collect(List<MarkerNode> nodes) {
        for (final n in nodes) {
          if (n.isLeaf) {
            reachable.add(n.value!);
          } else {
            collect(n.children);
          }
        }
      }
      collect(level);
      expect(reachable, options.toSet());
    });

    test('recursion terminates for very large lists (no level exceeds the cap)', () {
      final options = List.generate(200, (i) => 'opt$i');
      void checkLevel(List<MarkerNode> nodes) {
        expect(nodes.length, lessThanOrEqualTo(kMaxMarkersPerLevel));
        for (final n in nodes) {
          if (!n.isLeaf) checkLevel(n.children);
        }
      }
      checkLevel(buildMarkerLevel(options));
    });
  });

  group('MarkerGridController', () {
    test('a leaf marker resolves with the right index and value', () {
      String? resolvedValue;
      int? resolvedIndex;
      final controller = MarkerGridController(
        ['first', 'second', 'third'],
        onResolve: (i, v) {
          resolvedIndex = i;
          resolvedValue = v;
        },
      );

      controller.onUtterance(2, 300); // 2 bursts -> marker B -> 'second'

      expect(resolvedIndex, 1);
      expect(resolvedValue, 'second');
      controller.dispose();
    });

    test('a group marker descends instead of resolving, and back() returns', () {
      var resolved = false;
      final options = List.generate(8, (i) => 'opt$i'); // > 5, so it groups
      final controller = MarkerGridController(
        options,
        onResolve: (_, _) => resolved = true,
      );

      expect(controller.level.length, lessThanOrEqualTo(kMaxMarkersPerLevel));
      expect(controller.canGoBack, isFalse);

      // Pick whichever marker is a group (not a leaf) to descend.
      final groupIndex = controller.level.indexWhere((n) => !n.isLeaf);
      expect(groupIndex, greaterThanOrEqualTo(0),
          reason: '8 options into <=5 slots must produce at least one group');
      controller.onUtterance(groupIndex + 1, 300);

      expect(resolved, isFalse, reason: 'descending into a group must not resolve');
      expect(controller.canGoBack, isTrue);

      controller.back();
      expect(controller.canGoBack, isFalse);
      controller.dispose();
    });

    test('a sound count with no matching cell is reported but does not crash', () {
      var raw = '';
      final controller = MarkerGridController(
        ['a', 'b'],
        onResolve: (_, _) {},
        onRaw: (m) => raw = m,
      );
      controller.onUtterance(5, 300); // only 2 markers exist
      expect(raw, contains('no matching cell'));
      controller.dispose();
    });
  });
}
