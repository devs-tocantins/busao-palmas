import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/dados_locais.dart';

/// Etiqueta com o número da linha, na cor que a operadora usa.
class LinhaChip extends StatelessWidget {
  const LinhaChip({
    super.key,
    required this.numero,
    this.cor,
    this.corTexto,
    this.grande = false,
  });

  final String numero;
  final Color? cor;
  final Color? corTexto;
  final bool grande;

  factory LinhaChip.de(LinhaLocal? l, String numero, {bool grande = false}) =>
      LinhaChip(
        numero: numero,
        cor: l?.cor,
        corTexto: l?.corTexto,
        grande: grande,
      );

  @override
  Widget build(BuildContext context) {
    final fundo = cor ?? Tokens.azul;
    final texto = corTexto ?? Colors.white;
    return Semantics(
      label: 'ônibus $numero',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: grande ? 12 : 8,
          vertical: grande ? 6 : 4,
        ),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_bus_rounded,
              size: grande ? 18 : 14,
              color: texto,
            ),
            const SizedBox(width: 4),
            Text(
              numero,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: texto,
                fontWeight: FontWeight.w700,
                fontSize: grande ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
