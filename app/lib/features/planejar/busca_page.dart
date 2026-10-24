import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema.dart';
import '../../domain/models.dart';
import '../../state/planejador.dart';

/// Busca de lugar para a origem ou o destino. Usa o geocodificador do Bus2 (mínimo de 3 letras).
class BuscaPage extends ConsumerStatefulWidget {
  const BuscaPage({super.key, required this.campo});

  final CampoMapa campo;

  @override
  ConsumerState<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends ConsumerState<BuscaPage> {
  final _controle = TextEditingController();
  Timer? _espera;
  List<Lugar> _resultados = const [];
  bool _carregando = false;
  Object? _erro;
  int _pedido = 0;

  bool get _origem => widget.campo == CampoMapa.origem;

  @override
  void dispose() {
    _espera?.cancel();
    _controle.dispose();
    super.dispose();
  }

  void _digitou(String texto) {
    _espera?.cancel();
    final q = texto.trim();
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

  void _escolher(Lugar l) {
    final n = ref.read(planejadorProvider.notifier);
    _origem ? n.definirOrigem(l) : n.definirDestino(l);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final digitou = _controle.text.trim().length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(_origem ? 'De onde você sai?' : 'Para onde você vai?'),
      ),
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
                if (_origem)
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
                ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(Icons.pin_drop_outlined, color: cs.onSurface),
                  title: const Text('Escolher no mapa'),
                  onTap: () {
                    ref
                        .read(planejadorProvider.notifier)
                        .escolherNoMapa(widget.campo);
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
                else if (digitou && !_carregando && _resultados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Tokens.margem),
                    child: Text(
                      'Nada encontrado para "${_controle.text.trim()}". Tente outro nome ou toque no mapa.',
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                else if (!digitou)
                  Padding(
                    padding: const EdgeInsets.all(Tokens.margem),
                    child: Text(
                      'Digite pelo menos 3 letras. Ex.: uft, palmas shopping, 104 sul.',
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                for (final l in _resultados)
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
