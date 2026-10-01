// Utilidades de formato compartidas (sin depender del paquete intl).

const List<String> mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const List<String> _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _hora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

/// "Hoy, 21:30" · "Ayer, 09:05" · "Hace 3 días" · "12 sep" · "12 sep 2025"
String fechaRelativa(DateTime fecha, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final diaHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final diaFecha = DateTime(fecha.year, fecha.month, fecha.day);
  // Contar días con fechas UTC evita errores por horario de verano
  final dias = DateTime.utc(diaHoy.year, diaHoy.month, diaHoy.day)
      .difference(DateTime.utc(diaFecha.year, diaFecha.month, diaFecha.day))
      .inDays;

  if (dias <= 0) return 'Hoy, ${_hora(fecha)}';
  if (dias == 1) return 'Ayer, ${_hora(fecha)}';
  if (dias < 7) return 'Hace $dias días';
  final base = '${fecha.day} ${_mesesCortos[fecha.month - 1]}';
  return fecha.year == hoy.year ? base : '$base ${fecha.year}';
}

/// "1 día" / "5 días"
String plural(int n, String singular, String pluralForma) =>
    '$n ${n == 1 ? singular : pluralForma}';
