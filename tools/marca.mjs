// Gera a marca (SVG + PNG) em app/assets/brand/. Uso: node marca.mjs [caminho-da-fonte-Roboto-Black.ttf]
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import opentype from 'opentype.js';

const aqui = dirname(fileURLToPath(import.meta.url));
const saida = join(aqui, '..', 'app', 'assets', 'brand');
mkdirSync(saida, { recursive: true });

const AMARELO = '#FFD100';
const PRETO = '#111111';
const fonte = process.argv[2] ?? 'C:/Users/LeonardoViniciusBati/dev/flutter/bin/cache/artifacts/material_fonts/roboto-black.ttf';

// Frente de ônibus em tela 1024. Os recortes (janela, pino, faróis, grade) são furos de verdade,
// então o símbolo funciona sobre qualquer cor de fundo.
const furos = `
  <rect x="312" y="304" width="400" height="232" rx="40" fill="#000"/>
  <rect x="432" y="618" width="160" height="30" rx="15" fill="#000"/>
  <circle cx="352" cy="632" r="32" fill="#000"/>
  <circle cx="672" cy="632" r="32" fill="#000"/>`;
// O pino fica dentro da janela (furo): precisa ter o miolo vazado também.
function simboloCompleto(cor, id) {
  return `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
    <rect width="1024" height="1024" fill="#fff"/>${furos}
    <path d="M512 500C512 500 452 446 452 402A60 60 0 1 1 572 402C572 446 512 500 512 500Z" fill="#fff"/>
    <circle cx="512" cy="402" r="22" fill="#000"/></mask></defs>
  <g fill="${cor}">
    <rect x="282" y="268" width="460" height="484" rx="76" mask="url(#${id})"/>
    <rect x="248" y="372" width="40" height="84" rx="16"/>
    <rect x="736" y="372" width="40" height="84" rx="16"/>
    <rect x="334" y="738" width="64" height="62" rx="18"/>
    <rect x="626" y="738" width="64" height="62" rx="18"/>
  </g>`;
}

const svg = (w, h, vb, corpo) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${vb}">${corpo}</svg>\n`;

const arquivos = {};
arquivos['simbolo'] = svg(1024, 1024, '0 0 1024 1024', simboloCompleto(PRETO, 'f'));
arquivos['simbolo-claro'] = svg(1024, 1024, '0 0 1024 1024', simboloCompleto(AMARELO, 'f'));
arquivos['icone'] = svg(
  1024, 1024, '0 0 1024 1024',
  `<rect width="1024" height="1024" fill="${AMARELO}"/>${simboloCompleto(PRETO, 'f')}`,
);
arquivos['icone-primeiro-plano'] = arquivos['simbolo'];
arquivos['icone-monocromatico'] = svg(1024, 1024, '0 0 1024 1024', simboloCompleto('#000', 'f'));

// Logotipo: símbolo + "Busão Palmas" convertido em contornos (não depende de fonte instalada).
const f = opentype.parse(readFileSync(fonte).buffer.slice(0));
function texto(t, tamanho) {
  const p = f.getPath(t, 0, 0, tamanho);
  const b = p.getBoundingBox();
  return { d: p.toPathData(2), x1: b.x1, x2: b.x2, y1: b.y1, y2: b.y2 };
}
function logotipo(corTexto, corSimbolo, fundo) {
  const t = texto('Busão Palmas', 150);
  const esc = 0.4; // símbolo 1024 → ~410
  const largura = 410 + 30 + (t.x2 - t.x1) + 40;
  const altura = 410;
  const ty = 205 - (t.y1 + t.y2) / 2;
  return svg(
    Math.round(largura), altura, `0 0 ${Math.round(largura)} ${altura}`,
    `${fundo ? `<rect width="100%" height="100%" fill="${fundo}"/>` : ''}
    <g transform="translate(-5 0) scale(${esc})">${simboloCompleto(corSimbolo, 'f')}</g>
    <path transform="translate(${410 + 20 - t.x1} ${ty})" d="${t.d}" fill="${corTexto}"/>`,
  );
}
arquivos['logo'] = logotipo(PRETO, PRETO, null);
arquivos['logo-escuro'] = logotipo('#FFFFFF', AMARELO, '#111111');

for (const [nome, conteudo] of Object.entries(arquivos)) {
  writeFileSync(join(saida, `${nome}.svg`), conteudo);
}

function png(nome, svgTexto, largura, fundo) {
  const r = new Resvg(svgTexto, {
    fitTo: { mode: 'width', value: largura },
    background: fundo,
  });
  writeFileSync(join(saida, nome), r.render().asPng());
}
png('icone.png', arquivos['icone'], 1024);
png('icone-primeiro-plano.png', arquivos['icone-primeiro-plano'], 1024);
png('icone-monocromatico.png', arquivos['icone-monocromatico'], 1024);
png('logo.png', arquivos['logo'], 1200, '#FFFFFF');
png('logo-escuro.png', arquivos['logo-escuro'], 1200);
console.log('marca gerada em', saida);


