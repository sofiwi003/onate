import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  String? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  } catch (error, stackTrace) {
    startupError = error.toString();
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
  }

  runApp(MainApp(startupError: startupError));

  // Native services are optional for the first frame. Initializing them
  // before runApp can leave Android showing only a black window if a plugin
  // stalls during startup.
  if (!kIsWeb && startupError == null) {
    _initializeNativeServices();
  }
}

Future<void> _initializeNativeServices() async {
  try {
    await GoogleSignIn.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Google Sign-In initialization failed: $error\n$stackTrace');
  }

  try {
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.music());
  } catch (error, stackTrace) {
    debugPrint('Audio session initialization failed: $error\n$stackTrace');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audiomack',
      theme: audioMack,
      home: startupError == null
          ? const AuthGate()
          : StartupErrorScreen(message: startupError!),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: AppMetrics.px42),
                const SizedBox(height: AppMetrics.px16),
                const Text(
                  'No se pudo iniciar Audiomack',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppFontSize.title, fontWeight: AppFontWeight.bold),
                ),
                const SizedBox(height: AppMetrics.px8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Song {
  const Song({
    this.id = '',
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.audioUrl = '',
    this.album = '',
    this.artistImageUrl = '',
    this.genre = '',
    this.releaseYear = 0,
    this.discoverSeason = '',
    this.bloomPrediction = false,
  });

  final String id;
  final String title;
  final String artist;
  final String imageUrl;
  final String audioUrl;
  final String album;
  final String artistImageUrl;
  final String genre;
  final int releaseYear;
  final String discoverSeason;
  final bool bloomPrediction;

  factory Song.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return Song(
      id: id,
      title: (data['title'] ?? data['titulo'] ?? 'Sin título').toString(),
      artist: _primaryArtistName(
        (data['artist'] ?? data['subtitulo'] ?? 'Desconocido').toString(),
      ),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      audioUrl: songAudioValue(data),
      album: (data['album'] ?? data['albumName'] ?? '').toString(),
      artistImageUrl: (data['artistImageUrl'] ?? '').toString(),
      genre: (data['genre'] ?? '').toString(),
      releaseYear: int.tryParse((data['releaseYear'] ?? '').toString()) ?? 0,
      discoverSeason: (data['discoverSeason'] ?? '').toString(),
      bloomPrediction: data['bloomPrediction'] == true,
    );
  }
}

