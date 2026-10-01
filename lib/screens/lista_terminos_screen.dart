import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/progreso_helper.dart';

const Color _kTeal = Color(0xFF0D9488);

/// Lista genérica de términos guardados en progreso.db
/// (se usa para "Términos Guardados" y "Términos por repasar").
class ListaTerminosScreen extends StatefulWidget {
  const ListaTerminosScreen({
    super.key,
    required this.titulo,
    required this.cargarNombres,
    required this.mensajeVacio,
    this.iconoVacio = Icons.inbox_outlined,
    this.permitirQuitarFavorito = false,
  });

  final String titulo;

  /// Devuelve los nombres de los términos en el orden a mostrar.
  final Future<List<String>> Function() cargarNombres;
  final String mensajeVacio;
  final IconData iconoVacio;

  /// Muestra un botón para quitar cada término de favoritos.
  final bool permitirQuitarFavorito;

  /// Atajo: pantalla de "Términos Guardados".
  factory ListaTerminosScreen.favoritos({Key? key}) => ListaTerminosScreen(
        key: key,
        titulo: 'Términos Guardados',
        cargarNombres: ProgresoHelper.instance.obtenerFavoritos,
        mensajeVacio: 'Aún no guardas términos.\n'
            'Toca el marcador del Término del Día para guardarlo.',
        iconoVacio: Icons.bookmark_border,
        permitirQuitarFavorito: true,
      );

  /// Atajo: términos cuya última respuesta fue "Repasar".
  factory ListaTerminosScreen.porRepasar({Key? key}) => ListaTerminosScreen(
        key: key,
        titulo: 'Términos por repasar',
        cargarNombres: ProgresoHelper.instance.obtenerTerminosParaRepasar,
        mensajeVacio: '¡Nada pendiente!\n'
            'Los términos que marques como "Repasar" aparecerán aquí.',
        iconoVacio: Icons.task_alt,
      );

  @override
  State<ListaTerminosScreen> createState() => _ListaTerminosScreenState();
}

class _ListaTerminosScreenState extends State<ListaTerminosScreen> {
  late Future<List<Map<String, dynamic>>> _terminos;

  @override
  void initState() {
    super.initState();
    _terminos = _cargar();
  }

  Future<List<Map<String, dynamic>>> _cargar() async {
    final nombres = await widget.cargarNombres();
    final filas =
        await DatabaseHelper.instance.obtenerTerminosPorNombre(nombres);
    // Respetar el orden de progreso.db (más recientes primero)
    final porNombre = {for (final f in filas) f['termino'] as String: f};
    return [
      for (final n in nombres)
        if (porNombre[n] != null) porNombre[n]!,
    ];
  }

  Future<void> _quitarFavorito(String termino) async {
    await ProgresoHelper.instance.alternarFavorito(termino);
    if (!mounted) return;
    setState(() => _terminos = _cargar());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('"$termino" eliminado de favoritos'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await ProgresoHelper.instance.alternarFavorito(termino);
            if (mounted) setState(() => _terminos = _cargar());
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.titulo,
          style: const TextStyle(color: _kTeal, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _terminos,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _kTeal),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final lista = snapshot.data ?? [];
          if (lista.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.iconoVacio, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      widget.mensajeVacio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Text(
                    '${lista.length} '
                    '${lista.length == 1 ? 'término' : 'términos'}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }
              final t = lista[index - 1];
              final nombre = t['termino']?.toString() ?? '';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    t['categoria']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: widget.permitirQuitarFavorito
                      ? IconButton(
                          tooltip: 'Quitar de favoritos',
                          icon: const Icon(Icons.bookmark, color: _kTeal),
                          onPressed: () => _quitarFavorito(nombre),
                        )
                      : null,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['definicion']?.toString() ?? 'Definición no disponible',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
