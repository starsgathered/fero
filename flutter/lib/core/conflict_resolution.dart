// conflict_resolution works on integer versions only; no import required

/// Defines how to resolve conflicts when both local and remote have changes.
enum ConflictResolutionStrategy {
  /// Remote (server) changes always win. Local changes are discarded.
  serverWins,

  /// Local (client) changes always win. Remote changes are discarded.
  clientWins,

  /// Both local and remote changes are applied (merge both).
  mergeBoth,

  /// Version-based resolution: higher version wins (Fero server is source of truth).
  /// If versions are equal, timestamp is used as tiebreaker.
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
  /// Apply the given strategy to resolve version conflicts.
  static VersionResolution resolveVersions({
    required int localVersion,
    required int remoteVersion,
    required ConflictResolutionStrategy strategy,
  }) {
    switch (strategy) {
      case ConflictResolutionStrategy.serverWins:
        return VersionResolution(
          applyLocal: false,
          applyRemote: true,
          hasConflict: remoteVersion > localVersion,
          winner: ResolutionWinner.remote,
        );

      case ConflictResolutionStrategy.clientWins:
        return VersionResolution(
          applyLocal: true,
          applyRemote: false,
          hasConflict: localVersion > remoteVersion,
          winner: ResolutionWinner.local,
        );

      case ConflictResolutionStrategy.mergeBoth:
        return VersionResolution(
          applyLocal: true,
          applyRemote: true,
          hasConflict: localVersion != remoteVersion,
          winner: ResolutionWinner.merge,
        );

      case ConflictResolutionStrategy.highestVersionWins:
        return _resolveByHighestVersion(localVersion, remoteVersion);
    }
  }

  /// Implementation of highest-version-wins: higher version is authoritative.
  /// Version is the primary ordering key.
  static VersionResolution _resolveByHighestVersion(
      int localVersion, int remoteVersion) {
    if (remoteVersion > localVersion) {
      return VersionResolution(
        applyLocal: false,
        applyRemote: true,
        hasConflict: true,
        winner: ResolutionWinner.remote,
      );
    } else if (localVersion > remoteVersion) {
      return VersionResolution(
        applyLocal: true,
        applyRemote: false,
        hasConflict: true,
        winner: ResolutionWinner.local,
      );
    } else {
      // Versions equal - no action needed
      return VersionResolution(
        applyLocal: false,
        applyRemote: false,
        hasConflict: false,
        winner: ResolutionWinner.none,
      );
    }
  }
}
