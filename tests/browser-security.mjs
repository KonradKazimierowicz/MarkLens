import { chromium } from 'playwright-core';

const [edgePath, url] = process.argv.slice(2);
if (!edgePath || !url) {
  throw new Error('Usage: node tests/browser-security.mjs <edge-path> <viewer-url>');
}

const browser = await chromium.launch({
  executablePath: edgePath,
  headless: true,
  args: ['--disable-extensions', '--no-first-run'],
});

try {
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    () => document.querySelector('#content')?.textContent?.includes('This is code and must stay visible as text.'),
    null,
    { timeout: 10_000 },
  );

  const result = await page.locator('#content').evaluate((article) => ({
    activeElementCount: article.querySelectorAll('script, iframe, svg, [onerror], [onload]').length,
    unsafeUrlCount: [...article.querySelectorAll('[href], [src]')].filter((element) => {
      const rawUrl = element.getAttribute('href') ?? element.getAttribute('src') ?? '';
      return /^(?:javascript:|file:)/i.test(rawUrl) || /example\.com\/tracker\.png/i.test(rawUrl);
    }).length,
    pwned: document.body.hasAttribute('data-pwned'),
    text: article.textContent ?? '',
  }));

  const assertions = [
    [!result.pwned, 'Hostile Markdown executed and changed the document.'],
    [result.activeElementCount === 0, 'Active HTML survived DOMPurify sanitization.'],
    [result.unsafeUrlCount === 0, 'An unsafe or remote URL survived sanitization.'],
    [result.text.includes('This is code and must stay visible as text.'), 'Safe code content was removed.'],
    [result.text.includes('Unsafe JavaScript link'), 'Unsafe link text should remain readable.'],
  ];

  for (const [condition, message] of assertions) {
    if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
  }
} finally {
  await browser.close();
}
