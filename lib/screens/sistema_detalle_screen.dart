import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/progreso_helper.dart';
import '../utils/recarga_automatica.dart';
import '../utils/sistemas.dart';
import 'estudiar_screen.dart';

const Color _kTeal = Color(0xFF0D9488);
const Color _kRepasar = Color(0xFFF59E0B);

// Pestañas por categoría (clave en BD → texto de la pestaña)
const Map<String, String> _pestanas = {
  'Término Completo': 'Términos',
  'Raíz': 'Raíces',
  'Prefijo': 'Prefijos',
  'Sufijo': 'Sufijos',
};

/// Términos de un sistema anatómico (CU-04), filtrables por categoría,
/// con el estado de estudio de cada uno y acceso a flashcards del sistema.
class SistemaDetalleScreen extends StatefulWidget {
  const SistemaDetalleScreen({super.key, required this.sistema});

  final String sistema;

  @override
  State<SistemaDetalleScreen> createState() => _SistemaDetalleScreenState();
}

class _SistemaDetalleScreenState extends State<SistemaDetalleScreen>
    with RecargaAutomatica<SistemaDetalleScreen> {
  List<Map<String, dynamic>>? _terminos;
  Set<String> _aprendidos = {};
  Set<String> _porRepasar = {};
  String? _error;

  EstiloSistema get _estilo => EstiloSistema.de(widget.sistema);
  bool get _esGeneral => widget.sistema == sistemaGeneral;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  @override
  Future<void> recargar() async {
    try {
      final terminos =
          await DatabaseHelper.instance.obtenerTerminosPorSistema(widget.sistema);
      var aprendidos = <String>{};
      var porRepasar = <String>{};
      try {
        aprendidos =
            (await ProgresoHelper.instance.obtenerTerminosAprendidos()).toSet();
        porRepasar =
            (await ProgresoHelper.instance.obtenerTerminosParaRepasar()).toSet();
      } catch (e) {
        debugPrint('No se pudo leer el progreso: $e');
      }
      if (!mounted) return;
      setState(() {
        _terminos = terminos;
        _aprendidos = aprendidos;
        _porRepasar = porRepasar;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _estudiar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EstudiarScreen(sistema: widget.sistema),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final terminos = _terminos;
    final titulo = _esGeneral ? 'General' : widget.sistema;

    if (_error != null || terminos == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(backgroundColor: Colors.white, title: Text(titulo)),
        body: Center(
          child: _error != null
              ? Text('Error al cargar: $_error')
              : const CircularProgressIndicator(color: _kTeal),
        ),
      );
    }

    // Solo las pestañas con contenido en este sistema
    final listas = <String, List<Map<String, dynamic>>>{'Todos': terminos};
    for (final e in _pestanas.entries) {
      final filtrados = terminos.where((t) => t['categoria'] == e.key).toList();
      if (filtrados.isNotEmpty) listas[e.value] = filtrados;
    }

    return DefaultTabController(
      length: listas.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            titulo,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _estilo.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildCabecera(terminos.length),
            Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _estilo.color,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _estilo.color,
                tabs: [
                  for (final e in listas.entries)
                    Tab(text: '${e.key} (${e.value.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final lista in listas.values) _buildLista(lista),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecera(int total) {
    final dominados =
        _terminos!.where((t) => _aprendidos.contains(t['termino'])).length;
    final progreso = total == 0 ? 0.0 : dominados / total;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _estilo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_estilo.icono, color: _estilo.color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_estilo.descripcion.isNotEmpty)
                      Text(
                        _estilo.descripcion,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '$total términos · $dominados dominados',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dominados == 0 ? 0 : progreso.clamp(0.02, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: _estilo.color,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: total == 0 ? null : _estudiar,
              icon: const Icon(Icons.school),
              label: Text(
                total < 10
                    ? 'Estudiar este sistema ($total tarjetas)'
                    : 'Estudiar este sistema (10 tarjetas)',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _estilo.color,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> lista) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final t = lista[index];
        final nombre = t['termino']?.toString() ?? '';
        final otros = separarSistemas(t['sistema_anatomico'])
            .where((s) => s != widget.sistema)
            .toList();

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            key: PageStorageKey('${widget.sistema}-$nombre-$index'),
            shape: const Border(),
            leading: _iconoEstado(nombre),
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
              if (otros.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'También en:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    for (final s in otros)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          EstiloSistema.de(s).icono,
                          size: 16,
                          color: EstiloSistema.de(s).color,
                        ),
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SistemaDetalleScreen(sistema: s),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ✓ dominado · ↻ por repasar · ○ sin estudiar
  Widget _iconoEstado(String termino) {
    if (_aprendidos.contains(termino)) {
      return const Tooltip(
        message: 'Dominado',
        child: Icon(Icons.check_circle, color: _kTeal),
      );
    }
    if (_porRepasar.contains(termino)) {
      return const Tooltip(
        message: 'Por repasar',
        child: Icon(Icons.replay_circle_filled, color: _kRepasar),
      );
    }
    return Icon(Icons.circle_outlined, color: Colors.grey.shade300);
  }
}
