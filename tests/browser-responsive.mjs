import { chromium } from 'playwright-core';

const [edgePath, url] = process.argv.slice(2);
if (!edgePath || !url) throw new Error('Usage: node tests/browser-responsive.mjs <edge-path> <viewer-url>');

function assert(condition, message) {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

const browser = await chromium.launch({
  executablePath: edgePath,
  headless: true,
  args: ['--disable-extensions', '--no-first-run'],
});

try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 700 } });
  page.setDefaultTimeout(10_000);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.locator('#content h1').waitFor();

  assert(await page.locator('#reloadButton').count() === 0, 'The removed reload action should not remain in the toolbar.');
  assert(await page.locator('#printButton').isVisible(), 'Print / preview should be visible in the toolbar.');
  assert(await page.locator('#copyPathButton').count() === 0, 'The old copy-path action should not remain in the toolbar.');
  assert(await page.locator('#copyMarkdownButton').getAttribute('aria-label') === 'Copy full Markdown source', 'The copy action should describe the content copied.');
  await page.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: new URL(url).origin });
  await page.locator('#copyMarkdownButton').click();
  const clipboardResult = await page.evaluate(async () => {
    const binary = atob(window.__MARKLENS_BOOTSTRAP__.document.markdownBase64);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    return { copied: await navigator.clipboard.readText(), source: new TextDecoder('utf-8').decode(bytes) };
  });
  assert(clipboardResult.copied === clipboardResult.source, 'Copy Markdown should copy the complete raw source file.');

  const favicon = await page.locator('#favicon').getAttribute('href');
  assert(favicon === '/favicon.ico', 'Default favicon should use the packaged MarkLens icon.');
  const faviconResponse = await page.request.get(new URL('/favicon.ico', url).toString());
  assert(faviconResponse.ok(), 'Packaged favicon should be served by the local reader.');
  assert((faviconResponse.headers()['content-type'] || '').startsWith('image/x-icon'), 'Packaged favicon should use an icon content type.');
  const faviconBytes = await faviconResponse.body();
  assert(faviconBytes.length > 1000 && faviconBytes[0] === 0 && faviconBytes[1] === 0 && faviconBytes[2] === 1 && faviconBytes[3] === 0, 'Packaged favicon should be a valid multi-size ICO file.');

  await page.evaluate(() => window.scrollTo(0, 900));
  await page.waitForFunction(() => document.querySelector('#topbar').classList.contains('is-hidden'));
  const hiddenTopbar = await page.locator('#topbar').boundingBox();
  assert(hiddenTopbar && hiddenTopbar.y < -50 && hiddenTopbar.y + hiddenTopbar.height >= 1, 'Hidden toolbar should leave the progress strip visible.');

  await page.evaluate(() => window.scrollBy(0, -180));
  await page.waitForFunction(() => !document.querySelector('#topbar').classList.contains('is-hidden'));
  await page.evaluate(() => window.scrollBy(0, 300));
  await page.waitForFunction(() => document.querySelector('#topbar').classList.contains('is-hidden'));
  await page.mouse.move(5, 5);
  await page.waitForFunction(() => !document.querySelector('#topbar').classList.contains('is-hidden'));

  await page.setViewportSize({ width: 390, height: 640 });
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.locator('#tocToggle').click();
  await page.locator('#tocPanel.mobile-open').waitFor();
  assert(await page.locator('#tocToggle').getAttribute('aria-expanded') === 'true', 'Mobile TOC button should expose its open state.');
  assert(await page.locator('#tocPanel').getAttribute('aria-hidden') === 'false', 'Open mobile TOC should be visible to assistive technology.');
  assert(await page.locator('body.toc-open').count() === 1, 'Opening mobile TOC should lock background scrolling.');

  const tocMetrics = await page.locator('#tocPanel').evaluate((panel) => ({
    clientHeight: panel.clientHeight,
    scrollHeight: panel.scrollHeight,
    overflowY: getComputedStyle(panel).overflowY,
  }));
  assert(tocMetrics.scrollHeight > tocMetrics.clientHeight, 'Long mobile TOC should overflow inside its drawer.');
  assert(['auto', 'scroll'].includes(tocMetrics.overflowY), 'Mobile TOC should own vertical scrolling.');
  await page.locator('#tocPanel').evaluate((panel) => { panel.scrollTop = 240; });
  assert(await page.locator('#tocPanel').evaluate((panel) => panel.scrollTop) > 0, 'Mobile TOC should be scrollable.');

  await page.keyboard.press('Escape');
  await page.waitForFunction(() => !document.querySelector('#tocPanel').classList.contains('mobile-open'));
  assert(await page.locator('#tocToggle').getAttribute('aria-expanded') === 'false', 'Escape should close the mobile TOC.');
  assert(await page.evaluate(() => document.activeElement?.id) === 'tocToggle', 'Escape should return focus to the TOC button.');

  await page.locator('#tocToggle').click();
  await page.locator('#tocList a').first().click();
  await page.waitForFunction(() => !document.querySelector('#tocPanel').classList.contains('mobile-open'));
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth), 'Mobile layout should not overflow horizontally.');

  for (const width of [320, 768, 1024, 1440]) {
    await page.setViewportSize({ width, height: 700 });
    assert(await page.locator('#printButton').isVisible(), `Print / preview should remain visible at ${width}px.`);
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth), `Layout should not overflow at ${width}px.`);
  }
} finally {
  await browser.close();
}
