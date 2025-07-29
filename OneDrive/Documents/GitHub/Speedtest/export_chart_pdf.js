const puppeteer = require('puppeteer');
const fs = require('fs');

// Configurable parameters
const URL = process.env.SPEEDTEST_URL || 'http://localhost/speedtest/';
const EXPORT_DIR = process.env.EXPORT_DIR || '/var/www/html/speedtest/exports';
const LOG_FILE = process.env.LOG_FILE || '/var/log/export_chart_pdf.log';
const today = new Date().toISOString().split('T')[0];
const PDF_PATH = `${EXPORT_DIR}/speedtest_${today}.pdf`;

function log(message) {
  const entry = `[${new Date().toISOString()}] ${message}\n`;
  try {
    fs.appendFileSync(LOG_FILE, entry);
  } catch (e) {
    // Fallback to console if logging fails
    console.error('Logging failed:', e, entry);
  }
}

(async () => {
  try {
    // Ensure export directory exists
    fs.mkdirSync(EXPORT_DIR, { recursive: true });

    log('Launching Puppeteer...');
    const browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox']
    });
    const page = await browser.newPage();
    log(`Navigating to ${URL}`);
    await page.goto(URL, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#speedChart', { timeout: 10000 });

    log(`Exporting PDF to ${PDF_PATH}`);
    await page.pdf({
      path: PDF_PATH,
      format: 'A4',
      printBackground: true
    });

    await browser.close();
    log('PDF export completed successfully.');
  } catch (err) {
    log(`ERROR: ${err.stack || err}`);
    process.exit(1);
  }
})();
