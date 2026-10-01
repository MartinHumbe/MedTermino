import 'package:flutter/material.dart';

import '../database/progreso_helper.dart';
import '../utils/formato.dart';

const Color _kTeal = Color(0xFF0D9488);
const Color _kTealOscuro = Color(0xFF0F766E);

const String _sistemaGenerico = 'General / No específico';

/// Tarjeta destacada del "Término del Día" (CU-01) para el Dashboard.
class TerminoDelDiaCard extends StatefulWidget {
  const TerminoDelDiaCard({
    super.key,
    required this.termino,
    this.onFavoritoCambiado,
  });

  final Map<String, dynamic> termino;

  /// Se llama después de guardar/quitar el favorito (para refrescar el Dashboard).
  final VoidCallback? onFavoritoCambiado;

  @override
  State<TerminoDelDiaCard> createState() => _TerminoDelDiaCardState();
}

class _TerminoDelDiaCardState extends State<TerminoDelDiaCard> {
  bool _esFavorito = false;

  String get _nombre => widget.termino['termino']?.toString() ?? '';
  String get _definicion => widget.termino['definicion']?.toString() ?? '';
  String get _categoria => widget.termino['categoria']?.toString() ?? '';

  // Separa "Nervioso; Musculoesquelético" y omite el valor genérico
  List<String> get _sistemas => (widget.termino['sistema_anatomico']
              ?.toString() ??
          '')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != _sistemaGenerico)
      .toList();

  @override
  void initState() {
    super.initState();
    _cargarFavorito();
  }

  @override
  void didUpdateWidget(TerminoDelDiaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.termino['termino'] != widget.termino['termino']) {
      _cargarFavorito();
    }
  }

  Future<void> _cargarFavorito() async {
    try {
      final fav = await ProgresoHelper.instance.esFavorito(_nombre);
      if (mounted) setState(() => _esFavorito = fav);
    } catch (e) {
      debugPrint('No se pudo leer favorito: $e');
    }
  }

  Future<void> _alternarFavorito() async {
    try {
      final fav = await ProgresoHelper.instance.alternarFavorito(_nombre);
      if (!mounted) return;
      setState(() => _esFavorito = fav);
      widget.onFavoritoCambiado?.call();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(fav
              ? '"$_nombre" guardado en favoritos'
              : '"$_nombre" eliminado de favoritos'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
    } catch (e) {
      debugPrint('No se pudo guardar favorito: $e');
    }
  }

  String _fechaHoy() {
    final hoy = DateTime.now();
    return '${hoy.day} de ${mesesLargos[hoy.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kTeal, _kTealOscuro],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kTeal.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
          onTap: _mostrarDetalle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado: etiqueta + fecha + favorito
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'TÉRMINO DEL DÍA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· ${_fechaHoy()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: _esFavorito
                          ? 'Quitar de favoritos'
                          : 'Guardar en favoritos',
                      onPressed: _alternarFavorito,
                      icon: Icon(
                        _esFavorito ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _definicion,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (_categoria.isNotEmpty)
                                  _EtiquetaClara(texto: _categoria),
                                for (final s in _sistemas.take(2))
                                  _EtiquetaClara(texto: s),
                              ],
                            ),
                          ),
                          const Text(
                            'Leer más',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hoja inferior con la definición completa
  void _mostrarDetalle() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        // StatefulBuilder para que el ícono de favorito se actualice aquí también
        builder: (context, setSheetState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Término del día · ${_fechaHoy()}',
                  style: const TextStyle(
                    color: _kTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _nombre,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_categoria.isNotEmpty) _EtiquetaTeal(texto: _categoria),
                    for (final s in _sistemas) _EtiquetaTeal(texto: s),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _definicion,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _alternarFavorito();
                      setSheetState(() {});
                    },
                    icon: Icon(
                      _esFavorito ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    label: Text(
                      _esFavorito ? 'Guardado en favoritos' : 'Guardar en favoritos',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kTeal,
                      side: const BorderSide(color: _kTeal, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EtiquetaClara extends StatelessWidget {
  const _EtiquetaClara({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EtiquetaTeal extends StatelessWidget {
  const _EtiquetaTeal({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: _kTeal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
