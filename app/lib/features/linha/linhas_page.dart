import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema.dart';
import '../../state/parada.dart';
import '../../widgets/linha_chip.dart';

/// Aba Linhas: todas as linhas de Palmas, com busca por número ou nome.
class LinhasPage extends ConsumerStatefulWidget {
  const LinhasPage({super.key});

  @override
  ConsumerState<LinhasPage> createState() => _LinhasPageState();
}

class _LinhasPageState extends ConsumerState<LinhasPage> {
  String _filtro = '';

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll(RegExp('[úü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final dados = ref.watch(dadosLinhasProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.margem,
                16,
                Tokens.margem,
                12,
              ),
              child: Text(
                'Linhas',
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.margem),
              child: TextField(
                onChanged: (v) => setState(() => _filtro = _norm(v.trim())),
                decoration: const InputDecoration(
                  hintText: 'Número ou nome da linha',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: dados.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text('Não foi possível carregar as linhas.'),
                ),
                data: (d) {
                  final lista = [
                    for (final l in d.todas)
                      if (_filtro.isEmpty ||
                          _norm(l.linha.numero).contains(_filtro) ||
                          _norm(l.linha.nome).contains(_filtro))
                        l,
                  ];
                  if (lista.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma linha encontrada.',
                        style: t.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (_, i) {
                      final l = lista[i].linha;
                      return ListTile(
                        leading: SizedBox(
                          width: 84,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: LinhaChip.de(l, l.numero),
                          ),
                        ),
                        title: Text(
                          l.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/linha/${l.numero}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
