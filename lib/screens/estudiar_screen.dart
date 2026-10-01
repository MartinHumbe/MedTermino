import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../database/progreso_helper.dart';

// Paleta compartida del proyecto
const Color _kTeal = Color(0xFF0D9488);
const Color _kFondo = Color(0xFFF4F6F9);
const Color _kRepasar = Color(0xFFF59E0B); // Ámbar para "Repasar"

class EstudiarScreen extends StatefulWidget {
  const EstudiarScreen({super.key, this.sistema});

  /// Si se indica, las tarjetas salen solo de ese sistema (CU-04).
  /// Se abre como pantalla aparte desde "Explorar por sistemas".
  final String? sistema;

  @override
  State<EstudiarScreen> createState() => _EstudiarScreenState();
}

class _EstudiarScreenState extends State<EstudiarScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _flashcards = [];
  bool _cargando = true;
  String? _error;
  int _indiceActual = 0; // Para saber qué tarjeta estamos viendo

  // Id de la sesión en progreso.db (se resuelve en segundo plano)
  Future<int?> _sesionId = Future.value(null);

  // Clasificación del conocimiento durante la sesión
  final List<Map<String, dynamic>> _loSe = [];
  final List<Map<String, dynamic>> _porRepasar = [];

  // Animación de giro (0.0 = frente, 1.0 = reverso)
  late final AnimationController _giroController;
  late final Animation<double> _giro;

  bool get _sesionTerminada =>
      _flashcards.isNotEmpty && _indiceActual >= _flashcards.length;

  @override
  void initState() {
    super.initState();
    _giroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _giro = CurvedAnimation(
      parent: _giroController,
      curve: Curves.easeInOutCubic,
    );
    _cargarNuevasTarjetas();
  }

  @override
  void dispose() {
    _giroController.dispose();
    super.dispose();
  }

  // Extrae 10 términos aleatorios de la BD (CU-05)
  Future<void> _cargarNuevasTarjetas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final sistema = widget.sistema;
      final tarjetas = sistema == null
          ? await DatabaseHelper.instance.obtenerTerminosAleatoriosParaFlashcards()
          : await DatabaseHelper.instance.obtenerAleatoriosPorSistema(sistema);
      if (!mounted) return;
      _iniciarSesion(
        tarjetas,
        tipo: sistema == null
            ? ProgresoHelper.tipoSesionNueva
            : ProgresoHelper.tipoSesionSistema(sistema),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // Reinicia contadores y arranca una sesión con la lista dada
  void _iniciarSesion(
    List<Map<String, dynamic>> tarjetas, {
    required String tipo,
  }) {
    _giroController.value = 0;

    // Se registra la sesión en progreso.db sin bloquear la UI.
    // Las respuestas se encadenan a este Future para tener el id.
    _sesionId = tarjetas.isEmpty
        ? Future.value(null)
        : _crearSesion(tipo, tarjetas.length);

    setState(() {
      _flashcards = List.of(tarjetas)..shuffle();
      _indiceActual = 0;
      _loSe.clear();
      _porRepasar.clear();
      _cargando = false;
    });
  }

  // Guarda en segundo plano; un error de escritura nunca rompe la sesión
  Future<void> _guardarProgreso(
    Future<void> Function(int? sesionId) accion,
  ) async {
    try {
      await accion(await _sesionId);
    } catch (e) {
      debugPrint('No se pudo guardar el progreso: $e');
    }
  }

  Future<int?> _crearSesion(String tipo, int total) async {
    try {
      return await ProgresoHelper.instance.iniciarSesion(
        tipo: tipo,
        total: total,
      );
    } catch (e) {
      debugPrint('No se pudo iniciar la sesión: $e');
      return null;
    }
  }

  void _girarTarjeta() {
    if (_giroController.isAnimating) return;
    if (_giroController.value < 0.5) {
      _giroController.forward();
    } else {
      _giroController.reverse();
    }
  }

  // Clasifica la tarjeta actual y avanza a la siguiente
  void _clasificar({required bool loSe}) {
    if (_sesionTerminada) return;
    final tarjeta = _flashcards[_indiceActual];

    // La siguiente tarjeta siempre aparece por el frente,
    // así no se revela su definición durante la transición.
    _giroController.stop();
    _giroController.value = 0;

    setState(() {
      (loSe ? _loSe : _porRepasar).add(tarjeta);
      _indiceActual++;
    });

    // Cada respuesta se guarda al momento: si el usuario sale a media
    // sesión, lo ya respondido no se pierde.
    final termino = tarjeta['termino']?.toString();
    if (termino != null) {
      _guardarProgreso(
        (id) => ProgresoHelper.instance.registrarRespuesta(
          termino: termino,
          loSe: loSe,
          sesionId: id,
        ),
      );
    }
    if (_sesionTerminada) {
      _guardarProgreso((id) async {
        if (id != null) await ProgresoHelper.instance.finalizarSesion(id);
      });
    }
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.sistema ?? 'Módulo de Estudio',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _kTeal,
            fontWeight: FontWeight.bold,
            // Nombres como "Psicológico/Psiquiátrico" necesitan algo menos de tamaño
            fontSize: widget.sistema == null ? 24 : 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nuevas tarjetas',
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _cargando ? null : _cargarNuevasTarjetas,
          ),
        ],
      ),
      body: _buildCuerpo(),
    );
  }

  Widget _buildCuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kTeal));
    }
    if (_error != null) {
      return _buildMensaje(
        icono: Icons.error_outline,
        texto: 'No se pudieron cargar las tarjetas.\n$_error',
      );
    }
    if (_flashcards.isEmpty) {
      return _buildMensaje(
        icono: Icons.inbox_outlined,
        texto: 'No hay términos disponibles para estudiar.',
      );
    }
    if (_sesionTerminada) return _buildResumen();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          _buildProgreso(),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                final entrada = Tween<Offset>(
                  begin: const Offset(0.25, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: entrada, child: child),
                );
              },
              child: _TarjetaGiratoria(
                key: ValueKey(_indiceActual),
                giro: _giro,
                tarjeta: _flashcards[_indiceActual],
                onTap: _girarTarjeta,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildBotones(),
        ],
      ),
    );
  }

  Widget _buildProgreso() {
    final total = _flashcards.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tarjeta ${_indiceActual + 1} de $total',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            _ContadorChip(
              icono: Icons.replay,
              valor: _porRepasar.length,
              color: _kRepasar,
            ),
            const SizedBox(width: 8),
            _ContadorChip(
              icono: Icons.check,
              valor: _loSe.length,
              color: _kTeal,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _indiceActual / total),
            duration: const Duration(milliseconds: 300),
            builder: (context, valor, _) => LinearProgressIndicator(
              value: valor,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: _kTeal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotones() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _clasificar(loSe: false),
            icon: const Icon(Icons.replay),
            label: const Text('Repasar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kRepasar,
              side: const BorderSide(color: _kRepasar, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _clasificar(loSe: true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Lo sé'),
            style: FilledButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Pantalla final de la sesión
  Widget _buildResumen() {
    final total = _flashcards.length;
    final porcentaje = total == 0 ? 0 : (_loSe.length * 100 / total).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, size: 56, color: _kTeal),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Sesión completada!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dominaste el $porcentaje% de las tarjetas',
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _TarjetaResultado(
                  titulo: 'Lo sé',
                  valor: _loSe.length,
                  color: _kTeal,
                  icono: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _TarjetaResultado(
                  titulo: 'Repasar',
                  valor: _porRepasar.length,
                  color: _kRepasar,
                  icono: Icons.replay,
                ),
              ),
            ],
          ),
          if (_porRepasar.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Términos para repasar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _porRepasar
                  .map(
                    (t) => Chip(
                      label: Text(t['termino']?.toString() ?? ''),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 28),
          if (_porRepasar.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _iniciarSesion(
                  _porRepasar,
                  tipo: ProgresoHelper.tipoSesionRepaso,
                ),
                icon: const Icon(Icons.replay),
                label: Text('Repasar ${_porRepasar.length} pendientes'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kRepasar,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cargarNuevasTarjetas,
              icon: const Icon(Icons.shuffle),
              label: const Text('Nueva sesión (10 términos)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTeal,
                side: const BorderSide(color: _kTeal, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMensaje({required IconData icono, required String texto}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _cargarNuevasTarjetas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// TARJETA GIRATORIA (Flip 3D sobre el eje Y)
// =========================================================

class _TarjetaGiratoria extends StatelessWidget {
  const _TarjetaGiratoria({
    super.key,
    required this.giro,
    required this.tarjeta,
    required this.onTap,
  });

  final Animation<double> giro;
  final Map<String, dynamic> tarjeta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: giro,
        builder: (context, _) {
          final angulo = giro.value * math.pi;
          final mostrarReverso = angulo > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // Perspectiva
              ..rotateY(angulo),
            child: mostrarReverso
                // El reverso se gira 180° extra para no verse en espejo
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CaraReverso(tarjeta: tarjeta),
                  )
                : _CaraFrente(tarjeta: tarjeta),
          );
        },
      ),
    );
  }
}

class _BaseTarjeta extends StatelessWidget {
  const _BaseTarjeta({required this.child, this.color = Colors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _CaraFrente extends StatelessWidget {
  const _CaraFrente({required this.tarjeta});

  final Map<String, dynamic> tarjeta;

  @override
  Widget build(BuildContext context) {
    final categoria = tarjeta['categoria']?.toString() ?? '';

    return _BaseTarjeta(
      child: Column(
        children: [
          if (categoria.isNotEmpty)
            Align(
              alignment: Alignment.topLeft,
              child: _Etiqueta(texto: categoria, color: _kTeal),
            ),
          const Spacer(),
          Text(
            tarjeta['termino']?.toString() ?? 'Término desconocido',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                'Toca para ver la definición',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaraReverso extends StatelessWidget {
  const _CaraReverso({required this.tarjeta});

  final Map<String, dynamic> tarjeta;

  @override
  Widget build(BuildContext context) {
    final sistema = tarjeta['sistema_anatomico']?.toString() ?? '';

    return _BaseTarjeta(
      color: const Color(0xFFF0FDFA), // Teal muy claro
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tarjeta['termino']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _kTeal,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: 40, color: _kTeal),
          const SizedBox(height: 16),
          // Algunas definiciones superan los 1,000 caracteres
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                tarjeta['definicion']?.toString() ?? 'Definición no disponible',
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.45,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          if (sistema.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Etiqueta(
              texto: sistema,
              color: Colors.blueGrey,
              icono: Icons.monitor_heart_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

// =========================================================
// WIDGETS AUXILIARES
// =========================================================

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color, this.icono});

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContadorChip extends StatelessWidget {
  const _ContadorChip({
    required this.icono,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final int valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            '$valor',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({
    required this.titulo,
    required this.valor,
    required this.color,
    required this.icono,
  });

  final String titulo;
  final int valor;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color),
          const SizedBox(height: 6),
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(titulo, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
