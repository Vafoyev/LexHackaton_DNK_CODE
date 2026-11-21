const { chromium } = require("playwright");

async function run() {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  await page.goto("http://localhost:3000", { waitUntil: "networkidle" });

  // 1. Dastlabki holatda uploader ko'rinishi kerak (shartnoma muammolari EMAS)
  const uploaderVisible = await page.locator("text=Shartnomangizni").first().isVisible();
  console.log("1. Dastlabki Uploader ko'rinishi:", uploaderVisible ? "HA (To'g'ri!)" : "YO'Q");

  // Xavfli bandlar sarlavhalari dastlab ko'rinmasligi kerak
  const findingsVisible = await page.locator("text=Asossiz bir tomonlama bekor qilish").first().isVisible();
  console.log("2. Muammolar dastlab ko'rinmayaptimi?:", !findingsVisible ? "HA, toza! (To'g'ri!)" : "YO'Q, muammo chiqib qoldi");

  await page.screenshot({ path: "front/screenshots/verified_initial_lifecycle.png" });

  // 3. Demo shartnomani sinash
  const demoBtn = page.locator("text=Namunaviy B2B IT Shartnomani Sinash").first();
  if (await demoBtn.isVisible()) {
    await demoBtn.click();
    console.log("3. Namunaviy shartnoma bosildi, progress tahlili ketmoqda...");
    
    // Tahlil tugashini kutish (risky clause yoki konsolidatsiya kartasi)
    await page.waitForSelector("text=Dalolatnomani Ko'rib Chiqish", { timeout: 10000 });
    console.log("4. Tahlildan so'ng Studiya ochildimi?: HA (Muvaffaqiyatli!)");
    await page.screenshot({ path: "front/screenshots/verified_studio_after_upload.png" });
  }

  await browser.close();
}

run().catch(console.error);
