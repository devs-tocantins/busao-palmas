import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../data/dados_locais.dart';
import '../domain/models.dart';
import 'linha_chip.dart';

/// "andar 7 › [180] › [040] › andar 9": a rota entendida de relance.
class SequenciaRota extends StatelessWidget {
  const SequenciaRota({super.key, required this.grupo, required this.dados});

  final GrupoOpcoes grupo;
  final DadosLocais dados;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final itens = <Widget>[];
    var iBus = 0;
    for (final t in grupo.principal.trechos) {
      if (itens.isNotEmpty) {
        itens.add(
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
        );
      }
      if (t.tipo == TipoTrecho.andar) {
        itens.add(
          _Andar(minutos: t.duracao.inMinutes < 1 ? 1 : t.duracao.inMinutes),
        );
      } else {
        final linhas = grupo.linhasDoTrecho(iBus++);
        itens.add(_Linhas(linhas: linhas, dados: dados));
      }
    }
    return Semantics(
      label: _descricao(),
      excludeSemantics: true,
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: itens,
      ),
    );
  }

  String _descricao() {
    final partes = <String>[];
    var iBus = 0;
    for (final t in grupo.principal.trechos) {
      if (t.tipo == TipoTrecho.andar) {
        partes.add('andar ${duracaoTexto(t.duracao)}');
      } else {
        partes.add('ônibus ${grupo.linhasDoTrecho(iBus++).join(' ou ')}');
      }
    }
    return partes.join(', ');
  }
}

class _Andar extends StatelessWidget {
  const _Andar({required this.minutos});
  final int minutos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.directions_walk_rounded,
          size: 18,
          color: cs.onSurfaceVariant,
        ),
        Text(
          '$minutos',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Linhas extends StatelessWidget {
  const _Linhas({required this.linhas, required this.dados});
  final List<String> linhas;
  final DadosLocais dados;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = <Widget>[];
    for (final n in linhas) {
      if (r.isNotEmpty) {
        r.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ou',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        );
      }
      r.add(LinhaChip.de(dados.linhas[n], n));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: r,
    );
  }
}
