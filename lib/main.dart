import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:just_audio/just_audio.dart';

import 'auth/auth_gate.dart';
import 'firebase_options.dart';
import 'theme/theme.dart';
import 'views/player_screen.dart';
import 'views/playlists.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audiomack',
      theme: audioMack,
      home: const AuthGate(),
    );
  }
}

// Datos sencillos para pasar una canción desde Home al reproductor.
class Song {
  const Song({
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.audioUrl = '',
  });

  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;

  factory Song.fromMap(Map<String, dynamic> data) {
    return Song(
      title: (data['title'] ?? data['titulo'] ?? 'Sin título').toString(),
      artist: (data['artist'] ?? data['subtitulo'] ?? 'Desconocido').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Song? _currentSong;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: IndexedStack(
        index: _selectedIndex == 2 ? 1 : 0,
        children: [
          _homeContent(colors),
          PlaylistsView(
            audioPlayer: _audioPlayer,
            embedded: true,
            onPlaylistSaved: () => setState(() => _selectedIndex = 2),
            onSongSelected: (title, artist, imageUrl, audioUrl) {
              setState(() {
                _currentSong = Song(
                  title: title,
                  artist: artist,
                  imageUrl: imageUrl,
                  audioUrl: audioUrl,
                );
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_miniPlayerInBar(context), _navigationBar(colors)],
      ),
    );
  }

  Widget _homeContent(ColorScheme colors) => SafeArea(
    bottom: false,
    child: Column(
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
                _roundAction(Icons.notifications_none, colors),
                const SizedBox(width: 8),
                _roundAction(Icons.person_outline, colors),
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
                'Home',
                style: AppTypography.headline1.copyWith(color: Colors.white),
              ),
            ),
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
                  child: Text('Error al cargar las canciones'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary500),
                );
              }

              final songs = snapshot.data!.docs;
              final topPicks =
                  songs.where((doc) {
                    return doc.data()['homeSection'] == 'topPicks';
                  }).toList()..sort(
                    (a, b) => _order(a.data()).compareTo(_order(b.data())),
                  );
              final recent =
                  songs.where((doc) {
                    final data = doc.data();
                    final song = Song.fromMap(data);
                    return data['homeSection'] == 'recentlyPlayed' ||
                        (song.title == 'Hello' && song.artist == 'Adele');
                  }).toList()..sort(
                    (a, b) => _order(a.data()).compareTo(_order(b.data())),
                  );
              final madeForYou = songs.where((doc) {
                final song = Song.fromMap(doc.data());
                return song.title == 'Baby' && song.artist == 'Justin Bieber';
              }).toList();
              final favoriteArtists = madeForYou
                  .map((doc) => Song.fromMap(doc.data()).artist)
                  .toSet()
                  .toList();

              return ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  overscroll: false,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
                  children: [
                    _buildSongSection(
                      'Top picks for you',
                      topPicks,
                      wide: true,
                    ),
                    const SizedBox(height: 18),
                    _buildSongSection(
                      'Recently played',
                      recent,
                      subtitle: 'Based on what you hear',
                    ),
                    const SizedBox(height: 32),
                    _buildSongSection('Made for you', madeForYou),
                    const SizedBox(height: 32),
                    _buildArtistSection(favoriteArtists),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  int _order(Map<String, dynamic> data) =>
      data['homeOrder'] is int ? data['homeOrder'] as int : 0;

  Widget _roundAction(IconData icon, ColorScheme colors) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colors.onSurface, size: 20),
    );
  }

