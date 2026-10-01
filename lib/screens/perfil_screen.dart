import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/progreso_helper.dart';
import '../utils/formato.dart';
import '../utils/recarga_automatica.dart';
import 'historial_screen.dart';
import 'lista_terminos_screen.dart';

const Color _kTeal = Color(0xFF0D9488);
const Color _kPeligro = Color(0xFFDC2626);

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with RecargaAutomatica<PerfilScreen> {
  bool _cargando = true;
  String _nombre = ProgresoHelper.nombrePorDefecto;
  ResumenProgreso? _resumen;
  int _favoritos = 0;
  int _totalTerminos = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  Future<void> recargar() => _cargarDatos();

  Future<void> _cargarDatos() async {
    final progreso = ProgresoHelper.instance;
    try {
      final nombre = await progreso.obtenerNombreUsuario();
      final resumen = await progreso.obtenerResumen();
      final favoritos = (await progreso.obtenerFavoritos()).length;
      final total = await DatabaseHelper.instance.contarTotalTerminos();
      if (!mounted) return;
      setState(() {
        _nombre = nombre;
        _resumen = resumen;
        _favoritos = favoritos;
        _totalTerminos = total;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('No se pudo cargar el perfil: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => pantalla),
    );
  }

  // =========================================================
  // ACCIONES
  // =========================================================

  Future<void> _editarNombre() async {
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoNombre(
        inicial: _nombre == ProgresoHelper.nombrePorDefecto ? '' : _nombre,
      ),
    );
    if (nuevo == null) return;
    await ProgresoHelper.instance.guardarNombreUsuario(nuevo);
  }

  Future<void> _confirmarReinicio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar progreso?'),
        content: const Text(
          'Se borrarán tus sesiones, respuestas, racha y términos guardados. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kPeligro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ProgresoHelper.instance.reiniciarProgreso();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progreso reiniciado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _cargarDatos();
  }

  void _mostrarAcercaDe() {
    showAboutDialog(
      context: context,
      applicationName: 'MedTermino',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.medical_services, color: _kTeal),
      children: [
        Text(
          'Diccionario de terminología médica 100% offline con '
          '$_totalTerminos términos, raíces, prefijos y sufijos.',
        ),
      ],
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final r = _resumen;
    final aprendidos = r?.terminosAprendidos ?? 0;
    final nivel = NivelEstudio.para(aprendidos);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : RefreshIndicator(
              color: _kTeal,
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCabecera(nivel, aprendidos),
                  const SizedBox(height: 28),

                  const Text(
                    'Conocimiento Adquirido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard(
                        'Términos\nAprendidos',
                        '$aprendidos',
                        Icons.menu_book,
                      ),
                      _buildStatCard(
                        'Racha\nActual',
                        plural(r?.racha ?? 0, 'Día', 'Días'),
                        Icons.local_fire_department,
                      ),
                      _buildStatCard(
                        'Tarjetas\nDominadas',
                        '${r?.porcentajeDominio ?? 0}%',
                        Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${plural(r?.sesionesCompletadas ?? 0, 'sesión completada', 'sesiones completadas')}'
                      ' · ${plural(r?.terminosEstudiados ?? 0, 'término estudiado', 'términos estudiados')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Ajustes y Datos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildListTile(
                    Icons.bookmark,
                    'Términos Guardados',
                    _favoritos == 0
                        ? 'Aún no guardas términos'
                        : plural(_favoritos, 'término guardado', 'términos guardados'),
                    () => _abrir(ListaTerminosScreen.favoritos()),
                  ),
                  _buildListTile(
                    Icons.replay,
                    'Términos por repasar',
                    (r?.terminosPorRepasar ?? 0) == 0
                        ? 'Nada pendiente'
                        : plural(r!.terminosPorRepasar, 'término pendiente', 'términos pendientes'),
                    () => _abrir(ListaTerminosScreen.porRepasar()),
                  ),
                  _buildListTile(
                    Icons.bar_chart,
                    'Historial de Estudio',
                    'Revisa tus sesiones anteriores',
                    () => _abrir(const HistorialScreen()),
                  ),
                  _buildListTile(
                    Icons.info_outline,
                    'Acerca de MedTermino',
                    'Versión y créditos',
                    _mostrarAcercaDe,
                  ),
                  _buildListTile(
                    Icons.delete_outline,
                    'Reiniciar progreso',
                    'Borra sesiones, racha y favoritos',
                    _confirmarReinicio,
                    color: _kPeligro,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCabecera(NivelEstudio nivel, int aprendidos) {
    final siguiente = nivel.siguiente;
    final nombreSiguiente = siguiente == null
        ? null
        : NivelEstudio.niveles[NivelEstudio.niveles.indexOf(nivel) + 1].nombre;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _kTeal.withValues(alpha: 0.15),
                child: Text(
                  _iniciales(_nombre),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kTeal,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Nivel: ${nivel.nombre}',
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar nombre',
                icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                onPressed: _editarNombre,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nivel.progreso(aprendidos),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: _kTeal,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              siguiente == null
                  ? '¡Alcanzaste el nivel máximo!'
                  : 'Te faltan ${plural(siguiente - aprendidos, 'término', 'términos')} '
                      'para $nombreSiguiente',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: _kTeal, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kTeal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color color = _kTeal,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color == _kTeal ? null : color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// El diálogo es dueño de su TextEditingController y lo libera al cerrarse
class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({required this.inicial});
  final String inicial;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tu nombre'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: ProgresoHelper.nombrePorDefecto,
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
