import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../data/dados_locais.dart';
import '../data/otp_client.dart';
import '../domain/models.dart';

/// Substituído em main() depois de carregar os arquivos de assets/data.
final dadosLocaisProvider = Provider<DadosLocais>(
  (ref) => throw UnimplementedError('dadosLocaisProvider'),
);

final otpClientProvider = Provider<OtpClient>(
  (ref) => OtpClient(ref.watch(dadosLocaisProvider)),
);

/// Qual ponto o próximo toque no mapa vai definir.
enum CampoMapa { destino, origem }

class PlanejadorState {
  const PlanejadorState({
    this.origem,
    this.destino,
    this.grupos = const AsyncData([]),
    this.selecionado,
    this.campoMapa = CampoMapa.destino,
    this.buscandoLocalizacao = false,
    this.saida,
    this.proxima,
    this.procurandoProxima = false,
  });

  final Lugar? origem;
  final Lugar? destino;
  final AsyncValue<List<GrupoOpcoes>> grupos;
  final GrupoOpcoes? selecionado;
  final CampoMapa campoMapa;
  final bool buscandoLocalizacao;

  /// null = sair agora. Instante absoluto (UTC); a tela mostra no relógio de Palmas.
  final DateTime? saida;

  /// Quando não há ônibus agora: a primeira saída que o planejador encontrou mais tarde.
  final DateTime? proxima;
  final bool procurandoProxima;

  PlanejadorState copyWith({
    Lugar? origem,
    Lugar? destino,
    AsyncValue<List<GrupoOpcoes>>? grupos,
    GrupoOpcoes? selecionado,
    bool limparSelecionado = false,
    CampoMapa? campoMapa,
    bool? buscandoLocalizacao,
    DateTime? saida,
    bool sairAgora = false,
    DateTime? proxima,
    bool limparProxima = false,
    bool? procurandoProxima,
  }) => PlanejadorState(
    origem: origem ?? this.origem,
    destino: destino ?? this.destino,
    grupos: grupos ?? this.grupos,
    selecionado: limparSelecionado ? null : (selecionado ?? this.selecionado),
    campoMapa: campoMapa ?? this.campoMapa,
    buscandoLocalizacao: buscandoLocalizacao ?? this.buscandoLocalizacao,
    saida: sairAgora ? null : (saida ?? this.saida),
    proxima: limparProxima ? null : (proxima ?? this.proxima),
    procurandoProxima: procurandoProxima ?? this.procurandoProxima,
  );
}

class PlanejadorNotifier extends Notifier<PlanejadorState> {
  int _pedido = 0;

  @override
  PlanejadorState build() {
    // Link de rota (web): ?de=lat,lng&para=lat,lng&hora=08:00
    final q = Uri.base.queryParameters;
    final de = _ponto(q['de']), para = _ponto(q['para']);
    if (de != null && para != null) {
      Future.microtask(() => _abrirLink(de, para, q['hora']));
    } else {
      Future.microtask(usarMinhaLocalizacao);
    }
    return const PlanejadorState();
  }

