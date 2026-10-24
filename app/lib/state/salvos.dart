import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Atalhos e histórico, guardados só no aparelho (sem conta).
class Salvos {
  const Salvos({this.casa, this.trabalho, this.recentes = const []});

  final Lugar? casa;
  final Lugar? trabalho;

  /// Do mais novo para o mais antigo.
  final List<Lugar> recentes;

  static const maxRecentes = 8;

  Salvos copyWith({
    Lugar? casa,
    bool limparCasa = false,
    Lugar? trabalho,
    bool limparTrabalho = false,
    List<Lugar>? recentes,
  }) => Salvos(
    casa: limparCasa ? null : (casa ?? this.casa),
    trabalho: limparTrabalho ? null : (trabalho ?? this.trabalho),
    recentes: recentes ?? this.recentes,
  );

  Map<String, dynamic> toJson() => {
    'versao': 1,
    if (casa != null) 'casa': casa!.toJson(),
    if (trabalho != null) 'trabalho': trabalho!.toJson(),
    'recentes': [for (final l in recentes) l.toJson()],
  };

  static Salvos fromJson(Map<String, dynamic> j) => Salvos(
    casa: j['casa'] == null
        ? null
        : Lugar.fromJson(j['casa'] as Map<String, dynamic>),
    trabalho: j['trabalho'] == null
        ? null
        : Lugar.fromJson(j['trabalho'] as Map<String, dynamic>),
    recentes: [
      for (final l in (j['recentes'] as List? ?? const []))
        Lugar.fromJson(l as Map<String, dynamic>),
    ],
  );
}

/// Dois lugares são "o mesmo" se têm o mesmo nome e estão a menos de ~150 m um do outro.
bool _mesmoLugar(Lugar a, Lugar b) =>
    a.nome == b.nome &&
    const Distance().as(LengthUnit.Meter, a.pos, b.pos) < 150;

class SalvosNotifier extends AsyncNotifier<Salvos> {
  static const _chave = 'salvos_v1';
  late SharedPreferences _prefs;

  @override
  Future<Salvos> build() async {
    _prefs = await SharedPreferences.getInstance();
    final texto = _prefs.getString(_chave);
    if (texto == null) return const Salvos();
    try {
      return Salvos.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      return const Salvos(); // dado antigo ou corrompido: começa do zero em vez de travar
    }
  }

  Salvos get _atual => state.value ?? const Salvos();

  Future<void> _gravar(Salvos s) async {
    state = AsyncData(s);
    await _prefs.setString(_chave, jsonEncode(s.toJson()));
  }

  Future<void> definirCasa(Lugar l) => _gravar(_atual.copyWith(casa: l));
  Future<void> definirTrabalho(Lugar l) =>
      _gravar(_atual.copyWith(trabalho: l));
  Future<void> removerCasa() => _gravar(_atual.copyWith(limparCasa: true));
  Future<void> removerTrabalho() =>
      _gravar(_atual.copyWith(limparTrabalho: true));

  /// Põe [l] no topo dos recentes, sem repetir. Ignora "Minha localização".
  Future<void> registrarRecente(Lugar l) {
    if (l.minhaLocalizacao || l.nome == 'Ponto no mapa') return Future.value();
    final lista = [l, ..._atual.recentes.where((x) => !_mesmoLugar(x, l))];
    return _gravar(
      _atual.copyWith(recentes: lista.take(Salvos.maxRecentes).toList()),
    );
  }

  Future<void> removerRecente(Lugar l) => _gravar(
    _atual.copyWith(
      recentes: _atual.recentes.where((x) => !_mesmoLugar(x, l)).toList(),
    ),
  );

  Future<void> limparRecentes() => _gravar(_atual.copyWith(recentes: const []));
}

final salvosProvider = AsyncNotifierProvider<SalvosNotifier, Salvos>(
  SalvosNotifier.new,
);
