import 'package:flutter/material.dart';

import '../database/progreso_helper.dart';
import '../utils/formato.dart';

const Color _kTeal = Color(0xFF0D9488);
const Color _kRepasar = Color(0xFFF59E0B);

/// "Historial de Estudio": sesiones completadas, de la más reciente a la más antigua.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late final Future<List<ActividadReciente>> _sesiones =
      ProgresoHelper.instance.obtenerHistorialSesiones();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Historial de Estudio',
          style: TextStyle(color: _kTeal, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<ActividadReciente>>(
        future: _sesiones,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _kTeal),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final sesiones = snapshot.data ?? [];
          if (sesiones.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aún no completas ninguna sesión.\n'
                  'Ve a Estudiar y termina tus primeras 10 tarjetas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sesiones.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SesionTile(sesion: sesiones[i]),
          );
        },
      ),
    );
  }
}

class _SesionTile extends StatelessWidget {
  const _SesionTile({required this.sesion});

  final ActividadReciente sesion;

  @override
  Widget build(BuildContext context) {
    final repasar = sesion.total - sesion.loSe;
    final porcentaje =
        sesion.total == 0 ? 0 : (sesion.loSe * 100 / sesion.total).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Porcentaje de aciertos en círculo
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: sesion.total == 0 ? 0 : sesion.loSe / sesion.total,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey.shade200,
                  color: _kTeal,
                ),
                Text(
                  '$porcentaje%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ProgresoHelper.tituloSesion(sesion.tipoSesion),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fechaRelativa(sesion.fecha),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          _Cuenta(valor: sesion.loSe, icono: Icons.check, color: _kTeal),
          const SizedBox(width: 8),
          _Cuenta(valor: repasar, icono: Icons.replay, color: _kRepasar),
        ],
      ),
    );
  }
}

class _Cuenta extends StatelessWidget {
  const _Cuenta({
    required this.valor,
    required this.icono,
    required this.color,
  });

  final int valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 2),
        Text(
          '$valor',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
