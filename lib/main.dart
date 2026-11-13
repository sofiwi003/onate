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
    this.id = '',
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.audioUrl = '',
  });

  final String id;
  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;

  factory Song.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return Song(
      id: id,
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
  String? _selectedGenre;
  String _selectedMood = 'Echo';
  Song? _currentSong;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _markRecentlyPlayed(Song song) async {
    try {
      final documents = await FirebaseFirestore.instance
          .collection('canciones')
          .get();
      for (final document in documents.docs) {
        final savedSong = Song.fromMap(document.data());
        if (savedSong.title == song.title && savedSong.artist == song.artist) {
          await document.reference.update({
            'lastPlayedAt': FieldValue.serverTimestamp(),
          });
          return;
        }
      }
    } catch (_) {
      // No impide reproducir si falla guardar el historial.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _homeContent(colors),
          _discoverContent(colors),
          PlaylistsView(
            audioPlayer: _audioPlayer,
            embedded: true,
            onPlaylistSaved: () => setState(() => _selectedIndex = 2),
            onSongSelected: (title, artist, imageUrl, audioUrl, songId) {
              final song = Song(
                id: songId,
                title: title,
                artist: artist,
                imageUrl: imageUrl,
                audioUrl: audioUrl,
              );
              setState(() => _currentSong = song);
              _markRecentlyPlayed(song);
            },
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentSong != null) _miniPlayerInBar(context),
          _navigationBar(colors),
        ],
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
                style: AppTypography.headline1.copyWith(
                  color: AppColors.neutral0,
                ),
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
                    final song = Song.fromMap(data, id: doc.id);
                    return data['lastPlayedAt'] != null ||
                        data['homeSection'] == 'recentlyPlayed' ||
                        (song.title == 'Hello' && song.artist == 'Adele');
                  }).toList()..sort((a, b) {
                    final aPlayed = a.data()['lastPlayedAt'];
                    final bPlayed = b.data()['lastPlayedAt'];
                    if (aPlayed is Timestamp && bPlayed is Timestamp) {
                      return bPlayed.compareTo(aPlayed);
                    }
                    if (aPlayed is Timestamp) return -1;
                    if (bPlayed is Timestamp) return 1;
                    return _order(a.data()).compareTo(_order(b.data()));
                  });
              final madeForYou = songs.where((doc) {
                final song = Song.fromMap(doc.data(), id: doc.id);
                return song.title == 'Baby' && song.artist == 'Justin Bieber';
              }).toList();
              final favoriteArtists = madeForYou
                  .map((doc) => Song.fromMap(doc.data(), id: doc.id).artist)
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
                        color: AppColors.neutral0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral0,
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
              final song = Song.fromMap(
                songs[index].data(),
                id: songs[index].id,
              );
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
                            color: AppColors.neutral0,
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
          style: AppTypography.subtitle2.copyWith(color: AppColors.neutral0),
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

  String _genreForSong(Song song) {
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();
    if (artist.contains('katseye') || artist == 'bts') return 'K-pop';
    if (artist.contains('miki matsubara')) return 'J-pop';
    if (artist.contains('bad bunny') ||
        artist.contains('karol g') ||
        artist.contains('pablo chill-e')) {
      return 'Reggaeton';
    }
    if (artist.contains('chico trujillo')) return 'Cumbia';
    if (artist.contains('soda stereo') ||
        artist.contains('los bunkers') ||
        artist.contains('angine de poitrine')) {
      return 'Rock';
    }
    if (artist.contains('black sabbath')) {
      return 'Metal';
    }
    if (artist.contains('chic')) {
      return 'Disco / Funk';
    }
    if (artist.contains('bob marley')) {
      return 'Reggae';
    }
    if (artist.contains('chuck berry')) {
      return 'Rock & roll';
    }
    if (artist.contains('adele') ||
        artist.contains('katy perry') ||
        artist.contains('justin bieber') ||
        artist.contains('nsync')) {
      return 'Pop';
    }
    if (artist.contains('aretha franklin')) {
      return 'Soul';
    }
    if (artist.contains('michael jackson')) {
      return 'Pop';
    }
    if (artist.contains('mon laferte')) {
      return 'Pop latino';
    }
    if (artist.contains('the weeknd')) {
      return 'R&B';
    }
    if (title.contains('bby wow')) {
      return 'Reggaeton';
    }
    return 'Otros';
  }

  Widget _discoverContent(ColorScheme colors) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _selectedMood == 'Pulse'
            ? [AppColors.pulse500, AppColors.pulse800]
            : _selectedMood == 'Bloom'
            ? [AppColors.bloom500, AppColors.bloom800]
            : [AppColors.echo500, AppColors.echo800],
        stops: const [0.2, 1],
      ),
    ),
    child: SafeArea(
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
                    child: Image.asset('assets/images/logo.png'),
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
                  'Discover',
                  style: AppTypography.headline1.copyWith(
                    color: AppColors.neutral0,
                  ),
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
                    child: Text('No se pudieron cargar las canciones'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary500,
                    ),
                  );
                }
                final songs = snapshot.data!.docs
                    .map((doc) => Song.fromMap(doc.data(), id: doc.id))
                    .toList();
                final genres =
                    songs
                        .map(_genreForSong)
                        .toSet()
                        .where((g) => g != 'Otros')
                        .toList()
                      ..sort();
                const genreOrder = ['Pop', 'Reggaeton'];
                genres.sort((a, b) {
                  final aRank = genreOrder.indexOf(a);
                  final bRank = genreOrder.indexOf(b);
                  if (aRank >= 0 || bRank >= 0) {
                    if (aRank < 0) return 1;
                    if (bRank < 0) return -1;
                    return aRank.compareTo(bRank);
                  }
                  return a.compareTo(b);
                });
                final filtered = _selectedGenre == null
                    ? songs
                    : songs
                          .where((s) => _genreForSong(s) == _selectedGenre)
                          .toList();
                final rock = songs
                    .where(
                      (s) => [
                        'Rock',
                        'Rock & roll',
                        'Metal',
                      ].contains(_genreForSong(s)),
                    )
                    .toList();
                final pop = songs
                    .where(
                      (s) => [
                        'Pop',
                        'Pop latino',
                        'K-pop',
                        'J-pop',
                      ].contains(_genreForSong(s)),
                    )
                    .toList();
                final extraGenres = genres
                    .where(
                      (g) => ![
                        'Rock',
                        'Rock & roll',
                        'Metal',
                        'Pop',
                        'Pop latino',
                        'K-pop',
                        'J-pop',
                      ].contains(g),
                    )
                    .toList();
                final sections = _selectedGenre != null
                    ? [
                        (
                          _selectedGenre!,
                          'Explore ${_selectedGenre!} music',
                          filtered,
                        ),
                      ]
                    : [
                        ('Rock', 'Turn it up and feel the power', rock),
                        ('Pop', 'The new of the moment', pop),
                        ...extraGenres.map(
                          (genre) => (
                            genre,
                            'Explore more ${genre.toLowerCase()} music',
                            songs
                                .where((s) => _genreForSong(s) == genre)
                                .toList(),
                          ),
                        ),
                      ];
                return ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    overscroll: false,
                  ),
                  child: ListView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    clipBehavior: Clip.hardEdge,
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 22),
                    children: [
                      SizedBox(
                        height: 54,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            const SizedBox(width: 28),
                            _discoverFilter('Genre'),
                            ...[
                              ...(_selectedGenre == null
                                  ? <String>[]
                                  : <String>[_selectedGenre!]),
                              ...genres.where((g) => g != _selectedGenre),
                            ].map(
                              (genre) => GestureDetector(
                                onTap: () => setState(
                                  () => _selectedGenre = _selectedGenre == genre
                                      ? null
                                      : genre,
                                ),
                                child: _discoverFilter(
                                  genre,
                                  selected: _selectedGenre == genre,
                                ),
                              ),
                            ),
                            _discoverFilter('Mood'),
                            _discoverFilter('BPM'),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            color: _selectedMood == 'Echo'
                                ? AppColors.echo700
                                : _selectedMood == 'Pulse'
                                ? AppColors.pulse700
                                : AppColors.bloom700,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: ['Echo', 'Pulse', 'Bloom']
                                .map(
                                  (m) => GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedMood = m),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedMood == m
                                            ? AppColors.primary500
                                            : AppColors.transparent,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        m,
                                        style: TextStyle(
                                          color: _selectedMood == m
                                              ? AppColors.neutral0
                                              : AppColors.neutral200,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (var i = 0; i < sections.length; i++) ...[
                        _discoverSection(
                          sections[i].$1,
                          sections[i].$2,
                          sections[i].$3,
                        ),
                        if (i != sections.length - 1)
                          const SizedBox(height: 32),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _discoverFilter(String label, {bool selected = false}) {
    final outlineColor = _selectedMood == 'Pulse'
        ? AppColors.pulse700
        : _selectedMood == 'Bloom'
        ? AppColors.bloom700
        : AppColors.echo700;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.transparent,
          border: selected ? null : Border.all(color: outlineColor, width: 1.4),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.neutral0,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _discoverSection(String title, String subtitle, List<Song> songs) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.subtitle2.copyWith(
                          color: AppColors.neutral0,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral100,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'See all',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral0,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 148,
            child: ListView.builder(
              primary: false,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SizedBox(
                  width: 132,
                  height: 148,
                  child: GestureDetector(
                    onTap: () => _openPlayer(context, song),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox.square(
                              dimension: 104,
                              child: _cover(song.imageUrl),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label2.copyWith(
                              color: AppColors.neutral0,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral0,
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

  Widget _miniPlayerInBar(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('canciones').snapshots(),
      builder: (context, snapshot) {
        Song? song = _currentSong;
        final source = _audioPlayer.audioSource;
        if (source is UriAudioSource && snapshot.hasData) {
          final playingSong = snapshot.data!.docs.where(
            (doc) => doc.data()['audioUrl'] == source.uri.toString(),
          );
          if (playingSong.isNotEmpty) {
            song = Song.fromMap(
              playingSong.first.data(),
              id: playingSong.first.id,
            );
          }
        }
        if (song == null) return const SizedBox.shrink();
        final selectedSong = song;
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
                        onTap: () => _openPlayer(context, selectedSong),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: _cover(selectedSong.imageUrl),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedSong.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.label2.copyWith(
                                      color: AppColors.neutral0,
                                    ),
                                  ),
                                  Text(
                                    selectedSong.artist,
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
                      onPressed: () => _toggleMiniPlayer(context, selectedSong),
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
          if (index < 3) setState(() => _selectedIndex = index);
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
                color: selected ? AppColors.neutral0 : AppColors.neutral300,
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
    _markRecentlyPlayed(song);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          audioPlayer: _audioPlayer,
          songId: song.id,
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
      await _markRecentlyPlayed(song);
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
