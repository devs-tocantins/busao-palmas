import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/rotas.dart';
import '../../core/tema.dart';
import '../../data/dados_locais.dart' show ParadaLocal;
import '../../data/linhas_repo.dart';
import '../../domain/models.dart';
import '../../state/parada.dart';
import '../../state/planejador.dart';
import '../../state/salvos.dart';
import '../../widgets/camada_onibus.dart';
import '../../widgets/estrela.dart';
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
      appBar: AppBar(
        title: Text('Linha $numero'),
        actions: [
          BotaoEstrela(
            oQue: 'linha',
            marcado: (ref.watch(salvosProvider).value ?? const Salvos())
                .linhasFavoritas
                .contains(numero),
            aoAlternar: () =>
                ref.read(salvosProvider.notifier).alternarLinha(numero),
          ),
        ],
      ),
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

class _Conteudo extends ConsumerStatefulWidget {
  const _Conteudo({required this.detalhe});
  final DetalheLinha detalhe;

  @override
  ConsumerState<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends ConsumerState<_Conteudo> {
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
    final minha = ref.watch(planejadorProvider.select((x) => x.minhaPos));
    final perto = minha == null ? null : s.maisPerto(minha);
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
                    // Os ônibus desta linha rodando agora.
                    CamadaOnibus(linhas: {l.numero}),
                    // Todas as paradas do percurso; a mais perto da pessoa fica maior.
                    CircleLayer(
                      circles: [
                        for (final p in s.paradas)
                          CircleMarker(
                            point: p.pos,
                            radius: 3.5,
                            color: Colors.white,
                            borderColor: l.cor,
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (perto != null)
                          marcadorPonto(
                            s.paradas[perto.indice].pos,
                            destino: true,
                            context: context,
                          ),
                        if (minha != null)
                          marcadorPonto(
                            minha,
                            destino: false,
                            context: context,
                          ),
                      ],
                    ),
                  ],
                ),
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
          child: perto == null
              ? const _PedirLocalizacao()
              : _ParadaMaisPerto(
                  numero: l.numero,
                  parada: s.paradas[perto.indice],
                  metros: perto.metros,
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
            title: Text(
              s.paradas[i].nome,
              style: i == perto?.indice
                  ? const TextStyle(fontWeight: FontWeight.w800)
                  : null,
            ),
            subtitle: i == perto?.indice
                ? const Text('Mais perto de você')
                : null,
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

/// Pede a localização para achar a parada da linha mais perto de quem está olhando.
class _PedirLocalizacao extends ConsumerWidget {
  const _PedirLocalizacao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buscando = ref.watch(
      planejadorProvider.select((x) => x.buscandoLocalizacao),
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.my_location_rounded),
        title: const Text('Qual parada fica mais perto de mim?'),
        subtitle: Text(
          buscando ? 'Buscando sua localização…' : 'Usar minha localização',
        ),
        onTap: buscando
            ? null
            : ref.read(planejadorProvider.notifier).usarMinhaLocalizacao,
      ),
    );
  }
}

/// A parada da linha mais perto da pessoa, com a próxima passagem desta linha ali.
class _ParadaMaisPerto extends ConsumerWidget {
  const _ParadaMaisPerto({
    required this.numero,
    required this.parada,
    required this.metros,
  });

  final String numero;
  final ParadaLocal parada;
  final double metros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ref0 = ParadaRef(nome: parada.nome, pos: parada.pos);
    final saidas = ref.watch(saidasProvider(ref0));
    final proxima = saidas.value
        ?.where((x) => x.linha == numero)
        .map((x) => x.proxima)
        .fold<Chegada?>(
          null,
          (a, b) => a == null || b.horario.isBefore(a.horario) ? b : a,
        );
    final detalhe = saidas.isLoading
        ? 'Carregando horários…'
        : proxima == null
        ? 'Sem passagem desta linha nas próximas horas'
        : 'Próximo ônibus: ${faltaTexto(proxima)}${proxima.aoVivo ? ' · ao vivo' : ''}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(caminhoParada(parada.nome, parada.pos)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parada mais perto de você · ${distanciaTexto(metros)}',
                      style: t.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      parada.nome,
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(detalhe, style: t.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
