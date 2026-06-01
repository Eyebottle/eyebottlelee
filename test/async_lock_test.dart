import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_recorder/utils/async_lock.dart';

void main() {
  group('AsyncLock', () {
    test('등록 순서대로 직렬 실행하며 이전 작업이 끝나기 전엔 다음을 시작하지 않는다',
        () async {
      final lock = AsyncLock();
      final events = <String>[];
      final gate1 = Completer<void>();

      final f1 = lock.synchronized(() async {
        events.add('start1');
        await gate1.future;
        events.add('end1');
      });
      final f2 = lock.synchronized(() async {
        events.add('start2');
        events.add('end2');
      });

      // gate1이 열리기 전엔 두 번째 작업이 시작조차 하지 않아야 한다.
      await Future<void>.delayed(Duration.zero);
      expect(events, ['start1']);

      gate1.complete();
      await Future.wait([f1, f2]);
      expect(events, ['start1', 'end1', 'start2', 'end2']);
    });

    test('한 작업이 예외를 던져도 락이 해제되어 후속 작업이 실행된다', () async {
      final lock = AsyncLock();

      await expectLater(
        lock.synchronized(() async => throw StateError('boom')),
        throwsStateError,
      );

      final result = await lock.synchronized(() async => 42);
      expect(result, 42);
    });

    test('작업의 반환값을 그대로 전달한다', () async {
      final lock = AsyncLock();
      expect(await lock.synchronized(() async => 'hello'), 'hello');
    });

    test('실패한 작업 다음에도 직렬 순서가 보존된다', () async {
      final lock = AsyncLock();
      final events = <String>[];

      final f1 = lock.synchronized<void>(() async {
        events.add('a');
        throw Exception('x');
      });
      final f2 = lock.synchronized<void>(() async {
        events.add('b');
      });

      try {
        await f1;
      } catch (_) {}
      await f2;
      expect(events, ['a', 'b']);
    });

    test('다수의 동시 작업이 인터리브 없이 순차 실행된다', () async {
      final lock = AsyncLock();
      final order = <int>[];
      var active = 0;
      var maxActive = 0;

      final futures = List.generate(20, (i) {
        return lock.synchronized(() async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          order.add(i);
          active--;
        });
      });

      await Future.wait(futures);
      expect(maxActive, 1, reason: '한 번에 하나의 작업만 활성이어야 한다');
      expect(order, List.generate(20, (i) => i), reason: '등록 순서가 보존되어야 한다');
    });
  });
}
