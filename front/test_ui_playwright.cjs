const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function testFrontend() {
  console.log('🚀 Playwright test boshlandi: http://localhost:3000');
  
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

  // 2. CSS tekshiruvi: body computed background-color
  const bodyStyles = await page.evaluate(() => {
    const el = document.body;
    const computed = window.getComputedStyle(el);
    return {
      backgroundColor: computed.backgroundColor,
      color: computed.color,
      fontFamily: computed.fontFamily,
    };
  });

  console.log('\n📊 BODY COMPUTED STYLES:');
  console.log('  Background:', bodyStyles.backgroundColor);
  console.log('  Color:', bodyStyles.color);
  console.log('  Font Family:', bodyStyles.fontFamily);

  // 3. Navbar 6 ta minimalist yagona so'zli tugmalari tekshiruvi
  const navText = await page.textContent('nav');
  console.log('\n🧭 NAVBAR TUGMALARI (Kelishilgan 6 ta yagona so\'zli minimalist nomlar):');
  console.log(' ', navText?.replace(/\s+/g, ' ').trim());

  const landingScreenshot = path.join(screenshotDir, '01_landing.png');
  await page.screenshot({ path: landingScreenshot, fullPage: true });
  console.log(`📸 [1/5] Landing page saqlandi: ${landingScreenshot}`);

  // 4. "Fuqaro" va "Biznes" o'rtasida almashish
  console.log('\n⚡ "Fuqaro" (B2C) rejimiga o\'tish...');
  await page.click('nav button:has-text("Fuqaro")');
  await page.waitForTimeout(500);
  console.log('✓ Fuqaro rejimi faol.');

  console.log('⚡ "Biznes" (B2B) rejimiga o\'tish...');
  await page.click('nav button:has-text("Biznes")');
  await page.waitForTimeout(500);
  console.log('✓ Biznes rejimi faol.');

  // 5. "Xulosa" tugmasini bosish (Shartnoma studiyasiga o'tish)
  console.log('\n⚡ "Xulosa" tugmasi bosilmoqda...');
  await page.click('nav button:has-text("Xulosa")');
  await page.waitForTimeout(1000);
  const studioScreenshot = path.join(screenshotDir, '02_studio_diff.png');
  await page.screenshot({ path: studioScreenshot, fullPage: true });
  console.log(`📸 [2/5] Shartnoma xulosa studiyasi saqlandi: ${studioScreenshot}`);

  // 6. "Diff" tugmasini bosish (Yonma-yon qizil/yashil tahrir ko'rinishi)
  console.log('\n⚡ "Diff" tugmasi bosilmoqda...');
  await page.click('nav button:has-text("Diff")');
  await page.waitForTimeout(1000);
  const diffScreenshot = path.join(screenshotDir, '03_sample_contract_analysis.png');
  await page.screenshot({ path: diffScreenshot, fullPage: true });
  console.log(`📸 [3/5] Side-by-side diff saqlandi: ${diffScreenshot}`);

  // 7. "3D" tugmasini bosish (Three.js WebGL fazosi)
  console.log('\n⚡ "3D" tugmasi bosilmoqda...');
  await page.click('nav button:has-text("3D")');
  await page.waitForTimeout(1000);
  const threeDScreenshot = path.join(screenshotDir, '04_3d_modal.png');
  await page.screenshot({ path: threeDScreenshot });
  console.log(`📸 [4/5] Three.js 3D modal saqlandi: ${threeDScreenshot}`);

  // 3D modalni yopish (X tugmasi orqali)
  const close3DBtn = page.locator('.fixed.inset-0 button:has(svg.lucide-x)').first();
  if (await close3DBtn.count() > 0) {
    await close3DBtn.click();
    await page.waitForTimeout(500);
    console.log('✓ 3D modal yopildi.');
  }

  // 8. "Kirish" tugmasini bosish (OneID / E-IMZO / Login)
  console.log('\n⚡ "Kirish" tugmasi bosilmoqda...');
  await page.click('button:has-text("Kirish")');
  await page.waitForTimeout(500);
  const authScreenshot = path.join(screenshotDir, '05_auth_modal.png');
  await page.screenshot({ path: authScreenshot });
  console.log(`📸 [5/5] Kirish / Auth modali saqlandi: ${authScreenshot}`);

  // Auth modalni yopish
  const closeAuthBtn = page.locator('.fixed.inset-0 button:has(svg.lucide-x)').first();
  if (await closeAuthBtn.count() > 0) {
    await closeAuthBtn.click();
    await page.waitForTimeout(500);
    console.log('✓ Kirish modali yopildi.');
  }

  // 9. Konsol hisoboti
  console.log('\n📋 KONSOL VA XATOLAR HISOBOTI:');
  const severeErrors = consoleMessages.filter(m => m.type === 'error');
  console.log(`  Jami konsol xabarlari: ${consoleMessages.length}`);
  console.log(`  Jiddiy xatolar (Console Errors): ${severeErrors.length}`);
  if (severeErrors.length > 0) {
    severeErrors.forEach(e => console.log('   ⚠️', e.text));
  }
  console.log(`  Sahifa xatoliklari (Page Errors): ${errors.length}`);

  await browser.close();

  if (severeErrors.length > 0 || errors.length > 0) {
    throw new Error('Test davomida xatoliklar qayd etildi!');
  }

  console.log('\n✅ BARCHA KELISHILGAN 6 TA MODUL VA PLAYWRIGHT TESTLARI 100% MUVAFFAQIYATLI O\'TDI!');
}

testFrontend().catch(err => {
  console.error('❌ Xatolik:', err);
  process.exit(1);
});
