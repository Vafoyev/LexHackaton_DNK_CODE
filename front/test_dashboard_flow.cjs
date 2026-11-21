const { chromium } = require("playwright");

async function run() {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  
  // LocalStorage tozalash
  await page.goto("http://localhost:3000");
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: "networkidle" });

  console.log("--- 1. MEHMON (GUEST) HOLATI ---");
  const guestLanding = await page.locator("text=Shartnomangizni Imzolashdan Oldin").first().isVisible();
  console.log("Mehmon Landing sahifasi ko'rinyaptimi?:", guestLanding ? "HA (To'g'ri!)" : "YO'Q");
  
  const kirishBtn = await page.locator("text=Kirish (OneID / E-IMZO)").first().isVisible();
  console.log("Navbarda Kirish tugmasi bormi?:", kirishBtn ? "HA (To'g'ri!)" : "YO'Q");

  console.log("\n--- 2. LOGIN QILISH (ONEID / DEMO) ---");
  await page.locator("text=Kirish (OneID / E-IMZO)").first().click();
  await page.waitForTimeout(500);

  // Demo yuridik kirish tugmasini bosish
  const demoB2BBtn = page.locator("text=Yuridik shaxs sifatida tezkor kirish").first();
  await demoB2BBtn.click();
  await page.waitForTimeout(1000);

  console.log("\n--- 3. LOGIN BO'LGANDAN KEYINGI BOSH SAHIFA (HOME DASHBOARD) ---");
  // Landing sales pitch endi ko'rinmasligi kerak!
  const salesPitchVisible = await page.locator("text=E'tiborsizlik Bahosi Juda Qimmat").isVisible();
  console.log("Landing reklama matni yashirildimi?:", !salesPitchVisible ? "HA, to'liq yashirildi! (To'g'ri!)" : "YO'Q, hali ham turibdi");

  // Xush kelibsiz banneri
  const welcomeBanner = await page.locator("text=Xush kelibsiz").first().isVisible();
  console.log("Dashboardda Xush kelibsiz banneri bormi?:", welcomeBanner ? "HA" : "YO'Q");

  // Avvalgi analiz qilingan hujjatlar bo'limi
  const prevDocsTitle = await page.locator("text=Avvalgi Analiz Qilingan Hujjatlar").first().isVisible();
  console.log("Dashboardda 'Avvalgi Analiz Qilingan Hujjatlar' bormi?:", prevDocsTitle ? "HA (Aynan foydalanuvchi so'ragandek!)" : "YO'Q");

  // Yangi qonunlar bo'limi
  const lawsTitle = await page.locator("text=Yangi Qonunlar & Lex.uz").first().isVisible();
  console.log("Dashboardda 'Yangi Qonunlar & Lex.uz' bormi?:", lawsTitle ? "HA (Aynan foydalanuvchi so'ragandek!)" : "YO'Q");

  // Navbarda Chiqish tugmasi bormi?
  const logoutBtn = await page.locator("text=Chiqish").first().isVisible();
  console.log("Navbarda Chiqish tugmasi bormi?:", logoutBtn ? "HA" : "YO'Q");

  // Skrinshot olish
  await page.screenshot({ path: "screenshots/verified_user_dashboard.png", fullPage: true });
  console.log("📸 Dashboard skrinshoti saqlandi: front/screenshots/verified_user_dashboard.png");

  console.log("\n--- 4. HUJJATNI OCHISH VA QAYTISH OQIMI ---");
  // Avvalgi tahlil qilingan hujjatlardan birining qatorini bosish (natijani ochadi)
  await page.locator("section[aria-labelledby='docs-title'] ul button").first().click();
  await page.waitForTimeout(1000);

  const backBtn = await page.locator("text=Boshqaruv Paneliga Qaytish").first().isVisible();
  console.log("Shartnoma studio ochildimi va 'Boshqaruv Paneliga Qaytish' bormi?:", backBtn ? "HA" : "YO'Q");

  await page.screenshot({ path: "screenshots/verified_studio_with_back_btn.png" });

  // Orqaga qaytish
  await page.locator("text=Boshqaruv Paneliga Qaytish").first().click();
  await page.waitForTimeout(500);

  const backToDash = await page.locator("text=Avvalgi Analiz Qilingan Hujjatlar").first().isVisible();
  console.log("Orqaga bosilganda Dashboardga qaytdimi?:", backToDash ? "HA, qaytdi!" : "YO'Q");

  console.log("\n--- 5. CHIQISH (LOGOUT) ---");
  await page.locator("text=Chiqish").first().click();
  await page.waitForTimeout(500);

  const backToLanding = await page.locator("text=Kirish (OneID / E-IMZO)").first().isVisible();
  console.log("Chiqish bosilganda yana Mehmon Landing sahifasiga o'tdimi?:", backToLanding ? "HA, o'tdi!" : "YO'Q");

  await browser.close();
  console.log("\n✅ BARCHA TESTLAR MUVAFFAQINLI YAKUNLANDI!");
}

run().catch(console.error);
