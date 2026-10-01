import 'package:flutter_test/flutter_test.dart';
import 'package:med_termino/database/db_helper.dart';

void main() {
  int indice(DateTime f) => DatabaseHelper.indiceTerminoDelDia(f, 1023);

  test('el mismo día siempre da el mismo término, sin importar la hora', () {
    expect(indice(DateTime(2026, 9, 30, 0, 1)), indice(DateTime(2026, 9, 30, 23, 59)));
  });

  test('días distintos dan términos distintos', () {
    expect(indice(DateTime(2026, 9, 30)), isNot(indice(DateTime(2026, 10, 1))));
  });

  test('no se repite ningún término hasta completar el ciclo', () {
    final vistos = <int>{};
    for (var i = 0; i < 1023; i++) {
      vistos.add(indice(DateTime(2026, 1, 1 + i)));
    }
    expect(vistos.length, 1023);
  });

  test('el índice siempre está dentro del rango', () {
    for (var i = -500; i < 500; i++) {
      final idx = DatabaseHelper.indiceTerminoDelDia(DateTime(2024, 1, 1 + i), 7);
      expect(idx, inInclusiveRange(0, 6));
    }
  });
}
