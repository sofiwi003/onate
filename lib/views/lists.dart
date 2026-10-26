import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/theme.dart';

class ListsView extends StatefulWidget {
  const ListsView({super.key});

  @override
  State<ListsView> createState() => _ListsViewState();
}

class _ListsViewState extends State<ListsView> {
  // colección de firestore
  final canciones = FirebaseFirestore.instance.collection('canciones');

  // controladores de los campos de texto
  final tituloController = TextEditingController();
  final subtituloController = TextEditingController();

  // validación del formulario
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    tituloController.dispose();
    subtituloController.dispose();
    super.dispose();
  }

  // formulario para crear o editar una canción
  Future<void> formularioCancion({
    String? id,
    String titulo = '',
    String subtitulo = '',
  }) async {
    // cargar los datos en los campos
    tituloController.text = titulo;
    subtituloController.text = subtitulo;

    // si existe un id, estamos editando
    final editando = id != null;

    // estado local del formulario
    bool guardando = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // guardar los cambios en firestore
            Future<void> guardarCancion() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setSheetState(() {
                guardando = true;
              });

              try {
                // datos obtenidos de los controladores
                final datos = {
                  'titulo': tituloController.text.trim(),
                  'subtitulo': subtituloController.text.trim(),
                };

                if (editando) {
                  // actualizar una canción existente
                  await canciones.doc(id).update(datos);
                } else {
                  // crear una canción nueva
                  await canciones.add({
                    ...datos,
                    'creadoEn': FieldValue.serverTimestamp(),
                  });
                }

                if (!sheetContext.mounted) return;

                // cerrar el bottom sheet
                Navigator.pop(sheetContext);

                if (!mounted) return;

                // mostrar confirmación
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      editando
                          ? 'Canción actualizada correctamente'
                          : 'Canción guardada correctamente',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
              } finally {
                guardando = false;

                if (sheetContext.mounted) {
                  setSheetState(() {});
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.spacing24,
                AppSpacing.spacing8,
                AppSpacing.spacing24,
                MediaQuery.viewInsetsOf(context).bottom + AppSpacing.spacing24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // título del formulario
                      Text(
                        editando ? 'Editar canción' : 'Nueva canción',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),

                      const SizedBox(height: AppSpacing.spacing24),

                      // campo título
                      TextFormField(
                        controller: tituloController,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un título';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppSpacing.spacing16),

                      // campo subtítulo
                      TextFormField(
                        controller: subtituloController,
                        decoration: const InputDecoration(
                          labelText: 'Subtítulo',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.spacing24),

                      // botones del formulario
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: guardando
                                ? null
                                : () => Navigator.pop(sheetContext),
                            child: const Text('Cancelar'),
                          ),

                          const SizedBox(width: AppSpacing.spacing8),

                          FilledButton(
                            onPressed: guardando ? null : guardarCancion,
                            child: guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(editando ? 'Actualizar' : 'Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // confirmar y eliminar una canción
  Future<void> eliminarCancion(String id, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar canción'),
          content: Text('¿Quieres eliminar "$titulo"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    // cancelar si no se confirmó
    if (confirmar != true || !mounted) return;

    try {
      // eliminar documento de firestore
      await canciones.doc(id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canción eliminada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      // app bar
      appBar: AppBar(title: const Text('Listas')),

      // lista de canciones desde firestore
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: canciones.snapshots(),
        builder: (context, snapshot) {
          // error de conexión
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las canciones'));
          }

          // estado de carga
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // documentos de firestore
          final documentos = snapshot.data!.docs;

          // lista vacía
          if (documentos.isEmpty) {
            return const Center(child: Text('No hay canciones todavía'));
          }

          // construir lista dinámica
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacing8),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              // documento y datos de la canción
              final documento = documentos[index];
              final datos = documento.data();

              // identificador único de firestore
              final id = documento.id;

              final titulo = datos['titulo'] as String? ?? '';
              final subtitulo = datos['subtitulo'] as String? ?? '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacing16,
                  vertical: AppSpacing.spacing4,
                ),

                // imagen local
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.radius200),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: AppSpacing.spacing56,
                    height: AppSpacing.spacing56,
                    fit: BoxFit.cover,
                  ),
                ),

                // título
                title: Text(titulo, style: text.bodyLarge),

                // subtítulo
                subtitle: Text(
                  subtitulo,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                // menú para editar o eliminar
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (opcion) {
                    if (opcion == 'editar') {
                      formularioCancion(
                        id: id,
                        titulo: titulo,
                        subtitulo: subtitulo,
                      );
                    }

                    if (opcion == 'eliminar') {
                      eliminarCancion(id, titulo);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: AppSpacing.spacing8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: AppSpacing.spacing8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      // botón para crear una canción
      floatingActionButton: FloatingActionButton(
        onPressed: () => formularioCancion(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
