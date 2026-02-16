import 'package:fero_sync/core/sync_handler.dart';

/// Defines how to resolve conflicts when both local and remote have changes.
enum ConflictResolutionStrategy {
  /// Remote (server) changes always win. Local changes are discarded.
  serverWins,

  /// Local (client) changes always win. Remote changes are discarded.
  clientWins,

  /// Both local and remote changes are applied (merge both).
  mergeBoth,

  /// Version-based resolution: higher version wins (Fero server is source of truth).
  /// If versions are equal, syncId is used as tiebreaker (lexicographically higher wins).
  highestVersionWins,
}

/// Result of version-based conflict resolution.
class VersionResolution {
  final bool applyLocal;
  final bool applyRemote;
  final bool hasConflict;
  final ResolutionWinner winner;

  VersionResolution({
    required this.applyLocal,
    required this.applyRemote,
    required this.hasConflict,
    required this.winner,
  });
}

/// Indicates which side won a version resolution.
enum ResolutionWinner { local, remote, merge, none }

/// Helper class to apply conflict resolution strategies on version objects.
class ConflictResolver {
  /// Apply the given strategy to resolve conflicts between local and remote Syncable objects.
  static VersionResolution resolve({
    required Syncable local,
    required Syncable remote,
    required ConflictResolutionStrategy strategy,
  }) {
    switch (strategy) {
      case ConflictResolutionStrategy.serverWins:
        return VersionResolution(
          applyLocal: false,
          applyRemote: true,
          hasConflict: remote.version > local.version,
          winner: ResolutionWinner.remote,
        );

      case ConflictResolutionStrategy.clientWins:
        return VersionResolution(
          applyLocal: true,
          applyRemote: false,
          hasConflict: local.version > remote.version,
          winner: ResolutionWinner.local,
        );

      case ConflictResolutionStrategy.mergeBoth:
        return VersionResolution(
          applyLocal: true,
          applyRemote: true,
          hasConflict: local.version != remote.version,
          winner: ResolutionWinner.merge,
        );

      case ConflictResolutionStrategy.highestVersionWins:
        return _resolveByHighestVersion(local, remote);
    }
  }

  /// Implementation of highest-version-wins: higher version is authoritative.
  /// If versions are equal, syncId is used as tiebreaker (lexicographically higher wins).
  static VersionResolution _resolveByHighestVersion(
      Syncable local, Syncable remote) {
    if (remote.version > local.version) {
      return VersionResolution(
        applyLocal: false,
        applyRemote: true,
        hasConflict: true,
        winner: ResolutionWinner.remote,
      );
    } else if (local.version > remote.version) {
      return VersionResolution(
        applyLocal: true,
        applyRemote: false,
        hasConflict: true,
        winner: ResolutionWinner.local,
      );
    } else {
      // Versions equal - use syncId as tiebreaker
      final comparison = remote.syncId.compareTo(local.syncId);
      if (comparison > 0) {
        // Remote syncId is lexicographically higher
        return VersionResolution(
          applyLocal: false,
          applyRemote: true,
          hasConflict: true,
          winner: ResolutionWinner.remote,
        );
      } else if (comparison < 0) {
        // Local syncId is lexicographically higher
        return VersionResolution(
          applyLocal: true,
          applyRemote: false,
          hasConflict: true,
          winner: ResolutionWinner.local,
        );
      } else {
        // Same version and same syncId - no action needed
        return VersionResolution(
          applyLocal: false,
          applyRemote: false,
          hasConflict: false,
          winner: ResolutionWinner.none,
        );
      }
    }
  }
}
