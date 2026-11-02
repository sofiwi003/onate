import 'package:flutter/material.dart';
import 'theme/theme.dart';
import 'views/lists.dart';
import 'auth/auth_gate.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.surface,

      // App bar
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,

        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/images/logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),

        actions: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              color: colors.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.spacing8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: colors.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.spacing16),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacing16,
            ),
            child: Text(
              'Home',
              style: text.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

      // Contenido scrolleable con todas las cards
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.spacing16),
        children: [
          const SizedBox(height: AppSpacing.spacing40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top picks for you', style: text.titleLarge),
              Text(
                'See all',
                style: text.titleLarge?.copyWith(color: colors.primary),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.spacing12),

          // Contenedor con altura fija para la lista horizontal de cards
          SizedBox(
            height: 200, // Altura adecuada para la imagen + textos
            child: StreamBuilder<QuerySnapshot>(
              // Reemplaza 'top_picks' con el nombre de tu colección en Firebase
              stream: FirebaseFirestore.instance
                  .collection('canciones')
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. Manejo de estados (Carga o Error)
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error al cargar los datos',
                      style: TextStyle(color: AppColors.error400),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary500,
                    ),
                  );
                }

                // 2. Obtener documentos
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay elementos',
                      style: AppTypography.body1.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
                  );
                }

                // 3. ListView horizontal usando tu sistema de diseño
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spacing16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Sin título';
                    final artist = data['artist'] ?? 'Desconocido';
                    final imageUrl = data['imageUrl'] ?? '';

                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(
                        right: AppSpacing.spacing12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Imagen con tus radios predefinidos (AppRadius.radius400 = 16px)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.radius400,
                            ),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    height: 140,
                                    width: 140,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 140,
                                    width: 140,
                                    color: AppColors.neutral700,
                                    child: const Icon(
                                      Icons.music_note,
                                      color: AppColors.neutral300,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.spacing8),

                          // Título principal usando AppTypography.label1 o body1
                          Text(
                            title,
                            style: AppTypography.label1.copyWith(
                              color: AppColors.neutral0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Subtítulo usando AppTypography.caption o body2
                          Text(
                            artist,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral300,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Barra de navegación inferior
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ListsView()),
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Comunidad',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted),
            label: 'Listas',
          ),
        ],
      ),
    );
  }
}
