import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// =========================================================
// MODELOS
// =========================================================

/// Resumen de estadísticas para Perfil y Explorar.
class ResumenProgreso {
  const ResumenProgreso({
    required this.terminosEstudiados,
    required this.terminosAprendidos,
    required this.racha,
    required this.totalRespuestas,
    required this.sesionesCompletadas,
  });

  /// Términos distintos que han aparecido al menos una vez en una sesión.
  final int terminosEstudiados;

  /// Términos cuya ÚLTIMA respuesta fue "Lo sé".
  final int terminosAprendidos;

  /// Días consecutivos de estudio (contando hoy o, si hoy aún no, ayer).
  final int racha;

  final int totalRespuestas;
  final int sesionesCompletadas;

  /// Porcentaje (0–100) de términos estudiados que están dominados.
  int get porcentajeDominio => terminosEstudiados == 0
      ? 0
      : (terminosAprendidos * 100 / terminosEstudiados).round();

  int get terminosPorRepasar => terminosEstudiados - terminosAprendidos;
}

enum TipoActividad { sesion, favorito }

/// Una entrada de la lista "Actividad Reciente".
class ActividadReciente {
  const ActividadReciente({
    required this.tipo,
    required this.fecha,
    this.termino,
    this.tipoSesion,
    this.total = 0,
    this.loSe = 0,
  });

  final TipoActividad tipo;
  final DateTime fecha;

  /// Solo para favoritos.
  final String? termino;

  /// Solo para sesiones: 'nueva' o 'repaso'.
  final String? tipoSesion;
  final int total;
  final int loSe;
}

/// Nivel del estudiante según los términos aprendidos.
class NivelEstudio {
  const NivelEstudio(this.nombre, this.minimo, this.siguiente);

  final String nombre;
  final int minimo;

  /// Términos necesarios para el siguiente nivel (null = nivel máximo).
  final int? siguiente;

  static const List<NivelEstudio> niveles = [
    NivelEstudio('Principiante', 0, 25),
    NivelEstudio('Estudiante', 25, 100),
    NivelEstudio('Interno', 100, 300),
    NivelEstudio('Residente', 300, 700),
    NivelEstudio('Especialista', 700, 1200),
    NivelEstudio('Maestro', 1200, null),
  ];

  static NivelEstudio para(int aprendidos) =>
      niveles.lastWhere((n) => aprendidos >= n.minimo);

  /// Avance (0.0–1.0) hacia el siguiente nivel.
  double progreso(int aprendidos) {
    final meta = siguiente;
    if (meta == null) return 1;
    return ((aprendidos - minimo) / (meta - minimo)).clamp(0.0, 1.0);
  }
}

// =========================================================
// HELPER
// =========================================================

/// Progreso del usuario en una BD aparte (`progreso.db`).
///
/// Se separa de `diccionario.db` a propósito: si algún día se regenera
/// el diccionario de los assets, el progreso del usuario no se pierde.
/// Los términos se relacionan por el texto de `termino` (es único en
/// `diccionario_medico`).
class ProgresoHelper {
  static final ProgresoHelper instance = ProgresoHelper._init();
  ProgresoHelper._init();

  static const String _dbName = 'progreso.db';
  static const int _version = 2;

  static const String tipoSesionNueva = 'nueva';
  static const String tipoSesionRepaso = 'repaso';

  // Sesión de un sistema: se guarda como 'sistema:Cardiovascular'
  static const String _prefijoSistema = 'sistema:';
  static String tipoSesionSistema(String sistema) => '$_prefijoSistema$sistema';

  /// Texto para mostrar una sesión en Actividad Reciente / Historial.
  static String tituloSesion(String? tipo) {
    if (tipo == tipoSesionRepaso) return 'Repaso';
    if (tipo != null && tipo.startsWith(_prefijoSistema)) {
      return 'Sistema ${tipo.substring(_prefijoSistema.length)}';
    }
    return 'Sesión de flashcards';
  }

  // Guardamos el Future (no la BD) para que dos llamadas simultáneas
  // no abran dos conexiones.
  static Future<Database>? _dbFuture;

