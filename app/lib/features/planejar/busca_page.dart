import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/formato.dart';
import '../../core/rotas.dart';
import '../../core/tema.dart';
import '../../data/busca_local.dart';
import '../../domain/models.dart';
import '../../state/parada.dart';
import '../../state/planejador.dart';
import '../../state/salvos.dart';
import '../../widgets/atalhos.dart';
import '../../widgets/linha_chip.dart';

/// Para que a busca está sendo aberta.
enum ModoBusca {
  origem('De onde você sai?'),
  destino('Para onde você vai?'),
  casa('Onde fica a sua casa?'),
  trabalho('Onde você trabalha?');

  const ModoBusca(this.titulo);
  final String titulo;

  bool get ehViagem => this == origem || this == destino;

  static ModoBusca doTexto(String? t) => ModoBusca.values.firstWhere(
    (m) => m.name == t,
    orElse: () => ModoBusca.destino,
  );
}

/// Busca de lugar. Usa o geocodificador do Bus2 (mínimo de 3 letras).
/// Sem nada digitado, mostra os atalhos Casa e Trabalho e os lugares recentes.
class BuscaPage extends ConsumerStatefulWidget {
  const BuscaPage({super.key, required this.modo});

  final ModoBusca modo;

  @override
  ConsumerState<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends ConsumerState<BuscaPage> {
  final _controle = TextEditingController();
  Timer? _espera;
  List<Lugar> _resultados = const [];
  List<ResultadoBusca> _locais = const [];
  bool _carregando = false;
  Object? _erro;
  int _pedido = 0;

  ModoBusca get _modo => widget.modo;

  @override
  void dispose() {
    _espera?.cancel();
    _controle.dispose();
    super.dispose();
  }

  /// Resultados do aparelho: aparecem a cada letra, sem esperar a rede.
  List<ResultadoBusca> _buscarLocal(String q) {
    final indice = ref.read(buscaLocalProvider).value;
    if (indice == null || q.isEmpty) return const [];
    final r = indice.buscar(
      q,
      perto: ref.read(planejadorProvider).minhaPos,
      limite: 10,
    );
    // Casa e trabalho são lugares: linha não serve.
    return _modo.ehViagem
        ? r
        : [
            for (final x in r)
              if (x.tipo != TipoBusca.linha) x,
          ];
  }

  void _digitou(String texto) {
    _espera?.cancel();
    final q = texto.trim();
    _locais = _buscarLocal(q);
    if (q.length < 3) {
      setState(() {
        _resultados = const [];
        _carregando = false;
        _erro = null;
      });
      return;
    }
    setState(() => _carregando = true);
    _espera = Timer(const Duration(milliseconds: 350), () => _buscar(q));
  }

  Future<void> _buscar(String q) async {
    final meu = ++_pedido;
    try {
      final r = await ref.read(otpClientProvider).buscar(q);
      if (!mounted || meu != _pedido) return;
      setState(() {
        _resultados = r;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      if (!mounted || meu != _pedido) return;
      setState(() {
        _carregando = false;
        _erro = e;
      });
    }
  }

  /// [guardar]: entra nos recentes. Os atalhos e os próprios recentes não precisam entrar de novo.
  void _escolher(Lugar l, {bool guardar = true}) {
    final planejador = ref.read(planejadorProvider.notifier);
    final salvos = ref.read(salvosProvider.notifier);
    switch (_modo) {
      case ModoBusca.origem:
        planejador.definirOrigem(l);
      case ModoBusca.destino:
        planejador.definirDestino(l);
      case ModoBusca.casa:
        salvos.definirCasa(l);
      case ModoBusca.trabalho:
        salvos.definirTrabalho(l);
    }
    if (guardar && _modo.ehViagem) salvos.registrarRecente(l);
    context.pop();
  }

  void _salvarComo(Atalho a, Lugar l) {
    final n = ref.read(salvosProvider.notifier);
    a == Atalho.casa ? n.definirCasa(l) : n.definirTrabalho(l);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${a.rotulo} salva: ${l.nome}')));
  }

  /// Abre a escolha de um atalho sem sair do fluxo atual.
  void _definirAtalho(Atalho a) =>
      context.push('/busca/${a == Atalho.casa ? 'casa' : 'trabalho'}');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // Começa a ler o índice local e refaz a busca quando ele ficar pronto.
    ref.listen(buscaLocalProvider, (_, _) {
      if (!mounted) return;
      setState(() => _locais = _buscarLocal(_controle.text.trim()));
    });
    final digitou = _controle.text.trim().isNotEmpty;
    final minha = ref.watch(planejadorProvider.select((x) => x.minhaPos));
    // O que o aparelho achou vem primeiro; o servidor entra no que sobra, sem repetir.
    final locais = _locais;
    final jaTem = {
      for (final x in locais)
        if (x.pos != null) normalizar(x.titulo),
    };
    final servidor = [
      for (final l in _resultados)
        if (!jaTem.contains(normalizar(l.nome))) l,
    ];
    final vazio = locais.isEmpty && servidor.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(_modo.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.margem,
              4,
              Tokens.margem,
              8,
            ),
            child: TextField(
              controller: _controle,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _digitou,
              decoration: InputDecoration(
                hintText: 'Lugar, endereço ou parada',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controle.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controle.clear();
                          _digitou('');
                        },
                      ),
              ),
            ),
          ),
          if (_carregando) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              children: [
                if (_modo == ModoBusca.origem)
                  ListTile(
                    minVerticalPadding: 12,
                    leading: const Icon(
                      Icons.my_location_rounded,
                      color: Tokens.azul,
                    ),
                    title: const Text('Minha localização'),
                    onTap: () {
                      ref
                          .read(planejadorProvider.notifier)
                          .usarMinhaLocalizacao();
                      context.pop();
                    },
                  ),
                if (_modo.ehViagem)
                  ListTile(
                    minVerticalPadding: 12,
                    leading: Icon(Icons.pin_drop_outlined, color: cs.onSurface),
                    title: const Text('Escolher no mapa'),
                    onTap: () {
                      ref
                          .read(planejadorProvider.notifier)
                          .escolherNoMapa(
                            _modo == ModoBusca.origem
                                ? CampoMapa.origem
                                : CampoMapa.destino,
                          );
                      context.pop();
                    },
                  ),
                const Divider(height: 1),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.all(Tokens.margem),
                    child: Text(
                      'Não conseguimos buscar agora. Verifique a internet e tente de novo.',
                      style: t.bodyMedium?.copyWith(color: cs.error),
                    ),
                  )
                else if (digitou && !_carregando && vazio)
                  Padding(
                    padding: const EdgeInsets.all(Tokens.margem),
                    child: Text(
                      'Nada encontrado para "${_controle.text.trim()}". Tente outro nome${_modo.ehViagem ? ' ou toque no mapa' : ''}.',
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                else if (!digitou)
                  Padding(
                    padding: const EdgeInsets.all(Tokens.margem),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_modo.ehViagem) ...[
                          AtalhosCasaTrabalho(
                            aoEscolher: (l) => _escolher(l, guardar: false),
                            aoDefinir: _definirAtalho,
                          ),
                          const SizedBox(height: 16),
                        ],
                        ListaRecentes(
                          aoEscolher: (l) => _escolher(l, guardar: false),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Digite um lugar, endereço, parada ou linha. Ex.: uft, palmas shopping, 104 sul, 090.',
                          style: t.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final r in locais)
                  _ItemLocal(
                    r: r,
                    minha: minha,
                    aoEscolher: r.tipo == TipoBusca.linha
                        ? () => context.push('/linha/${r.linha}')
                        : () => _escolher(r.lugar!),
                  ),
                for (final l in servidor)
                  ListTile(
                    minVerticalPadding: 10,
                    leading: Icon(
                      l.ehParada
                          ? Icons.directions_bus_rounded
                          : Icons.place_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    title: Text(
                      l.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: l.detalhe == null
                        ? null
                        : Text(
                            l.detalhe!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: _modo.ehViagem
                        ? PopupMenuButton<Object>(
                            tooltip: l.ehParada
                                ? 'Mais opções da parada'
                                : 'Salvar como casa ou trabalho',
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onSelected: (a) => a is Atalho
                                ? _salvarComo(a, l)
                                : context.push(caminhoParada(l.nome, l.pos)),
                            itemBuilder: (_) => [
                              if (l.ehParada)
                                const PopupMenuItem<Object>(
                                  value: 'horarios',
                                  child: Text('Ver horários da parada'),
                                ),
                              for (final a in Atalho.values)
                                PopupMenuItem<Object>(
                                  value: a,
                                  child: Text(
                                    'Definir como ${a.rotulo.toLowerCase()}',
                                  ),
                                ),
                            ],
                          )
                        : null,
                    onTap: () => _escolher(l),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha de resultado vinda do aparelho: ícone ou etiqueta pelo tipo, e a distância até a pessoa.
class _ItemLocal extends ConsumerWidget {
  const _ItemLocal({
    required this.r,
    required this.minha,
    required this.aoEscolher,
  });

  final ResultadoBusca r;
  final LatLng? minha;
  final VoidCallback aoEscolher;

  static IconData _icone(ResultadoBusca r) => switch (r.categoria) {
    'parada' => Icons.directions_bus_rounded,
    'aeroporto' => Icons.flight_rounded,
    'educacao' => Icons.school_outlined,
    'saude' => Icons.local_hospital_outlined,
    'comercio' => Icons.shopping_bag_outlined,
    'lazer' => Icons.park_outlined,
    'culto' => Icons.church_outlined,
    'bairro' => Icons.location_city_rounded,
    _ => Icons.place_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dados = ref.watch(dadosLocaisProvider);
    final linha = r.tipo == TipoBusca.linha;
    final dist = (minha != null && r.pos != null)
        ? distanciaTexto(const Distance().as(LengthUnit.Meter, minha!, r.pos!))
        : null;
    final detalhe = [
      if (linha) 'Linha de ônibus' else if (r.detalhe != null) r.detalhe!,
      if (dist != null) 'a $dist',
    ].join(' · ');
    return ListTile(
      minVerticalPadding: 10,
      leading: linha
          ? SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.centerLeft,
                child: LinhaChip.de(dados.linhas[r.linha], r.linha!),
              ),
            )
          : Icon(_icone(r), color: cs.onSurfaceVariant),
      title: Text(r.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: detalhe.isEmpty
          ? null
          : Text(detalhe, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: aoEscolher,
    );
  }
}
