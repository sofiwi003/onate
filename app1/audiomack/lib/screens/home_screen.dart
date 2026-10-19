import 'package:app1/data/music_catalog.dart';
import 'package:app1/widgets/home_icons.dart';
import 'package:app1/theme/theme.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _playing = false;
  MusicTrack _current = initialTrack;
  final _searchController = TextEditingController();
  static const _tabs = ['Home', 'Discover', 'Library', 'Search'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectTrack(MusicTrack track) {
    setState(() {
      _current = track;
      _playing = true;
    });
  }

  void _showTracks(String title, List<MusicTrack> tracks) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (tracks.isEmpty)
                const Text(
                  'Aún no hay canciones de este artista en el catálogo.',
                ),
              for (final track in tracks)
                ListTile(
                  leading: _Artwork(size: 44, cover: track.cover),
                  title: Text(track.title),
                  subtitle: Text(track.artist),
                  trailing: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _selectTrack(track);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: ValueKey(_tab),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 32, 16, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          label: 'App1 música',
                          child: const SizedBox(
                            width: 32,
                            height: 24,
                            child: CustomPaint(painter: WaveLogoPainter()),
                          ),
                        ),
                        const Spacer(),
                        Badge(
                          smallSize: 9,
                          backgroundColor: AppColors.primary,
                          alignment: Alignment.topRight,
                          offset: const Offset(-7, 6),
                          child: IconButton.filledTonal(
                            tooltip: 'Notificaciones',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.neutral.shade600,
                              foregroundColor: AppColors.textSecondary,
                              minimumSize: const Size(36, 36),
                              maximumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _showInfo(
                              'Notificaciones',
                              'No tienes notificaciones nuevas.',
                            ),
                            icon: const Icon(
                              Icons.notifications_rounded,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          tooltip: 'Perfil',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.neutral.shade500,
                            foregroundColor: AppColors.textSecondary,
                            minimumSize: const Size(36, 36),
                            maximumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showInfo(
                            'Perfil',
                            'Tu espacio para disfrutar de la música.',
                          ),
                          icon: const Icon(Icons.person_rounded, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _tabs[_tab],
                      style: textTheme.headlineLarge?.copyWith(fontSize: 31),
                    ),
                  ],
                ),
              ),
            ),
            if (_tab == 0) ...[
              SliverToBoxAdapter(
                child: _section('Top picks for you', topPicks, wide: true),
              ),
              SliverToBoxAdapter(
                child: _section(
                  'Recently played',
                  recentlyPlayed,
                  subtitle: 'Based on what you hear',
                ),
              ),
              SliverToBoxAdapter(
                child: _section('Made for you', madeForYou, seeAll: false),
              ),
              SliverToBoxAdapter(child: _artists()),
            ] else if (_tab == 1) ...[
              SliverToBoxAdapter(
                child: _section('Top picks for you', topPicks, wide: true),
              ),
              SliverToBoxAdapter(child: _section('Made for you', madeForYou)),
              SliverToBoxAdapter(child: _artists()),
            ] else if (_tab == 2)
              SliverToBoxAdapter(
                child: _section('Recently played', [
                  _current,
                  ...recentlyPlayed.where((track) => track != _current),
                ], subtitle: 'Based on what you hear'),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar canciones o artistas',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _searchResults()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 148)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
            child: Material(
              color: AppColors.neutral.shade600,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    _Artwork(size: 38, cover: _current.cover),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _current.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _playing ? 'Pausar' : 'Reproducir',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 38,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      iconSize: 28,
                      color: AppColors.primary,
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: AppColors.neutral.shade900,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (var index = 0; index < _tabs.length; index++)
                    Expanded(
                      child: Semantics(
                        selected: _tab == index,
                        child: InkWell(
                          onTap: () => setState(() => _tab = index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (index == 1 || index == 2)
                                  SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CustomPaint(
                                      painter: NavIconPainter(
                                        library: index == 2,
                                        color: _tab == index
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    index == 0
                                        ? Icons.home_rounded
                                        : Icons.search_rounded,
                                    size: 23,
                                    color: _tab == index
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  _tabs[index],
                                  style: textTheme.labelSmall?.copyWith(
                                    color: _tab == index
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<MusicTrack> tracks, {
    String? subtitle,
    bool wide = false,
    bool seeAll = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            subtitle: subtitle,
            onSeeAll: seeAll ? () => _showTracks(title, tracks) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < tracks.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    SizedBox(
                      width: wide ? 194 : 120,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectTrack(tracks[i]),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Artwork(
                                size: 104,
                                width: wide ? 178 : 104,
                                cover: tracks[i].cover,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tracks[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tracks[i].artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _artists() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Artistas favoritos',
          actionLabel: 'Ver todo',
          onSeeAll: () => _showTracks('Artistas favoritos', musicCatalog),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final artist in const [
                ('Bad Bunny', 'bad_bunny_avatar'),
                ('Maluma', 'maluma_avatar'),
                ('Shakira', 'shakira_avatar'),
              ])
                SizedBox(
                  width: 124,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showTracks(
                      artist.$1,
                      musicCatalog
                          .where((track) => track.artist == artist.$1)
                          .toList(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.neutral.shade600,
                            backgroundImage: AssetImage(
                              'assets/images/${artist.$2}.png',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            artist.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Artista',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchResults() {
    final matches = musicCatalog
        .where(
          (track) => '${track.title} ${track.artist}'.toLowerCase().contains(
            _searchController.text.trim().toLowerCase(),
          ),
        )
        .toList();
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No se encontraron canciones.'),
      );
    }
    return Column(
      children: [
        for (final track in matches)
          ListTile(
            leading: _Artwork(size: 44, cover: track.cover),
            title: Text(track.title),
            subtitle: Text(track.artist),
            onTap: () => _selectTrack(track),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.actionLabel = 'See all',
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.only(left: 12),
                textStyle: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

/// Portadas originales extraídas de MEDIA.png, disponibles sin conexión.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.size, required this.cover, this.width});
  final double size;
  final double? width;
  final String cover;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/images/$cover.png',
        width: width ?? size,
        height: size,
        fit: BoxFit.cover,
        alignment: cover == 'los_bunkers'
            ? Alignment.topCenter
            : Alignment.center,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
