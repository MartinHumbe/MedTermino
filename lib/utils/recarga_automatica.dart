import 'dart:async';

import 'package:flutter/widgets.dart';

import '../database/progreso_helper.dart';

/// Recarga una pantalla automáticamente:
///  - cuando cambia el progreso (respuestas, favoritos, nombre, reinicio), y
///  - cuando la app vuelve del segundo plano (p. ej. después de medianoche,
///    para actualizar el Término del Día y la racha).
///
/// Necesario porque con IndexedStack las pantallas no se vuelven a crear
/// al cambiar de pestaña.
mixin RecargaAutomatica<T extends StatefulWidget> on State<T> {
  Timer? _espera;
  AppLifecycleListener? _ciclo;

  /// La pantalla implementa aquí su carga de datos.
  Future<void> recargar();

  @override
  void initState() {
    super.initState();
    ProgresoHelper.instance.cambios.addListener(_programarRecarga);
    _ciclo = AppLifecycleListener(
      onResume: () {
        if (mounted) recargar();
      },
    );
  }

  @override
  void dispose() {
    ProgresoHelper.instance.cambios.removeListener(_programarRecarga);
    _ciclo?.dispose();
    _espera?.cancel();
    super.dispose();
  }

  // Agrupa varios cambios seguidos (p. ej. tocar "Lo sé" rápido) en una sola recarga
  void _programarRecarga() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), () {
      if (mounted) recargar();
    });
  }
}
