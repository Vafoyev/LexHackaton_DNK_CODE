const { chromium } = require('playwright');

function getLuminance(r, g, b) {
  const [rs, gs, bs] = [r, g, b].map(c => {
    c = c / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
}

function parseRgb(colorStr) {
  if (!colorStr) return [0, 0, 0, 1];
  const match = colorStr.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/);
  if (!match) return [0, 0, 0, 1];
  return [
    parseInt(match[1], 10),
    parseInt(match[2], 10),
    parseInt(match[3], 10),
    match[4] !== undefined ? parseFloat(match[4]) : 1.0
  ];
}

function rgbToHex(colorStr) {
  const [r, g, b] = parseRgb(colorStr);
  return '#' + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('').toUpperCase();
}

function getContrastRatio(fgRgbStr, bgRgbStr, defaultBg = [255, 255, 255]) {
  const fg = parseRgb(fgRgbStr);
  let bg = parseRgb(bgRgbStr);

  if (bg[3] < 1.0) {
    const alpha = bg[3];
    bg = [
      Math.round(bg[0] * alpha + defaultBg[0] * (1 - alpha)),
      Math.round(bg[1] * alpha + defaultBg[1] * (1 - alpha)),
      Math.round(bg[2] * alpha + defaultBg[2] * (1 - alpha)),
      1.0
    ];
  }

  const lum1 = getLuminance(fg[0], fg[1], fg[2]);
  const lum2 = getLuminance(bg[0], bg[1], bg[2]);
  const brightest = Math.max(lum1, lum2);
  const darkest = Math.min(lum1, lum2);
  return (brightest + 0.05) / (darkest + 0.05);
}

async function inspect(page, sel, text, elName, mode) {
  const defaultBgArr = mode === 'dark' ? [3, 7, 18] : [248, 250, 252];

  const res = await page.evaluate(({ selector, filterText, name }) => {
    let el = null;
    const candidates = Array.from(document.querySelectorAll(selector));
    if (filterText) {
      const lower = filterText.toLowerCase();
      el = candidates.find(c => c.textContent && c.textContent.toLowerCase().includes(lower));
    } else {
      el = candidates[0];
    }
    if (!el) return { name, found: false };

    const style = window.getComputedStyle(el);

    // resolved background
    let bg = style.backgroundColor;
    let curr = el.parentElement;
    while ((!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') && curr && curr !== document.documentElement) {
      const pStyle = window.getComputedStyle(curr);
      if (pStyle.backgroundColor && pStyle.backgroundColor !== 'rgba(0, 0, 0, 0)' && pStyle.backgroundColor !== 'transparent') {
        bg = pStyle.backgroundColor;
        break;
      }
      curr = curr.parentElement;
    }

    return {
      name,
      found: true,
      color: style.color,
      backgroundColor: style.backgroundColor,
      resolvedBg: bg || 'rgba(0, 0, 0, 0)',
      borderColor: style.borderColor,
      borderWidth: style.borderWidth,
      borderRadius: style.borderRadius,
      backdropFilter: style.backdropFilter || style.webkitBackdropFilter || 'none',
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
    };
  }, { selector: sel, filterText: text, name: elName });

  if (res.found) {
    const bgToUse = (res.backgroundColor && res.backgroundColor !== 'rgba(0, 0, 0, 0)') ? res.backgroundColor : res.resolvedBg;
    const ratio = getContrastRatio(res.color, bgToUse, defaultBgArr);
    res.ratio = ratio;
    res.colorHex = rgbToHex(res.color);
    res.bgHex = rgbToHex(bgToUse);
    res.wcagPass = ratio >= 7.0 ? 'AAA (A\'lo)' : ratio >= 4.5 ? 'AA (Yaxshi)' : ratio >= 3.0 ? 'AA Large' : 'FAIL';
  }
  return res;
}

function printItem(data) {
  if (!data.found) {
    console.log(`  [X] ${data.name}: [Topilmadi]`);
    return;
  }
  console.log(`  • ${data.name}`);
  console.log(`      Matn rangi:    ${data.color} (${data.colorHex}) [${data.fontSize}, w${data.fontWeight}]`);
  console.log(`      Fon rangi:     ${data.backgroundColor} (Asl fon: ${data.bgHex})`);
  console.log(`      Chegara:       ${data.borderColor} (${data.borderWidth}) | Radius: ${data.borderRadius}`);
  if (data.backdropFilter !== 'none') console.log(`      Liquid Glass:  ${data.backdropFilter}`);
  console.log(`      WCAG Kontrast: ${data.ratio.toFixed(2)}:1 -> [${data.wcagPass}]`);
}

async function runAnalysis() {
  console.log('========================================================================');
  console.log('   LEXGUARD AI — KUNDUZGI (LIGHT) VA TUNGI (DARK) ELEMENT TAHLILI       ');
  console.log('========================================================================\n');

  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();

  await page.goto('http://localhost:3000', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);

  for (const mode of ['dark', 'light']) {
    const isDark = mode === 'dark';
    const modeLabel = isDark ? '🌙 TUNGI REJIM (DARK MODE - Slate-950)' : '☀️ KUNDUZGI REJIM (LIGHT MODE - Slate-50)';

    console.log(`\n########################################################################`);
    console.log(`   ${modeLabel}`);
    console.log(`########################################################################`);

    // Rejimni moslash
    const currentIsDark = await page.evaluate(() => document.documentElement.classList.contains('dark'));
    if ((isDark && !currentIsDark) || (!isDark && currentIsDark)) {
      const toggleBtn = page.locator('header button[title*="rejim"]').first();
      await toggleBtn.click();
      await page.waitForTimeout(600);
    }

    // 1. STUDIYA VA HUJJAT VARAQASI ELEMENTLARI (Hozirgi standart ko'rinish)
    console.log(`\n--- 1. Kontrakt Studiyasi & Shartnoma Varaqi (DocumentPaper) ---`);
    printItem(await inspect(page, 'body', null, '1. Asosiy Sahifa Foni (Canvas Body)', mode));
    printItem(await inspect(page, 'header .liquid-glass-pill', null, '2. Stadium Floating Navbar (Liquid Glass)', mode));
    printItem(await inspect(page, 'header div[title="Bosh sahifaga qaytish"]', null, '3. Navbar Lex.uz & LexGuard Brend Bloki', mode));
    printItem(await inspect(page, 'header button', 'Xulosa', '4. Navbar "Xulosa" Studiya Ko‘rinishi Tab', mode));
    printItem(await inspect(page, 'header button', 'Diff', '5. Navbar "Diff" Yonma-yon Ko‘rinishi Tab', mode));
    printItem(await inspect(page, 'header button', '3D', '6. Navbar "3D" Lex.uz Modeli Tugmasi', mode));
    printItem(await inspect(page, '.max-w-4xl.liquid-glass', null, '7. Shartnoma Varaqi (DocumentPaper A4)', mode));
    printItem(await inspect(page, '.max-w-4xl.liquid-glass h1', null, '8. Shartnoma Bosh Sarlavhasi (Document Title)', mode));
    printItem(await inspect(page, 'div.liquid-glass-danger', null, '9. Qizil Xavfli Band Kartasi (FK 707 ziddiyat)', mode));
    printItem(await inspect(page, 'div.liquid-glass-danger p', 'Buyurtmachi istalgan vaqtda', '10. Qizil Asl Matn Qutisi (Hujjatdagi asl tahrir)', mode));
    printItem(await inspect(page, 'div.liquid-glass-danger p', 'bekor qilishdan kamida 15', '11. Yashil LexGuard Redline Qutisi (Tavsiya)', mode));
    printItem(await inspect(page, 'div.liquid-glass-danger a', 'Lex.uz', '12. Lex.uz Rasmiy Havola Tugmasi', mode));
    printItem(await inspect(page, 'div.liquid-glass-warning', null, '13. Sariq Asimmetriya Bandi (Tijoriy xavf)', mode));
    printItem(await inspect(page, 'div.liquid-glass-subtle', 'Smart Legal Solutions', '14. Shartnoma Tomonlar Rekviziti (Imzo Bloki)', mode));
    printItem(await inspect(page, 'button', 'Qabul qilish', '15. 1-Click Fix Tugmasi ("Qabul qilish")', mode));

    // 2. YURIDIK INSPEKTOR PANELI (ClauseInspector)
    console.log(`\n--- 2. Yuridik Inspektor Paneli (ClauseInspector) ---`);
    printItem(await inspect(page, 'div.backdrop-blur-2xl', null, '16. Inspektor Asosiy Oyna Foni', mode));
    printItem(await inspect(page, 'div.backdrop-blur-2xl span', 'QONUNGA ZID', '17. Inspektor Xavf Holati Nishoni (Status Badge)', mode));
    printItem(await inspect(page, 'div.backdrop-blur-2xl h3', null, '18. Inspektor Muammo Sarlavhasi', mode));
    printItem(await inspect(page, 'div.backdrop-blur-2xl p', null, '19. Inspektor AI Huquqiy Tahlili', mode));
    printItem(await inspect(page, 'div.backdrop-blur-2xl span', 'FK 707-modda', '20. Lex.uz Knowledge Graph Zanjiri (Multi-hop Modda)', mode));
    printItem(await inspect(page, 'button', 'Advokat ovozli sharhini eshitish', '21. Advokat Ovozli Sharh Tugmasi', mode));

    // 3. DIFF (REDLINE) KO'RINISHI
    console.log(`\n--- 3. Yonma-yon Redline Diff ---`);
    await page.click('header button:has-text("Diff")');
    await page.waitForTimeout(800);

    printItem(await inspect(page, 'div.space-y-6 > div.liquid-glass', null, '22. Diff Boshqaruv Paneli (Filtrlar & Qidiruv)', mode));
    printItem(await inspect(page, 'div[class*="rounded-2xl border"]', 'QIZIL', '23. Diff Yonma-yon Solishtirish Kartasi', mode));

    // 4. BOSH SAHIFA / DROPZONE
    console.log(`\n--- 4. Bosh Sahifa (Landing & Hero & Footer) ---`);
    await page.evaluate(() => {
      const logo = document.querySelector('header div[title="Bosh sahifaga qaytish"]');
      if (logo) logo.click();
    });
    await page.waitForTimeout(800);

    printItem(await inspect(page, 'h1', null, '24. Hero Katta Sarlavha (H1)', mode));
    printItem(await inspect(page, 'div.liquid-glass-card', null, '25. Shartnoma Yuklash Dropzone Kartasi', mode));
    printItem(await inspect(page, 'footer', null, '26. Sayt Futer Qismi (Footer & Lex.uz)', mode));

    // Qayta studio ochish (keyingi rejim uchun)
    await page.click('header button:has-text("Xulosa")');
    await page.waitForTimeout(600);
  }

  await browser.close();
  console.log('\n========================================================================');
  console.log('   BARCHA ELEMENTLAR KONTRAST TAHLILI MUVAFFAQIYATLI YAKUNLANDI!');
  console.log('========================================================================');
}

runAnalysis().catch(err => {
  console.error('Xatolik:', err);
  process.exit(1);
});
