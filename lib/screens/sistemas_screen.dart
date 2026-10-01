import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/progreso_helper.dart';
import '../utils/recarga_automatica.dart';
import '../utils/sistemas.dart';
import 'sistema_detalle_screen.dart';

const Color _kTeal = Color(0xFF0D9488);

/// Sistemas con su total de términos y cuántos ya domina el usuario.
Future<List<SistemaInfo>> cargarSistemasConProgreso() async {
  final db = DatabaseHelper.instance;
  final sistemas = await db.obtenerSistemas();

  final aprendidosPorSistema = <String, int>{};
  try {
    final aprendidos = await db.obtenerTerminosPorNombre(
      await ProgresoHelper.instance.obtenerTerminosAprendidos(),
    );
    for (final t in aprendidos) {
      for (final s in separarSistemas(t['sistema_anatomico'], incluirGeneral: true)) {
        aprendidosPorSistema[s] = (aprendidosPorSistema[s] ?? 0) + 1;
      }
    }
  } catch (e) {
    debugPrint('No se pudo leer el progreso por sistema: $e');
  }

  return [
    for (final s in sistemas)
      SistemaInfo(
        nombre: s.nombre,
        total: s.total,
        aprendidos: aprendidosPorSistema[s.nombre] ?? 0,
      ),
  ];
}

/// Abre el detalle de un sistema.
void abrirSistema(BuildContext context, SistemaInfo sistema) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SistemaDetalleScreen(sistema: sistema.nombre),
    ),
  );
}

// =========================================================
// PANTALLA: todos los sistemas en cuadrícula
// =========================================================

class SistemasScreen extends StatefulWidget {
  const SistemasScreen({super.key});

  @override
  State<SistemasScreen> createState() => _SistemasScreenState();
}

class _SistemasScreenState extends State<SistemasScreen>
    with RecargaAutomatica<SistemasScreen> {
  List<SistemaInfo>? _sistemas;
  String? _error;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  @override
  Future<void> recargar() async {
    try {
      final sistemas = await cargarSistemasConProgreso();
      if (mounted) setState(() => _sistemas = sistemas);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final sistemas = _sistemas;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Explorar por sistemas',
          style: TextStyle(color: _kTeal, fontWeight: FontWeight.bold),
        ),
      ),
      body: _error != null
          ? Center(child: Text('Error al cargar: $_error'))
          : sistemas == null
              ? const Center(child: CircularProgressIndicator(color: _kTeal))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 168,
                  ),
                  itemCount: sistemas.length,
                  itemBuilder: (context, i) => TarjetaSistema(
                    sistema: sistemas[i],
                    onTap: () => abrirSistema(context, sistemas[i]),
                  ),
                ),
    );
  }
}

// =========================================================
// WIDGET: tarjeta de un sistema (se usa aquí y en el Dashboard)
// =========================================================

class TarjetaSistema extends StatelessWidget {
  const TarjetaSistema({
    super.key,
    required this.sistema,
    required this.onTap,
  });

  final SistemaInfo sistema;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final estilo = sistema.estilo;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: estilo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(estilo.icono, color: estilo.color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                sistema.etiqueta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${sistema.total} términos',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sistema.aprendidos == 0
                      ? 0
                      : sistema.progreso.clamp(0.03, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  color: estilo.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sistema.aprendidos} dominados',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
