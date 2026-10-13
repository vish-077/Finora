import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Deterministic UUIDv5 for rows the app seeds itself (default categories,
/// the default cash wallet, …).
///
/// Two things depend on this:
///   * Older schemas declared `uuid` columns — a literal id like `default-food` is
///     rejected outright, which silently kept seeded rows (and every expense
///     pointing at one) local to whichever device created them.
///   * Two devices that seed the same account while offline must produce the
///     *same* id, so the rows merge instead of duplicating.
String stableId(String seed) => _uuid.v5(Namespace.url.value, 'finora://$seed');

/// True when [value] is already a well-formed UUID.
bool isUuid(String value) => Uuid.isValidUUID(fromString: value);