  /// Aumenta cada vez que cambia el progreso. Explorar y Perfil lo escuchan
  /// para recargarse aunque sigan vivos en el IndexedStack.
  final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  void _notificar() => cambios.value++;
  Future<Database> get database => _dbFuture ??= _initDB();

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _crearTablas,
      onUpgrade: _migrar,
    );
  }

  // Migraciones: cada versión agrega lo suyo sin borrar el progreso existente
  Future<void> _migrar(Database db, int anterior, int nueva) async {
    if (anterior < 2) {
      await db.execute(_sqlTablaAjustes);
    }
  }

  static const String _sqlTablaAjustes = '''
    CREATE TABLE IF NOT EXISTS ajustes (
      clave TEXT PRIMARY KEY,
      valor TEXT
    )
  ''';

  Future<void> _crearTablas(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE sesiones (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        inicio TEXT    NOT NULL,
        fin    TEXT,
        tipo   TEXT    NOT NULL,
        total  INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE respuestas (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        termino   TEXT    NOT NULL,
        resultado INTEGER NOT NULL,   -- 1 = Lo sé, 0 = Repasar
        fecha     TEXT    NOT NULL,   -- ISO-8601 en hora local
        sesion_id INTEGER REFERENCES sesiones(id) ON DELETE SET NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_respuestas_termino ON respuestas(termino)');
    batch.execute('CREATE INDEX idx_respuestas_fecha ON respuestas(fecha)');
    batch.execute('''
      CREATE TABLE favoritos (
        termino TEXT PRIMARY KEY,
        fecha   TEXT NOT NULL
      )
    ''');
    batch.execute(_sqlTablaAjustes);
    await batch.commit(noResult: true);
  }

  static String _ahora() => DateTime.now().toIso8601String();

  // Subconsulta: la última respuesta de cada término.
  static const String _ultimaRespuestaPorTermino = '''
    SELECT r.termino, r.resultado, r.fecha
    FROM respuestas r
    JOIN (SELECT termino, MAX(id) AS max_id FROM respuestas GROUP BY termino) u
      ON r.id = u.max_id
  ''';

  // =========================================================
  // SESIONES Y RESPUESTAS (Flashcards, CU-05)
  // =========================================================

  Future<int> iniciarSesion({required String tipo, required int total}) async {
    final db = await database;
    return db.insert('sesiones', {
      'inicio': _ahora(),
      'tipo': tipo,
      'total': total,
    });
  }

  Future<void> registrarRespuesta({
    required String termino,
    required bool loSe,
    int? sesionId,
  }) async {
    final db = await database;
    await db.insert('respuestas', {
      'termino': termino,
      'resultado': loSe ? 1 : 0,
      'fecha': _ahora(),
      'sesion_id': sesionId,
    });
    _notificar();
  }

  Future<void> finalizarSesion(int sesionId) async {
    final db = await database;
    await db.update(
      'sesiones',
      {'fin': _ahora()},
      where: 'id = ?',
      whereArgs: [sesionId],
    );
    _notificar();
  }

  // =========================================================
  // ESTADÍSTICAS (Perfil / Explorar)
  // =========================================================

  Future<ResumenProgreso> obtenerResumen() async {
    final db = await database;

    final conteo = await db.rawQuery('''
      SELECT COUNT(*) AS estudiados,
             COALESCE(SUM(resultado), 0) AS aprendidos
      FROM ($_ultimaRespuestaPorTermino)
    ''');
    final totalRespuestas = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM respuestas'),
        ) ??
        0;
    final sesiones = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sesiones WHERE fin IS NOT NULL'),
        ) ??
        0;

    return ResumenProgreso(
      terminosEstudiados: (conteo.first['estudiados'] as int?) ?? 0,
      terminosAprendidos: (conteo.first['aprendidos'] as int?) ?? 0,
      racha: await calcularRacha(),
      totalRespuestas: totalRespuestas,
      sesionesCompletadas: sesiones,
    );
  }

  Future<int> calcularRacha() async {
    final db = await database;
    final filas = await db.rawQuery(
      'SELECT DISTINCT substr(fecha, 1, 10) AS dia FROM respuestas',
    );
    final dias = filas.map((f) => f['dia'] as String).toSet();
    return calcularRachaDesdeDias(dias, DateTime.now());
  }

  /// Lógica pura de la racha (separada para poder probarla sin BD).
  ///
  /// [dias] contiene fechas 'yyyy-MM-dd'. La racha sigue viva si se
  /// estudió hoy o ayer; se cuenta hacia atrás mientras no falte un día.
  @visibleForTesting
  static int calcularRachaDesdeDias(Set<String> dias, DateTime hoy) {
    var dia = DateTime(hoy.year, hoy.month, hoy.day);
    if (!dias.contains(_clave(dia))) {
      dia = DateTime(dia.year, dia.month, dia.day - 1);
      if (!dias.contains(_clave(dia))) return 0;
    }
    var racha = 0;
    while (dias.contains(_clave(dia))) {
      racha++;
      // Construir la fecha así evita errores con el horario de verano.
      dia = DateTime(dia.year, dia.month, dia.day - 1);
    }
    return racha;
  }

  static String _clave(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Términos cuya última respuesta fue "Repasar" (más recientes primero).
  Future<List<String>> obtenerTerminosParaRepasar({int? limite}) async {
    final db = await database;
    final filas = await db.rawQuery('''
      SELECT termino FROM ($_ultimaRespuestaPorTermino)
      WHERE resultado = 0
      ORDER BY fecha DESC
      ${limite != null ? 'LIMIT $limite' : ''}
    ''');
    return filas.map((f) => f['termino'] as String).toList();
  }

  Future<List<ActividadReciente>> obtenerActividadReciente({
    int limite = 5,
  }) async {
    final db = await database;

    final sesiones = await obtenerHistorialSesiones(limite: limite);

    final favoritos = await db.query(
      'favoritos',
      orderBy: 'fecha DESC',
      limit: limite,
    );

    final actividad = <ActividadReciente>[
      ...sesiones,
      for (final f in favoritos)
        ActividadReciente(
          tipo: TipoActividad.favorito,
          fecha: DateTime.parse(f['fecha'] as String),
          termino: f['termino'] as String,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));

    return actividad.take(limite).toList();
  }

  /// Términos cuya última respuesta fue "Lo sé".
  Future<List<String>> obtenerTerminosAprendidos() async {
    final db = await database;
    final filas = await db.rawQuery(
      'SELECT termino FROM ($_ultimaRespuestaPorTermino) WHERE resultado = 1',
    );
    return filas.map((f) => f['termino'] as String).toList();
  }

  /// Sesiones completadas, de la más reciente a la más antigua.
  Future<List<ActividadReciente>> obtenerHistorialSesiones({
    int limite = 100,
  }) async {
    final db = await database;
    final filas = await db.rawQuery('''
      SELECT s.tipo, s.fin,
             COUNT(r.id) AS respondidas,
             COALESCE(SUM(r.resultado), 0) AS lo_se
      FROM sesiones s
      LEFT JOIN respuestas r ON r.sesion_id = s.id
      WHERE s.fin IS NOT NULL
      GROUP BY s.id
      ORDER BY s.fin DESC
      LIMIT ?
    ''', [limite]);
    return [
      for (final s in filas)
        ActividadReciente(
          tipo: TipoActividad.sesion,
          fecha: DateTime.parse(s['fin'] as String),
          tipoSesion: s['tipo'] as String,
          total: s['respondidas'] as int,
          loSe: s['lo_se'] as int,
        ),
    ];
  }

  // =========================================================
  // AJUSTES (nombre del usuario, etc.)
  // =========================================================

  static const String claveNombre = 'nombre_usuario';
  static const String nombrePorDefecto = 'Estudiante de Medicina';

  Future<String?> leerAjuste(String clave) async {
    final db = await database;
    final filas = await db.query(
      'ajustes',
      where: 'clave = ?',
      whereArgs: [clave],
      limit: 1,
    );
    return filas.isEmpty ? null : filas.first['valor'] as String?;
  }

  Future<void> guardarAjuste(String clave, String valor) async {
    final db = await database;
    await db.insert(
      'ajustes',
      {'clave': clave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notificar();
  }

  Future<String> obtenerNombreUsuario() async {
    final nombre = (await leerAjuste(claveNombre))?.trim();
    return (nombre == null || nombre.isEmpty) ? nombrePorDefecto : nombre;
  }

  Future<void> guardarNombreUsuario(String nombre) =>
      guardarAjuste(claveNombre, nombre.trim());

  // =========================================================
  // FAVORITOS ("Términos Guardados")
  // =========================================================

  Future<bool> esFavorito(String termino) async {
    final db = await database;
    final filas = await db.query(
      'favoritos',
      where: 'termino = ?',
      whereArgs: [termino],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  /// Agrega o quita el término. Devuelve `true` si quedó como favorito.
  Future<bool> alternarFavorito(String termino) async {
    final db = await database;
    final borrados = await db.delete(
      'favoritos',
      where: 'termino = ?',
      whereArgs: [termino],
    );
    if (borrados > 0) {
      _notificar();
      return false;
    }
    await db.insert('favoritos', {'termino': termino, 'fecha': _ahora()});
    _notificar();
    return true;
  }

  Future<List<String>> obtenerFavoritos() async {
    final db = await database;
    final filas = await db.query('favoritos', orderBy: 'fecha DESC');
    return filas.map((f) => f['termino'] as String).toList();
  }

  // =========================================================
  // MANTENIMIENTO (para "Configuración de la App")
  // =========================================================

  Future<void> reiniciarProgreso() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('respuestas');
      await txn.delete('sesiones');
      await txn.delete('favoritos');
    });
    _notificar();
  }
}
