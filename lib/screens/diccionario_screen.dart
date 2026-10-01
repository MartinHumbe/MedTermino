import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/motor_busqueda.dart';
import 'buscador_delegate.dart';

const Color _kTeal = Color(0xFF0D9488);

// Pestañas: texto visible → categoría en la BD (null = todas)
const List<(String, String?)> _pestanas = [
  ('Todos', null),
  ('Términos', 'Término Completo'),
  ('Raíces', 'Raíz'),
  ('Prefijos', 'Prefijo'),
  ('Sufijos', 'Sufijo'),
];

class DiccionarioScreen extends StatefulWidget {
  const DiccionarioScreen({super.key});

  @override
  State<DiccionarioScreen> createState() => _DiccionarioScreenState();
}

class _DiccionarioScreenState extends State<DiccionarioScreen> {
  late Future<List<Map<String, dynamic>>> _terminosFuture;

  @override
  void initState() {
    super.initState();
    _terminosFuture = _cargarOrdenados();
  }

  // Orden alfabético real: sin distinguir mayúsculas ni acentos, y sin el
  // guion de los afijos ("-dokhos" va en la D, "Ammon" junto a "amphí").
  static Future<List<Map<String, dynamic>>> _cargarOrdenados() async {
    final filas = await DatabaseHelper.instance.obtenerTodosLosTerminos();
    final conClave = [
      for (final f in filas)
        (MotorBusqueda.normalizar(f['termino']?.toString() ?? ''), f),
    ]..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0
            ? c
            : (a.$2['termino'] as String).compareTo(b.$2['termino'] as String);
      });
    return [for (final e in conClave) e.$2];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _pestanas.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Diccionario',
            style: TextStyle(
              color: _kTeal,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search, color: Colors.black87),
              onPressed: () {
                showSearch(context: context, delegate: BuscadorTerminos());
              },
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _terminosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _kTeal),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar: ${snapshot.error}'));
            }
            final todos = snapshot.data ?? [];
            final listas = [
              for (final p in _pestanas)
                p.$2 == null
                    ? todos
                    : todos.where((t) => t['categoria'] == p.$2).toList(),
            ];

            return Column(
              children: [
                Material(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: _kTeal,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: _kTeal,
                    tabs: [
                      for (var i = 0; i < _pestanas.length; i++)
                        Tab(text: '${_pestanas[i].$1} (${listas[i].length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (var i = 0; i < _pestanas.length; i++)
                        _ListaAlfabetica(
                          // Cada pestaña recuerda su posición de scroll
                          key: PageStorageKey('dic-${_pestanas[i].$1}'),
                          terminos: listas[i],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lista con encabezados por letra (A, B, C...).
class _ListaAlfabetica extends StatelessWidget {
  const _ListaAlfabetica({super.key, required this.terminos});

  final List<Map<String, dynamic>> terminos;

  static String _letra(Map<String, dynamic> t) {
    final n = MotorBusqueda.normalizar(t['termino']?.toString() ?? '');
    return n.isEmpty ? '#' : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (terminos.isEmpty) {
      return const Center(
        child: Text(
          'No hay términos en esta pestaña.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Intercala un encabezado cada vez que cambia la letra inicial
    final elementos = <Object>[];
    String? letraActual;
    for (final t in terminos) {
      final letra = _letra(t);
      if (letra != letraActual) {
        elementos.add(letra);
        letraActual = letra;
      }
      elementos.add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: elementos.length,
      itemBuilder: (context, index) {
        final e = elementos[index];
        if (e is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
            child: Text(
              e,
              style: const TextStyle(
                color: _kTeal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          );
        }
        final termino = e as Map<String, dynamic>;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            // Key propia: sin ella el tile comparte identificador de PageStorage
            // con la lista y lee su posición de scroll (double) como si fuera
            // su estado abierto/cerrado (bool) → "double is not a subtype of bool?"
            key: PageStorageKey<String>('tile-${termino['termino']}'),
            shape: const Border(),
            title: Text(
              termino['termino']?.toString() ?? 'Término desconocido',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                termino['definicion']?.toString() ?? 'Definición no disponible',
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
  }
}
