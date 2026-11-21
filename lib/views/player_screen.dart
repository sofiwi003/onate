import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/theme.dart';

String songAudioValue(Map<String, dynamic> data) {
  // `archivo` es la ruta única del objeto en Storage. Si también guardaron
  // una URL de descarga duplicada o antigua, conservar la ruta evita repetirla.
  final storagePath = (data['archivo'] ?? data['storagePath'] ?? '')
      .toString()
      .trim();
  if (storagePath.isNotEmpty) return storagePath;
  return (data['audioUrl'] ?? data['url'] ?? '').toString().trim();
}

Future<String> resolveSongAudioUrl(String value) async {
  final candidate = value.trim();
  if (candidate.isEmpty) return '';
  final uri = Uri.tryParse(candidate);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return candidate;
  }
  final reference = candidate.startsWith('gs://')
      ? FirebaseStorage.instance.refFromURL(candidate)
      : FirebaseStorage.instance.ref(
          candidate.replaceFirst(RegExp(r'^/+'), ''),
        );
  return reference.getDownloadURL();
}

class PlayerTrack {
  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.audioUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;
}

int _audioRequestVersion = 0;
Future<void> _audioOperationTail = Future<void>.value();

Future<bool> playAudioTrack(
  AudioPlayer player, {
  required String title,
  required String audioUrl,
  bool autoplay = true,
}) async {
  final requestVersion = ++_audioRequestVersion;
  final url = await resolveSongAudioUrl(audioUrl);
  if (requestVersion != _audioRequestVersion) return false;
  if (url.isEmpty) {
    final stopped = Completer<bool>();
    _audioOperationTail = _audioOperationTail.catchError((_) {}).then((
      _,
    ) async {
      if (requestVersion == _audioRequestVersion) await player.stop();
      stopped.complete(false);
    });
    return stopped.future;
  }

  final result = Completer<bool>();
  _audioOperationTail = _audioOperationTail.catchError((_) {}).then((_) async {
    if (requestVersion != _audioRequestVersion) {
      result.complete(false);
      return;
    }
    try {
      final currentSource = player.audioSource;
      if (currentSource is! UriAudioSource ||
          currentSource.uri.toString() != url) {
        // Detén explícitamente la decodificación actual antes de asignar otra
        // URL. En web, cambiar el source mientras sigue reproduciéndose puede
        // dejar activo el audio anterior aunque la pantalla ya muestre el nuevo.
        await player.stop();
        await player.setUrl(url);
      }
      if (requestVersion != _audioRequestVersion) {
        result.complete(false);
        return;
      }
      // Cada pista debe comenzar a velocidad normal. Esto evita conservar un
      // valor de reproducción alterado por la sesión multimedia del sistema.
      await player.setSpeed(1.0);
      if (autoplay) unawaited(player.play());
      result.complete(true);
    } catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    }
  });
  return result.future;
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.audioPlayer,
    this.songId = '',
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.audioUrl,
    this.selectedNavigationIndex = 0,
    this.queue = const [],
    this.queueIndex = 0,
    this.onSongChanged,
  });

  final AudioPlayer audioPlayer;
  final String songId;
  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;
  final int selectedNavigationIndex;
  final List<PlayerTrack> queue;
  final int queueIndex;
  final ValueChanged<PlayerTrack>? onSongChanged;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  AudioPlayer get _player => widget.audioPlayer;
  late PlayerTrack _currentTrack;
  late int _currentQueueIndex;
  int _loadGeneration = 0;

  bool _liked = false;
  bool _loading = false;
  bool _audioLoaded = false;
  bool _playing = false;
  bool _shuffle = false;
  bool _repeat = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  static const _playerAccentColor = AppColors.primary500;
  static const _mutedIconColor = AppColors.neutral200;

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _favoriteSubscription;

  @override
  void initState() {
    super.initState();
    _currentTrack = PlayerTrack(
      id: widget.songId,
      title: widget.title,
      artist: widget.artist,
      imageUrl: widget.imageUrl,
      audioUrl: widget.audioUrl,
    );
    _currentQueueIndex = widget.queueIndex;

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted) setState(() => _duration = duration ?? Duration.zero);
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _listenForFavorite();

    _loadAudio(autoplay: true);
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    _favoriteSubscription?.cancel();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? get _favoriteReference {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentTrack.id.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(_currentTrack.id);
  }

  void _listenForFavorite() {
    final reference = _favoriteReference;
    if (reference == null) return;
    _favoriteSubscription = reference.snapshots().listen((snapshot) {
      if (mounted) setState(() => _liked = snapshot.exists);
    });
  }

  Future<void> _toggleFavorite() async {
    final reference = _favoriteReference;
    if (reference == null) {
      _showMessage('Inicia sesión para guardar tus favoritos.');
      return;
    }

    final wasLiked = _liked;
    setState(() => _liked = !wasLiked);
    try {
      if (wasLiked) {
        await reference.delete();
      } else {
        await reference.set({
          'songId': _currentTrack.id,
          'title': _currentTrack.title,
          'artist': _currentTrack.artist,
          'imageUrl': _currentTrack.imageUrl,
          'audioUrl': _currentTrack.audioUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _liked = wasLiked);
        _showMessage('No se pudo guardar el favorito. Revisa tu conexión.');
      }
    }
  }

  Future<void> _loadAudio({
    bool autoplay = false,
    bool notifyMissing = false,
  }) async {
    final generation = ++_loadGeneration;
    final requestedTrack = _currentTrack;
    setState(() => _loading = true);

    try {
      var audioValue = requestedTrack.audioUrl;
      if (audioValue.isEmpty) {
        final songs = await FirebaseFirestore.instance
            .collection('canciones')
            .get();
        final match = songs.docs.where((doc) {
          final data = doc.data();
          final title = (data['title'] ?? data['titulo'] ?? '').toString();
          final artist = (data['artist'] ?? data['subtitulo'] ?? '').toString();
          return title == requestedTrack.title &&
              artist == requestedTrack.artist &&
              songAudioValue(data).isNotEmpty;
        });
        if (match.isNotEmpty) audioValue = songAudioValue(match.first.data());
      }
      if (generation != _loadGeneration) return;

      if (audioValue.isEmpty) {
        await playAudioTrack(
          _player,
          title: requestedTrack.title,
          audioUrl: '',
        );
        if (generation != _loadGeneration) return;
        if (mounted) setState(() => _audioLoaded = false);
        if (notifyMissing) {
          _showMessage('Todavía no hay un archivo de audio para esta canción.');
        }
        return;
      }

      final loaded = await playAudioTrack(
        _player,
        title: requestedTrack.title,
        audioUrl: audioValue,
        autoplay: autoplay,
      );
      if (generation != _loadGeneration) return;
      if (!loaded) return;
      if (!mounted) return;
      setState(() => _audioLoaded = true);
    } catch (error) {
      if (generation == _loadGeneration) await _player.stop();
      if (mounted && generation == _loadGeneration) {
        setState(() => _audioLoaded = false);
      }
      if (notifyMissing && generation == _loadGeneration) {
        _showMessage('No se pudo cargar el audio: $error');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _playAdjacentTrack(int offset) async {
    if (widget.queue.isEmpty) {
      if (offset > 0) _showMessage('No hay otra canción en la cola.');
      return;
    }
    final nextIndex = _currentQueueIndex + offset;
    if (nextIndex < 0 || nextIndex >= widget.queue.length) {
      if (offset > 0) _showMessage('Llegaste al final de esta playlist.');
      return;
    }
    final nextTrack = widget.queue[nextIndex];
    await _favoriteSubscription?.cancel();
    setState(() {
      _currentTrack = nextTrack;
      _currentQueueIndex = nextIndex;
      _liked = false;
      _audioLoaded = false;
      _position = Duration.zero;
    });
    _listenForFavorite();
    widget.onSongChanged?.call(nextTrack);
    await _loadAudio(autoplay: true, notifyMissing: true);
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;

    if (!_audioLoaded) {
      await _loadAudio(autoplay: true, notifyMissing: true);
    } else if (_playing) {
      await _player.pause();
    } else {
      _player.play();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _time(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral800,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final coverSize = math
                .min((constraints.maxWidth - 36) * 0.855, 460.0)
                .toDouble();

            return ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                overscroll: false,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(
                          'assets/icons/player_back_circle.svg',
                          () => Navigator.pop(context),
                        ),
                        _circleButton(
                          'assets/icons/player_share_circle.svg',
                          () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppRadius.radius500,
                        ),
                        child: SizedBox(
                          width: coverSize,
                          height: coverSize,
                          child: Image.network(
                            _currentTrack.imageUrl,
                            key: ValueKey(_currentTrack.imageUrl),
                            fit: BoxFit.cover,
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: AppColors.neutral700,
                                  child: const Icon(
                                    Icons.music_note,
                                    color: AppColors.neutral300,
                                    size: 64,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentTrack.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.15,
                                    color: AppColors.neutral0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentTrack.artist,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 0.4,
                                    color: _mutedIconColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleFavorite,
                            child: _liked
                                ? SvgPicture.asset(
                                    'assets/icons/player_like_circle.svg',
                                    width: 36,
                                    height: 36,
                                  )
                                : Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: AppColors.neutral600,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_border,
                                      color: AppColors.neutral0,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 13,
                        ),
                      ),
                      child: Slider(
                        value: _duration.inMilliseconds == 0
                            ? 0
                            : _position.inMilliseconds
                                  .clamp(0, _duration.inMilliseconds)
                                  .toDouble(),
                        max: _duration.inMilliseconds == 0
                            ? 1
                            : _duration.inMilliseconds.toDouble(),
                        activeColor: _playerAccentColor,
                        inactiveColor: AppColors.neutral500,
                        thumbColor: AppColors.neutral0,
                        onChanged: _audioLoaded
                            ? (value) => _player.seek(
                                Duration(milliseconds: value.round()),
                              )
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _time(_position),
                            style: AppTypography.caption.copyWith(
                              color: _mutedIconColor,
                            ),
                          ),
                          Text(
                            _time(_duration),
                            style: AppTypography.caption.copyWith(
                              color: _mutedIconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 42),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _svgControl(
                          'assets/icons/player_shuffle.svg',
                          width: 20,
                          height: 20,
                          color: _shuffle
                              ? _playerAccentColor
                              : _mutedIconColor,
                          onTap: () async {
                            final shuffle = !_shuffle;
                            setState(() => _shuffle = shuffle);
                            await _player.setShuffleModeEnabled(shuffle);
                          },
                        ),
                        const SizedBox(width: 24),
                        _seekButton(previous: true),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _togglePlayback,
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: _playerAccentColor,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : _playing
                                  ? _pauseIcon()
                                  : const Icon(
                                      Icons.play_arrow_rounded,
                                      color: _mutedIconColor,
                                      size: 56,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        _seekButton(previous: false),
                        const SizedBox(width: 24),
                        _svgControl(
                          'assets/icons/player_repeat.svg',
                          width: 22,
                          height: 22,
                          color: _repeat ? _playerAccentColor : _mutedIconColor,
                          onTap: () async {
                            final repeat = !_repeat;
                            setState(() => _repeat = repeat);
                            await _player.setLoopMode(
                              repeat ? LoopMode.one : LoopMode.off,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 56),
                    _actionMenu(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: AppColors.neutral900,
          child: _bottomNavigationBar(context),
        ),
      ),
    );
  }

  Widget _actionMenu() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _actionItem('assets/icons/player_add.svg', 'Add', 18, 18),
          _actionItem('assets/icons/player_download.svg', 'Download', 21, 21),
          _actionItem('assets/icons/player_mod.svg', 'Mod', 18, 21),
          _actionItem('assets/icons/player_queue.svg', 'Queue', 24, 18),
        ],
      ),
    );
  }

  Widget _actionItem(String asset, String label, double width, double height) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showMessage('$label: función pendiente.'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: width,
              height: height,
              colorFilter: const ColorFilter.mode(
                _mutedIconColor,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: _mutedIconColor,
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavigationBar(BuildContext context) {
    return Container(
      height: 60,
      color: AppColors.neutral900,
      child: Row(
        children: [
          _navigationItem(
            context,
            'assets/icons/home.svg',
            'Home',
            widget.selectedNavigationIndex == 0,
          ),
          _navigationItem(
            context,
            'assets/icons/discover.svg',
            'Discover',
            widget.selectedNavigationIndex == 1,
          ),
          _navigationItem(
            context,
            'assets/icons/library.svg',
            'Library',
            widget.selectedNavigationIndex == 2,
          ),
          _navigationItem(
            context,
            'assets/icons/search.svg',
            'Search',
            widget.selectedNavigationIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _navigationItem(
    BuildContext context,
    String asset,
    String label,
    bool selected,
  ) {
    final color = selected ? _playerAccentColor : _mutedIconColor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (label == 'Home') {
            Navigator.pop(context);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: 21,
              height: 21,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(String asset, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: SvgPicture.asset(asset, width: 36, height: 36),
    );
  }

  Widget _pauseIcon() {
    return SizedBox(
      width: 33,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 14,
            height: 40,
            decoration: BoxDecoration(
              color: _playerAccentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 14,
            height: 40,
            decoration: BoxDecoration(
              color: _playerAccentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seekButton({required bool previous}) {
    return GestureDetector(
      onTap: () {
        if (previous && widget.queue.isNotEmpty && _currentQueueIndex > 0) {
          _playAdjacentTrack(-1);
        } else if (previous) {
          _player.seek(Duration.zero);
        } else if (widget.queue.isNotEmpty) {
          _playAdjacentTrack(1);
        } else {
          _showMessage('No hay otra canción en la cola.');
        }
      },
      child: SizedBox(
        width: 28,
        height: 24,
        child: Center(
          child: Transform.flip(
            flipX: previous,
            child: SvgPicture.asset(
              'assets/icons/player_seek.svg',
              width: 28,
              height: 21,
              colorFilter: const ColorFilter.mode(
                _mutedIconColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _svgControl(
    String asset, {
    required double width,
    required double height,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: 24,
        child: Center(
          child: SvgPicture.asset(
            asset,
            width: width,
            height: height,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
