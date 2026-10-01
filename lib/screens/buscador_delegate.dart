import 'package:flutter/material.dart';

import '../database/motor_busqueda.dart';

const Color _kTeal = Color(0xFF0D9488);

class BuscadorTerminos extends SearchDelegate<String> {
  BuscadorTerminos()
      : super(
          searchFieldLabel: 'Buscar término médico...',
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
        );

  // Se carga una sola vez por búsqueda abierta. Antes se lanzaba una consulta
  // SQL nueva en cada reconstrucción (cada letra, al abrir el teclado...),
  // y el FutureBuilder podía mostrar el resultado de una consulta anterior.
  final Future<MotorBusqueda> _motor = MotorBusqueda.instancia;

  // Botón para borrar el texto escrito (la 'X' a la derecha)
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Borrar',
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  // Botón para regresar a la pantalla anterior (Flecha a la izquierda)
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  // Lo que se muestra al dar "Enter"
  @override
  Widget buildResults(BuildContext context) => _construirLista(context);

  // Lo que se muestra mientras el usuario teclea (Tiempo real)
  @override
  Widget buildSuggestions(BuildContext context) => _construirLista(context);

  Widget _construirLista(BuildContext context) {
    if (query.trim().isEmpty) {
      return _mensaje(Icons.search, 'Escribe una palabra para buscar...\n'
          'No importan los acentos ni las mayúsculas.');
    }

    return FutureBuilder<MotorBusqueda>(
      future: _motor,
      builder: (context, snapshot) {
        // Solo espera la primera vez; luego la búsqueda es instantánea
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _kTeal));
        }
        if (snapshot.hasError) {
          return _mensaje(Icons.error_outline,
              'No se pudo cargar el diccionario.\n${snapshot.error}');
        }

        // La búsqueda es síncrona: el resultado siempre corresponde a `query`
        final resultados = snapshot.data!.buscar(query);
        if (resultados.isEmpty) {
          return _mensaje(
            Icons.search_off,
            'No se encontraron términos para "${query.trim()}".',
          );
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: resultados.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  resultados.length >= 200
                      ? 'Más de 200 resultados · los más relevantes primero'
                      : '${resultados.length} '
                          '${resultados.length == 1 ? 'resultado' : 'resultados'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              );
            }
            final term = resultados[index - 1];
            return Card(
              // Key por término: al cambiar la búsqueda no se "heredan" tarjetas abiertas
              key: ValueKey(term['termino']),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(
                  term['termino']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  term['categoria']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alineado a la izquierda: el justificado dejaba huecos grandes
                  Text(
                    term['definicion']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _mensaje(IconData icono, String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
