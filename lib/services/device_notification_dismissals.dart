// Device-only IDs, partitioned by account. Does not change server notifications.
class DeviceNotificationDismissals {
  DeviceNotificationDismissals({required this.read, required this.write});
  final Future<List<String>> Function(String owner) read;
  final Future<void> Function(String owner, List<String> ids) write;
  Future<void> _tail = Future<void>.value();
  Future<Set<String>> ids(String owner) async => (await read(owner)).toSet();
  Future<void> setHidden(String owner, String id, bool hidden) {
    final next = _tail.then((_) async {
      final values = await ids(owner);
      if (hidden) {
        values.add(id);
      } else {
        values.remove(id);
      }
      await write(owner, values.toList());
    });
    _tail = next.then((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
}
