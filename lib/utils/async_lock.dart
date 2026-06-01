import 'dart:async';

/// 비동기 작업을 등록 순서대로 직렬화하는 단순 뮤텍스.
///
/// [synchronized]로 감싼 작업들은 호출된 순서대로 하나씩 실행되며, 이전 작업이
/// 완료된 뒤에야(성공이든 실패든) 다음 작업이 시작된다. 한 작업이 예외를 던져도
/// 락은 정상적으로 해제되어 후속 작업이 계속 진행된다.
///
/// 용도: 녹음 start/stop/세그먼트 분할처럼 같은 자원(recorder)의 상태 전이가
/// 서로 끼어들면 안 되는 경로를 직렬화한다. 타이머가 발생시킨 분할과 사용자가
/// 누른 정지가 인터리브되어 고아 세션이 생기는 경쟁을 차단한다.
class AsyncLock {
  Future<void> _tail = Future<void>.value();

  /// [action]을 직렬 큐에 넣고 결과를 반환한다.
  /// 이전에 등록된 모든 작업이 끝난 뒤에 실행된다.
  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous
        .then((_) => action())
        .whenComplete(() => completer.complete());
  }
}
