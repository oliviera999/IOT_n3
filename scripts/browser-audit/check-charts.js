const { chromium } = require('playwright');

const pages = [
  { name: 'Serre', path: '/serre' },
  { name: 'Meteo', path: '/meteo' },
  { name: 'Aquaponie', path: '/aquaponie' },
  { name: 'Aquaponie Alt', path: '/aquaponie-alt' }
];

function getBaseUrl() {
  const argIndex = process.argv.findIndex((arg) => arg === '--baseUrl');
  if (argIndex !== -1 && process.argv[argIndex + 1]) {
    return process.argv[argIndex + 1];
  }
  return process.env.BASE_URL || 'http://127.0.0.1:8093';
}

async function auditPage(browser, baseUrl, pageConfig) {
  const page = await browser.newPage();
  const consoleErrors = [];
  const requestFailures = [];
  const responseErrors = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      consoleErrors.push(msg.text());
    }
  });

  page.on('requestfailed', (req) => {
    requestFailures.push({
      url: req.url(),
      method: req.method(),
      reason: req.failure() ? req.failure().errorText : 'unknown'
    });
  });

  page.on('response', (res) => {
    if (res.status() >= 400) {
      responseErrors.push({
        url: res.url(),
        status: res.status()
      });
    }
  });

  const url = `${baseUrl}${pageConfig.path}`;
  const goto = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
  await page.waitForTimeout(1500);

  const pageStatus = goto ? goto.status() : null;
  const chartInfo = await page.evaluate(() => {
    const charts = (window.Highcharts && Array.isArray(window.Highcharts.charts))
      ? window.Highcharts.charts.filter(Boolean)
      : [];

    const details = charts.map((chart, chartIndex) => ({
      chartIndex,
      renderTo: chart.renderTo ? chart.renderTo.id : null,
      seriesCount: Array.isArray(chart.series) ? chart.series.length : 0,
      visibleSeriesCount: Array.isArray(chart.series)
        ? chart.series.filter((s) => s.visible !== false).length
        : 0,
      firstSeriesPoints: (chart.series && chart.series[0] && chart.series[0].data)
        ? chart.series[0].data.length
        : 0
    }));

    return {
      highchartsLoaded: !!window.Highcharts,
      chartsCount: charts.length,
      details
    };
  });

  await page.screenshot({
    path: `./screenshots/${pageConfig.name.toLowerCase().replace(/\s+/g, '-')}.png`,
    fullPage: true
  });

  await page.close();

  const baseHost = new URL(baseUrl).host;
  const isFirstParty = (targetUrl) => {
    try {
      return new URL(targetUrl).host === baseHost;
    } catch {
      return false;
    }
  };

  const firstPartyRequestFailures = requestFailures.filter((r) => isFirstParty(r.url));
  const firstPartyResponseErrors = responseErrors.filter((r) => isFirstParty(r.url));

  return {
    name: pageConfig.name,
    url,
    pageStatus,
    chartInfo,
    consoleErrors,
    requestFailures,
    responseErrors,
    firstPartyRequestFailures,
    firstPartyResponseErrors
  };
}

async function main() {
  const baseUrl = getBaseUrl();
  const browser = await chromium.launch({ headless: true });
  const fs = require('fs');

  if (!fs.existsSync('./screenshots')) {
    fs.mkdirSync('./screenshots');
  }

  const results = [];
  for (const pageConfig of pages) {
    try {
      const result = await auditPage(browser, baseUrl, pageConfig);
      results.push(result);
    } catch (error) {
      results.push({
        name: pageConfig.name,
        url: `${baseUrl}${pageConfig.path}`,
        fatalError: error.message
      });
    }
  }

  await browser.close();

  fs.writeFileSync('./report.json', JSON.stringify(results, null, 2), 'utf8');

  console.log('=== Audit Graphiques Highcharts ===');
  for (const r of results) {
    if (r.fatalError) {
      console.log(`- ${r.name}: KO (fatal: ${r.fatalError})`);
      continue;
    }
    const ok =
      r.pageStatus === 200 &&
      r.chartInfo &&
      r.chartInfo.highchartsLoaded &&
      r.chartInfo.chartsCount > 0 &&
      r.consoleErrors.length === 0 &&
      r.firstPartyRequestFailures.length === 0 &&
      r.firstPartyResponseErrors.length === 0;
    console.log(`- ${r.name}: ${ok ? 'OK' : 'A verifier'} (HTTP ${r.pageStatus}, charts=${r.chartInfo.chartsCount}, consoleErr=${r.consoleErrors.length}, reqFail[first]=${r.firstPartyRequestFailures.length}, resp>=400[first]=${r.firstPartyResponseErrors.length}, reqFail[all]=${r.requestFailures.length})`);
  }
  console.log('Rapport detaille: scripts/browser-audit/report.json');
  console.log('Captures: scripts/browser-audit/screenshots/');
}

main().catch((err) => {
  console.error('Erreur audit:', err);
  process.exit(1);
});
