import { chromium } from 'playwright-core';

const [edgePath, url, mode, artifactDirectory] = process.argv.slice(2);
if (!edgePath || !url || !['first-run', 'returning'].includes(mode)) throw new Error('Usage: node tests/browser-onboarding.mjs <edge-path> <viewer-url> <first-run|returning>');

function assert(condition, message) {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

const browser = await chromium.launch({ executablePath: edgePath, headless: true, args: ['--disable-extensions', '--no-first-run'] });
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  page.setDefaultTimeout(10_000);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.locator('#content h1').waitFor();

  if (mode === 'first-run') {
    await page.locator('#onboardingLayer[aria-hidden="false"]').waitFor();
    assert(await page.locator('#onboardingPresets .preset-card').count() === 5, 'First run should offer exactly five style presets.');
    const names = await page.locator('#onboardingPresets .preset-card strong').allTextContents();
    assert(JSON.stringify(names) === JSON.stringify(['Ocean Blue', 'Forest Green', 'Amber Paper', 'Plum Focus', 'Midnight Cyan']), 'First-run preset names should be stable and descriptive.');
    assert(await page.locator('#continueOnboardingButton').isDisabled(), 'Continue should wait for an explicit style choice.');
    if (artifactDirectory) { await page.waitForTimeout(250); await page.screenshot({ path: `${artifactDirectory}/first-run-styles.png` }); }

    await page.setViewportSize({ width: 320, height: 700 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth), 'First-run setup should not overflow at 320px.');
    await page.setViewportSize({ width: 1440, height: 900 });

    await page.locator('[data-preset-id="forest-green"]').click();
    assert(await page.locator('[data-preset-id="forest-green"]').getAttribute('aria-checked') === 'true', 'Selected style should expose its checked state.');
    assert(await page.locator('#continueOnboardingButton').textContent() === 'Use Forest Green', 'Continue should name the selected style.');
    assert(await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--reader-accent').trim()) === '#16805a', 'Preset selection should preview on the document immediately.');

    await page.locator('#continueOnboardingButton').click();
    await page.locator('#tourLayer[aria-hidden="false"]').waitFor();
    assert(await page.locator('#tourDots span').count() === 5, 'Quick guide should contain five steps.');
    assert(await page.locator('#tocToggle').evaluate((element) => element.classList.contains('tour-target')), 'The first guide step should point to the table of contents.');
    await page.waitForFunction(() => document.activeElement?.id === 'tourNextButton');
    assert(await page.evaluate(() => document.activeElement?.id) === 'tourNextButton', 'Guide navigation should receive keyboard focus.');
    if (artifactDirectory) { await page.waitForTimeout(250); await page.screenshot({ path: `${artifactDirectory}/quick-guide.png` }); }

    const expectedTargets = ['#themeToggle', '#copyMarkdownButton', '#printButton', '#settingsButton'];
    for (const selector of expectedTargets) {
      await page.locator('#tourNextButton').click();
      assert(await page.locator(selector).evaluate((element) => element.classList.contains('tour-target')), `Guide should point to ${selector}.`);
    }
    assert(await page.locator('#tourNextButton').textContent() === 'Finish', 'The final guide action should be explicit.');
    await page.locator('#tourNextButton').click();
    assert(await page.locator('#tourLayer').getAttribute('aria-hidden') === 'true', 'Finishing should close the guide.');

    await page.waitForFunction(async () => {
      const settings = await fetch('/api/settings').then((response) => response.json());
      return settings.behavior.onboardingComplete === true && settings.theme.light.accent === '#16805a';
    });
  } else {
    assert(await page.locator('#onboardingLayer').getAttribute('aria-hidden') === 'true', 'Completed setup should not return on later launches.');
    await page.locator('#settingsButton').click();
    await page.locator('#showGuideButton').click();
    await page.locator('#tourLayer[aria-hidden="false"]').waitFor();
    await page.keyboard.press('Escape');
    assert(await page.locator('#tourLayer').getAttribute('aria-hidden') === 'true', 'Escape should close the replayed guide.');
    assert(await page.evaluate(() => document.activeElement?.id) === 'settingsButton', 'Closing the guide should restore focus to Settings.');
  }
} finally {
  await browser.close();
}
