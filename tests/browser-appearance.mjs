import { chromium } from 'playwright-core';

const [edgePath, url] = process.argv.slice(2);
if (!edgePath || !url) {
  throw new Error('Usage: node tests/browser-appearance.mjs <edge-path> <viewer-url>');
}

function assert(condition, message) {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

const browser = await chromium.launch({
  executablePath: edgePath,
  headless: true,
  args: ['--disable-extensions', '--no-first-run'],
});

try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  page.setDefaultTimeout(10_000);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.locator('#basicColors [data-basic-color]').first().waitFor();

  const settingsTrigger = page.locator('#settingsButton:visible, #floatingSettingsButton:visible').first();
  await settingsTrigger.click();
  await page.locator('#settingsPanel[aria-hidden="false"]').waitFor();

  assert(await page.locator('#basicColors [data-basic-color]').count() === 5, 'Basic colors should expose exactly five controls.');
  assert(await page.locator('#lightColors [data-setting^="theme.light."]').count() > 5, 'Advanced light palette should expose the complete color set.');
  assert(await page.locator('#darkColors [data-setting^="theme.dark."]').count() > 5, 'Advanced dark palette should expose the complete color set.');
  assert(await page.locator('details.advanced-settings:not([open])').count() >= 3, 'Advanced color, typography, and layout groups should be collapsed initially.');

  const mode = page.locator('[data-setting="theme.mode"]');
  const basicAccent = page.locator('[data-basic-color="accent"]');
  await mode.selectOption('light');
  await basicAccent.fill('#d946ef');
  let applied = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--reader-accent').trim());
  assert(applied === '#d946ef', 'Basic accent should apply immediately in light mode.');

  await mode.selectOption('dark');
  applied = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--reader-accent').trim());
  assert(applied === '#d946ef', 'A basic color change should synchronize dark mode.');

  const advancedColors = page.locator('details.advanced-settings').filter({ has: page.locator('#lightColors') });
  await advancedColors.locator(':scope > summary').click();
  await page.locator('#darkColors').locator('xpath=..').locator('summary').click();
  const advancedDarkAccent = page.locator('[data-setting="theme.dark.accent"]');
  await advancedDarkAccent.fill('#22c55e');
  applied = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--reader-accent').trim());
  assert(applied === '#22c55e', 'Advanced dark color should apply independently.');

  await mode.selectOption('light');
  applied = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--reader-accent').trim());
  assert(applied === '#d946ef', 'Advanced dark edits must not overwrite the light palette.');

  assert(await page.locator('#content').getByText('Markdown in, beautiful reading out').count() === 1, 'Demo should explain Markdown source and output.');
  assert(await page.locator('#content pre code.language-markdown').count() >= 1, 'Demo should show raw Markdown source.');
  assert(await page.locator('#content pre code.language-powershell').count() >= 2, 'Demo should show highlighted code output.');
} finally {
  await browser.close();
}
