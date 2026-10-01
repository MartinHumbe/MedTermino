import 'package:flutter_test/flutter_test.dart';
import 'package:med_termino/database/progreso_helper.dart';
import 'package:med_termino/utils/formato.dart';

void main() {
  group('Racha de estudio', () {
    final hoy = DateTime(2026, 9, 30, 21, 30);
    int racha(Set<String> dias) =>
        ProgresoHelper.calcularRachaDesdeDias(dias, hoy);

    test('sin estudio es 0', () => expect(racha({}), 0));

    test('solo hoy es 1', () => expect(racha({'2026-09-30'}), 1));

    test('días consecutivos hasta hoy', () {
      expect(racha({'2026-09-28', '2026-09-29', '2026-09-30'}), 3);
    });

    test('si hoy aún no estudia, la racha de ayer sigue viva', () {
      expect(racha({'2026-09-28', '2026-09-29'}), 2);
    });

    test('un día sin estudiar rompe la racha', () {
      expect(racha({'2026-09-25', '2026-09-26', '2026-09-30'}), 1);
      expect(racha({'2026-09-27', '2026-09-28'}), 0);
    });

    test('cruza cambio de mes', () {
      final dias = {'2026-08-30', '2026-08-31', '2026-09-01'};
      expect(
        ProgresoHelper.calcularRachaDesdeDias(dias, DateTime(2026, 9, 1)),
        3,
      );
    });
  });

  group('ResumenProgreso', () {
    test('porcentaje de dominio', () {
      const r = ResumenProgreso(
        terminosEstudiados: 10,
        terminosAprendidos: 9,
        racha: 1,
        totalRespuestas: 10,
        sesionesCompletadas: 1,
      );
      expect(r.porcentajeDominio, 90);
      expect(r.terminosPorRepasar, 1);
    });

    test('sin datos no divide entre cero', () {
      const r = ResumenProgreso(
        terminosEstudiados: 0,
        terminosAprendidos: 0,
        racha: 0,
        totalRespuestas: 0,
        sesionesCompletadas: 0,
      );
      expect(r.porcentajeDominio, 0);
    });
  });

  group('Niveles', () {
    test('cada umbral asigna el nivel correcto', () {
      expect(NivelEstudio.para(0).nombre, 'Principiante');
      expect(NivelEstudio.para(24).nombre, 'Principiante');
      expect(NivelEstudio.para(25).nombre, 'Estudiante');
      expect(NivelEstudio.para(300).nombre, 'Residente');
      expect(NivelEstudio.para(1908).nombre, 'Maestro');
    });

    test('progreso hacia el siguiente nivel', () {
      expect(NivelEstudio.para(50).progreso(50), closeTo(25 / 75, 0.001));
      expect(NivelEstudio.para(1500).progreso(1500), 1.0);
    });
  });

  group('fechaRelativa', () {
    final ahora = DateTime(2026, 9, 30, 21, 0);

    test('hoy y ayer con hora', () {
      expect(fechaRelativa(DateTime(2026, 9, 30, 9, 5), ahora: ahora), 'Hoy, 09:05');
      expect(fechaRelativa(DateTime(2026, 9, 29, 23, 59), ahora: ahora), 'Ayer, 23:59');
    });

    test('días recientes y fechas antiguas', () {
      expect(fechaRelativa(DateTime(2026, 9, 27), ahora: ahora), 'Hace 3 días');
      expect(fechaRelativa(DateTime(2026, 9, 12), ahora: ahora), '12 sep');
      expect(fechaRelativa(DateTime(2025, 12, 1), ahora: ahora), '1 dic 2025');
    });
  });
}
