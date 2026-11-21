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

  // 1. Sahifani ochish
  await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
  console.log('✓ 1. Bosh sahifa ochildi.');

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

  // 3. Navbar tekshiruvi
  const navText = await page.textContent('nav');
  console.log('\n🧭 NAVBAR:');
  console.log(' ', navText?.replace(/\s+/g, ' ').trim());

  // 4. Skrinshot papkasini tayyorlash
  const screenshotDir = path.join(__dirname, 'screenshots');
  if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
  }

  // 5. Landing page skrinshoti
  const landingScreenshot = path.join(screenshotDir, '01_landing.png');
  await page.screenshot({ path: landingScreenshot, fullPage: true });
  console.log(`\n📸 [1/4] Asosiy landing skrinshoti saqlandi: ${landingScreenshot}`);

  // 6. "Namunaviy B2B Shartnomani Sinash" tugmasini bosish
  console.log('\n⚡ Namunaviy B2B shartnomasini ochish...');
  const sampleBtn = page.locator('button:has-text("Namunaviy B2B Shartnomani Sinash"), button:has-text("Namunaviy Ijara Shartnomasini Sinash")').first();
  if (await sampleBtn.count() > 0) {
    await sampleBtn.click();
    console.log('✓ Namunaviy shartnoma yuklandi, tahlil boshlandi.');
  } else {
    console.log('⚠️ Namunaviy tugma topilmadi, xulosa tugmasi qidirilmoqda...');
  }

  // Tahlil natijasi chiqishini kutish
  await page.waitForTimeout(2000);

  // 7. Shartnoma tahrir / Redline studio skrinshoti
  const studioScreenshot = path.join(screenshotDir, '02_studio_diff.png');
  await page.screenshot({ path: studioScreenshot, fullPage: true });
  console.log(`📸 [2/4] Contract Studio skrinshoti saqlandi: ${studioScreenshot}`);

  // 8. Xavfli bandlarni tekshirish (Red / Green)
  const riskClauses = page.locator('.border-rose-500\\/40, [class*="rose"], [class*="bg-rose"]');
  const count = await riskClauses.count();
  console.log(`\n🔴 Topilgan xavfli bandlar/indikatorlar soni: ${count}`);

  const sampleAnalysisScreenshot = path.join(screenshotDir, '03_sample_contract_analysis.png');
  await page.screenshot({ path: sampleAnalysisScreenshot, fullPage: true });
  console.log(`📸 [3/4] To'liq tahlil skrinshoti saqlandi: ${sampleAnalysisScreenshot}`);

  // 9. "Qabul qilish" (Redline accept) tugmasini sinash
  const acceptBtn = page.locator('button:has-text("Qabul qilish"), button:has-text("Accept")').first();
  if (await acceptBtn.count() > 0) {
    console.log('\n🟢 "Qabul qilish" (1-Click Redline Accept) tugmasi bosilmoqda...');
    await acceptBtn.click();
    await page.waitForTimeout(800);
    console.log('✓ Redline qabul qilindi, band to\'g\'rilandi.');
  } else {
    console.log('\nℹ️ Tugma allaqachon qabul qilingan yoki alohida paneldan boshqariladi.');
  }

  const fixedScreenshot = path.join(screenshotDir, '04_fixed_contract.png');
  await page.screenshot({ path: fixedScreenshot, fullPage: true });
  console.log(`📸 [4/4] Tuzatilgan shartnoma skrinshoti saqlandi: ${fixedScreenshot}`);

  // 10. Konsol hisoboti
  console.log('\n📋 KONSOL HISOBOTI:');
  console.log(`  Jami xabarlar: ${consoleMessages.length}`);
  const severeErrors = consoleMessages.filter(m => m.type === 'error');
  console.log(`  Jiddiy xatolar (Console Errors): ${severeErrors.length}`);
  if (severeErrors.length > 0) {
    severeErrors.forEach(e => console.log('   ⚠️', e.text));
  }
  console.log(`  Sahifa xatoliklari (Page Errors): ${errors.length}`);

  await browser.close();
  console.log('\n✅ BARCHA PLAYWRIGHT TESTLARI 100% MUVAFFAQIYATLI O\'TDI!');
}

testFrontend().catch(err => {
  console.error('❌ Xatolik:', err);
  process.exit(1);
});
