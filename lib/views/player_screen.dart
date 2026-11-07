import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.audioPlayer,
    required this.title,
    required this.artist,
    required this.imageUrl,
    required this.audioUrl,
  });

  final AudioPlayer audioPlayer;
  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  AudioPlayer get _player => widget.audioPlayer;

  bool _liked = true;
  bool _loading = false;
  bool _audioLoaded = false;
  bool _playing = false;
  bool _shuffle = false;
  bool _repeat = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  static const _playerAccentColor = Color(0xFF765FFF);
  static const _mutedIconColor = Color(0xFFC9C9CE);

  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<Duration> _positionSubscription;

  @override
  void initState() {
    super.initState();

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

    _loadAudio(autoplay: true);
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadAudio({
    bool autoplay = false,
    bool notifyMissing = false,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      var url = widget.audioUrl;

      // El formulario del profesor guarda los audios en esta colección.
      if (url.isEmpty) {
        final audios = await FirebaseFirestore.instance
            .collection('audios')
            .where('titulo', isEqualTo: widget.title)
            .limit(1)
            .get();

        if (audios.docs.isNotEmpty) {
          url = (audios.docs.first.data()['url'] ?? '').toString();
        }
      }

      if (url.isEmpty) {
        if (notifyMissing) {
          _showMessage('Todavía no hay un archivo de audio para esta canción.');
        }
        return;
      }

      // Home y esta pantalla comparten el mismo AudioPlayer. Si ya tiene
      // cargada esta canción, no volvemos a asignarla ni reiniciamos su tiempo.
      final currentSource = _player.audioSource;
      if (currentSource is UriAudioSource &&
          currentSource.uri.toString() == url) {
        if (mounted) setState(() => _audioLoaded = true);
        return;
      }

      await _player.setUrl(url);
      if (!mounted) return;
      setState(() => _audioLoaded = true);

      if (autoplay) _player.play();
    } catch (error) {
      if (notifyMissing) {
        _showMessage('No se pudo cargar el audio: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                .min(
                  (constraints.maxWidth - 36) * 0.855,
                  constraints.maxHeight * 0.54,
                )
                .toDouble();

            return SingleChildScrollView(
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
                  SizedBox(
                    height: (constraints.maxHeight * 0.06)
                        .clamp(24.0, 48.0)
                        .toDouble(),
                  ),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.radius500),
                      child: SizedBox(
                        width: coverSize,
                        height: coverSize,
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
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
                  SizedBox(
                    height: (constraints.maxHeight * 0.045)
                        .clamp(20.0, 36.0)
                        .toDouble(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
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
                                widget.artist,
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
                          onTap: () => setState(() => _liked = !_liked),
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
                  SizedBox(
                    height: (constraints.maxHeight * 0.035)
                        .clamp(16.0, 28.0)
                        .toDouble(),
                  ),
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
                  SizedBox(
                    height: (constraints.maxHeight * 0.055)
                        .clamp(24.0, 42.0)
                        .toDouble(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _svgControl(
                        'assets/icons/player_shuffle.svg',
                        width: 20,
                        height: 20,
                        color: _shuffle ? _playerAccentColor : _mutedIconColor,
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
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionMenu(),
          const SizedBox(height: 52),
          Container(
            color: const Color(0xFF07070A),
            child: SafeArea(top: false, child: _bottomNavigationBar(context)),
          ),
        ],
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
      color: const Color(0xFF07070A),
      child: Row(
        children: [
          _navigationItem(context, 'assets/icons/home.svg', 'Home', false),
          _navigationItem(
            context,
            'assets/icons/discover.svg',
            'Discover',
            false,
          ),
          _navigationItem(context, 'assets/icons/library.svg', 'Library', true),
          _navigationItem(context, 'assets/icons/search.svg', 'Search', false),
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
        if (previous) {
          _player.seek(Duration.zero);
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
