/// Coalesces cloud reads and discards replies after account changes or edits.
class WishlistSync {
  WishlistSync({
    required this.currentOwner,
    required this.fetch,
    required this.apply,
    required this.onError,
  });
  final String? Function() currentOwner;
  final Future<Set<String>> Function(String owner) fetch;
  final void Function(Set<String> ids) apply;
  final void Function() onError;
  final Set<Object> _writes = {};
  Future<void>? _pending;
  int _version = 0;
  bool get refreshing => _pending != null;

  void invalidate() {
    _version++;
    _pending = null;
    _writes.clear();
  }

  Object beginWrite() {
    _version++;
    _pending = null;
    final token = Object();
    _writes.add(token);
    return token;
  }

  void endWrite(Object token) {
    if (_writes.remove(token)) _version++;
  }

  Future<void> refresh() {
    final owner = currentOwner();
    if (owner == null || _writes.isNotEmpty) return Future<void>.value();
    if (_pending != null) return _pending!;
    final version = _version;
    bool valid() => currentOwner() == owner && _version == version;
    late final Future<void> request;
    request = Future<void>.microtask(() async {
      try {
        if (!valid()) return;
        final ids = await fetch(owner);
        if (valid()) apply(ids);
      } catch (_) {
        if (valid()) onError();
      } finally {
        if (identical(_pending, request)) _pending = null;
      }
    });
    _pending = request;
    return request;
  }
}
