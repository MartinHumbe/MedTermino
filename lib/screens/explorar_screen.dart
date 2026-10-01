import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/progreso_helper.dart';
import '../utils/formato.dart';
import '../utils/recarga_automatica.dart';
import '../utils/sistemas.dart';
import 'buscador_delegate.dart';
import 'lista_terminos_screen.dart';
import 'sistemas_screen.dart';
import 'termino_del_dia_card.dart';

const Color _kTeal = Color(0xFF0D9488);
const Color _kRepasar = Color(0xFFF59E0B);

// Orden y nombre visible de cada categoría de la BD
const Map<String, String> _categorias = {
  'Término Completo': 'Términos completos',
  'Raíz': 'Raíces',
  'Prefijo': 'Prefijos',
  'Sufijo': 'Sufijos',
};

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen>
    with RecargaAutomatica<ExplorarScreen> {
  bool _isLoading = true;

  int _totalTerminos = 0;
  Map<String, dynamic>? _terminoDelDia;
  ResumenProgreso? _resumen;
  List<ActividadReciente> _actividad = [];
  Map<String, int> _totalPorCategoria = {};
  Map<String, int> _aprendidosPorCategoria = {};
  List<SistemaInfo> _sistemas = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  Future<void> recargar() => _cargarDatos();

  Future<void> _cargarDatos() async {
    final db = DatabaseHelper.instance;
    final progreso = ProgresoHelper.instance;

    final total = await db.contarTotalTerminos();
    final totalPorCategoria = await db.contarPorCategoria();

    // Cada bloque falla de forma independiente para no tirar el Dashboard
    Map<String, dynamic>? termino;
    try {
      termino = await db.obtenerTerminoDelDia();
    } catch (e) {
      debugPrint('No se pudo cargar el término del día: $e');
    }

    var sistemas = <SistemaInfo>[];
    try {
      sistemas = await cargarSistemasConProgreso();
    } catch (e) {
      debugPrint('No se pudieron cargar los sistemas: $e');
    }

    ResumenProgreso? resumen;
    var actividad = <ActividadReciente>[];
    final aprendidosPorCategoria = <String, int>{};
    try {
      resumen = await progreso.obtenerResumen();
      actividad = await progreso.obtenerActividadReciente(limite: 5);

      final aprendidos = await db.obtenerTerminosPorNombre(
        await progreso.obtenerTerminosAprendidos(),
      );
      for (final t in aprendidos) {
        final cat = (t['categoria'] ?? 'Sin categoría').toString();
        aprendidosPorCategoria[cat] = (aprendidosPorCategoria[cat] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('No se pudo cargar el progreso: $e');
    }

    if (!mounted) return;
    setState(() {
      _totalTerminos = total;
      _totalPorCategoria = totalPorCategoria;
      _terminoDelDia = termino;
      _resumen = resumen;
      _actividad = actividad;
      _aprendidosPorCategoria = aprendidosPorCategoria;
      _sistemas = sistemas;
      _isLoading = false;
    });
  }

  // Abre una pantalla y recarga al volver (p. ej. si quitó favoritos)
  Future<void> _abrir(Widget pantalla) async {
    // No hace falta recargar al volver: RecargaAutomatica escucha los cambios
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => pantalla),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'MedTermino',
          style: TextStyle(
            color: _kTeal,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              showSearch(context: context, delegate: BuscadorTerminos());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : RefreshIndicator(
              color: _kTeal,
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Término del Día (CU-01)
                  if (_terminoDelDia != null) ...[
                    // La key cambia con el término: a medianoche se reconstruye limpio
                    TerminoDelDiaCard(
                      key: ValueKey(_terminoDelDia!['termino']),
                      termino: _terminoDelDia!,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Explorar por sistemas (CU-04)
                  if (_sistemas.isNotEmpty) ...[
                    _buildSeccionSistemas(),
                    const SizedBox(height: 24),
                  ],

                  // Progreso real por categoría
                  _buildProgresoGeneral(),
                  const SizedBox(height: 16),

                  // Estadísticas principales
                  Row(
                    children: [
                      _buildStatCard(
                        '$_totalTerminos',
                        'Términos en\nDiccionario',
                        Icons.menu_book,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        '${_resumen?.racha ?? 0}',
                        (_resumen?.racha ?? 0) == 1
                            ? 'Día seguido'
                            : 'Días seguidos',
                        Icons.local_fire_department,
                      ),
                    ],
                  ),

                  // Aviso de pendientes
                  if ((_resumen?.terminosPorRepasar ?? 0) > 0) ...[
                    const SizedBox(height: 16),
                    _buildAvisoRepasar(_resumen!.terminosPorRepasar),
                  ],
                  const SizedBox(height: 28),

                  // Actividad reciente
                  const Text(
                    'Actividad Reciente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_actividad.isEmpty)
                    _buildActividadVacia()
                  else
                    for (final a in _actividad) _buildActividadTile(a),
                ],
              ),
            ),
    );
  }

  // =========================================================
  // COMPONENTES
  // =========================================================

  Widget _buildSeccionSistemas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Explorar por sistemas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => _abrir(const SistemasScreen()),
              style: TextButton.styleFrom(foregroundColor: _kTeal),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _sistemas.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 150,
              child: TarjetaSistema(
                sistema: _sistemas[i],
                onTap: () => abrirSistema(context, _sistemas[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgresoGeneral() {
    final aprendidos = _resumen?.terminosAprendidos ?? 0;
    final porcentaje = _totalTerminos == 0 ? 0.0 : aprendidos / _totalTerminos;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Tu progreso',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Text(
                '$aprendidos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: _kTeal,
                ),
              ),
              Text(
                ' / $_totalTerminos',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            aprendidos == 0
                ? 'Marca "Lo sé" en Estudiar para empezar a sumar.'
                : 'términos dominados',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _barra(porcentaje, alto: 10),
          const SizedBox(height: 18),
          for (final entrada in _categorias.entries)
            if ((_totalPorCategoria[entrada.key] ?? 0) > 0)
              _buildFilaCategoria(
                entrada.value,
                _aprendidosPorCategoria[entrada.key] ?? 0,
                _totalPorCategoria[entrada.key]!,
              ),
        ],
      ),
    );
  }

  Widget _buildFilaCategoria(String nombre, int aprendidos, int total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(nombre, style: const TextStyle(fontSize: 14)),
              ),
              Text(
                '$aprendidos / $total',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _barra(aprendidos / total),
        ],
      ),
    );
  }

  Widget _barra(double valor, {double alto = 6}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: LinearProgressIndicator(
        // Un mínimo visible para que un avance pequeño no se vea como 0
        value: valor == 0 ? 0 : valor.clamp(0.015, 1.0),
        minHeight: alto,
        backgroundColor: Colors.grey.shade200,
        color: _kTeal,
      ),
    );
  }

  Widget _buildStatCard(String valor, String titulo, IconData icono) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoracionTarjeta(),
        child: Column(
          children: [
            Icon(icono, color: _kTeal, size: 36),
            const SizedBox(height: 12),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvisoRepasar(int pendientes) {
    return Material(
      color: _kRepasar.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.replay, color: _kRepasar),
        title: Text(
          'Tienes ${plural(pendientes, 'término', 'términos')} por repasar',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right, color: _kRepasar),
        onTap: () => _abrir(ListaTerminosScreen.porRepasar()),
      ),
    );
  }

  Widget _buildActividadVacia() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.history, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aún no hay actividad. Completa una sesión en Estudiar '
              'o guarda un término para verla aquí.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActividadTile(ActividadReciente a) {
    final esSesion = a.tipo == TipoActividad.sesion;
    final titulo = esSesion
        ? ProgresoHelper.tituloSesion(a.tipoSesion)
        : 'Guardaste "${a.termino}" en favoritos';
    final detalle = esSesion
        ? '${a.loSe} de ${a.total} "Lo sé" · ${fechaRelativa(a.fecha)}'
        : fechaRelativa(a.fecha);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            esSesion ? Icons.school : Icons.bookmark,
            color: _kTeal,
          ),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(detalle, style: const TextStyle(color: Colors.grey)),
        onTap: esSesion ? null : () => _abrir(ListaTerminosScreen.favoritos()),
      ),
    );
  }

  BoxDecoration _decoracionTarjeta() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
