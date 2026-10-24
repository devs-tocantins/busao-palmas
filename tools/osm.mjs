// Baixa do OpenStreetMap (Overpass) ruas, áreas e lugares nomeados de Palmas, com cache local em tools/.cache/.
import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const CACHE = join(dirname(fileURLToPath(import.meta.url)), '.cache');
export const BBOX = '-10.40,-48.50,-10.05,-48.15'; // sul,oeste,norte,leste
const OVERPASS = 'https://overpass-api.de/api/interpreter';
const UA = 'BusaoPalmas/0.1 (https://github.com/devs-tocantins; comunidade Devs Tocantins)';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function overpass(nome, consulta) {
  mkdirSync(CACHE, { recursive: true });
  const arq = join(CACHE, `${nome}.json`);
  if (existsSync(arq)) return JSON.parse(readFileSync(arq, 'utf8'));
  for (let i = 1; i <= 3; i++) {
    try {
      const r = await fetch(OVERPASS, {
        method: 'POST',
        headers: { 'User-Agent': UA, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'data=' + encodeURIComponent(`[out:json][timeout:120];${consulta}`),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const dados = (await r.json()).elements;
      writeFileSync(arq, JSON.stringify(dados));
      return dados;
    } catch (e) {
      if (i === 3) throw new Error(`Overpass falhou em ${nome}: ${e.message}`);
      await sleep(10_000 * i);
    }
  }
}

export const baixarRuas = () => overpass('ruas', `way[highway][name](${BBOX});out geom tags;`);
export const baixarAreas = () =>
  overpass('areas', `(way[place~"^(suburb|neighbourhood|city_block|quarter)$"][name](${BBOX});` +
    `relation[place~"^(suburb|neighbourhood|city_block|quarter)$"][name](${BBOX}););out geom tags;`);
export const baixarLocalidades = () =>
  overpass('localidades', `nwr[place~"^(town|village|hamlet|suburb|neighbourhood|quarter)$"][name](${BBOX});out center tags;`);
export const baixarLugares = async () => {
  const partes = [
    ['amenity', 'nwr[amenity][name]'], ['comercio', 'nwr[shop][name]'],
    ['lazer', 'nwr[tourism][name];nwr[leisure][name]'],
    ['outros', 'nwr[office][name];nwr[healthcare][name];nwr[aeroway][name];nwr[railway=station][name]'],
  ];
  const tudo = [];
  for (const [n, q] of partes) tudo.push(...(await overpass(`lugares_${n}`, `(${q.split(';').map((x) => `${x}(${BBOX})`).join(';')};);out tags center;`)));
  return tudo;
};
