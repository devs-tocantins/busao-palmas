// Gera data/gerado/paradas.json: todas as paradas de Palmas com nome legível.
// Fonte: trip-details da API (uma viagem por sentido de cada linha) + nomes do OpenStreetMap + correções em data/paradas_nomes.json.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { criarNomeador } from './nomes-paradas.mjs';

const B = 'https://mobilibus.com/api', P = 635, H = { 'User-Agent': 'BusaoPalmas/0.1 (comunidade Devs Tocantins)' };
const get = async (u) => { const r = await fetch(u, { headers: H }); if (!r.ok) throw new Error(`${r.status} ${u}`); return r.json(); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// "Avenida Tocantins Palmas - Tocantins 77060-150 Brasil" -> "Avenida Tocantins"
const limpar = (n) => n.replace(/\s*Palmas\s*-\s*Tocantins.*$/i, '').replace(/\s*\d{5}-?\d{3}.*$/, '').replace(/\s*Brasil$/i, '').trim();

const correcoes = JSON.parse(readFileSync(new URL('../data/paradas_nomes.json', import.meta.url), 'utf8'));
const nomear = await criarNomeador();
const paradas = new Map();

for (const r of await get(`${B}/routes?project_id=${P}`)) {
  const viagens = (await get(`${B}/timetable?project_id=${P}&route_id=${r.routeId}`))[0]?.timetable?.trips ?? [];
  const sentidos = new Set();
  for (const v of viagens) {
    if (sentidos.has(v.directionId)) continue; sentidos.add(v.directionId);
    for (const s of (await get(`${B}/trip-details?project_id=${P}&trip_id=${v.tripId}`)).stops) {
      const p = paradas.get(s.stopId) ?? { id: s.stopId, lat: s.lat, lng: s.lng, nomeApi: s.name, linhas: [] };
      if (!p.linhas.includes(r.shortName)) p.linhas.push(r.shortName);
      paradas.set(s.stopId, p);
    }
    await sleep(120);
  }
}

const saida = [...paradas.values()].map((p) => {
  const numerico = /^\d+$/.test(p.nomeApi);
  const osm = nomear(p.lat, p.lng);
  const nome = correcoes[p.id] ?? (numerico ? osm.nome : limpar(p.nomeApi)) ?? `Parada ${p.id}`;
  const origem = correcoes[p.id] ? 'correcao' : numerico ? (osm.nome ? 'osm' : 'codigo') : 'api';
  return { id: p.id, nome, origem, lat: +p.lat.toFixed(6), lng: +p.lng.toFixed(6), linhas: p.linhas };
});
mkdirSync(new URL('../data/gerado/', import.meta.url), { recursive: true });
writeFileSync(new URL('../data/gerado/paradas.json', import.meta.url), JSON.stringify(saida));
const c = saida.reduce((a, p) => ((a[p.origem] = (a[p.origem] || 0) + 1), a), {});
console.log(`${saida.length} paradas`, JSON.stringify(c));
