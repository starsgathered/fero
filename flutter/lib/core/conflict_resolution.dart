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
  /// If versions are equal, timestamp is used as tiebreaker.
  highestVersionWins,
}

/// Helper class to apply conflict resolution strategies.
class ConflictResolver {
  /// Apply the given strategy to merge log events.
  static MergeResult resolve({
    required List<LogEvent> localEvents,
    required List<LogEvent> remoteEvents,
    required ConflictResolutionStrategy strategy,
  }) {
    switch (strategy) {
      case ConflictResolutionStrategy.serverWins:
        return MergeResult(
          toApplyLocally: remoteEvents,
          toApplyRemotely: [],
          hasConflicts: localEvents.isNotEmpty && remoteEvents.isNotEmpty,
        );

      case ConflictResolutionStrategy.clientWins:
        return MergeResult(
          toApplyLocally: [],
          toApplyRemotely: localEvents,
          hasConflicts: localEvents.isNotEmpty && remoteEvents.isNotEmpty,
        );

      case ConflictResolutionStrategy.mergeBoth:
        return MergeResult(
          toApplyLocally: remoteEvents,
          toApplyRemotely: localEvents,
          hasConflicts: localEvents.isNotEmpty && remoteEvents.isNotEmpty,
        );

      case ConflictResolutionStrategy.highestVersionWins:
        return _resolveByHighestVersion(localEvents, remoteEvents);
    }
  }

  /// Implementation of highest-version-wins: Fero's version is authoritative.
  /// Version is the primary ordering key (set by Fero server).
  /// Timestamp is only used as a tiebreaker if versions are equal.
  /// 
  /// Why versions are better than timestamps:
  /// - No clock skew (clients can have wrong time)
  /// - Deterministic (version N always comes before N+1)
  /// - Source of truth is Fero server
  /// - Works in distributed offline-first scenarios
  static MergeResult _resolveByHighestVersion(
    List<LogEvent> localEvents,
    List<LogEvent> remoteEvents,
  ) {
    final toApplyLocally = <LogEvent>[];
    final toApplyRemotely = <LogEvent>[];

    // Build map of ID -> event from each side
    final localMap = <String, LogEvent>{};
    final remoteMap = <String, LogEvent>{};

    for (final event in localEvents) {
      localMap[event.id] = event;
    }
    for (final event in remoteEvents) {
      remoteMap[event.id] = event;
    }

    // For each ID, determine which side wins based on version
    final allIds = <String>{...localMap.keys, ...remoteMap.keys};

    for (final id in allIds) {
      final localEvent = localMap[id];
      final remoteEvent = remoteMap[id];

      if (localEvent == null) {
        // Only in remote
        toApplyLocally.add(remoteEvent!);
      } else if (remoteEvent == null) {
        // Only in local
        toApplyRemotely.add(localEvent);
      } else {
        // In both - highest version wins
        if (remoteEvent.version > localEvent.version) {
          toApplyLocally.add(remoteEvent);
        } else if (localEvent.version > remoteEvent.version) {
          toApplyRemotely.add(localEvent);
        } else {
          // Versions are equal - use timestamp as tiebreaker
          if (remoteEvent.timestamp.isAfter(localEvent.timestamp)) {
            toApplyLocally.add(remoteEvent);
          } else {
            toApplyRemotely.add(localEvent);
          }
        }
      }
    }

    return MergeResult(
      toApplyLocally: toApplyLocally,
      toApplyRemotely: toApplyRemotely,
      hasConflicts: localEvents.isNotEmpty && remoteEvents.isNotEmpty,
    );
  }
}
