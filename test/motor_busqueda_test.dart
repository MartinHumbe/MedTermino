import 'package:flutter_test/flutter_test.dart';
import 'package:med_termino/database/motor_busqueda.dart';

void main() {
  final motor = MotorBusqueda.desdeFilas([
    {'termino': 'celíaca', 'definicion': 'Relativo al vientre. Diarrea crónica.'},
    {'termino': 'diarrea', 'definicion': 'Síntoma o fenómeno morboso.'},
    {'termino': 'disentería', 'definicion': 'Enfermedad con diarrea y sangre.'},
    {'termino': 'patognomónico', 'definicion': 'Síntoma que define una enfermedad.'},
    {'termino': '-itis', 'definicion': 'Inflamación.'},
    {'termino': 'otitis', 'definicion': 'Inflamación del oído.'},
    {'termino': 'Ammon', 'definicion': 'Raíz.'},
  ]);

  List<String> buscar(String q) =>
      motor.buscar(q).map((t) => t['termino'] as String).toList();

  group('normalizar', () {
    test('quita acentos, mayúsculas, espacios y guiones de afijo', () {
      expect(MotorBusqueda.normalizar('  PATOGNOMÓNICO '), 'patognomonico');
      expect(MotorBusqueda.normalizar('-ÍTIS'), 'itis');
      expect(MotorBusqueda.normalizar('niño   pequeño'), 'nino pequeno');
    });
  });

  group('buscar', () {
    test('una sola letra devuelve resultados (bug de la "D")', () {
      expect(buscar('D'), isNotEmpty);
      expect(buscar('d'), buscar('D'));
    });

    test('la coincidencia exacta va primero', () {
      expect(buscar('DIARREA').first, 'diarrea');
      expect(buscar('diarrea'), containsAll(['celíaca', 'disentería']));
    });

    test('ignora acentos', () {
      expect(buscar('patognomonico'), ['patognomónico']);
    });

    test('encuentra sufijos con o sin guion', () {
      expect(buscar('-itis').first, '-itis');
      expect(buscar('itis').first, '-itis');
      expect(buscar('itis'), contains('otitis'));
    });

    test('vacío o sin coincidencias', () {
      expect(buscar('   '), isEmpty);
      expect(buscar('xyzxyz'), isEmpty);
    });
  });
}
