import '../lib/services/device_notification_dismissals.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

Future<void> main() async {
  final disk = <String, List<String>>{};
  var fail = false;
  DeviceNotificationDismissals create() => DeviceNotificationDismissals(
    read: (owner) async => List.of(disk[owner] ?? []),
    write: (owner, ids) async {
      if (fail) throw StateError('Storage failed');
      disk[owner] = List.of(ids);
    },
  );
  final service = create();
  await Future.wait([
    service.setHidden('a', 'notice-1', true),
    service.setHidden('a', 'notice-2', true),
  ]);
  check(
    (await service.ids('a')).length == 2,
    'Concurrent deletions must not overwrite each other',
  );
  check((await service.ids('b')).isEmpty, 'Account isolation');
  check(
    (await create().ids('a')).contains('notice-1'),
    'Hidden state survives restart',
  );
  await service.setHidden('a', 'notice-1', false);
  check(
    !(await service.ids('a')).contains('notice-1'),
    'Undo restores notification',
  );
  check(
    (await service.ids('a')).contains('notice-2'),
    'Undo preserves other deletions',
  );
  final snapshot = await service.ids('a');
  snapshot.clear();
  check((await service.ids('a')).isNotEmpty, 'Caller cannot mutate stored set');
  fail = true;
  try {
    await service.setHidden('a', 'notice-3', true);
    throw StateError('Failure swallowed');
  } catch (e) {
    check(
      e.toString().contains('Storage failed'),
      'Persistence failure surfaced',
    );
  }
  fail = false;
  await service.setHidden('a', 'notice-4', true);
  check(
    (await service.ids('a')).contains('notice-4'),
    'Queue recovers after write failure',
  );
  check(
    !(await service.ids('a')).contains('notice-3'),
    'Failed deletion stays visible',
  );
  print(
    'PASS: local persistence, account isolation, concurrent deletes, undo and failed-write recovery',
  );
}
