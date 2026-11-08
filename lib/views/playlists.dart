import 'dart:async';

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
  const PlaylistsView({super.key, this.audioPlayer});

  final AudioPlayer? audioPlayer;

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  int _selectedTab = 2;
  bool _showCreateOptions = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.neutral800,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 28),
            _tabs(),
            const SizedBox(height: 24),
            Expanded(child: _tabContent(uid)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selectedTab == 2 ? _createMenu() : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniPlayer(),
          _bottomNavigation(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'My Library',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headline1.copyWith(
                color: Colors.white,
                fontSize: 34,
              ),
            ),
          ),
          _headerAction(Icons.notifications_rounded, hasNotification: true),
          const SizedBox(width: 12),
          _headerAction(Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, {bool hasNotification = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: AppColors.neutral700,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.neutral200, size: 28),
        ),
        if (hasNotification)
          Positioned(
            right: -1,
            top: 1,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabs() {
    const labels = ['Songs', 'Artists', 'Playlists'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _selectedTab = index;
                _showCreateOptions = false;
              }),
              child: Column(
                children: [
                  Text(
                    labels[index],
                    style: AppTypography.subtitle1.copyWith(
                      color: selected ? Colors.white : AppColors.neutral300,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 4,
                    width: 68,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary500
                          : Colors.transparent,
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
      return const Center(
        child: Text('Inicia sesión para ver tu biblioteca'),
      );
    }
    if (_selectedTab == 0) return _songsGrid();
    if (_selectedTab == 1) return _artistsGrid();
    return _playlistsGrid(uid);
  }

  Widget _songsGrid() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('canciones').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _message('No se pudieron cargar las canciones');
      if (!snapshot.hasData) return _loading();
      final songs = snapshot.data!.docs;
      if (songs.isEmpty) return _message('Todavía no hay canciones');
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: songs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 28,
          mainAxisSpacing: 28,
          childAspectRatio: 0.84,
        ),
        itemBuilder: (context, index) {
          final data = songs[index].data();
          return _LibraryCard(
            title: (data['title'] ?? data['titulo'] ?? 'Sin título').toString(),
            subtitle: (data['artist'] ?? data['subtitulo'] ?? 'Artista').toString(),
            imageUrl: (data['imageUrl'] ?? '').toString(),
          );
        },
      );
    },
  );

  Widget _artistsGrid() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('canciones').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _message('No se pudieron cargar los artistas');
      if (!snapshot.hasData) return _loading();
      final artists = <String, String>{};
      for (final doc in snapshot.data!.docs) {
        final data = doc.data();
        final name = (data['artist'] ?? data['subtitulo'] ?? '').toString().trim();
        if (name.isNotEmpty) artists.putIfAbsent(name, () => (data['artistImageUrl'] ?? '').toString());
      }
      if (artists.isEmpty) return _message('Todavía no hay artistas');
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: artists.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final entry = artists.entries.elementAt(index);
          return Column(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipOval(
                    child: entry.value.isEmpty
                        ? Container(
                            color: AppColors.neutral700,
                            child: const Icon(Icons.person, color: AppColors.neutral400, size: 44),
                          )
                        : Image.network(entry.value, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.neutral700, child: const Icon(Icons.person, color: AppColors.neutral400, size: 44))),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label1.copyWith(color: Colors.white)),
            ],
          );
        },
      );
    },
  );

  Widget _playlistsGrid(String uid) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('playlists')
        .where('userId', isEqualTo: uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _message('No se pudieron cargar las playlists');
      if (!snapshot.hasData) return _loading();
      final playlists = snapshot.data!.docs;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: playlists.isEmpty ? 1 : playlists.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 28,
          mainAxisSpacing: 24,
          childAspectRatio: 0.84,
        ),
        itemBuilder: (context, index) {
          if (playlists.isEmpty) {
            return GestureDetector(
              onTap: _openPlaylistForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.radius300),
                      child: Container(
                        color: AppColors.neutral700,
                        child: const Center(
                          child: Icon(Icons.queue_music_rounded, color: AppColors.neutral400, size: 72),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('My playlist', style: AppTypography.subtitle2.copyWith(color: Colors.white)),
                ],
              ),
            );
          }
          final playlist = playlists[index].data();
          return _LibraryCard(
            title: (playlist['name'] ?? 'Playlist').toString(),
            subtitle: '${(playlist['songIds'] as List?)?.length ?? 0} songs',
            imageUrl: (playlist['coverUrl'] ?? '').toString(),
          );
        },
      );
    },
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
              const SnackBar(content: Text('La creación de carpetas estará disponible más adelante.')),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
      FloatingActionButton(
        heroTag: 'library-create-fab',
        backgroundColor: AppColors.primary500,
        foregroundColor: Colors.white,
        onPressed: () => setState(() => _showCreateOptions = !_showCreateOptions),
        child: Icon(_showCreateOptions ? Icons.close_rounded : Icons.add, size: 34),
      ),
    ],
  );

  Widget _createOption({required String label, required IconData icon, required VoidCallback onTap}) =>
      Material(
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
                Text(label, style: AppTypography.body1.copyWith(color: Colors.white)),
                const SizedBox(width: 16),
                Icon(icon, color: Colors.white, size: 24),
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
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            if (data['isMiniPlayerCurrent'] == true ||
                ((data['title'] ?? data['titulo']) == 'Baby' &&
                    (data['artist'] ?? data['subtitulo']) == 'Justin Bieber')) {
              song = data;
              if (data['isMiniPlayerCurrent'] == true) break;
            }
          }
        }
        final title = (song?['title'] ?? song?['titulo'] ?? 'Baby').toString();
        final artist = (song?['artist'] ?? song?['subtitulo'] ?? 'Justin Bieber').toString();
        final imageUrl = (song?['imageUrl'] ?? '').toString();
        final audioUrl = (song?['audioUrl'] ?? '').toString();
        final player = widget.audioPlayer!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Material(
            color: AppColors.neutral700,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: song == null ? null : () => _openPlayer(title, artist, imageUrl, audioUrl),
              child: SizedBox(
                height: 76,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 54, height: 54, child: _cover(imageUrl)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.label1.copyWith(color: Colors.white)),
                            Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body2.copyWith(color: AppColors.neutral300)),
                          ],
                        ),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, state) => IconButton(
                          onPressed: () async {
                            if (state.data?.playing == true) {
                              await player.pause();
                            } else if (player.audioSource != null) {
                              await player.play();
                            } else if (song != null) {
                              await _openPlayer(title, artist, imageUrl, audioUrl);
                            }
                          },
                          icon: Icon(state.data?.playing == true ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.primary500, size: 30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomNavigation() => Container(
    height: 72,
    color: AppColors.neutral900,
    child: Row(
      children: [
        _navItem('assets/icons/home.svg', 'Home', false, () => Navigator.of(context).pop()),
        _navItem('assets/icons/discover.svg', 'Discover', false, () => _notAvailable('Discover')),
        _navItem('assets/icons/library.svg', 'Library', true, () {}),
        _navItem('assets/icons/search.svg', 'Search', false, () => _notAvailable('Search')),
      ],
    ),
  );

  Widget _navItem(String asset, String label, bool selected, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                asset,
                width: 26,
                height: 26,
                colorFilter: ColorFilter.mode(
                  selected ? AppColors.primary500 : AppColors.neutral200,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 4),
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

  Widget _cover(String imageUrl) => imageUrl.isEmpty
      ? Container(
          color: AppColors.neutral600,
          child: const Icon(Icons.music_note_rounded, color: AppColors.neutral300),
        )
      : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.neutral600, child: const Icon(Icons.music_note_rounded, color: AppColors.neutral300)));

  Widget _loading() => const Center(child: CircularProgressIndicator(color: AppColors.primary500));
  Widget _message(String text) => Center(child: Text(text, style: AppTypography.body2.copyWith(color: AppColors.neutral300)));

  Future<void> _openPlaylistForm() async {
    setState(() => _showCreateOptions = false);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.neutral0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.radius400)),
      ),
      builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: const _PlaylistFormSheet()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playlist creada correctamente')));
    }
  }

  Future<void> _openPlayer(String title, String artist, String imageUrl, String audioUrl) async {
    final player = widget.audioPlayer;
    if (player == null) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, secondaryAnimation) => PlayerScreen(
          audioPlayer: player,
          title: title,
          artist: artist,
          imageUrl: imageUrl,
          audioUrl: audioUrl,
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
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
  const _LibraryCard({required this.title, required this.subtitle, required this.imageUrl});

  final String title;
  final String subtitle;
  final String imageUrl;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.radius300),
          child: SizedBox.expand(
            child: imageUrl.isEmpty
                ? Container(color: AppColors.neutral700, child: const Icon(Icons.music_note_rounded, color: AppColors.neutral400, size: 48))
                : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.neutral700, child: const Icon(Icons.music_note_rounded, color: AppColors.neutral400, size: 48))),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.subtitle2.copyWith(color: Colors.white)),
      const SizedBox(height: 2),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body2.copyWith(color: AppColors.neutral300)),
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
  const _PlaylistFormSheet();

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
      backgroundColor: AppColors.neutral0,
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
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Inicia sesión para crear una playlist.');
      return;
    }

    setState(() => _saving = true);
    try {
      final coverUrl = _cover == null ? '' : await _uploadCover();
      await FirebaseFirestore.instance.collection('playlists').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverUrl': coverUrl,
        'isPrivate': _private,
        'userId': user.uid,
        'songIds': _selectedSongs.map((song) => song.id).toList(),
        'songs': _selectedSongs.map((song) => song.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _showError('No se pudo crear la playlist: $error');
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
      color: AppColors.neutral0,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 101,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
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
                  'New playlist',
                  style: AppTypography.body1.copyWith(
                    color: AppColors.neutral800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: _saving ? null : () => Navigator.pop(context),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.neutral600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.neutral0,
                      size: 16,
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
                                  color: AppColors.neutral50,
                                  border: Border.all(
                                    color: AppColors.neutral200,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.radius300,
                                  ),
                                ),
                                child: _coverBytes == null
                                    ? const Center(
                                        child: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: AppColors.neutral500,
                                          size: 32,
                                        ),
                                      )
                                    : Image.memory(
                                        _coverBytes!,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : _pickCover,
                            child: Text(
                              _cover == null ? 'Add cover' : 'Change cover',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral500,
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
                                  color: AppColors.neutral800,
                                ),
                              ),
                              Text(
                                'Only you will be able to see it',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.neutral500,
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
                                  ? AppColors.neutral700
                                  : AppColors.neutral300,
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
                      onTap: _saving ? null : _chooseSongs,
                      borderRadius: BorderRadius.circular(AppRadius.radius200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.neutral100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: AppColors.neutral800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _selectedSongs.isEmpty
                                  ? 'Add songs'
                                  : 'Add or remove songs (${_selectedSongs.length})',
                              style: AppTypography.body2.copyWith(
                                color: AppColors.neutral800,
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
                onPressed: _saving ? null : _savePlaylist,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neutral700,
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
                    : const Text('Create playlist'),
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
      style: AppTypography.caption.copyWith(color: AppColors.neutral500),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.body2.copyWith(color: AppColors.neutral400),
    counterText: '',
    filled: true,
    fillColor: AppColors.neutral0,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radius200),
      borderSide: const BorderSide(color: AppColors.neutral200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radius200),
      borderSide: const BorderSide(color: AppColors.neutral500),
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
                style: AppTypography.label2.copyWith(
                  color: AppColors.neutral800,
                ),
              ),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral500,
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
          color: AppColors.neutral500,
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
                      color: AppColors.neutral800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, _selected.values.toList()),
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
                          color: AppColors.neutral800,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral500,
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

