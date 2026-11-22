# NGR Trades — Gold Terminal

Black & Gold, Android-first static trading assistant for XAUUSD.

## Deploy to GitHub Pages
1. Open your `Team-10` repository.
2. Upload and replace the files in this ZIP at the repository root: `index.html`, `sw.js`, `manifest.webmanifest`, `icon.svg`.
3. Commit the changes.
4. In GitHub: Settings → Pages. Keep the existing Pages source/branch and root folder.
5. Open the published site in Chrome. Use the exact GitHub Pages URL shown in Settings → Pages.
6. Reload once, then open Chrome menu → Add to Home screen / Install app.

## Included
- TradingView XAUUSD chart embed (OANDA feed; compare with Exness MT5 quote).
- Manual risk/reward and approximate lot-size calculator.
- Transparent manual EMA20/EMA50/RSI signal filter.
- Local trade journal stored in this browser.
- Service worker for app shell caching.
- Browser notification permission and local test notification.

## Important limitations
- This is a static website. It does not connect to MT5 or Exness accounts.
- It does not execute trades or receive server-side market signals.
- TradingView's embedded chart is for viewing; the app cannot read its chart data automatically.
- The signal lab only evaluates values you enter manually.
- Local notifications are not live market alerts and there is no guaranteed background push service.
- Journal data stays in this browser/device and may be lost if site data is cleared.
- Lot-size estimate depends on your broker's contract size, tick value, minimum volume, spread and account currency. Verify all specifications in MT5 before trading.

## Service worker path
All files must be in the same published root directory. For a project Pages URL such as `https://USERNAME.github.io/Team-10/`, `./sw.js` resolves within `/Team-10/`. Do not create a second copy of `sw.js` in another folder.