String _primaryArtistName(String artist) {
  final trimmed = artist.trim();
  final normalized = trimmed.toLowerCase();
  if (normalized.startsWith('karol g')) return 'Karol G';
  if (normalized.startsWith('drake')) return 'Drake';
  final featuring = RegExp(
    r'\s+(?:ft\.?|feat\.?|featuring)\s+',
    caseSensitive: false,
  );
  final featuredArtist = featuring.firstMatch(trimmed);
  if (featuredArtist != null) {
    return trimmed.substring(0, featuredArtist.start).trim();
  }
  if (trimmed.contains(',')) return trimmed.split(',').first.trim();
  return trimmed;
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
  bool _isSearchOpen = false;
  bool _searchPanelMounted = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _markRecentlyPlayed(Song song) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || song.id.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recentlyPlayed')
          .doc(song.id)
          .set({
            'songId': song.id,
            'lastPlayedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final discoverBackground = _selectedIndex == 1
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _selectedMood == 'Pulse'
                  ? [AppColors.pulse500, AppColors.pulse800]
                  : _selectedMood == 'Bloom'
                  ? [AppColors.bloom500, AppColors.bloom800]
                  : [AppColors.echo500, AppColors.echo800],
              stops: const [AppLayout.gradientStartStop, AppLayout.gradientEndStop],
            ),
          )
        : BoxDecoration(color: colors.surface);

    return DecoratedBox(
      decoration: discoverBackground,
      child: Scaffold(
        backgroundColor: AppColors.transparent,
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _homeContent(colors),
                    _discoverContent(colors),
                    PlaylistsView(
                      audioPlayer: _audioPlayer,
                      embedded: true,
                      hasMiniPlayer: _currentSong != null,
                      onPlaylistSaved: () => setState(() => _selectedIndex = 2),
                      onSongSelected:
                          (title, artist, imageUrl, audioUrl, songId) {
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
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isSearchOpen,
                  child: GestureDetector(
                    onTap: _closeSearch,
                    child: AnimatedOpacity(
                      opacity: _isSearchOpen ? AppLayout.searchScrimOpacity : AppSpacing.spacing0,
                      duration: const Duration(milliseconds: 260),
                      child: const ColoredBox(color: AppColors.neutral900),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Duration(milliseconds: _isSearchOpen ? 340 : 260),
                curve: _isSearchOpen ? Curves.easeOutCubic : Curves.easeInCubic,
                left: AppSpacing.spacing0,
                right: AppSpacing.spacing0,
                bottom: AppSpacing.spacing0,
                height: _isSearchOpen ? constraints.maxHeight * AppLayout.searchSheetHeightFactor : 0,
                child: Offstage(
                  offstage: !_searchPanelMounted,
                  child: SearchSheet(
                    onClose: _closeSearch,
                    onPlaySong: (song) => _openPlayer(context, song),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentSong != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.spacing10),
                  child: _miniPlayerInBar(context),
                ),
              _navigationBar(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeContent(ColorScheme colors) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.spacing16, AppSpacing.spacing4, AppSpacing.spacing16, AppSpacing.spacing0),
          child: SizedBox(
            height: AppMetrics.px48,
            child: Row(
              children: [
                SizedBox(
                  width: AppMetrics.px40,
                  height: AppMetrics.px40,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const Spacer(),
                _roundAction(
                  Icons.notifications_none,
                  colors,
                  backgroundColor: AppColors.neutral700,
                ),
                const SizedBox(width: AppMetrics.px8),
                _roundAction(
                  Icons.person_outline,
                  colors,
                  backgroundColor: AppColors.neutral700,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: AppMetrics.px56,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing16),
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
              final topPickIds = topPicks.map((doc) => doc.id).toSet();
              final topPickArtists = topPicks
                  .map((doc) => Song.fromMap(doc.data()).artist)
                  .toSet();
              final additionalPicks = [...songs]
                ..sort((a, b) {
                  final order = _order(a.data()).compareTo(_order(b.data()));
                  if (order != 0) return order;
                  return Song.fromMap(
                    a.data(),
                  ).title.compareTo(Song.fromMap(b.data()).title);
                });
              for (final doc in additionalPicks) {
                if (topPicks.length >= 6) break;
                final artist = Song.fromMap(doc.data()).artist;
                if (!topPickIds.contains(doc.id) &&
                    topPickArtists.add(artist)) {
                  topPickIds.add(doc.id);
                  topPicks.add(doc);
                }
              }
              final madeForYou = songs
                  .where((doc) => doc.data()['homeSection'] == 'madeForYou')
                  .toList();
              final madeForYouIds = madeForYou.map((doc) => doc.id).toSet();
              final madeForYouArtists = madeForYou
                  .map((doc) => Song.fromMap(doc.data()).artist)
                  .toSet();
              for (final doc in additionalPicks) {
                if (madeForYou.length >= 6) break;
                final song = Song.fromMap(doc.data(), id: doc.id);
                if (!topPickIds.contains(doc.id) &&
                    madeForYouIds.add(doc.id) &&
                    !topPickArtists.contains(song.artist) &&
                    madeForYouArtists.add(song.artist)) {
                  madeForYou.add(doc);
                }
              }

              final userId = FirebaseAuth.instance.currentUser?.uid;
              final recentlyPlayedStream = userId == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('recentlyPlayed')
                        .orderBy('lastPlayedAt', descending: true)
                        .limit(10)
                        .snapshots();
              final favoritesStream = userId == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('favorites')
                        .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: recentlyPlayedStream,
                builder: (context, historySnapshot) {
                  final songsById = {for (final song in songs) song.id: song};
                  final recent = (historySnapshot.data?.docs ?? [])
                      .map((entry) => songsById[entry.id])
                      .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
                      .toList();
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: favoritesStream,
                    builder: (context, favoritesSnapshot) {
                      final favoriteArtists =
                          (favoritesSnapshot.data?.docs ?? [])
                              .map((doc) {
                                final favoriteSong = songsById[doc.id];
                                final artist = favoriteSong == null
                                    ? (doc.data()['artist'] ?? '').toString()
                                    : (favoriteSong.data()['artist'] ??
                                              favoriteSong
                                                  .data()['subtitulo'] ??
                                              '')
                                          .toString();
                                return _primaryArtistName(artist);
                              })
                              .where((artist) => artist.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort();
                      return ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          overscroll: false,
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                          },
                        ),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.spacing16, AppSpacing.spacing48, AppSpacing.spacing16, AppSpacing.spacing20),
                          children: [
                            _buildSongSection(
                              'Top picks for you',
                              topPicks,
                              wide: true,
                            ),
                            const SizedBox(height: AppMetrics.px18),
                            _buildSongSection(
                              'Recently played',
                              recent,
                              subtitle: 'Based on what you hear',
                            ),
                            const SizedBox(height: AppMetrics.px32),
                            _buildSongSection('Made for you', madeForYou),
                            if (favoriteArtists.isNotEmpty) ...[
                              const SizedBox(height: AppMetrics.px32),
                              _buildArtistSection(favoriteArtists, songs),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  int _order(Map<String, dynamic> data) =>
      data['homeOrder'] is int ? data['homeOrder'] as int : 0;

  Widget _roundAction(
    IconData icon,
    ColorScheme colors, {
    Color? backgroundColor,
  }) {
    return Container(
      width: AppMetrics.px38,
      height: AppMetrics.px38,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colors.onSurface, size: AppMetrics.px20),
    );
  }

  Color _moodIconBackground() {
    if (_selectedMood == 'Pulse') {
      return AppColors.pulse800;
    }
    if (_selectedMood == 'Bloom') {
      return AppColors.bloom800;
    }
    return AppColors.echo800;
  }

  Widget _buildSongSection(
    String title,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> songs, {
    bool wide = false,
    String? subtitle,
  }) {
    final imageWidth = wide ? AppMetrics.px178 : AppMetrics.px104;
    final albumSpacing = subtitle == null ? AppSpacing.spacing16 : AppSpacing.spacing24;
    final cardWidth = imageWidth + albumSpacing;
    final imageHeight = AppMetrics.px104;
    final cardHeight = AppMetrics.px161;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: subtitle == null ? AppLayout.homeCardHeightCompact : AppLayout.homeCardHeightRegular,
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
                      const SizedBox(height: AppMetrics.px2),
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
            findChildIndexCallback: (key) {
              final index = songs.indexWhere(
                (song) => ValueKey(song.id) == key,
              );
              return index < 0 ? null : index;
            },
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = Song.fromMap(
                songs[index].data(),
                id: songs[index].id,
              );
              return SizedBox(
                key: ValueKey(song.id),
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
                        const SizedBox(height: AppMetrics.px6),
                        Text(
                          song.title,
                          maxLines: AppLayout.singleLineText,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label2.copyWith(
                            color: AppColors.neutral0,
                          ),
                        ),
                        Text(
                          song.artist,
                          maxLines: AppLayout.singleLineText,
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
      key: ValueKey(url),
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.neutral700,
        child: const Icon(Icons.music_note, color: AppColors.neutral300),
      ),
    );
  }

  Widget _buildArtistSection(
    List<String> artists,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> songs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your favorite artist',
          style: AppTypography.subtitle2.copyWith(color: AppColors.neutral0),
        ),
        const SizedBox(height: AppMetrics.px16),
        SizedBox(
          height: AppMetrics.px104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artistName = artists[index];
              Song? representative;
              for (final document in songs) {
                final candidate = Song.fromMap(
                  document.data(),
                  id: document.id,
                );
                final candidateArtist = candidate.artist.toLowerCase();
                final favoriteArtist = artistName.toLowerCase();
                if (candidateArtist == favoriteArtist ||
                    candidateArtist.startsWith('$favoriteArtist,') ||
                    candidateArtist.startsWith('$favoriteArtist ')) {
                  if (representative == null ||
                      (representative.artistImageUrl.isEmpty &&
                          candidate.artistImageUrl.isNotEmpty)) {
                    representative = candidate;
                  }
                }
              }
              final artistImageUrl = representative?.artistImageUrl ?? '';
              return SizedBox(
                width: AppMetrics.px88,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: AppRadius.radius600,
                      backgroundColor: AppColors.neutral700,
                      child: artistImageUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: AppColors.neutral300,
                              size: AppMetrics.px32,
                            )
                          : ClipOval(
                              child: Image.network(
                                artistImageUrl,
                                width: AppMetrics.px64,
                                height: AppMetrics.px64,
                                fit: BoxFit.cover,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.fallback,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person,
                                  color: AppColors.neutral300,
                                  size: AppMetrics.px32,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: AppMetrics.px6),
                    Text(
                      artistName,
                      maxLines: AppLayout.singleLineText,
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
    if (song.genre.isNotEmpty) return song.genre;
    const genresBySong = <String, String>{
      'KfyrTMEVdbNVSQXqQJ1X': 'Pop',
      'ahora_quien': 'Cumbia',
      'angine_de_poitrine_sarniezz': 'Rock',
      'aretha_franklin_respect': 'Soul',
      'aventura_obsesion': 'Bachata',
      'bad_bunny_callaita': 'Reggaeton',
      'bad_bunny_weltita': 'Reggaeton',
      'belanova_rosa_pastel': 'Electropop',
      'black_sabbath_paranoid': 'Metal',
      'bob_marley_three_little_birds': 'Reggae',
      'bts_dynamite': 'K-pop',
      'chanel_jb_the_voice': 'Pop latino',
      'chic_good_times': 'Disco / Funk',
      'chuck_berry_johnny_be_goode': 'Rock & roll',
      'coldplay_yellow': 'Rock',
      'don_omar_virtual_diva': 'Reggaeton',
      'drake_one_dance': 'Dancehall',
      'eminem_the_monster': 'Hip-hop',
      'eminem_without_me': 'Hip-hop',
      'evanescence_bring_me_to_life': 'Rock',
      'gotye_somebody_that_i_used_to_know': 'Indie Pop',
      'grupo_la_noche_que_nadie_se_entere': 'Cumbia',
      'illit_magnetic': 'K-pop',
      'julieta_venegas_limon_y_sal': 'Pop latino',
      'justin_bieber_baby': 'Pop',
      'justin_bieber_never_say_never': 'Pop',
      'karol_g_bby_wow': 'Reggaeton',
      'katseye_gabriela': 'Pop',
      'katy_perry_roar': 'Pop',
      'leandro_leonardo_pense_em_mim': 'Sertanejo',
      'los_bunkers_bailando_solo': 'Rock',
      'los_jaivas_mira_ninita': 'Fusión de raíz folclórica',
      'marshmello_happier': 'Pop',
      'michael_jackson_billie_jean': 'Disco / Funk',
      'miki_matsubara_stay_with_me': 'J-pop',
      'milo_j_nino': 'Urbano latino',
      'mon_laferte_amarrame': 'Latin Alternative',
      'mon_laferte_tu_falta_de_querer': 'Latin Alternative',
      'noche_de_brujas_me_gusta_todo_de_ti': 'Cumbia',
      'nsync_bye_bye_bye': 'Pop',
      'oasis_wonderwall': 'Rock',
      'pablo_chill_e_gitana': 'Reggaeton',
      'pablo_chill_e_resentia': 'Reggaeton',
      'pablo_chill_e_shishigang': 'Urbano latino',
      'pitbull_kesha_timber': 'Pop',
      'pitbull_we_are_one': 'Pop latino',
      'queen_bohemian_rhapsody': 'Rock',
      'red_hot_chili_peppers_cant_stop': 'Rock',
      'red_hot_chili_peppers_dark_necessities': 'Rock',
      'rihanna_where_have_you_been': 'Pop',
      'smash_mouth_all_star': 'Rock',
      'soda_stereo_profugos': 'Rock',
      'system_of_a_down_chop_suey': 'Metal',
      'system_of_a_down_toxicity': 'Metal',
      'the_weeknd_starboy': 'R&B',
    };
    final mappedGenre = genresBySong[song.id];
    if (mappedGenre != null) return mappedGenre;
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();
    if (artist.contains('katseye') ||
        artist.contains('bts') ||
        artist.contains('illit')) {
      return 'K-pop';
    }
    if (artist.contains('miki matsubara')) return 'J-pop';
    if (artist.contains('bad bunny') ||
        artist.contains('karol g') ||
        artist.contains('pablo chill-e') ||
        artist.contains('milo j') ||
        artist.contains('don omar')) {
      return 'Reggaeton';
    }
    if (artist.contains('eminem')) return 'Hip-hop';
    if (artist.contains('chico trujillo') ||
        artist.contains('noche de brujas') ||
        artist.contains('grupo la noche')) {
      return 'Cumbia';
    }
    if (artist.contains('soda stereo') ||
        artist.contains('los bunkers') ||
        artist.contains('angine de poitrine') ||
        artist.contains('coldplay') ||
        artist.contains('evanescence') ||
        artist.contains('oasis') ||
        artist.contains('queen') ||
        artist.contains('red hot chili peppers') ||
        artist.contains('smash mouth')) {
      return 'Rock';
    }
    if (artist.contains('black sabbath') ||
        artist.contains('system of a down')) {
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
        artist.contains('nsync') ||
        artist.contains('gotye') ||
        artist.contains('rihanna') ||
        artist.contains('marshmello')) {
      return 'Pop';
    }
    if (artist.contains('belanova') ||
        artist.contains('julieta venegas') ||
        artist.contains('mon laferte') ||
        artist.contains('jb the voice')) {
      return 'Pop latino';
    }
    if (artist.contains('aventura')) return 'Bachata';
    if (artist.contains('aretha franklin')) {
      return 'Soul';
    }
    if (artist.contains('31 minutos')) {
      return 'Pop';
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

  Widget _discoverContent(ColorScheme colors) => SafeArea(
    bottom: false,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.spacing16, AppSpacing.spacing4, AppSpacing.spacing16, AppSpacing.spacing0),
          child: SizedBox(
            height: AppMetrics.px48,
            child: Row(
              children: [
                SizedBox(
                  width: AppMetrics.px40,
                  height: AppMetrics.px40,
                  child: Image.asset('assets/images/logo.png'),
                ),
                const Spacer(),
                _roundAction(
                  Icons.notifications_none,
                  colors,
                  backgroundColor: _moodIconBackground(),
                ),
                const SizedBox(width: AppMetrics.px8),
                _roundAction(
                  Icons.person_outline,
                  colors,
                  backgroundColor: _moodIconBackground(),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: AppMetrics.px56,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing16),
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
                  child: CircularProgressIndicator(color: AppColors.primary500),
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
              const genreOrder = ['Pop', 'Reggaeton', 'Urbano latino'];
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
              final sections = _discoverShelves(
                _selectedMood,
                songs,
                _selectedGenre,
              );
              return Column(
                children: [
                  const SizedBox(height: AppMetrics.px14),
                  SizedBox(
                    height: AppMetrics.px54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing16),
                      children: [...genres.map(_genreChip)],
                    ),
                  ),
                  const SizedBox(height: AppMetrics.px14),
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing40),
                      decoration: BoxDecoration(
                        color: _selectedMood == 'Echo'
                            ? AppColors.echo700
                            : _selectedMood == 'Pulse'
                            ? AppColors.pulse700
                            : AppColors.bloom700,
                        borderRadius: BorderRadius.circular(AppRadius.radius600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['Echo', 'Pulse', 'Bloom'].map((m) {
                          final selected = _selectedMood == m;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedMood = m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.spacing20,
                                vertical: AppSpacing.spacing13,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.actionPrimaryDefault
                                    : AppColors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.radius30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected) ...[
                                    Container(
                                      width: AppMetrics.px10,
                                      height: AppMetrics.px10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.neutral0,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: AppMetrics.px8),
                                  ],
                                  Text(
                                    m,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.neutral0
                                          : AppColors.neutral200,
                                      fontSize: AppFontSize.body,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppMetrics.px28),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        overscroll: false,
                      ),
                      child: ListView(
                        primary: false,
                        physics: const ClampingScrollPhysics(),
                        clipBehavior: Clip.hardEdge,
                        padding: const EdgeInsets.fromLTRB(AppSpacing.spacing0, AppSpacing.spacing0, AppSpacing.spacing0, AppSpacing.spacing22),
                        children: sections.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.spacing24),
                                  child: Text(
                                    'No songs in this season yet',
                                    style: AppTypography.body2.copyWith(
                                      color: AppColors.neutral100,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ]
                            : [
                                for (var i = 0; i < sections.length; i++) ...[
                                  _discoverSection(
                                    sections[i].$1,
                                    sections[i].$2,
                                    sections[i].$3,
                                  ),
                                  if (i != sections.length - 1)
                                    const SizedBox(height: AppMetrics.px32),
                                ],
                              ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  List<(String, String, List<Song>)> _discoverShelves(
    String mood,
    List<Song> songs,
    String? selectedGenre,
  ) {
    const releaseYears = <String, int>{
      'KfyrTMEVdbNVSQXqQJ1X': 2015,
      'ahora_quien': 2010,
      'angine_de_poitrine_sarniezz': 2026,
      'aretha_franklin_respect': 1967,
      'aventura_obsesion': 2002,
      'bad_bunny_callaita': 2019,
      'bad_bunny_weltita': 2025,
      'belanova_rosa_pastel': 2005,
      'black_sabbath_paranoid': 1970,
      'bob_marley_three_little_birds': 1977,
      'bts_dynamite': 2020,
      'chanel_jb_the_voice': 2025,
      'chic_good_times': 1979,
      'chuck_berry_johnny_be_goode': 1958,
      'coldplay_yellow': 2000,
      'don_omar_virtual_diva': 2009,
      'drake_one_dance': 2016,
      'eminem_the_monster': 2013,
      'eminem_without_me': 2002,
      'evanescence_bring_me_to_life': 2003,
      'gotye_somebody_that_i_used_to_know': 2011,
      'grupo_la_noche_que_nadie_se_entere': 2008,
      'illit_magnetic': 2024,
      'julieta_venegas_limon_y_sal': 2006,
      'justin_bieber_baby': 2010,
      'justin_bieber_never_say_never': 2010,
      'karol_g_bby_wow': 2026,
      'katseye_gabriela': 2025,
      'katy_perry_roar': 2013,
      'leandro_leonardo_pense_em_mim': 1990,
      'los_bunkers_bailando_solo': 2013,
      'los_jaivas_mira_ninita': 1972,
      'marshmello_happier': 2018,
      'michael_jackson_billie_jean': 1982,
      'miki_matsubara_stay_with_me': 1979,
      'milo_j_nino': 2024,
      'mon_laferte_amarrame': 2017,
      'mon_laferte_tu_falta_de_querer': 2015,
      'noche_de_brujas_me_gusta_todo_de_ti': 2011,
      'nsync_bye_bye_bye': 2000,
      'oasis_wonderwall': 1995,
      'pablo_chill_e_gitana': 2024,
      'pablo_chill_e_resentia': 2024,
      'pablo_chill_e_shishigang': 2016,
      'pitbull_kesha_timber': 2013,
      'pitbull_we_are_one': 2014,
      'queen_bohemian_rhapsody': 1975,
      'red_hot_chili_peppers_cant_stop': 2002,
      'red_hot_chili_peppers_dark_necessities': 2016,
      'rihanna_where_have_you_been': 2011,
      'smash_mouth_all_star': 1999,
      'soda_stereo_profugos': 1986,
      'system_of_a_down_chop_suey': 2001,
      'system_of_a_down_toxicity': 2002,
      'the_weeknd_starboy': 2016,
    };
    final periodSongs = songs.where((song) {
      final year = song.releaseYear > 0
          ? song.releaseYear
          : releaseYears[song.id] ?? 0;
      final explicitSeason = song.discoverSeason.trim().toLowerCase();
      final inPeriod = switch (mood) {
        'Pulse' =>
          explicitSeason == 'pulse' ||
              (explicitSeason.isEmpty &&
                  year >= 2022 &&
                  year <= DateTime.now().year),
        'Bloom' => song.bloomPrediction || explicitSeason == 'bloom',
        _ =>
          explicitSeason == 'echo' ||
              (explicitSeason.isEmpty && year > 0 && year < 2022),
      };
      return inPeriod &&
          (selectedGenre == null || _genreForSong(song) == selectedGenre);
    }).toList();

    final splitYear = switch (mood) {
      'Pulse' => 2022,
      'Bloom' => 2025,
      _ => 1980,
    };
    final firstIsNewer = mood != 'Echo';
    bool belongsInFirstShelf(Song song) {
      final year = song.releaseYear > 0
          ? song.releaseYear
          : releaseYears[song.id] ?? 0;
      return firstIsNewer ? year >= splitYear : year < splitYear;
    }

    List<Song> shelfSongs(bool first) {
      final shelf = periodSongs
          .where((song) => belongsInFirstShelf(song) == first)
          .toList();
      shelf.sort((a, b) {
        final genre = _genreForSong(a).compareTo(_genreForSong(b));
        return genre != 0 ? genre : a.title.compareTo(b.title);
      });
      return shelf;
    }

    final shelves = switch (mood) {
      'Pulse' => (
        ("What's playing now", 'Feel the moment right now'),
        ('Pop', 'The new of the moment'),
      ),
      'Bloom' => (
        ('The next boom', 'Turn it up and feel the power'),
        ('Beyond the day', 'Rhythms of the world'),
      ),
      _ => (
        ('Top: USA', 'Chart of trending songs this month'),
        ('Favorites of all times', 'Best Pop songs'),
      ),
    };
    return [
      (shelves.$1.$1, shelves.$1.$2, shelfSongs(true)),
      (shelves.$2.$1, shelves.$2.$2, shelfSongs(false)),
    ];
  }

  Widget _discoverFilter(String label, {bool selected = false}) {
    final outlineColor = _selectedMood == 'Pulse'
        ? AppColors.pulse700
        : _selectedMood == 'Bloom'
        ? AppColors.bloom700
        : AppColors.echo700;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.spacing8),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing14, vertical: AppSpacing.spacing6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.actionPrimaryDefault
                : AppColors.transparent,
            border: selected ? null : Border.all(color: outlineColor, width: AppMetrics.px1),
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.neutral0,
              fontSize: AppFontSize.bodySmall,
              fontWeight: AppFontWeight.semiBold,
              letterSpacing: AppLetterSpacing.body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _genreChip(String genre) => GestureDetector(
    onTap: () =>
        setState(() => _selectedGenre = _selectedGenre == genre ? null : genre),
    child: _discoverFilter(genre, selected: _selectedGenre == genre),
  );

  Widget _discoverSection(String title, String subtitle, List<Song> songs) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.spacing16, right: AppSpacing.spacing16),
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
                          fontSize: AppFontSize.titleLarge,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral100,
                          fontSize: AppFontSize.bodyCompact,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'See all',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral0,
                    fontSize: AppFontSize.bodyCompact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppMetrics.px18),
          SizedBox(
            height: AppMetrics.px148,
            child: ListView.builder(
              primary: false,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              findChildIndexCallback: (key) {
                final index = songs.indexWhere(
                  (song) => ValueKey(song.id) == key,
                );
                return index < 0 ? null : index;
              },
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SizedBox(
                  key: ValueKey(song.id),
                  width: AppMetrics.px132,
                  height: AppMetrics.px148,
                  child: GestureDetector(
                    onTap: () => _openPlayer(context, song),
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.spacing16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.radius200),
                            child: SizedBox.square(
                              dimension: AppMetrics.px104,
                              child: _cover(song.imageUrl),
                            ),
                          ),
                          const SizedBox(height: AppMetrics.px5),
                          Text(
                            song.title,
                            maxLines: AppLayout.singleLineText,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label2.copyWith(
                              color: AppColors.neutral0,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: AppLayout.singleLineText,
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
    final selectedSong = _currentSong;
    if (selectedSong == null) return const SizedBox.shrink();
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, playerSnapshot) {
        final isPlaying = playerSnapshot.data?.playing ?? false;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.spacing8, AppSpacing.spacing0, AppSpacing.spacing8, AppSpacing.spacing4),
          child: Container(
            height: AppMetrics.px54,
            padding: const EdgeInsets.all(AppSpacing.spacing6),
            decoration: BoxDecoration(
              color: AppColors.neutral700,
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
                          borderRadius: BorderRadius.circular(AppRadius.radius6),
                          child: SizedBox(
                            width: AppMetrics.px40,
                            height: AppMetrics.px40,
                            child: _cover(selectedSong.imageUrl),
                          ),
                        ),
                        const SizedBox(width: AppMetrics.px8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedSong.title,
                                maxLines: AppLayout.singleLineText,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label2.copyWith(
                                  color: AppColors.neutral0,
                                ),
                              ),
                              Text(
                                selectedSong.artist,
                                maxLines: AppLayout.singleLineText,
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
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.primary500,
                    size: AppMetrics.px28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: AppMetrics.px36,
                    height: AppMetrics.px40,
                  ),
                ),
              ],
            ),
          ),
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
          height: AppMetrics.px60,
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
    final selected = _isSearchOpen ? index == 3 : _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (index == 3) {
            if (_isSearchOpen) {
              _closeSearch();
            } else {
              setState(() {
                _searchPanelMounted = true;
                _isSearchOpen = true;
              });
            }
          } else {
            _closeSearch();
            setState(() => _selectedIndex = index);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: AppMetrics.px22,
              height: AppMetrics.px22,
              colorFilter: ColorFilter.mode(
                selected ? AppColors.primary500 : AppColors.neutral300,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: AppMetrics.px2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: selected ? AppColors.neutral0 : AppColors.neutral300,
                letterSpacing: AppLetterSpacing.navigation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeSearch() {
    if (!_isSearchOpen) return;
    setState(() => _isSearchOpen = false);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted && !_isSearchOpen) {
        setState(() => _searchPanelMounted = false);
      }
    });
  }

  Future<void> _openPlayer(BuildContext context, Song song) async {
    setState(() => _currentSong = song);
    _markRecentlyPlayed(song);
    try {
      final started = await playAudioTrack(
        _audioPlayer,
        title: song.title,
        audioUrl: song.audioUrl,
      );
      if (!started && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay un archivo de audio para esta canción.'),
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
    if (!context.mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          audioPlayer: _audioPlayer,
          songId: song.id,
          title: song.title,
          artist: song.artist,
          imageUrl: song.imageUrl,
          audioUrl: song.audioUrl,
          selectedNavigationIndex: _isSearchOpen ? 3 : _selectedIndex,
          onSongChanged: (track) {
            final selected = Song(
              id: track.id,
              title: track.title,
              artist: track.artist,
              imageUrl: track.imageUrl,
              audioUrl: track.audioUrl,
            );
            setState(() => _currentSong = selected);
            _markRecentlyPlayed(selected);
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(AppSpacing.spacing0, AppSpacing.spacing1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _toggleMiniPlayer(BuildContext context, Song song) async {
    try {
      final selectedUrl = await resolveSongAudioUrl(song.audioUrl);
      final source = _audioPlayer.audioSource;
      final isSelectedTrackPlaying =
          _audioPlayer.playing &&
          source is UriAudioSource &&
          source.uri.toString() == selectedUrl;
      if (isSelectedTrackPlaying) {
        await _audioPlayer.pause();
        return;
      }

      setState(() => _currentSong = song);
      await _markRecentlyPlayed(song);
      final started = await playAudioTrack(
        _audioPlayer,
        title: song.title,
        audioUrl: selectedUrl,
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

class SearchSheet extends StatefulWidget {
  const SearchSheet({
    required this.onClose,
    required this.onPlaySong,
    super.key,
  });

  final VoidCallback onClose;
  final ValueChanged<Song> onPlaySong;

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  static const _tabs = ['All', 'Songs', 'Artists', 'Albums'];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _songsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _recentSearchStream;
  String _selectedTab = 'All';
  bool _handleDragClosed = false;
  double _handleDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _songsStream = FirebaseFirestore.instance
        .collection('canciones')
        .snapshots();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _recentSearchStream = userId == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('recentSearches')
              .orderBy('updatedAt', descending: true)
              .limit(20)
              .snapshots();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _searchKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _matches(String value, String query) {
    final normalizedValue = _searchKey(value);
    final normalizedQuery = _searchKey(query);
    if (normalizedQuery.isEmpty) return false;
    return normalizedValue.startsWith(normalizedQuery) ||
        normalizedValue
            .split(' ')
            .any((word) => word.startsWith(normalizedQuery));
  }

  String _artistDisplayName(String artist) {
    return _primaryArtistName(artist);
  }

  Future<void> _saveRecent({
    required String title,
    String subtitle = '',
    String imageUrl = '',
    String kind = 'query',
    String songId = '',
    String searchTerm = '',
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || title.trim().isEmpty) return;

    final docKey = Uri.encodeComponent(
      '${kind}_${songId.isNotEmpty ? songId : title.toLowerCase()}',
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recentSearches')
        .doc(docKey)
        .set({
          'title': title.trim(),
          'subtitle': subtitle,
          'imageUrl': imageUrl,
          'kind': kind,
          'songId': songId,
          'searchTerm': searchTerm.isEmpty ? title.trim() : searchTerm,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _deleteRecent(String id) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recentSearches')
        .doc(id)
        .delete();
  }

  Future<void> _deleteAllRecent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final showTabs = query.isNotEmpty;

    return Material(
      color: AppColors.searchSurface,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: AppMetrics.px36,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                onVerticalDragStart: (_) {
                  _handleDragDistance = 0;
                  _handleDragClosed = false;
                },
                onVerticalDragUpdate: (details) {
                  _handleDragDistance += details.delta.dy;
                  if (_handleDragDistance > 56 && !_handleDragClosed) {
                    _handleDragClosed = true;
                    widget.onClose();
                  }
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 120 &&
                      !_handleDragClosed) {
                    widget.onClose();
                  }
                  _handleDragClosed = false;
                  _handleDragDistance = 0;
                },
                child: Center(
                  child: Container(
                    width: AppMetrics.px70,
                    height: AppMetrics.px4,
                    decoration: BoxDecoration(
                      color: AppColors.neutral400,
                      borderRadius: BorderRadius.circular(AppRadius.radius100),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.spacing20, AppSpacing.spacing14, AppSpacing.spacing20, AppSpacing.spacing14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Search', style: AppTypography.headline2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing18),
              child: SizedBox(
                height: AppMetrics.px44,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _saveRecent(title: value, searchTerm: value);
                    }
                  },
                  style: AppTypography.body2.copyWith(
                    color: AppColors.neutral0,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search songs & artists',
                    hintStyle: AppTypography.body2.copyWith(
                      color: AppColors.neutral200,
                    ),
                    filled: true,
                    fillColor: AppColors.searchField,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(AppSpacing.spacing13),
                      child: SvgPicture.asset(
                        'assets/icons/search.svg',
                        width: AppMetrics.px18,
                        height: AppMetrics.px18,
                      ),
                    ),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _controller.clear();
                              _selectedTab = 'All';
                              setState(() {});
                              _focusNode.requestFocus();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: AppMetrics.px16,
                              color: AppColors.neutral200,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spacing14,
                      vertical: AppSpacing.spacing10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radius28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radius28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radius28),
                      borderSide: const BorderSide(
                        color: AppColors.actionPrimaryDefault,
                        width: AppMetrics.px1_5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showTabs) _searchTabs(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _songsStream,
                builder: (context, songSnapshot) {
                  if (songSnapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Search is unavailable right now.',
                        style: TextStyle(color: AppColors.neutral300),
                      ),
                    );
                  }
                  final songs =
                      songSnapshot.data?.docs
                          .map((doc) => Song.fromMap(doc.data(), id: doc.id))
                          .toList() ??
                      const <Song>[];
                  if (query.isEmpty) return _recentSearches(songs);
                  if (songSnapshot.connectionState == ConnectionState.waiting &&
                      songs.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary500,
                        strokeWidth: AppMetrics.px2,
                      ),
                    );
                  }
                  return _searchResults(songs, query);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spacing18, AppSpacing.spacing14, AppSpacing.spacing18, AppSpacing.spacing8),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedTab = tab),
              child: Column(
                children: [
                  Text(
                    tab,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.neutral0
                          : AppColors.neutral300,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.px7),
                  Container(
                    height: AppMetrics.px2,
                    width: AppMetrics.px24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary500
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.radius2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _recentSearches(List<Song> songs) {
    final stream = _recentSearchStream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.spacing18, AppSpacing.spacing20, AppSpacing.spacing18, AppSpacing.spacing18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Searches',
                    style: AppTypography.label1.copyWith(
                      color: AppColors.neutral0,
                    ),
                  ),
                ),
                if (docs.isNotEmpty)
                  TextButton(
                    onPressed: () => _deleteAllRecent(docs),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.actionPrimaryDefault,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Delete',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.actionPrimaryDefault,
                        fontWeight: AppFontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppMetrics.px16),
            ...docs.map((doc) {
              final data = doc.data();
              return _recentRow(doc, data, songs);
            }),
          ],
        );
      },
    );
  }

  Widget _recentRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
    List<Song> songs,
  ) {
    final title = (data['title'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final kind = (data['kind'] ?? 'query').toString();
    final songId = (data['songId'] ?? '').toString();
    final searchTerm = (data['searchTerm'] ?? title).toString();
    return InkWell(
      onTap: () {
        if (songId.isNotEmpty) {
          for (final song in songs) {
            if (song.id == songId) {
              widget.onPlaySong(song);
              return;
            }
          }
        }
        _controller.text = searchTerm;
        _selectedTab = switch (kind) {
          'artist' => 'Artists',
          'album' => 'Albums',
          _ => 'All',
        };
        _focusNode.requestFocus();
        setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacing7),
        child: Row(
          children: [
            _searchAvatar(imageUrl, rounded: kind == 'artist', size: AppMetrics.px44),
            const SizedBox(width: AppMetrics.px12),
            Expanded(
              child: Text(
                title,
                maxLines: AppLayout.singleLineText,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label2.copyWith(color: AppColors.neutral0),
              ),
            ),
            IconButton(
              onPressed: () => _deleteRecent(doc.id),
              icon: const Icon(
                Icons.close_rounded,
                size: AppMetrics.px17,
                color: AppColors.neutral0,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove recent search',
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchResults(List<Song> songs, String query) {
    final matchedSongs = songs
        .where(
          (song) =>
              _matches(song.title, query) ||
              _matches(song.artist, query) ||
              _matches(song.album, query),
        )
        .toList();
    final artistSongs = <String, Song>{};
    for (final song in songs.where((song) => _matches(song.artist, query))) {
      final displayArtist = _artistDisplayName(song.artist);
      artistSongs.putIfAbsent(_searchKey(displayArtist), () => song);
    }
    final albumSongs = <String, Song>{};
    for (final song in songs.where(
      (song) => song.album.isNotEmpty && _matches(song.album, query),
    )) {
      albumSongs.putIfAbsent(song.album.toLowerCase(), () => song);
    }

    final rows = <Widget>[];
    if (_selectedTab == 'All' || _selectedTab == 'Artists') {
      rows.addAll(
        artistSongs.entries.map(
          (entry) => _artistResult(
            entry.value,
            _artistDisplayName(entry.value.artist),
          ),
        ),
      );
    }
    if (_selectedTab == 'All' || _selectedTab == 'Songs') {
      rows.addAll(matchedSongs.map(_songResult));
    }
    if (_selectedTab == 'Albums') {
      rows.addAll(albumSongs.values.map(_albumResult));
    }

    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: AppTypography.body2.copyWith(color: AppColors.neutral300),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.spacing18, AppSpacing.spacing8, AppSpacing.spacing18, AppSpacing.spacing18),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppMetrics.px2),
      itemBuilder: (context, index) => rows[index],
    );
  }

  Widget _artistResult(Song representative, String displayName) => InkWell(
    onTap: () async {
      await _saveRecent(
        title: displayName,
        subtitle: 'Artist',
        imageUrl: representative.artistImageUrl.isEmpty
            ? representative.imageUrl
            : representative.artistImageUrl,
        kind: 'artist',
        searchTerm: displayName,
      );
      _controller.text = displayName;
      setState(() => _selectedTab = 'Songs');
    },
    child: _resultRow(
      imageUrl: representative.artistImageUrl.isEmpty
          ? representative.imageUrl
          : representative.artistImageUrl,
      title: displayName,
      subtitle: 'Artist',
      rounded: true,
    ),
  );

  Widget _songResult(Song song) => InkWell(
    onTap: () async {
      await _saveRecent(
        title: song.title,
        subtitle: song.artist,
        imageUrl: song.imageUrl,
        kind: 'song',
        songId: song.id,
        searchTerm: song.title,
      );
      widget.onPlaySong(song);
    },
    child: _resultRow(
      imageUrl: song.imageUrl,
      title: song.title,
      subtitle: song.artist,
    ),
  );

  Widget _albumResult(Song representative) => InkWell(
    onTap: () async {
      await _saveRecent(
        title: representative.album,
        subtitle: representative.artist,
        imageUrl: representative.imageUrl,
        kind: 'album',
        searchTerm: representative.album,
      );
      _controller.text = representative.album;
      setState(() => _selectedTab = 'Songs');
    },
    child: _resultRow(
      imageUrl: representative.imageUrl,
      title: representative.album,
      subtitle: representative.artist,
    ),
  );

  Widget _resultRow({
    required String imageUrl,
    required String title,
    required String subtitle,
    bool rounded = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacing6),
    child: Row(
      children: [
        _searchAvatar(imageUrl, rounded: rounded, size: AppMetrics.px44),
        const SizedBox(width: AppMetrics.px12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: AppLayout.singleLineText,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label2.copyWith(color: AppColors.neutral0),
              ),
              Text(
                subtitle,
                maxLines: AppLayout.singleLineText,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral300,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.more_vert_rounded,
          size: AppMetrics.px19,
          color: AppColors.primary500,
        ),
      ],
    ),
  );

  Widget _searchAvatar(
    String imageUrl, {
    required bool rounded,
    required double size,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(rounded ? size / 2 : AppRadius.radius6),
    child: SizedBox(
      width: size,
      height: size,
      child: imageUrl.isEmpty
          ? ColoredBox(
              color: AppColors.neutral700,
              child: Icon(
                rounded ? Icons.person_rounded : Icons.music_note_rounded,
                color: AppColors.neutral400,
                size: AppMetrics.px22,
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => ColoredBox(
                color: AppColors.neutral700,
                child: Icon(
                  rounded ? Icons.person_rounded : Icons.music_note_rounded,
                  color: AppColors.neutral400,
                  size: AppMetrics.px22,
                ),
              ),
            ),
    ),
  );
}
