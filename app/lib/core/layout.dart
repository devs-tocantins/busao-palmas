import 'package:flutter/material.dart';

/// A partir daqui a tela é de computador ou tablet: menu na lateral, painel ao lado do mapa.
const larguraTelaGrande = 900.0;

/// Largura máxima do texto e das listas em tela grande; passando disso, a leitura fica cansativa.
const larguraColuna = 640.0;

bool telaGrande(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= larguraTelaGrande;

/// Centraliza o conteúdo numa coluna de largura confortável (não muda nada no celular).
class ColunaCentral extends StatelessWidget {
  const ColunaCentral({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: larguraColuna),
      child: child,
    ),
  );
}
