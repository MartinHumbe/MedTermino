import 'package:flutter_test/flutter_test.dart';
import 'package:med_termino/database/progreso_helper.dart';
import 'package:med_termino/utils/sistemas.dart';

void main() {
  group('separarSistemas', () {
    test('separa valores combinados', () {
      expect(separarSistemas('Nervioso; Musculoesquelético'),
          ['Nervioso', 'Musculoesquelético']);
    });

    test('omite General salvo que se pida', () {
      expect(separarSistemas(sistemaGeneral), isEmpty);
      expect(separarSistemas(sistemaGeneral, incluirGeneral: true),
          [sistemaGeneral]);
    });

    test('nulo o vacío', () {
      expect(separarSistemas(null), isEmpty);
      expect(separarSistemas(''), isEmpty);
    });
  });

  test('todo sistema de la BD tiene ícono propio', () {
    const sistemasBD = [
      'Musculoesquelético', 'Digestivo', 'Celular/Genético', 'Integumentario',
      'Hematológico', 'Nervioso', 'Respiratorio', 'Cardiovascular',
      'Sensorial', 'Urinario', 'Reproductor', 'Infeccioso',
      'Psicológico/Psiquiátrico', 'Endocrino', 'Linfático/Inmunitario',
      sistemaGeneral,
    ];
    for (final s in sistemasBD) {
      expect(EstiloSistema.de(s).descripcion, isNotEmpty, reason: s);
    }
  });

  test('títulos de sesión', () {
    expect(ProgresoHelper.tituloSesion('nueva'), 'Sesión de flashcards');
    expect(ProgresoHelper.tituloSesion('repaso'), 'Repaso');
    expect(
      ProgresoHelper.tituloSesion(ProgresoHelper.tipoSesionSistema('Nervioso')),
      'Sistema Nervioso',
    );
  });
}
