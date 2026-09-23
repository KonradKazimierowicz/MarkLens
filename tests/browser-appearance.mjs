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

  await page.locator('#settingsClose').click();
  await page.locator('#settingsPanel[aria-hidden="true"]').waitFor();

  const codeBlocks = page.locator('#content .code-block');
  const codeCopyButtons = page.locator('#content .code-block > .code-copy');
  assert(await codeBlocks.count() === await page.locator('#content pre code').count(), 'Every fenced code block should be wrapped for its own copy action.');
  assert(await codeCopyButtons.count() === await codeBlocks.count(), 'Every code block should offer a copy button.');
  assert(await page.locator('#content p .code-copy').count() === 0, 'Inline code should not receive a copy button.');
  assert(await codeCopyButtons.first().evaluate((button) => getComputedStyle(button).opacity) === '0', 'Copy buttons should stay hidden until the code block is pointed at.');
  await codeBlocks.first().hover();
  await page.waitForFunction(() => getComputedStyle(document.querySelector('#content .code-copy')).opacity === '1');

  await page.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: new URL(url).origin });
  await codeCopyButtons.first().click();
  const blockCopy = await page.evaluate(async () => ({
    clipboard: await navigator.clipboard.readText(),
    code: document.querySelector('#content .code-block code').textContent.replace(/\n$/, ''),
  }));
  assert(blockCopy.code.length > 0 && blockCopy.clipboard === blockCopy.code, 'A copy button should place exactly its own code block on the clipboard.');
  assert(await page.locator('#content .code-copy.is-copied').count() === 1, 'A finished copy should be confirmed on the button that was used.');

  await settingsTrigger.click();
  await page.locator('#settingsPanel[aria-hidden="false"]').waitFor();
  const codeCopySetting = page.locator('[data-setting="behavior.showCodeCopyButtons"]');
  assert(await codeCopySetting.isChecked(), 'Code copy buttons should be enabled by default.');
  await codeCopySetting.uncheck();
  assert(await codeCopyButtons.first().evaluate((button) => getComputedStyle(button).display) === 'none', 'Disabling the setting should remove code copy buttons from the document.');
  await codeCopySetting.check();
  assert(await codeCopyButtons.first().evaluate((button) => getComputedStyle(button).display) !== 'none', 'Re-enabling the setting should restore code copy buttons.');
} finally {
  await browser.close();
}
