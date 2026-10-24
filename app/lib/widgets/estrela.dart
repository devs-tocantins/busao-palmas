import 'package:flutter/material.dart';

/// Botão de estrela da barra de cima: marca ou desmarca um favorito.
class BotaoEstrela extends StatelessWidget {
  const BotaoEstrela({
    super.key,
    required this.marcado,
    required this.aoAlternar,
    required this.oQue,
  });

  final bool marcado;
  final VoidCallback aoAlternar;

  /// "parada" ou "linha", para o texto lido pelo leitor de tela.
  final String oQue;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: marcado ? 'Remover $oQue dos favoritos' : 'Favoritar $oQue',
    onPressed: aoAlternar,
    icon: Icon(
      marcado ? Icons.star_rounded : Icons.star_outline_rounded,
      color: marcado ? const Color(0xFFE6B800) : null,
    ),
  );
}
