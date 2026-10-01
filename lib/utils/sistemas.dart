import 'package:flutter/material.dart';

/// Valor de la BD para términos sin sistema asignado.
const String sistemaGeneral = 'General / No específico';

/// Separa "Nervioso; Musculoesquelético" → ['Nervioso', 'Musculoesquelético'].
/// Si [incluirGeneral] es false, omite 'General / No específico'.
List<String> separarSistemas(Object? valor, {bool incluirGeneral = false}) {
  return (valor?.toString() ?? '')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && (incluirGeneral || s != sistemaGeneral))
      .toList();
}

/// Ícono, color y descripción breve de cada sistema (CU-04).
class EstiloSistema {
  const EstiloSistema(this.icono, this.color, this.descripcion);

  final IconData icono;
  final Color color;
  final String descripcion;

  static const Map<String, EstiloSistema> _estilos = {
    'Cardiovascular': EstiloSistema(
        Icons.favorite, Color(0xFFE11D48), 'Corazón y vasos sanguíneos'),
    'Nervioso': EstiloSistema(
        Icons.psychology, Color(0xFF7C3AED), 'Cerebro, médula y nervios'),
    'Digestivo': EstiloSistema(
        Icons.restaurant, Color(0xFFEA580C), 'Tubo digestivo y glándulas anexas'),
    'Respiratorio': EstiloSistema(
        Icons.air, Color(0xFF0284C7), 'Vías aéreas y pulmones'),
    'Musculoesquelético': EstiloSistema(Icons.accessibility_new,
        Color(0xFF92400E), 'Huesos, músculos y articulaciones'),
    'Integumentario': EstiloSistema(
        Icons.spa, Color(0xFFDB2777), 'Piel, pelo y uñas'),
    'Hematológico': EstiloSistema(
        Icons.bloodtype, Color(0xFFB91C1C), 'Sangre y sus componentes'),
    'Celular/Genético': EstiloSistema(
        Icons.biotech, Color(0xFF0D9488), 'Células, tejidos y genética'),
    'Sensorial': EstiloSistema(
        Icons.visibility, Color(0xFF2563EB), 'Ojos, oídos y sentidos'),
    'Urinario': EstiloSistema(
        Icons.water_drop, Color(0xFFCA8A04), 'Riñones y vías urinarias'),
    'Reproductor': EstiloSistema(
        Icons.child_friendly, Color(0xFFC026D3), 'Órganos reproductores'),
    'Endocrino': EstiloSistema(
        Icons.science, Color(0xFF059669), 'Glándulas y hormonas'),
    'Linfático/Inmunitario': EstiloSistema(
        Icons.shield, Color(0xFF16A34A), 'Defensas y sistema linfático'),
    'Infeccioso': EstiloSistema(
        Icons.coronavirus, Color(0xFF65A30D), 'Microorganismos e infecciones'),
    'Psicológico/Psiquiátrico': EstiloSistema(
        Icons.self_improvement, Color(0xFF4F46E5), 'Mente y conducta'),
    sistemaGeneral: EstiloSistema(
        Icons.category, Color(0xFF64748B), 'Términos de uso general'),
  };

  static const EstiloSistema _porDefecto =
      EstiloSistema(Icons.label_outline, Color(0xFF64748B), '');

  static EstiloSistema de(String sistema) => _estilos[sistema] ?? _porDefecto;
}

/// Resumen de un sistema para las tarjetas de navegación.
class SistemaInfo {
  const SistemaInfo({
    required this.nombre,
    required this.total,
    this.aprendidos = 0,
  });

  final String nombre;
  final int total;
  final int aprendidos;

  EstiloSistema get estilo => EstiloSistema.de(nombre);
  bool get esGeneral => nombre == sistemaGeneral;
  double get progreso => total == 0 ? 0 : aprendidos / total;

  /// Nombre corto para mostrar ("General" en lugar de "General / No específico").
  String get etiqueta => esGeneral ? 'General' : nombre;
}
