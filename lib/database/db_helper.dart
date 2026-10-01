import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/sistemas.dart';

class DatabaseHelper {
  // Patrón Singleton para asegurar que solo haya una conexión a la BD abierta
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Nombre del archivo generado en nuestro Frente 1
  final String _dbName = 'diccionario.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    try {
      // 1. Obtener la ruta segura
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _dbName);

      // 2. Comprobar si existe
      bool exists = await databaseExists(path);

      if (!exists) {
        debugPrint("Creando una nueva copia de la base de datos desde los assets...");
        
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (_) {}

        // CORRECCIÓN CLAVE: Forzamos la barra diagonal '/' para que rootBundle no falle en Windows
        ByteData data = await rootBundle.load('assets/$_dbName');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

        // Escribir los bytes
        await File(path).writeAsBytes(bytes, flush: true);
        debugPrint("Base de datos copiada con éxito.");
      } else {
        debugPrint("La base de datos ya existe, abriendo conexión...");
      }

      // 4. Abrir la conexión
      return await openDatabase(path, version: 1);
      
    } catch (e) {
      // Si algo sale mal, el error explotará aquí y lo veremos en consola
      debugPrint("❌ ERROR FATAL AL INICIAR LA BASE DE DATOS: $e");
      rethrow; 
    }
  }
  // =========================================================
  // MÉTODOS DE CONSULTA (CUMPLIMIENTO DE REQUISITOS)
  // =========================================================

  // Obtener todos los términos médicos
  Future<List<Map<String, dynamic>>> obtenerTodosLosTerminos() async {
    final db = await instance.database;
    // Consulta SQL a la tabla 'diccionario_medico' que creamos en Python
    return await db.query('diccionario_medico', orderBy: 'termino ASC');
  }

  // Obtener una lista de 10 términos aleatorios para las Flashcards (CU-05)
  Future<List<Map<String, dynamic>>> obtenerTerminosAleatoriosParaFlashcards() async {
    final db = await instance.database;
    // Utilizamos ORDER BY RANDOM() para que cada sesión de estudio sea única
    return await db.query(
      'diccionario_medico', 
      orderBy: 'RANDOM()', 
      limit: 10,
    );
  }

  // =========================================================
  // TÉRMINO DEL DÍA (CU-01)
  // =========================================================

  // Solo términos completos con una definición útil para una tarjeta destacada
  static const String _filtroTerminoDelDia =
      "categoria = 'Término Completo' AND length(definicion) BETWEEN 40 AND 400";

  // Devuelve el mismo término durante todo el día y cambia a medianoche.
  // No usa RANDOM(): es determinista según la fecha.
  Future<Map<String, dynamic>?> obtenerTerminoDelDia([DateTime? fecha]) async {
    final db = await instance.database;
    final total = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM diccionario_medico WHERE $_filtroTerminoDelDia',
        )) ??
        0;
    if (total == 0) return null;

    final filas = await db.query(
      'diccionario_medico',
      where: _filtroTerminoDelDia,
      orderBy: 'rowid',
      limit: 1,
      offset: indiceTerminoDelDia(fecha ?? DateTime.now(), total),
    );
    return filas.isEmpty ? null : filas.first;
  }

  // Lógica pura (probada en test/termino_del_dia_test.dart).
  // Multiplicar por un primo mayor que [total] recorre todos los términos
  // en orden "salteado" sin repetir ninguno hasta completar el ciclo.
  static int indiceTerminoDelDia(DateTime fecha, int total) {
    // Se usa UTC con la fecha local para que el horario de verano no altere el conteo
    final dia = DateTime.utc(fecha.year, fecha.month, fecha.day)
        .difference(DateTime.utc(2024, 1, 1))
        .inDays;
    const primo = 7919;
    return ((dia * primo) % total + total) % total;
  }

  // =========================================================
  // EXPLORAR POR SISTEMAS (CU-04)
  // =========================================================

  // sistema_anatomico puede tener varios valores: "Nervioso; Musculoesquelético".
  // Se envuelve en ';' para comparar el valor completo (evita falsos parciales).
  static const String _filtroSistema =
      "';' || REPLACE(sistema_anatomico, '; ', ';') || ';' LIKE ?";

  // Total de términos por sistema, ya separados. Ordenado de mayor a menor,
  // con "General / No específico" al final.
  Future<List<SistemaInfo>> obtenerSistemas() async {
    final db = await instance.database;
    final filas = await db.rawQuery(
      'SELECT sistema_anatomico, COUNT(*) AS total FROM diccionario_medico '
      'GROUP BY sistema_anatomico',
    );
    final conteo = <String, int>{};
    for (final f in filas) {
      for (final s in separarSistemas(f['sistema_anatomico'], incluirGeneral: true)) {
        conteo[s] = (conteo[s] ?? 0) + (f['total'] as int);
      }
    }
    final sistemas = [
      for (final e in conteo.entries) SistemaInfo(nombre: e.key, total: e.value),
    ]..sort((a, b) {
        if (a.esGeneral != b.esGeneral) return a.esGeneral ? 1 : -1;
        return b.total.compareTo(a.total);
      });
    return sistemas;
  }

  Future<List<Map<String, dynamic>>> obtenerTerminosPorSistema(String sistema) async {
    final db = await instance.database;
    return db.query(
      'diccionario_medico',
      where: _filtroSistema,
      whereArgs: ['%;$sistema;%'],
      orderBy: 'termino COLLATE NOCASE ASC',
    );
  }

  // Flashcards de un solo sistema
  Future<List<Map<String, dynamic>>> obtenerAleatoriosPorSistema(
    String sistema, {
    int limite = 10,
  }) async {
    final db = await instance.database;
    return db.query(
      'diccionario_medico',
      where: _filtroSistema,
      whereArgs: ['%;$sistema;%'],
      orderBy: 'RANDOM()',
      limit: limite,
    );
  }

  // Obtener términos completos a partir de sus nombres
  // (para Favoritos y "Términos por repasar", guardados en progreso.db)
  Future<List<Map<String, dynamic>>> obtenerTerminosPorNombre(List<String> nombres) async {
    if (nombres.isEmpty) return [];
    final db = await instance.database;
    final resultado = <Map<String, dynamic>>[];
    // SQLite limita los parámetros por consulta; se consulta por bloques
    for (var i = 0; i < nombres.length; i += 500) {
      final bloque = nombres.sublist(i, i + 500 > nombres.length ? nombres.length : i + 500);
      resultado.addAll(await db.query(
        'diccionario_medico',
        where: 'termino IN (${List.filled(bloque.length, '?').join(',')})',
        whereArgs: bloque,
      ));
    }
    return resultado;
  }

  // Total de términos por categoría: {'Raíz': 509, 'Prefijo': 28, ...}
  Future<Map<String, int>> contarPorCategoria() async {
    final db = await instance.database;
    final filas = await db.rawQuery(
      'SELECT categoria, COUNT(*) AS total FROM diccionario_medico GROUP BY categoria',
    );
    return {
      for (final f in filas)
        (f['categoria'] ?? 'Sin categoría').toString(): f['total'] as int,
    };
  }

  // Obtener estadísticas rápidas (Para la pestaña del Perfil/Dashboard)
  Future<int> contarTotalTerminos() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM diccionario_medico');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}