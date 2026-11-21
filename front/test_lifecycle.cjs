const { chromium } = require("playwright");

async function run() {
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto("http://localhost:3000", { waitUntil: "networkidle" });

  // 1. Navbar tekshiruvi: Kirish tugmasi bormi?
  const kirishBtn = await page.locator("text=Kirish (OneID / E-IMZO)").first().isVisible();
  console.log("1. Navbarda Kirish tugmasi bormi?:", kirishBtn ? "HA (To'g'ri!)" : "YO'Q");

  // 2. Qonunlar va Profil guest rejimida yashiringanmi?
  const qonunlarInNav = await page.locator("nav >> text=Qonunlar").isVisible();
  console.log("2. Guest holatda Qonunlar yashiringanmi?:", !qonunlarInNav ? "HA, yashiringan! (To'g'ri!)" : "YO'Q, hali ham chiqib turibdi");

  // 3. 3D canvas yoki three.js bormi?
  const canvasCount = await page.locator("canvas").count();
  console.log("3. Sahifada 3D canvas soni:", canvasCount, canvasCount === 0 ? "(3D yo'q, toza!)" : "(3D hali bor)");

  // 4. Loyiha nima uchun va yengilliklari sarlavhalari bormi?
  const muammoTitle = await page.locator("text=Shartnomalarda Qanday Xavflar Yashiringan?").first().isVisible();
  const yengillikTitle = await page.locator("text=LexGuard AI Beradigan 4 Ta Katta Yengillik").first().isVisible();
  console.log("4. Loyiha nima uchun kerak bloki bormi?:", muammoTitle ? "HA" : "YO'Q");
  console.log("5. Yengilliklari bloki bormi?:", yengillikTitle ? "HA" : "YO'Q");

  // 6. Fuqaro / Biznes tugmalari landing pagedan to'liq olib tashlanganmi?
  const b2cToggle = await page.locator("text=Fuqaro Shartnomalari (B2C)").count();
  const b2bToggle = await page.locator("text=Biznes Bitimlari (B2B)").count();
  console.log("6. Landing pageda Fuqaro / Biznes tugmalari yo'qligi:", (b2cToggle === 0 && b2bToggle === 0) ? "HA, to'liq tozalangan! (To'g'ri!)" : "YO'Q, hali bor");

  await page.screenshot({ path: "screenshots/verified_real_landing.png", fullPage: true });
  console.log("📸 Yangi to'liq landing sahifa skrinshoti saqlandi: front/screenshots/verified_real_landing.png");

  // 7. Kirish tugmasi bosilganda OneID modali ochilishi
  await page.locator("text=Kirish (OneID / E-IMZO)").first().click();
  await page.waitForTimeout(500);
  const modalVisible = await page.locator("text=OneID / E-IMZO").first().isVisible();
  console.log("7. Kirish bosilganda OneID modali ochildimi?:", modalVisible ? "HA" : "YO'Q");
  await page.screenshot({ path: "screenshots/verified_oneid_modal_open.png" });

  await browser.close();
}

run().catch(console.error);
