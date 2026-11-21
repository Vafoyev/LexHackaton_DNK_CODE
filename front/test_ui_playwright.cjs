const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function testFrontend() {
  console.log('🚀 Playwright to\'liq Shadcn UI & Mobile UX testi: http://localhost:3000');
  
  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
  });

  const page = await context.newPage();
  
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push({ type: msg.type(), text: msg.text() });
  });

  const errors = [];
  page.on('pageerror', err => {
    errors.push(err.message);
  });

  const screenshotDir = path.join(__dirname, 'screenshots');
  if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
  }

  // 1. Sahifani ochish
  await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
  console.log('✓ 1. Asosiy sahifa ochildi.');

  // Screenshot: Asosiy tab
  await page.screenshot({ path: path.join(screenshotDir, '01_asosiy_tab.png'), fullPage: true });

  // 2. "Hujjatlar" tabiga o'tish
  console.log('⚡ 2. "Hujjatlar" tabiga o\'tish...');
  await page.click('nav button:has-text("Hujjatlar")');
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(screenshotDir, '02_hujjatlar_tab.png'), fullPage: true });
  console.log('✓ Hujjatlar sahifasi saqlandi.');

  // 3. "Qonunlar" tabiga o'tish
  console.log('⚡ 3. "Qonunlar" tabiga o\'tish...');
  await page.click('nav button:has-text("Qonunlar")');
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(screenshotDir, '03_qonunlar_tab.png'), fullPage: true });
  console.log('✓ Qonunlar sahifasi saqlandi.');

  // 4. "Profil" tabiga o'tish
  console.log('⚡ 4. "Profil" tabiga o\'tish...');
  await page.click('nav button:has-text("Profil")');
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(screenshotDir, '04_profil_tab.png'), fullPage: true });
  console.log('✓ Profil sahifasi saqlandi.');

  // 5. "Skanerlash" modali
  console.log('⚡ 5. "Skanerlash" tugmasi...');
  await page.click('button:has-text("Skanerlash")');
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(screenshotDir, '05_skanerlash_modal.png') });
  console.log('✓ Skanerlash modali saqlandi.');

  // Modalni yopish
  const closeBtn = page.locator('.fixed.inset-0 button').first();
  if (await closeBtn.count() > 0) {
    await closeBtn.click();
    await page.waitForTimeout(400);
  }

  // 6. Theme Toggle (Sun/Moon)
  console.log('⚡ 6. Kunduzgi rejimga o\'tish...');
  const themeToggle = page.locator('button[title*="rejim"]').first();
  await themeToggle.click();
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(screenshotDir, '06_light_mode_profile.png'), fullPage: true });
  console.log('✓ Kunduzgi rejim saqlandi.');

  await browser.close();

  console.log('\n================ Natija ================');
  console.log(`Console xabarlari: ${consoleMessages.length}`);
  console.log(`Page xatolari: ${errors.length}`);
  if (errors.length > 0) {
    console.error('❌ Xatolar:', errors);
    process.exit(1);
  }
  console.log('🎉 Shadcn UI & Mobile UX to\'liq muvaffaqiyatli yakunlandi!');
}

testFrontend().catch(e => {
  console.error('Test xatolik bilan to\'xtadi:', e);
  process.exit(1);
});
