import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current position of the attached video, in seconds — null when no video is
/// loaded.
///
/// The player owns playback; this only publishes where it is, so the rest of the
/// app can react without knowing anything about the platform. Two consumers:
/// the court, which reveals a rally's touches progressively, and the annotation
/// gestures, which stamp each new impact with the moment it happened.
class VideoPositionNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  /// Called by the player on every playback tick and every seek.
  ///
  /// A method rather than a setter: the position is owned by the player, and an
  /// assignable-looking property would invite the rest of the app to move the
  /// video by writing to state instead of commanding the player.
  // ignore: use_setters_to_change_properties
  void moveTo(double seconds) => state = seconds;

  /// No video attached, or the player was disposed.
  void clear() => state = null;
}

final videoPositionProvider =
    NotifierProvider<VideoPositionNotifier, double?>(VideoPositionNotifier.new);

/// Whether the replay screen is in correction mode.
///
/// Viewing an archive is read-only by default so a stray tap cannot rewrite a
/// scored match — which matters doubly for matches in the validation corpus.
/// Turning this on swaps the read-only notifier for the real scoring one.
class EditingArchiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final editingArchiveProvider =
    NotifierProvider<EditingArchiveNotifier, bool>(EditingArchiveNotifier.new);
