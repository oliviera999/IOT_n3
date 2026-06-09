#!/usr/bin/env node
/**
 * Script de scroll et debug des pages IoT
 * - Charge chaque page dans un navigateur headless
 * - Scrolle jusqu'en bas (pour déclencher lazy-load, scrollex, etc.)
 * - Capture les messages de la console (erreurs, warnings)
 * - Génère des screenshots (haut, milieu, bas)
 * - Produit un rapport Markdown
 *
 * Usage: node scroll-pages-debug.js [--baseUrl URL] [--headless] [--no-screenshots]
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = process.argv.includes('--baseUrl')
  ? process.argv[process.argv.indexOf('--baseUrl') + 1] || 'https://iot.olution.info'
  : 'https://iot.olution.info';

const HEADLESS = !process.argv.includes('--headed');
const SCREENSHOTS = !process.argv.includes('--no-screenshots');

const PAGES = [
  { name: 'Accueil', path: '/' },
  { name: 'Aquaponie', path: '/aquaponie' },
  { name: 'Aquaponie alt', path: '/aquaponie-alt' },
  { name: 'Météo (MSP1)', path: '/meteo' },
  { name: 'Serre (N3PP)', path: '/serre' },
  { name: 'Galerie MSP1', path: '/gallery/msp1' },
  { name: 'Galerie N3PP', path: '/gallery/n3pp' },
  { name: 'Galerie FFP3', path: '/gallery/ffp3' },
  { name: 'FFP3 Aquaponie', path: '/ffp3/aquaponie' },
  { name: 'FFP3 Dashboard', path: '/ffp3/dashboard' },
];

async function scrollPage(page) {
  const maxScrolls = 15;
  let lastHeight = 0;
  let scrollCount = 0;

  while (scrollCount < maxScrolls) {
    const newHeight = await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
      return document.body.scrollHeight;
    });
    await page.waitForTimeout(400);
    if (newHeight === lastHeight) break;
    lastHeight = newHeight;
    scrollCount++;
  }
}

async function analyzePage(browser, pageConfig, baseUrl, outputDir, timestamp) {
  const url = baseUrl.replace(/\/$/, '') + pageConfig.path;
  const slug = pageConfig.path.replace(/^\//, '').replace(/\//g, '-') || 'accueil';
  const result = {
    name: pageConfig.name,
    url,
    path: pageConfig.path,
    statusCode: null,
    consoleLogs: [],
    consoleErrors: [],
    consoleWarnings: [],
    screenshots: [],
    scrollHeight: 0,
    error: null,
  };

  const page = await browser.newPage();

  // Capture des messages de la console
  page.on('console', (msg) => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') result.consoleErrors.push(text);
    else if (type === 'warning') result.consoleWarnings.push(text);
    else result.consoleLogs.push({ type, text });
  });

  try {
    const response = await page.goto(url, {
      waitUntil: 'networkidle',
      timeout: 30000,
    });
    result.statusCode = response?.status() ?? 0;

    if (result.statusCode >= 400) {
      result.error = `HTTP ${result.statusCode}`;
      await page.close();
      return result;
    }

    await page.waitForTimeout(1500);

    // Hauteur avant scroll
    const initHeight = await page.evaluate(() => document.body.scrollHeight);
    result.scrollHeight = initHeight;

    if (SCREENSHOTS) {
      const dir = path.join(outputDir, 'screenshots', timestamp);
      fs.mkdirSync(dir, { recursive: true });
      const topPath = path.join(dir, `${slug}_top.png`);
      await page.screenshot({ path: topPath });
      result.screenshots.push(topPath);
    }

    // Scroll progressif
    await scrollPage(page);

    const finalHeight = await page.evaluate(() => document.body.scrollHeight);
    result.scrollHeight = finalHeight;

    if (SCREENSHOTS) {
      const dir = path.join(outputDir, 'screenshots', timestamp);
      const midPath = path.join(dir, `${slug}_mid.png`);
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 2));
      await page.waitForTimeout(300);
      await page.screenshot({ path: midPath });
      result.screenshots.push(midPath);

      const bottomPath = path.join(dir, `${slug}_bottom.png`);
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await page.waitForTimeout(300);
      await page.screenshot({ path: bottomPath });
      result.screenshots.push(bottomPath);
    }
  } catch (err) {
    result.error = err.message;
  } finally {
    await page.close();
  }

  return result;
}

function generateReport(results, outputPath) {
  const lines = [
    '# Rapport scroll et debug des pages IoT',
    '',
    `**Date** : ${new Date().toLocaleString('fr-FR')}`,
    `**Base URL** : ${BASE_URL}`,
    '',
    '## Résumé',
    '',
    '| Page | Status | Erreurs console | Warnings | Hauteur scroll |',
    '|------|--------|-----------------|----------|-----------------|',
  ];

  for (const r of results) {
    const status = r.error ? `❌ ${r.error}` : (r.statusCode === 200 ? '✅ 200' : `⚠️ ${r.statusCode}`);
    const errCount = r.consoleErrors.length;
    const warnCount = r.consoleWarnings.length;
    lines.push(`| ${r.name} | ${status} | ${errCount} | ${warnCount} | ${r.scrollHeight}px |`);
  }

  lines.push('', '---', '', '## Détail par page', '');

  for (const r of results) {
    lines.push(`### ${r.name} — ${r.url}`);
    lines.push('');
    lines.push(`- **Status** : ${r.statusCode ?? 'N/A'}`);
    lines.push(`- **Hauteur** : ${r.scrollHeight}px`);
    lines.push(`- **Erreurs console** : ${r.consoleErrors.length}`);
    lines.push(`- **Warnings** : ${r.consoleWarnings.length}`);
    if (r.error) lines.push(`- **Erreur** : ${r.error}`);
    if (r.screenshots.length > 0) {
      lines.push('- **Screenshots** :');
      r.screenshots.forEach((s) => lines.push(`  - \`${path.basename(s)}\``));
    }
    if (r.consoleErrors.length > 0) {
      lines.push('', '#### Erreurs console');
      lines.push('```');
      r.consoleErrors.forEach((e) => lines.push(e));
      lines.push('```', '');
    }
    if (r.consoleWarnings.length > 0) {
      lines.push('#### Warnings');
      lines.push('```');
      r.consoleWarnings.slice(0, 5).forEach((w) => lines.push(w));
      if (r.consoleWarnings.length > 5) lines.push(`... et ${r.consoleWarnings.length - 5} autres`);
      lines.push('```', '');
    }
    lines.push('');
  }

  lines.push('---', '*Généré par scripts/browser-audit/scroll-pages-debug.js*');

  fs.writeFileSync(outputPath, lines.join('\n'), 'utf8');
}

async function main() {
  const root = path.resolve(__dirname, '../..');
  const reportDir = path.join(root, 'scripts', 'reports');
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const reportPath = path.join(reportDir, `scroll-debug-${timestamp}.md`);

  fs.mkdirSync(path.join(reportDir, 'screenshots', timestamp), { recursive: true });

  console.log('=== Scroll et debug des pages IoT ===\n');
  console.log(`Base URL : ${BASE_URL}`);
  console.log(`Mode : ${HEADLESS ? 'headless' : 'visible'}`);
  console.log(`Screenshots : ${SCREENSHOTS ? 'oui' : 'non'}`);
  console.log(`Rapport : ${reportPath}\n`);

  const browser = await chromium.launch({
    headless: HEADLESS,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });

  const results = [];
  for (const pageConfig of PAGES) {
    console.log(`  [ ] ${pageConfig.name}...`);
    const r = await analyzePage(browser, pageConfig, BASE_URL, reportDir, timestamp);
    results.push(r);
    const icon = r.error ? '✗' : (r.consoleErrors.length > 0 ? '!' : '✓');
    console.log(`  [${icon}] ${pageConfig.name} — ${r.statusCode ?? 'ERR'} — ${r.consoleErrors.length} erreurs, ${r.consoleWarnings.length} warnings`);
  }

  await browser.close();

  generateReport(results, reportPath);
  console.log(`\nRapport généré : ${reportPath}`);
  if (SCREENSHOTS) {
    console.log(`Screenshots : ${path.join(reportDir, 'screenshots', timestamp)}`);
  }

  const hasErrors = results.some((r) => r.error || r.consoleErrors.length > 0);
  process.exit(hasErrors ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
