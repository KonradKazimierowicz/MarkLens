import { readFile, stat } from 'node:fs/promises';
import { chromium } from 'playwright-core';

const [edgePath, url, pdfPath] = process.argv.slice(2);
if (!edgePath || !url || !pdfPath) throw new Error('Usage: node tests/browser-print.mjs <edge-path> <viewer-url> <pdf-path>');

function assert(condition, message) {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

const browser = await chromium.launch({ executablePath: edgePath, headless: true, args: ['--disable-extensions', '--no-first-run'] });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.setDefaultTimeout(10_000);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.locator('#content h1').waitFor();

  await page.evaluate(() => { window.__markLensPrintCalled = false; window.print = () => { window.__markLensPrintCalled = true; }; });
  await page.locator('#printButton').click();
  assert(await page.evaluate(() => window.__markLensPrintCalled), 'Print button should open the browser print preview.');

  await page.emulateMedia({ media: 'print' });
  const chromeDisplay = await page.locator('#topbar').evaluate((element) => getComputedStyle(element).display);
  const printHeader = await page.locator('.print-header').evaluate((element) => ({
    display: getComputedStyle(element).display,
    text: element.textContent,
  }));
  const documentStyle = await page.locator('#content').evaluate((element) => {
    const style = getComputedStyle(element);
    return { background: style.backgroundColor, color: style.color, boxShadow: style.boxShadow, maxWidth: style.maxWidth };
  });
  const codeStyle = await page.locator('#content pre').first().evaluate((element) => ({
    whiteSpace: getComputedStyle(element).whiteSpace,
    breakInside: getComputedStyle(element).breakInside,
  }));

  assert(chromeDisplay === 'none', 'Reader controls should not be printed.');
  assert(printHeader.display !== 'none' && printHeader.text.includes('demo.md'), 'Print output should identify the document.');
  assert(documentStyle.background === 'rgb(255, 255, 255)' && documentStyle.color === 'rgb(0, 0, 0)', 'Print output should use an ink-friendly white document with black text.');
  assert(documentStyle.boxShadow === 'none' && documentStyle.maxWidth === 'none', 'Print output should use the full printable area without reader decoration.');
  assert(codeStyle.whiteSpace === 'pre-wrap' && codeStyle.breakInside.includes('avoid'), 'Code should wrap and avoid being split across pages.');

  await page.pdf({ path: pdfPath, format: 'A4', printBackground: true, preferCSSPageSize: true });
  const pdf = await readFile(pdfPath);
  const metadata = await stat(pdfPath);
  assert(pdf.subarray(0, 4).toString() === '%PDF' && metadata.size > 10_000, 'Edge should produce a non-empty PDF print preview.');
} finally {
  await browser.close();
}
