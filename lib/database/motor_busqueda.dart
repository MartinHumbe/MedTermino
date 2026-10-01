import 'db_helper.dart';

/// Búsqueda en memoria sobre los 1,908 términos (~150 KB).
///
/// Ventajas frente a `LIKE` en SQLite:
///  - Ignora acentos y mayúsculas ("patognomonico" encuentra "patognomónico").
///  - Ordena por relevancia (coincidencia exacta primero).
///  - Una sola lectura de la BD; cada búsqueda posterior es instantánea.
class MotorBusqueda {
  MotorBusqueda._(this._entradas);

  final List<_Entrada> _entradas;

  static Future<MotorBusqueda>? _instancia;

  /// Se construye una sola vez (la primera búsqueda) y se reutiliza.
  static Future<MotorBusqueda> get instancia =>
      _instancia ??= _construir().catchError((Object e) {
        _instancia = null; // Permitir reintentar si falló la carga
        throw e;
      });

  static Future<MotorBusqueda> _construir() async {
    final filas = await DatabaseHelper.instance.obtenerTodosLosTerminos();
    return MotorBusqueda.desdeFilas(filas);
  }

  /// Constructor público para pruebas (sin BD).
  factory MotorBusqueda.desdeFilas(List<Map<String, dynamic>> filas) =>
      MotorBusqueda._([for (final f in filas) _Entrada(f)]);

  /// Resultados ordenados por relevancia:
  ///  0. el término es exactamente la búsqueda
  ///  1. el término empieza con la búsqueda
  ///  2. una palabra del término empieza con la búsqueda
  ///  3. el término contiene la búsqueda
  ///  4. una palabra de la definición empieza con la búsqueda
  ///  5. la definición contiene la búsqueda
  List<Map<String, dynamic>> buscar(String consulta, {int limite = 200}) {
    final q = normalizar(consulta);
    if (q.isEmpty) return const [];

    final puntuados = <(int, _Entrada)>[];
    for (final e in _entradas) {
      final p = e.puntuar(q);
      if (p != null) puntuados.add((p, e));
    }
    puntuados.sort((a, b) {
      final porRango = a.$1.compareTo(b.$1);
      if (porRango != 0) return porRango;
      final porLargo = a.$2.termino.length.compareTo(b.$2.termino.length);
      if (porLargo != 0) return porLargo;
      return a.$2.termino.compareTo(b.$2.termino);
    });
    return [for (final p in puntuados.take(limite)) p.$2.datos];
  }

  static const Map<String, String> _sinAcento = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  /// Minúsculas, sin acentos, sin espacios repetidos ni guiones de afijo.
  /// "-ÍTIS " → "itis"
  static String normalizar(String texto) {
    final sb = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      sb.write(_sinAcento[ch] ?? ch);
    }
    return sb
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

class _Entrada {
  _Entrada(this.datos)
      : termino = MotorBusqueda.normalizar(datos['termino']?.toString() ?? ''),
        definicion =
            MotorBusqueda.normalizar(datos['definicion']?.toString() ?? '');

  final Map<String, dynamic> datos;
  final String termino;
  final String definicion;

  static bool _palabraEmpiezaCon(String texto, String q) {
    var i = texto.indexOf(q);
    while (i != -1) {
      if (i == 0 || !_esLetra(texto.codeUnitAt(i - 1))) return true;
      i = texto.indexOf(q, i + 1);
    }
    return false;
  }

  // Texto ya normalizado: basta con a-z y 0-9
  static bool _esLetra(int c) =>
      (c >= 97 && c <= 122) || (c >= 48 && c <= 57);

  int? puntuar(String q) {
    if (termino == q) return 0;
    if (termino.startsWith(q)) return 1;
    if (termino.contains(q)) return _palabraEmpiezaCon(termino, q) ? 2 : 3;
    if (definicion.contains(q)) return _palabraEmpiezaCon(definicion, q) ? 4 : 5;
    return null;
  }
}
