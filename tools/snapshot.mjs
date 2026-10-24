// Gera data/gerado/: meta, linhas, horarios, trajetos, paradas e busca. Formato descrito em docs/DADOS.md.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { criarNomeador } from './nomes-paradas.mjs';
import { montarIndice } from './indice-busca.mjs';

const API = 'https://mobilibus.com/api', PROJETO = 635;
const H = { 'User-Agent': 'BusaoPalmas/0.1 (comunidade Devs Tocantins)' };
const dir = new URL('../data/gerado/', import.meta.url);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(caminho) {
  for (let i = 1; i <= 3; i++) {
    const r = await fetch(`${API}/${caminho}`, { headers: H });
    if (r.ok) return r.json();
    if (i === 3) throw new Error(`${r.status} ${caminho}`);
    await sleep(2000 * i);
  }
}

// "Avenida Tocantins Palmas - Tocantins 77060-150 Brasil" -> "Avenida Tocantins"
const limpar = (n) => n.replace(/\s*Palmas\s*-\s*Tocantins.*$/i, '').replace(/\s*\d{5}-?\d{3}.*$/, '').replace(/\s*Brasil$/i, '').trim();
const moda = (xs) => [...xs.reduce((m, x) => m.set(x, (m.get(x) ?? 0) + 1), new Map())].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

const detalhes = await get(`project-details?project_id=${PROJETO}`);
const rotas = await get(`routes?project_id=${PROJETO}`);

const linhas = [], horarios = {}, trajetos = {}, paradasBruto = new Map();
for (const r of rotas) {
  const tt = (await get(`timetable?project_id=${PROJETO}&route_id=${r.routeId}`))[0]?.timetable ?? { directions: [], trips: [] };
  const viagens = tt.trips ?? [];
  const sentidos = (tt.directions ?? []).map((d) => ({
    id: d.directionId,
    nome: d.desc,
    destino: moda(viagens.filter((v) => v.directionId === d.directionId).map((v) => v.tripDesc)),
  }));
  linhas.push({ id: r.routeId, numero: r.shortName, nome: r.longName, cor: r.color, corTexto: r.textColor, sentidos });

  horarios[r.routeId] = (tt.directions ?? []).map((d) => ({
    sentido: d.directionId,
    servicos: d.services.map((s) => ({
      id: s.serviceId, nome: s.desc, dias: s.days,
      saidas: s.departures.map((x) => [x.dep, x.arr, x.seq]),
    })),
  }));

  for (const v of viagens) {
    const d = await get(`trip-details?project_id=${PROJETO}&trip_id=${v.tripId}`);
    trajetos[v.tripId] = { linha: r.routeId, sentido: v.directionId, destino: v.tripDesc, seq: v.seq, shape: d.shape, paradas: d.stops.map((s) => s.stopId) };
    for (const s of d.stops) {
      const p = paradasBruto.get(s.stopId) ?? { id: s.stopId, lat: s.lat, lng: s.lng, nomeApi: s.name, linhas: new Set() };
      p.linhas.add(r.shortName); paradasBruto.set(s.stopId, p);
    }
    await sleep(120);
  }
  console.log(`linha ${r.shortName}: ${viagens.length} viagens`);
}

const correcoes = JSON.parse(readFileSync(new URL('../data/paradas_nomes.json', import.meta.url), 'utf8'));
const nomear = await criarNomeador();
const paradas = [...paradasBruto.values()].map((p) => {
  const numerico = /^\d+$/.test(p.nomeApi), osm = nomear(p.lat, p.lng);
  const nome = correcoes[p.id] ?? (numerico ? osm.nome : limpar(p.nomeApi)) ?? `Parada ${p.id}`;
  const origem = correcoes[p.id] ? 'correcao' : numerico ? (osm.nome ? 'osm' : 'codigo') : 'api';
  return { id: p.id, nome, origem, lat: +p.lat.toFixed(6), lng: +p.lng.toFixed(6), linhas: [...p.linhas].sort() };
}).sort((a, b) => a.id - b.id);

const busca = await montarIndice();
const meta = {
  versao: 1, geradoEm: new Date().toISOString(), cidade: detalhes.city,
  projetoId: PROJETO, corPrimaria: detalhes.colorPrimary ?? null, otpUri: detalhes.otpUri, apiUri: detalhes.apiUri,
  atualizacaoAoVivoSeg: detalhes.realtimeUpdateFreqSec,
  contagens: { linhas: linhas.length, viagens: Object.keys(trajetos).length, paradas: paradas.length, busca: busca.length },
};

mkdirSync(dir, { recursive: true });
for (const [nome, dados] of Object.entries({ meta, linhas, horarios, trajetos, paradas, busca }))
  writeFileSync(new URL(`${nome}.json`, dir), JSON.stringify(dados));
console.log(JSON.stringify(meta.contagens));
