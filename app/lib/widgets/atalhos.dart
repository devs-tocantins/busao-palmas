import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tema.dart';
import '../domain/models.dart';
import '../state/salvos.dart';

enum Atalho { casa, trabalho }

extension AtalhoInfo on Atalho {
  String get rotulo => this == Atalho.casa ? 'Casa' : 'Trabalho';
  IconData get icone =>
      this == Atalho.casa ? Icons.home_rounded : Icons.work_rounded;
}

/// Dois cartões: Casa e Trabalho. Tocar leva até o lugar salvo; se ainda não há, abre a escolha.
class AtalhosCasaTrabalho extends ConsumerWidget {
  const AtalhosCasaTrabalho({
    super.key,
    required this.aoEscolher,
    required this.aoDefinir,
  });

  /// Chamado com o lugar salvo quando a pessoa toca num atalho já definido.
  final void Function(Lugar) aoEscolher;

  /// Chamado quando o atalho ainda não existe, ou quando a pessoa pede para alterá-lo.
  final void Function(Atalho) aoDefinir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salvos = ref.watch(salvosProvider).value ?? const Salvos();
    return Row(
      children: [
        for (final a in Atalho.values) ...[
          Expanded(
            child: _Cartao(
              atalho: a,
              lugar: a == Atalho.casa ? salvos.casa : salvos.trabalho,
              aoEscolher: aoEscolher,
              aoDefinir: aoDefinir,
            ),
          ),
          if (a == Atalho.casa) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Cartao extends ConsumerWidget {
  const _Cartao({
    required this.atalho,
    required this.lugar,
    required this.aoEscolher,
    required this.aoDefinir,
  });

  final Atalho atalho;
  final Lugar? lugar;
  final void Function(Lugar) aoEscolher;
  final void Function(Atalho) aoDefinir;

  Future<void> _opcoes(BuildContext context, WidgetRef ref) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Alterar ${atalho.rotulo.toLowerCase()}'),
              onTap: () => Navigator.pop(c, 'alterar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text('Remover ${atalho.rotulo.toLowerCase()}'),
              onTap: () => Navigator.pop(c, 'remover'),
            ),
          ],
        ),
      ),
    );
    if (acao == 'alterar') aoDefinir(atalho);
    if (acao == 'remover') {
      final n = ref.read(salvosProvider.notifier);
      atalho == Atalho.casa ? await n.removerCasa() : await n.removerTrabalho();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final definido = lugar != null;
    return Semantics(
      button: true,
      label: definido
          ? '${atalho.rotulo}: ${lugar!.nome}'
          : 'Definir ${atalho.rotulo.toLowerCase()}',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.raioCartao),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.raioCartao),
          onTap: () => definido ? aoEscolher(lugar!) : aoDefinir(atalho),
          onLongPress: definido ? () => _opcoes(context, ref) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: definido ? Tokens.amarelo : cs.outline,
                    child: Icon(
                      atalho.icone,
                      size: 20,
                      color: definido ? Colors.black : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          atalho.rotulo,
                          style: t.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          definido ? lugar!.nome : 'Toque para definir',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (definido)
                    IconButton(
                      tooltip:
                          'Alterar ou remover ${atalho.rotulo.toLowerCase()}',
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      onPressed: () => _opcoes(context, ref),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Os últimos lugares buscados, do mais novo para o mais antigo. Não mostra nada se não há histórico.
class ListaRecentes extends ConsumerWidget {
  const ListaRecentes({
    super.key,
    required this.aoEscolher,
    this.max = Salvos.maxRecentes,
  });

  final void Function(Lugar) aoEscolher;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentes = (ref.watch(salvosProvider).value ?? const Salvos())
        .recentes
        .take(max)
        .toList();
    if (recentes.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final n = ref.read(salvosProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recentes',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: n.limparRecentes,
              child: const Text('Limpar'),
            ),
          ],
        ),
        for (final l in recentes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 8,
            leading: Icon(
              l.ehParada ? Icons.directions_bus_rounded : Icons.history_rounded,
              color: cs.onSurfaceVariant,
            ),
            title: Text(l.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: l.detalhe == null
                ? null
                : Text(
                    l.detalhe!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: IconButton(
              tooltip: 'Remover dos recentes',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => n.removerRecente(l),
            ),
            onTap: () => aoEscolher(l),
          ),
      ],
    );
  }
}
