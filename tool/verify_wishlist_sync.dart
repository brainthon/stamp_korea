import 'dart:async';
import 'dart:io';
import 'package:stamp_korea/services/wishlist_sync.dart';

void check(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> main() async {
  String? owner = 'A';
  Set<String> visible = {'existing'};
  int calls = 0, errors = 0;
  final requests = <Completer<Set<String>>>[];
  final sync = WishlistSync(
    currentOwner: () => owner,
    fetch: (_) {
      calls++;
      final request = Completer<Set<String>>();
      requests.add(request);
      return request.future;
    },
    apply: (ids) => visible = ids,
    onError: () => errors++,
  );
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  final first = sync.refresh(), duplicate = sync.refresh();
  check(identical(first, duplicate), 'Overlapping reads must coalesce');
  await tick();
  check(calls == 1, 'Duplicate cloud request');
  requests.last.complete({'remote'});
  await first;
  check(
    visible.contains('remote') && !sync.refreshing,
    'Cloud state not applied',
  );

  final oldAccount = sync.refresh();
  await tick();
  owner = 'B';
  sync.invalidate();
  visible = {'B-local'};
  final newAccount = sync.refresh();
  await tick();
  requests[1].complete({'A-private'});
  await oldAccount;
  check(visible.contains('B-local'), 'Old account reply leaked');
  check(sync.refreshing, 'Old read cleared new account request');
  requests[2].complete({'B-cloud'});
  await newAccount;
  check(visible.contains('B-cloud'), 'New account refresh lost');

  final beforeEdit = sync.refresh();
  await tick();
  final write = sync.beginWrite();
  visible = {'B-edited'};
  requests[3].complete({'B-old'});
  await beforeEdit;
  check(visible.contains('B-edited'), 'Old cloud read overwrote edit');
  final before = calls;
  await sync.refresh();
  check(calls == before, 'Cloud read started during a write');
  sync.endWrite(write);

  final failure = sync.refresh();
  await tick();
  requests.last.completeError(StateError('offline'));
  await failure;
  check(
    errors == 1 && visible.contains('B-edited'),
    'Offline read erased records',
  );

  final staleFailure = sync.refresh();
  await tick();
  owner = null;
  sync.invalidate();
  visible = {};
  requests.last.completeError(StateError('late error'));
  await staleFailure;
  await sync.refresh();
  check(
    errors == 1 && visible.isEmpty,
    'Logged-out account received stale error',
  );
  check(calls == 6, 'Guest performed cloud read');
  stdout.writeln(
    'PASS: coalesced reads, account isolation, edit race, offline preservation, logout',
  );
}