  static LatLng? _ponto(String? s) {
    final p = s?.split(',');
    if (p == null || p.length != 2) return null;
    final la = double.tryParse(p[0]), lo = double.tryParse(p[1]);
    if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) {
      return null;
    }
    return LatLng(la, lo);
  }

  Future<void> _abrirLink(LatLng de, LatLng para, String? hora) async {
    final h = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hora ?? '');
    if (h != null) {
      final hh = int.parse(h[1]!), mm = int.parse(h[2]!);
      if (hh < 24 && mm < 60) {
        final agora = DateTime.now().toUtc().add(Config.fusoPalmas);
        var parede = DateTime.utc(agora.year, agora.month, agora.day, hh, mm);
        if (!parede.isAfter(agora)) {
          parede = parede.add(const Duration(days: 1));
        }
        state = state.copyWith(saida: parede.subtract(Config.fusoPalmas));
      }
    }
    state = state.copyWith(
      origem: Lugar(nome: 'Origem', pos: de),
    );
    definirDestino(Lugar(nome: 'Destino', pos: para));
    // Troca os nomes genéricos pelos do mapa, se o serviço responder.
    final otp = ref.read(otpClientProvider);
    final no = await otp.nomeDoPonto(de), nd = await otp.nomeDoPonto(para);
    if (state.origem?.pos == de && no != null) {
      state = state.copyWith(
        origem: Lugar(nome: no, pos: de),
      );
    }
    if (state.destino?.pos == para && nd != null) {
      state = state.copyWith(
        destino: Lugar(nome: nd, pos: para),
      );
    }
  }

  /// Origem = posição do aparelho. Se não houver permissão, a origem fica vazia e a pessoa escolhe.
  Future<void> usarMinhaLocalizacao() async {
    state = state.copyWith(buscandoLocalizacao: true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        state = state.copyWith(buscandoLocalizacao: false);
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      definirOrigem(
        Lugar(
          nome: 'Minha localização',
          pos: LatLng(p.latitude, p.longitude),
          minhaLocalizacao: true,
        ),
      );
    } catch (_) {
      // Sem GPS ou sem permissão: segue sem origem.
    } finally {
      state = state.copyWith(buscandoLocalizacao: false);
    }
  }

  void definirOrigem(Lugar l) {
    state = state.copyWith(origem: l, campoMapa: CampoMapa.destino);
    _calcular();
  }

  void definirDestino(Lugar l) {
    state = state.copyWith(destino: l, campoMapa: CampoMapa.destino);
    _calcular();
  }

  void escolherNoMapa(CampoMapa campo) =>
      state = state.copyWith(campoMapa: campo);

  void trocar() {
    final o = state.origem, d = state.destino;
    if (o == null && d == null) return;
    state = PlanejadorState(
      origem: d,
      destino: o,
      campoMapa: state.campoMapa,
      saida: state.saida,
    );
    _calcular();
  }

  /// Hora e minuto no relógio de Palmas; se já passou hoje, vale para amanhã. null = sair agora.
  void definirSaida(int? hora, [int minuto = 0]) {
    if (hora == null) {
      state = state.copyWith(sairAgora: true);
    } else {
      final agora = DateTime.now().toUtc().add(Config.fusoPalmas);
      var parede = DateTime.utc(
        agora.year,
        agora.month,
        agora.day,
        hora,
        minuto,
      );
      if (!parede.isAfter(agora)) parede = parede.add(const Duration(days: 1));
      state = state.copyWith(saida: parede.subtract(Config.fusoPalmas));
    }
    _calcular();
  }

  void selecionar(GrupoOpcoes g) => state = state.copyWith(selecionado: g);

  /// Toque no mapa: define origem ou destino conforme [PlanejadorState.campoMapa].
  Future<void> tocarNoMapa(LatLng p) async {
    final campo = state.campoMapa;
    final provisorio = Lugar(nome: 'Ponto no mapa', pos: p);
    campo == CampoMapa.origem
        ? definirOrigem(provisorio)
        : definirDestino(provisorio);
    final nome = await ref.read(otpClientProvider).nomeDoPonto(p);
    if (nome == null) return;
    final nomeado = Lugar(nome: nome, pos: p);
    // Só atualiza o nome se a pessoa não mudou de ideia nesse meio tempo.
    if (campo == CampoMapa.origem && state.origem?.pos == p) {
      state = state.copyWith(origem: nomeado);
    } else if (campo == CampoMapa.destino && state.destino?.pos == p) {
      state = state.copyWith(destino: nomeado);
    }
  }

  Future<void> _calcular() async {
    final o = state.origem, d = state.destino;
    if (o == null || d == null) return;
    final meu = ++_pedido;
    state = state.copyWith(
      grupos: const AsyncLoading(),
      limparSelecionado: true,
      limparProxima: true,
      procurandoProxima: false,
    );
    try {
      final opcoes = await ref
          .read(otpClientProvider)
          .planejar(de: o.pos, para: d.pos, saida: state.saida);
      if (meu != _pedido) return;
      state = state.copyWith(grupos: AsyncData(agruparOpcoes(opcoes)));
    } catch (e, s) {
      if (meu != _pedido) return;
      state = state.copyWith(grupos: AsyncError(e, s));
      if (e is SemRota && state.saida == null) _procurarProxima(o, d, meu);
    }
  }

  /// Sem ônibus agora: pergunta ao planejador por horários mais tarde e fica com a primeira saída que achar.
  /// Cobre madrugada e fim de noite (ex.: o Corujão, linha 620, só sai à 00:30, 01:30, 02:30 e 03:30).
  Future<void> _procurarProxima(Lugar o, Lugar d, int meu) async {
    state = state.copyWith(procurandoProxima: true);
    final agora = DateTime.now();
    final otp = ref.read(otpClientProvider);
    final saidas = await Future.wait([
      for (final h in const [1, 2, 3, 4, 5, 6, 8, 12, 16, 20])
        otp
            .planejar(
              de: o.pos,
              para: d.pos,
              saida: agora.add(Duration(hours: h)),
            )
            .then<DateTime?>(
              (opcoes) => opcoes
                  .map((x) => x.inicio)
                  .reduce((a, b) => a.isBefore(b) ? a : b),
            )
            .catchError((_) => null),
    ]);
    if (meu != _pedido) return;
    final achadas = saidas.whereType<DateTime>().toList()..sort();
    state = state.copyWith(
      procurandoProxima: false,
      proxima: achadas.isEmpty ? null : achadas.first,
      limparProxima: achadas.isEmpty,
    );
  }

  /// Sair num instante exato (usado por "Próximo ônibus").
  void definirSaidaExata(DateTime t) {
    state = state.copyWith(saida: t);
    _calcular();
  }
}

final planejadorProvider =
    NotifierProvider<PlanejadorNotifier, PlanejadorState>(
      PlanejadorNotifier.new,
    );
