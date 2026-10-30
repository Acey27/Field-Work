/// A page and the sections inside it that load their own data. The page calls
/// [run] to fetch everything again; it completes when every section is done,
/// so a refresh button can keep spinning until then.
///
/// Sections add their loader in `initState` and remove it in `dispose`. A
/// loader must handle its own errors (keep the old data on screen).
class RefreshGroup {
  final _loaders = <Future<void> Function()>[];

  void add(Future<void> Function() loader) => _loaders.add(loader);

  void remove(Future<void> Function() loader) => _loaders.remove(loader);

  Future<void> run() =>
      Future.wait([for (final loader in List.of(_loaders)) loader()]);
}
