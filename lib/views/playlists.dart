import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/theme.dart';
import 'player_screen.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({
    super.key,
    this.audioPlayer,
    this.embedded = false,
    this.onPlaylistSaved,
    this.onSongSelected,
  });

  final AudioPlayer? audioPlayer;
  final bool embedded;
  final VoidCallback? onPlaylistSaved;
  final void Function(
    String title,
    String artist,
    String imageUrl,
    String audioUrl,
    String songId,
  )?
  onSongSelected;

  static Widget _emptyCover() => Container(
    color: AppColors.neutral700,
    child: const Center(
      child: Icon(Icons.music_note_rounded, color: AppColors.neutral300),
    ),
  );

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  int _selectedTab = 2;
  bool _showCreateOptions = false;
  DocumentSnapshot<Map<String, dynamic>>? _openedPlaylist;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final content = _openedPlaylist == null
        ? SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 20),
                _tabs(),
                const SizedBox(height: 24),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      overscroll: false,
                    ),
                    child: _tabContent(uid),
                  ),
                ),
              ],
            ),
          )
        : _playlistDetail(_openedPlaylist!);

    if (widget.embedded) {
      return Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (_selectedTab == 2 && _openedPlaylist == null)
            Positioned(right: 16, bottom: 16, child: _createMenu()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral800,
      body: content,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selectedTab == 2 && _openedPlaylist == null
          ? _createMenu()
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_miniPlayer(), _bottomNavigation()],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const Spacer(),
                _headerAction(Icons.notifications_none),
                const SizedBox(width: 8),
                _headerAction(Icons.person_outline),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Library',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subtitle2.copyWith(
                  color: AppColors.neutral0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerAction(IconData icon) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.neutral700,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.neutral200, size: 20),
        ),
      ],
    );
  }

  Widget _tabs() {
    const labels = ['Songs', 'Artists', 'Playlists'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _selectedTab = index;
                _showCreateOptions = false;
                _openedPlaylist = null;
              }),
              child: Column(
                children: [
                  Text(
                    labels[index],
                    style: AppTypography.subtitle2.copyWith(
                      color: selected
                          ? AppColors.neutral0
                          : AppColors.neutral300,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: 56,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary500
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _tabContent(String? uid) {
    if (uid == null) {
      return const Center(child: Text('Inicia sesión para ver tu biblioteca'));
    }
    if (_selectedTab == 0) return _songsGrid(uid);
    if (_selectedTab == 1) return _artistsGrid();
    return _playlistsGrid(uid);
  }

  Widget _songsGrid(String uid) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message('No se pudieron cargar tus canciones');
          }
          if (!snapshot.hasData) return _loading();
          final songs = snapshot.data!.docs;
          if (songs.isEmpty) {
            return _message('No liked songs yet');
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: songs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final song = songs[index];
              final data = song.data();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPlayer(
                  (data['title'] ?? 'Sin título').toString(),
                  (data['artist'] ?? 'Artista').toString(),
                  (data['imageUrl'] ?? '').toString(),
                  (data['audioUrl'] ?? '').toString(),
                  song.id,
                ),
                child: _LibraryCard(
                  title: (data['title'] ?? 'Sin título').toString(),
                  subtitle: (data['artist'] ?? 'Artista').toString(),
                  imageUrl: (data['imageUrl'] ?? '').toString(),
                ),
              );
            },
          );
        },
      );

  Widget _artistsGrid() => const SizedBox.shrink();

  Widget _playlistsGrid(
    String uid,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('playlists')
        .where('userId', isEqualTo: uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _message('No se pudieron cargar las playlists');
      }
      if (!snapshot.hasData) return _loading();
      final playlists = snapshot.data!.docs;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: playlists.isEmpty ? 1 : playlists.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          if (playlists.isEmpty) {
            return GestureDetector(
              onTap: _openPlaylistForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.radius300),
                      child: Container(
                        color: AppColors.neutral700,
                        child: const Center(
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.neutral400,
                            size: 72,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'My playlist',
                    style: AppTypography.label1.copyWith(
                      color: AppColors.neutral0,
                    ),
                  ),
                ],
              ),
            );
          }
          final playlist = playlists[index].data();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _selectedTab = 2;
                _showCreateOptions = false;
                _openedPlaylist = playlists[index];
              });
            },
            child: _LibraryCard(
              title: (playlist['name'] ?? 'Playlist').toString(),
              subtitle: '${(playlist['songIds'] as List?)?.length ?? 0} songs',
              imageUrl: (playlist['coverUrl'] ?? '').toString(),
            ),
          );
        },
      );
    },
  );

  Widget _playlistDetail(DocumentSnapshot<Map<String, dynamic>> playlist) {
    final data = playlist.data() ?? <String, dynamic>{};
    final title = (data['name'] ?? 'Playlist').toString();
    final coverUrl = (data['coverUrl'] ?? '').toString();
    final songIds = (data['songIds'] as List? ?? [])
        .map((id) => id.toString())
        .toList();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _detailAction(
                  Icons.chevron_left_rounded,
                  () => setState(() => _openedPlaylist = null),
                ),
                Row(
                  children: [
                    _detailAction(
                      Icons.edit_rounded,
                      () => _openPlaylistForm(playlist: playlist),
                    ),
                    const SizedBox(width: 16),
                    _detailAction(
                      Icons.share_rounded,
                      () => _notAvailable('Compartir playlist'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: 68,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('canciones')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message('No se pudieron cargar las canciones');
                }
                if (!snapshot.hasData) return _loading();

                final songs =
                    snapshot.data!.docs
                        .where((song) => songIds.contains(song.id))
                        .toList()
                      ..sort(
                        (first, second) => songIds
                            .indexOf(first.id)
                            .compareTo(songIds.indexOf(second.id)),
                      );

                Future<void> playFromPlaylist(
                  QueryDocumentSnapshot<Map<String, dynamic>> document,
                ) async {
                  final song = document.data();
                  final songTitle =
                      (song['title'] ?? song['titulo'] ?? 'Sin título')
                          .toString();
                  final songArtist = (song['artist'] ?? song['subtitulo'] ?? '')
                      .toString();
                  final songImage = (song['imageUrl'] ?? '').toString();
                  final songAudio = (song['audioUrl'] ?? '').toString();
                  widget.onSongSelected?.call(
                    songTitle,
                    songArtist,
                    songImage,
                    songAudio,
                    document.id,
                  );
                  final player = widget.audioPlayer;
                  if (player == null) return;
                  final started = await playAudioTrack(
                    player,
                    title: songTitle,
                    audioUrl: songAudio,
                  );
                  if (!started && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No hay audio disponible para reproducir.',
                        ),
                      ),
                    );
                  }
                }

                final coverSize = (MediaQuery.sizeOf(context).width * 0.48)
                    .clamp(172.0, 224.0)
                    .toDouble();

                return ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    overscroll: false,
                  ),
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    clipBehavior: Clip.hardEdge,
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.radius300,
                          ),
                          child: SizedBox.square(
                            dimension: coverSize,
                            child: coverUrl.isEmpty
                                ? PlaylistsView._emptyCover()
                                : Image.network(coverUrl, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle1.copyWith(
                          color: AppColors.neutral0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created by me',
                        textAlign: TextAlign.center,
                        style: AppTypography.body1.copyWith(
                          color: AppColors.neutral300,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${songs.length} songs',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral300,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _roundPlaylistControl(
                            icon: Icons.shuffle_rounded,
                            onPressed: songs.isEmpty
                                ? null
                                : () => playFromPlaylist(songs.last),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary500,
                                  foregroundColor: AppColors.neutral0,
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: songs.isEmpty
                                    ? null
                                    : () => playFromPlaylist(songs.first),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 26,
                                ),
                                label: Text(
                                  'Play',
                                  style: AppTypography.subtitle2.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _roundPlaylistControl(
                            icon: Icons.download_rounded,
                            onPressed: () => _notAvailable('Descarga'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (songs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: _message(
                            'Esta playlist todavía no tiene canciones',
                          ),
                        ),
                      ...songs.map((document) {
                        final songData = document.data();
                        final songTitle =
                            (songData['title'] ??
                                    songData['titulo'] ??
                                    'Sin título')
                                .toString();
                        final songArtist =
                            (songData['artist'] ?? songData['subtitulo'] ?? '')
                                .toString();
                        final songImage = (songData['imageUrl'] ?? '')
                            .toString();
                        final songAudio = (songData['audioUrl'] ?? '')
                            .toString();
                        return InkWell(
                          onTap: () => _openPlayer(
                            songTitle,
                            songArtist,
                            songImage,
                            songAudio,
                            document.id,
                          ),
                          child: SizedBox(
                            height: 72,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.radius200,
                                  ),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: _cover(songImage),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        songTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.label1.copyWith(
                                          color: AppColors.neutral0,
                                        ),
                                      ),
                                      Text(
                                        songArtist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.body2.copyWith(
                                          color: AppColors.neutral300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.more_vert_rounded,
                                  color: AppColors.primary500,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailAction(IconData icon, VoidCallback onPressed) => Material(
    color: AppColors.neutral600,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: AppColors.neutral100, size: 24),
      ),
    ),
  );

  Widget _roundPlaylistControl({
    required IconData icon,
    required VoidCallback? onPressed,
  }) => Material(
    color: AppColors.neutral700,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Icon(
          icon,
          color: onPressed == null
              ? AppColors.neutral500
              : AppColors.neutral100,
          size: 24,
        ),
      ),
    ),
  );

  Widget _createMenu() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (_showCreateOptions) ...[
        _createOption(
          label: 'Create Playlist',
          icon: Icons.queue_music_rounded,
          onTap: () {
            setState(() => _showCreateOptions = false);
            _openPlaylistForm();
          },
        ),
        const SizedBox(height: 10),
        _createOption(
          label: 'Create Folder',
          icon: Icons.create_new_folder_rounded,
          onTap: () {
            setState(() => _showCreateOptions = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La creación de carpetas estará disponible más adelante.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
      FloatingActionButton(
        heroTag: 'library-create-fab',
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.neutral0,
        shape: const CircleBorder(),
        onPressed: () =>
            setState(() => _showCreateOptions = !_showCreateOptions),
        child: Icon(
          _showCreateOptions ? Icons.close_rounded : Icons.add,
          size: 34,
        ),
      ),
    ],
  );

  Widget _createOption({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: AppColors.neutral700,
    borderRadius: BorderRadius.circular(32),
    child: InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 13, 18, 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.body1.copyWith(color: AppColors.neutral0),
            ),
            const SizedBox(width: 16),
            Icon(icon, color: AppColors.neutral0, size: 24),
          ],
        ),
      ),
    ),
  );

  Widget _miniPlayer() {
    if (widget.audioPlayer == null) return const SizedBox(height: 8);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('canciones').snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? song;
        String? songId;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            if (data['isMiniPlayerCurrent'] == true ||
                ((data['title'] ?? data['titulo']) == 'Baby' &&
                    (data['artist'] ?? data['subtitulo']) == 'Justin Bieber')) {
              song = data;
              songId = doc.id;
              if (data['isMiniPlayerCurrent'] == true) break;
            }
          }
        }
        final title = (song?['title'] ?? song?['titulo'] ?? 'Baby').toString();
        final artist =
            (song?['artist'] ?? song?['subtitulo'] ?? 'Justin Bieber')
                .toString();
        final imageUrl = (song?['imageUrl'] ?? '').toString();
        final audioUrl = (song?['audioUrl'] ?? '').toString();
        final player = widget.audioPlayer!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Material(
            color: AppColors.neutral700,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: song == null
                            ? null
                            : () => _openPlayer(
                                title,
                                artist,
                                imageUrl,
                                audioUrl,
                                songId ?? '',
                              ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: _cover(imageUrl),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.label2.copyWith(
                                      color: AppColors.neutral0,
                                    ),
                                  ),
                                  Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.neutral300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (context, state) => IconButton(
                        onPressed: () async {
                          widget.onSongSelected?.call(
                            title,
                            artist,
                            imageUrl,
                            audioUrl,
                            songId ?? '',
                          );
                          if (state.data?.playing == true) {
                            await player.pause();
                          } else {
                            try {
                              final started = await playAudioTrack(
                                player,
                                title: title,
                                audioUrl: audioUrl,
                              );
                              if (!started && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Todavía no hay un archivo de audio para esta canción.',
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo reproducir la canción: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: Icon(
                          state.data?.playing == true
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.primary500,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomNavigation() => Container(
    color: AppColors.neutral900,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            _navItem(
              'assets/icons/home.svg',
              'Home',
              false,
              () => Navigator.of(context).pop(),
            ),
            _navItem(
              'assets/icons/discover.svg',
              'Discover',
              false,
              () => _notAvailable('Discover'),
            ),
            _navItem('assets/icons/library.svg', 'Library', true, () {}),
            _navItem(
              'assets/icons/search.svg',
              'Search',
              false,
              () => _notAvailable('Search'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _navItem(
    String asset,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            asset,
            width: 21,
            height: 21,
            colorFilter: ColorFilter.mode(
              selected ? AppColors.primary500 : AppColors.neutral200,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: selected ? AppColors.neutral0 : AppColors.neutral300,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cover(String imageUrl) => imageUrl.isEmpty
      ? Container(
          color: AppColors.neutral600,
          child: const Icon(
            Icons.music_note_rounded,
            color: AppColors.neutral300,
          ),
        )
      : Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.neutral600,
            child: const Icon(
              Icons.music_note_rounded,
              color: AppColors.neutral300,
            ),
          ),
        );

  Widget _loading() => const Center(
    child: CircularProgressIndicator(color: AppColors.primary500),
  );
  Widget _message(String text) => Center(
    child: Text(
      text,
      style: AppTypography.body2.copyWith(color: AppColors.neutral300),
    ),
  );

  Future<void> _openPlaylistForm({
    DocumentSnapshot<Map<String, dynamic>>? playlist,
  }) async {
    setState(() => _showCreateOptions = false);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radius400),
        ),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _PlaylistFormSheet(
          playlistId: playlist?.id,
          initialData: playlist?.data(),
        ),
      ),
    );
    if (saved != true || !mounted) return;

    if (playlist == null) {
      setState(() {
        _selectedTab = 2;
        _openedPlaylist = null;
        _showCreateOptions = false;
      });
      widget.onPlaylistSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist creada correctamente')),
      );
    } else {
      final updated = await playlist.reference.get();
      if (!mounted) return;
      setState(() {
        _selectedTab = 2;
        _openedPlaylist = updated;
        _showCreateOptions = false;
      });
      // Asegura que la navegación principal siga en Library al volver del sheet.
      widget.onPlaylistSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist actualizada correctamente')),
      );
    }
  }

  Future<void> _openPlayer(
    String title,
    String artist,
    String imageUrl,
    String audioUrl,
    String songId,
  ) async {
    final player = widget.audioPlayer;
    if (player == null) return;
    widget.onSongSelected?.call(title, artist, imageUrl, audioUrl, songId);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, animation, secondaryAnimation) => PlayerScreen(
          audioPlayer: player,
          songId: songId,
          title: title,
          artist: artist,
          imageUrl: imageUrl,
          audioUrl: audioUrl,
          selectedNavigationIndex: 2,
        ),
        transitionsBuilder: (_, _, _, child) => child,
      ),
    );
  }

  void _notAvailable(String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$section todavía no está disponible.')),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String imageUrl;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.radius300),
          child: SizedBox.expand(
            child: imageUrl.isEmpty
                ? Container(
                    color: AppColors.neutral700,
                    child: const Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        color: AppColors.neutral400,
                        size: 48,
                      ),
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.neutral700,
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: AppColors.neutral400,
                        size: 48,
                      ),
                    ),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.label1.copyWith(color: AppColors.neutral0),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: AppColors.neutral300),
      ),
    ],
  );
}