  Widget _buildSongSection(
    String title,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> songs, {
    bool wide = false,
    String? subtitle,
  }) {
    final imageWidth = wide ? 178.0 : 104.0;
    final albumSpacing = subtitle == null ? 16.0 : 24.0;
    final cardWidth = imageWidth + albumSpacing;
    final imageHeight = 104.0;
    final cardHeight = 161.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: subtitle == null ? 34 : 52,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.subtitle2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral300,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                'See all',
                style: AppTypography.body2.copyWith(
                  color: AppColors.primary400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = Song.fromMap(songs[index].data());
              return SizedBox(
                width: cardWidth,
                child: InkWell(
                  onTap: () => _openPlayer(context, song),
                  child: Padding(
                    padding: EdgeInsets.only(right: albumSpacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.radius200,
                          ),
                          child: SizedBox(
                            width: imageWidth,
                            height: imageHeight,
                            child: _cover(song.imageUrl),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label2.copyWith(
                            color: Colors.white,
                          ),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cover(String url) {
    if (url.isEmpty) {
      return Container(
        color: AppColors.neutral700,
        child: const Icon(Icons.music_note, color: AppColors.neutral300),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.neutral700,
        child: const Icon(Icons.music_note, color: AppColors.neutral300),
      ),
    );
  }

  Widget _buildArtistSection(List<String> artists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your favorite artist',
          style: AppTypography.subtitle2.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: 88,
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.neutral700,
                      child: Icon(
                        Icons.person,
                        color: AppColors.neutral300,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artists[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral300,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniPlayerInBar(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('canciones').snapshots(),
      builder: (context, snapshot) {
        Song song = const Song(
          title: 'Baby',
          artist: 'Justin Bieber',
          imageUrl: '',
        );
        if (snapshot.hasData) {
          final current = snapshot.data!.docs.where(
            (doc) => doc.data()['isMiniPlayerCurrent'] == true,
          );
          if (current.isNotEmpty) song = Song.fromMap(current.first.data());
        }
        song = _currentSong ?? song;
        final source = _audioPlayer.audioSource;
        if (source is UriAudioSource && snapshot.hasData) {
          final playingSong = snapshot.data!.docs.where(
            (doc) => doc.data()['audioUrl'] == source.uri.toString(),
          );
          if (playingSong.isNotEmpty) {
            song = Song.fromMap(playingSong.first.data());
          }
        }
        return StreamBuilder<PlayerState>(
          stream: _audioPlayer.playerStateStream,
          builder: (context, playerSnapshot) {
            final isPlaying = playerSnapshot.data?.playing ?? false;
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Container(
                height: 54,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.radius300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openPlayer(context, song),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: _cover(song.imageUrl),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.label2.copyWith(
                                      color: Colors.white,
                                    ),
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
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _toggleMiniPlayer(context, song),
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.primary500,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _navigationBar(ColorScheme colors) {
    return Container(
      color: colors.surfaceDim,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem('assets/icons/home.svg', 'Home', 0),
              _navItem('assets/icons/discover.svg', 'Discover', 1),
              _navItem('assets/icons/library.svg', 'Library', 2),
              _navItem('assets/icons/search.svg', 'Search', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String asset, String label, int index) {
    final selected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index == 0 || index == 2) {
            setState(() => _selectedIndex = index);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  index == 1
                      ? 'Discover todavía no está disponible.'
                      : 'Search todavía no está disponible.',
                ),
              ),
            );
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                selected ? AppColors.primary500 : AppColors.neutral300,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? Colors.white : AppColors.neutral300,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, Song song) {
    setState(() => _currentSong = song);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          audioPlayer: _audioPlayer,
          title: song.title,
          artist: song.artist,
          imageUrl: song.imageUrl,
          audioUrl: song.audioUrl,
        ),
        transitionsBuilder: (_, _, _, child) => child,
      ),
    );
  }

  Future<void> _toggleMiniPlayer(BuildContext context, Song song) async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      return;
    }

    try {
      setState(() => _currentSong = song);
      final started = await playAudioTrack(
        _audioPlayer,
        title: song.title,
        audioUrl: song.audioUrl,
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
          SnackBar(content: Text('No se pudo reproducir la canción: $error')),
        );
      }
    }
  }
}
