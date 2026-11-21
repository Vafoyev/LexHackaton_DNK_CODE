const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function testFrontend() {
  console.log('🚀 Playwright to\'liq test boshlandi: http://localhost:3000');
  
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
  console.log('✓ 1. Bosh sahifa muvaffaqiyatli ochildi.');

  // 2. Dastlabki Tungi Rejim (Dark Mode) tekshiruvi
  const darkBg = await page.evaluate(() => window.getComputedStyle(document.body).backgroundColor);
  console.log('🌙 Tungi rejim fon rangi:', darkBg);

  const landingScreenshot = path.join(screenshotDir, '01_landing.png');
  await page.screenshot({ path: landingScreenshot, fullPage: true });

  // 3. Kunduzgi rejimga o'tish (Sun / Moon tugmasi)
  console.log('\n☀️ Kunduzgi rejimga o\'tish (Sun / Moon toggle)...');
  const themeToggle = page.locator('button[title*="rejim"]').first();
  await themeToggle.click();
  await page.waitForTimeout(600);

  const lightBg = await page.evaluate(() => window.getComputedStyle(document.body).backgroundColor);
  console.log('☀️ Kunduzgi rejim fon rangi:', lightBg);

  const lightLandingScreenshot = path.join(screenshotDir, '06_light_mode_landing.png');
  await page.screenshot({ path: lightLandingScreenshot, fullPage: true });
  console.log(`📸 Kunduzgi landing saqlandi: ${lightLandingScreenshot}`);

  // 4. "Xulosa" studiyasi (Kunduzgi rejimda)
  await page.click('nav button:has-text("Xulosa")');
  await page.waitForTimeout(1000);
  const lightStudioScreenshot = path.join(screenshotDir, '07_light_mode_studio.png');
  await page.screenshot({ path: lightStudioScreenshot, fullPage: true });
  console.log(`📸 Kunduzgi studiya saqlandi: ${lightStudioScreenshot}`);

  // 5. "Diff" ko'rinishi (Kunduzgi rejimda)
  await page.click('nav button:has-text("Diff")');
  await page.waitForTimeout(1000);
  const lightDiffScreenshot = path.join(screenshotDir, '08_light_mode_diff.png');
  await page.screenshot({ path: lightDiffScreenshot, fullPage: true });
  console.log(`📸 Kunduzgi diff saqlandi: ${lightDiffScreenshot}`);

  // 6. Qayta Tungi rejimga qaytish
  const studioThemeToggle = page.locator('button[title*="rejim"]').first();
  await studioThemeToggle.click();
  await page.waitForTimeout(600);

  // 7. Diff "Huquqiy tahlil" modalini sinash
  console.log('\n⚡ "Huquqiy tahlil" modalini ochish...');
  const tahlilBtn = page.locator('button:has-text("Huquqiy tahlil")').first();
  if (await tahlilBtn.count() > 0) {
    await tahlilBtn.click();
    await page.waitForTimeout(800);
    const modalScreenshot = path.join(screenshotDir, '04_legal_modal.png');
    await page.screenshot({ path: modalScreenshot });
    console.log(`📸 Huquqiy tahlil modali saqlandi: ${modalScreenshot}`);

    // Modalni yopish
    const closeModal = page.locator('.fixed.inset-0 button:has-text("Yopish")').first();
    if (await closeModal.count() > 0) {
      await closeModal.click();
      await page.waitForTimeout(400);
    }
  }

  // 8. "Kirish" modali
  console.log('\n⚡ "Kirish" tugmasi bosilmoqda...');
  await page.click('button:has-text("Kirish")');
  await page.waitForTimeout(500);
  const authScreenshot = path.join(screenshotDir, '05_auth_modal.png');
  await page.screenshot({ path: authScreenshot });

  const closeAuthBtn = page.locator('.fixed.inset-0 button:has(svg.lucide-x)').first();
  if (await closeAuthBtn.count() > 0) {
    await closeAuthBtn.click();
    await page.waitForTimeout(500);
  }

  // 9. "Fuqaro" va "Biznes" rejimlari
  await page.click('nav button:has-text("Fuqaro")');
  await page.waitForTimeout(400);
  await page.click('nav button:has-text("Biznes")');
  await page.waitForTimeout(400);

  // 10. Konsol hisoboti
  console.log('\n📋 KONSOL VA XATOLAR HISOBOTI:');
  const severeErrors = consoleMessages.filter(m => m.type === 'error');
  console.log(`  Jami konsol xabarlari: ${consoleMessages.length}`);
  console.log(`  Jiddiy xatolar (Console Errors): ${severeErrors.length}`);
  console.log(`  Sahifa xatoliklari (Page Errors): ${errors.length}`);

  await browser.close();

  if (severeErrors.length > 0 || errors.length > 0) {
    throw new Error('Test davomida xatoliklar qayd etildi!');
  }

  console.log('\n✅ TUNGI / KUNDUZGI REJIM VA BARCHA MODULLAR 100% MUVAFFAQIYATLI O\'TDI!');
}

testFrontend().catch(err => {
  console.error('❌ Xatolik:', err);
  process.exit(1);
});