class _PlaylistSong {
  const _PlaylistSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String imageUrl;

  Map<String, String> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'imageUrl': imageUrl,
  };
}

class _PlaylistFormSheet extends StatefulWidget {
  const _PlaylistFormSheet({this.playlistId, this.initialData});

  final String? playlistId;
  final Map<String, dynamic>? initialData;

  @override
  State<_PlaylistFormSheet> createState() => _PlaylistFormSheetState();
}

class _PlaylistFormSheetState extends State<_PlaylistFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _cover;
  Uint8List? _coverBytes;
  List<_PlaylistSong> _selectedSongs = [];
  bool _private = true;
  bool _saving = false;
  bool _loadingSongs = false;

  bool get _editing => widget.playlistId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data == null) return;

    _nameController.text = (data['name'] ?? '').toString();
    _descriptionController.text = (data['description'] ?? '').toString();
    _private = data['isPrivate'] as bool? ?? true;
    final ids = (data['songIds'] as List? ?? []).map((id) => id.toString());
    _loadingSongs = ids.isNotEmpty;
    if (_loadingSongs) _loadPlaylistSongs(ids.toList());
  }

  Future<void> _loadPlaylistSongs(List<String> ids) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('canciones')
          .get();
      final songsById = <String, _PlaylistSong>{};
      for (final document in snapshot.docs) {
        if (!ids.contains(document.id)) continue;
        final data = document.data();
        songsById[document.id] = _PlaylistSong(
          id: document.id,
          title: (data['title'] ?? data['titulo'] ?? 'Sin título').toString(),
          artist: (data['artist'] ?? data['subtitulo'] ?? '').toString(),
          imageUrl: (data['imageUrl'] ?? '').toString(),
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedSongs = [
          for (final id in ids)
            if (songsById[id] != null) songsById[id]!,
        ];
      });
    } catch (_) {
      if (mounted) _showError('No se pudieron cargar las canciones guardadas.');
    } finally {
      if (mounted) setState(() => _loadingSongs = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _cover = image;
      _coverBytes = bytes;
    });
  }

  Future<void> _chooseSongs() async {
    final selected = await showModalBottomSheet<List<_PlaylistSong>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral800,
      builder: (_) => _SongPickerSheet(selectedSongs: _selectedSongs),
    );
    if (selected != null && mounted) {
      setState(() => _selectedSongs = selected);
    }
  }

  Future<String> _uploadCover() async {
    final image = _cover!;
    final bytes = _coverBytes!;
    final extension = image.name.split('.').last.toLowerCase();
    final safeName = _nameController.text.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final fileName =
        'canciones/playlist_${safeName}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final reference = FirebaseStorage.instance.ref().child(fileName);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  Future<void> _savePlaylist() async {
    if (_loadingSongs) {
      _showError('Espera a que se carguen las canciones de la playlist.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Inicia sesión para crear una playlist.');
      return;
    }

    setState(() => _saving = true);
    try {
      final coverUrl = _cover == null
          ? (widget.initialData?['coverUrl'] ?? '').toString()
          : await _uploadCover();
      final playlistData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverUrl': coverUrl,
        'isPrivate': _private,
        'songIds': _selectedSongs.map((song) => song.id).toList(),
        'songs': _selectedSongs.map((song) => song.toMap()).toList(),
      };

      if (_editing) {
        await FirebaseFirestore.instance
            .collection('playlists')
            .doc(widget.playlistId)
            .update(playlistData);
      } else {
        await FirebaseFirestore.instance.collection('playlists').add({
          ...playlistData,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError(
        _editing
            ? 'No se pudo actualizar la playlist: $error'
            : 'No se pudo crear la playlist: $error',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral800,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 101,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral500,
              borderRadius: BorderRadius.circular(AppRadius.radius300),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  _editing ? 'Edit playlist' : 'New playlist',
                  style: AppTypography.body1.copyWith(
                    color: AppColors.neutral0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: _saving ? null : () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.neutral700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.neutral0,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _saving ? null : _pickCover,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.radius300,
                              ),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: AppColors.neutral700,
                                  border: Border.all(
                                    color: AppColors.neutral600,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.radius300,
                                  ),
                                ),
                                child: _coverBytes != null
                                    ? Image.memory(
                                        _coverBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : ((widget.initialData?['coverUrl'] ?? '')
                                              .toString()
                                              .isNotEmpty
                                          ? Image.network(
                                              widget.initialData!['coverUrl']
                                                  .toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Center(
                                                    child: Icon(
                                                      Icons
                                                          .add_photo_alternate_outlined,
                                                      color:
                                                          AppColors.neutral300,
                                                      size: 32,
                                                    ),
                                                  ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                color: AppColors.neutral300,
                                                size: 32,
                                              ),
                                            )),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : _pickCover,
                            child: Text(
                              _cover == null
                                  ? ((widget.initialData?['coverUrl'] ?? '')
                                            .toString()
                                            .isNotEmpty
                                        ? 'Change cover'
                                        : 'Add cover')
                                  : 'Change cover',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral300,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('Name'),
                    TextFormField(
                      controller: _nameController,
                      maxLength: 40,
                      style: AppTypography.body2.copyWith(
                        color: AppColors.neutral0,
                      ),
                      decoration: _inputDecoration('My new playlist'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a playlist name'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _fieldLabel('Description'),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      maxLength: 120,
                      style: AppTypography.body2.copyWith(
                        color: AppColors.neutral0,
                      ),
                      decoration: _inputDecoration('Add a description'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Private playlist',
                                style: AppTypography.label1.copyWith(
                                  color: AppColors.neutral0,
                                ),
                              ),
                              Text(
                                'Only you will be able to see it',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.neutral300,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _saving
                              ? null
                              : () => setState(() => _private = !_private),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 26,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _private
                                  ? AppColors.primary500
                                  : AppColors.neutral600,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Align(
                              alignment: _private
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: AppColors.neutral0,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _saving || _loadingSongs ? null : _chooseSongs,
                      borderRadius: BorderRadius.circular(AppRadius.radius200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.neutral700,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: AppColors.primary400,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _loadingSongs
                                  ? 'Loading saved songs…'
                                  : _selectedSongs.isEmpty
                                  ? 'Add songs'
                                  : 'Add or remove songs (${_selectedSongs.length})',
                              style: AppTypography.body2.copyWith(
                                color: AppColors.neutral0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedSongs.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ..._selectedSongs.map(_selectedSongTile),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving || _loadingSongs ? null : _savePlaylist,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.neutral0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radius500),
                  ),
                  elevation: 3,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neutral0,
                        ),
                      )
                    : Text(_editing ? 'Save changes' : 'Create playlist'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: AppTypography.caption.copyWith(color: AppColors.neutral300),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.body2.copyWith(color: AppColors.neutral400),
    counterText: '',
    filled: true,
    fillColor: AppColors.neutral700,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radius200),
      borderSide: const BorderSide(color: AppColors.neutral600),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radius200),
      borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radius200),
      borderSide: const BorderSide(color: AppColors.error500),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radius200),
      borderSide: const BorderSide(color: AppColors.error500),
    ),
  );

  Widget _selectedSongTile(_PlaylistSong song) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.radius100),
          child: SizedBox(
            width: 36,
            height: 36,
            child: song.imageUrl.isEmpty
                ? PlaylistsView._emptyCover()
                : Image.network(song.imageUrl, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label2.copyWith(color: AppColors.neutral0),
              ),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral300,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(
            () => _selectedSongs.removeWhere((item) => item.id == song.id),
          ),
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.neutral300,
        ),
      ],
    ),
  );
}

