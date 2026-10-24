import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/rotas.dart';
import '../../core/tema.dart';
import '../../data/linhas_repo.dart';
import '../../state/parada.dart';
import '../../widgets/linha_chip.dart';
import '../../widgets/mapa_base.dart';

/// Uma linha: percurso no mapa, horários por tipo de dia e a sequência de paradas.
class LinhaPage extends ConsumerWidget {
  const LinhaPage({super.key, required this.numero});

  final String numero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(dadosLinhasProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Linha $numero')),
      body: dados.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Não foi possível abrir a linha.')),
        data: (d) {
          final l = d.porNumero[numero];
          if (l == null) {
            return const Center(child: Text('Linha não encontrada.'));
          }
          return _Conteudo(detalhe: l);
        },
      ),
    );
  }
}

class _Conteudo extends StatefulWidget {
  const _Conteudo({required this.detalhe});
  final DetalheLinha detalhe;

  @override
  State<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends State<_Conteudo> {
  final _mapa = MapController();
  int _sentido = 0;
  int? _servico; // null = o de hoje

  SentidoLinha get _s => widget.detalhe.sentidos[_sentido];

  int get _servicoAtual {
    if (_servico != null && _servico! < _s.servicos.length) return _servico!;
    final i = _s.servicos.indexWhere((x) => x.vale(DadosLinhas.hoje()));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = widget.detalhe.linha;
    final s = _s;
    final servico = s.servicos.isEmpty ? null : s.servicos[_servicoAtual];
    final hojeVale = servico?.vale(DadosLinhas.hoje()) ?? false;
    final agora = horaPalmas(DateTime.now());
    final proxima = hojeVale
        ? servico!.saidas.where((h) => h.compareTo(agora) >= 0).firstOrNull
        : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.margem,
            4,
            Tokens.margem,
            12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinhaChip.de(l, l.numero, grande: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.nome,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (widget.detalhe.sentidos.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.margem),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < widget.detalhe.sentidos.length; i++)
                  ChoiceChip(
                    label: Text(
                      'Sentido ${widget.detalhe.sentidos[i].destino}',
                    ),
                    selected: i == _sentido,
                    onSelected: (_) {
                      setState(() => _sentido = i);
                    },
                  ),
              ],
            ),
          ),
        if (s.caminho.length >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.margem,
              12,
              Tokens.margem,
              0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.raioCartao),
              child: SizedBox(
                height: 200,
                child: MapaBase(
                  // Chave por sentido: o mapa recomeça enquadrado no percurso novo.
                  key: ValueKey(_sentido),
                  controller: _mapa,
                  interativo: false,
                  ajuste: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(s.caminho),
                    padding: const EdgeInsets.all(24),
                  ),
                  children: [
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: s.caminho,
                          strokeWidth: 5,
                          color: l.cor,
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.margem),
          child: Text(
            'Horários',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        if (servico == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.margem),
            child: Text('Sem horários para este sentido.'),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.margem),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < s.servicos.length; i++)
                  ChoiceChip(
                    label: Text(s.servicos[i].nome),
                    selected: i == _servicoAtual,
                    onSelected: (_) => setState(() => _servico = i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.margem,
              12,
              Tokens.margem,
              0,
            ),
            child: Text(
              !hojeVale
                  ? 'Horários de ${servico.nome.toLowerCase()}.'
                  : proxima != null
                  ? 'Próxima saída hoje: $proxima'
                  : 'Hoje não há mais saídas.',
              style: t.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: proxima != null ? Tokens.aoVivo : cs.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.margem,
              12,
              Tokens.margem,
              0,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in servico.saidas)
                  _Horario(
                    h,
                    destaque: h == proxima,
                    passou: hojeVale && h.compareTo(agora) < 0,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.margem),
          child: Text(
            'Paradas (${s.paradas.length})',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (var i = 0; i < s.paradas.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: l.cor,
              child: Text(
                '${i + 1}',
                style: TextStyle(fontSize: 11, color: l.corTexto),
              ),
            ),
            title: Text(s.paradas[i].nome),
            onTap: () => context.push(
              caminhoParada(s.paradas[i].nome, s.paradas[i].pos),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.margem,
            16,
            Tokens.margem,
            0,
          ),
          child: Text(
            'Horários programados. Para ver o ônibus ao vivo, abra uma parada.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Horario extends StatelessWidget {
  const _Horario(this.hora, {required this.destaque, required this.passou});
  final String hora;
  final bool destaque;
  final bool passou;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: destaque ? Tokens.amarelo : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        hora,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: destaque ? FontWeight.w800 : FontWeight.w500,
          color: destaque
              ? Colors.black
              : (passou ? cs.onSurfaceVariant : cs.onSurface),
          decoration: passou ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