class _SongPickerSheet extends StatefulWidget {
  const _SongPickerSheet({required this.selectedSongs});

  final List<_PlaylistSong> selectedSongs;

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  late final Map<String, _PlaylistSong> _selected = {
    for (final song in widget.selectedSongs) song.id: song,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add songs',
                    style: AppTypography.subtitle1.copyWith(
                      color: AppColors.neutral0,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, _selected.values.toList()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary400,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('canciones')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar las canciones'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No hay canciones disponibles'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final document = snapshot.data!.docs[index];
                    final data = document.data();
                    final song = _PlaylistSong(
                      id: document.id,
                      title: (data['title'] ?? data['titulo'] ?? 'Sin título')
                          .toString(),
                      artist:
                          (data['artist'] ?? data['subtitulo'] ?? 'Desconocido')
                              .toString(),
                      imageUrl: (data['imageUrl'] ?? '').toString(),
                    );
                    final checked = _selected.containsKey(song.id);

                    return CheckboxListTile(
                      value: checked,
                      activeColor: AppColors.primary500,
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selected[song.id] = song;
                        } else {
                          _selected.remove(song.id);
                        }
                      }),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppRadius.radius100,
                        ),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: song.imageUrl.isEmpty
                              ? PlaylistsView._emptyCover()
                              : Image.network(
                                  song.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      PlaylistsView._emptyCover(),
                                ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: AppTypography.body2.copyWith(
                          color: AppColors.neutral0,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral300,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
