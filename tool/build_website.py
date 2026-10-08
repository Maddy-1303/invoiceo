#!/usr/bin/env python3
"""Builds the Invoiceo website pages (plain HTML) into the website folder.

Usage (from the invoiso-main folder):
    python3 tool/build_website.py ../invoiceo-website

Edit the text here, run it, then upload the website folder. Values that are
not known yet (WhatsApp, form links, analytics ID, file sizes) live in the
website's assets/js/config.js, not here."""
import html
import json
import os
import sys

OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '../invoiceo-website')
SITE = 'https://invoiceo.in'
NAME = 'Invoiceo'
BUSINESS = 'Madcreations'
EMAIL = 'madhanprasat2002r@gmail.com'
VERSION = '1.0.0'
RELEASE_DATE = '9 October 2026'
RELEASE_ISO = '2026-10-09'
COFFEE = 'https://buymeacoffee.com/madcreations'
# Fixed-name copies the release workflow adds to every release (.github/workflows/build.yml).
DL = 'https://github.com/Maddy-1303/invoiceo/releases/latest/download/'
FILES = {
    'windows': 'Invoiceo-Setup-Windows.exe',
    'mac': 'Invoiceo-macOS.dmg',
    'linuxDeb': 'Invoiceo-Linux.deb',
    'linuxAppImage': 'Invoiceo-Linux.AppImage',
}

# Feather icons (MIT, © Cole Bemis) — see licenses.html.
ICONS = {
    'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>',
    'file': '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/>',
    'printer': '<polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/>',
    'globe': '<circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
    'users': '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    'package': '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/>',
    'chart': '<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>',
    'briefcase': '<rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>',
    'database': '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>',
    'percent': '<line x1="19" y1="5" x2="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
    'repeat': '<polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>',
    'qr': '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><path d="M14 14h3v3h-3zM20 14v.01M14 20h.01M17 20h4v-3"/>',
    'gift': '<polyline points="20 12 20 22 4 22 4 12"/><rect x="2" y="7" width="20" height="5"/><line x1="12" y1="22" x2="12" y2="7"/><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"/><path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"/>',
    'wifi-off': '<line x1="1" y1="1" x2="23" y2="23"/><path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/><path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/><path d="M10.71 5.05A16 16 0 0 1 22.58 9"/><path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/>',
    'hard-drive': '<line x1="22" y1="12" x2="2" y2="12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><line x1="6" y1="16" x2="6.01" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/>',
    'sliders': '<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/>',
    'layout': '<rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/>',
    'list': '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
    'share': '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/>',
    'tool': '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
    'mail': '<path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/>',
    'message': '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>',
    'help': '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
    'coffee': '<path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/>',
    'monitor': '<rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>',
    'laptop': '<rect x="3" y="4" width="18" height="12" rx="2"/><line x1="2" y1="20" x2="22" y2="20"/>',
    'terminal': '<polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/>',
    'arrow': '<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>',
    'menu': '<line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/>',
    'refresh': '<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>',
}


def icon(name, cls=''):
    return (f'<svg{(" class=" + chr(34) + cls + chr(34)) if cls else ""} viewBox="0 0 24 24" fill="none" '
            f'stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" '
            f'aria-hidden="true">{ICONS[name]}</svg>')


def tile(name, tone=''):
    return f'<span class="icon-tile{(" " + tone) if tone else ""}">{icon(name)}</span>'


NAV = [
    ('Features', 'index.html#features', 'features'),
    ('Download', 'download.html', 'download'),
    ('Customization', 'customization.html', 'customization'),
    ('FAQ', 'faq.html', 'faq'),
    ('Updates', 'changelog.html', 'changelog'),
    ('Contact', 'contact.html', 'contact'),
]


def header(active, base=False):
    links = '\n'.join(
        f'        <a href="{href}"{" aria-current=" + chr(34) + "page" + chr(34) if key == active else ""}>{label}</a>'
        for label, href, key in NAV)
    # The 404 page has <base href="/">, where "#main" would mean the home page.
    skip = '' if base else '<a class="skip-link" href="#main">Skip to content</a>\n'
    return f'''{skip}
<header class="site-header">
  <div class="container">
    <a class="brand" href="index.html" aria-label="{NAME} home"><img src="assets/images/logo.png" alt="{NAME}" width="196" height="68"></a>
    <button class="menu-toggle" type="button" aria-controls="site-nav" aria-expanded="false" aria-label="Menu">{icon('menu')}</button>
    <nav class="nav" id="site-nav" aria-label="Main">
{links}
        <a class="btn btn-primary btn-sm header-cta" href="download.html">{icon('download')} Download free</a>
    </nav>
  </div>
</header>'''


FOOTER = f'''<footer class="site-footer">
  <div class="container">
    <div class="footer-grid">
      <div class="footer-brand">
        <img src="assets/images/logo.png" alt="{NAME}" width="196" height="68">
        <p>Free billing and GST invoice software that runs on your own computer.</p>
        <a class="coffee" href="{COFFEE}" target="_blank" rel="noopener">{icon('coffee')} Buy me a coffee</a>
      </div>
      <div>
        <h4>Product</h4>
        <ul>
          <li><a href="download.html">Download</a></li>
          <li><a href="index.html#features">Features</a></li>
          <li><a href="changelog.html">Updates</a></li>
          <li><a href="customization.html">Customization</a></li>
        </ul>
      </div>
      <div>
        <h4>Help</h4>
        <ul>
          <li><a href="faq.html">FAQ</a></li>
          <li><a href="contact.html">Contact</a></li>
          <li data-block><a data-href="forms.support" data-hide-empty target="_blank" rel="noopener">Support request</a></li>
          <li data-block><a data-href="forms.feedback" data-hide-empty target="_blank" rel="noopener">Send feedback</a></li>
        </ul>
      </div>
      <div>
        <h4>Legal</h4>
        <ul>
          <li><a href="privacy.html">Privacy</a></li>
          <li><a href="terms.html">Terms</a></li>
          <li><a href="licenses.html">Licenses</a></li>
        </ul>
      </div>
    </div>
    <div class="footer-bottom">
      <span>© <span data-year>2026</span> {BUSINESS}. Built on Invoiso, released under the <a href="licenses.html">MIT License</a>, © 2025 ANOOP P.</span>
      <span><a href="mailto:{EMAIL}">{EMAIL}</a></span>
    </div>
  </div>
</footer>'''


def page(filename, title, description, active, body, jsonld=None, noindex=False):
    canonical = SITE + '/' + ('' if filename == 'index.html' else filename)
    ld = ''
    if jsonld:
        ld = '\n  <script type="application/ld+json">\n' + json.dumps(jsonld, ensure_ascii=False, indent=2) + '\n  </script>'
    full_title = title if filename == 'index.html' else f'{title} — {NAME}'
    doc = f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">{chr(10) + '  <base href="/">' if noindex else ''}
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="theme-color" content="#ffffff">
  <title>{html.escape(full_title)}</title>
  <meta name="description" content="{html.escape(description)}">
  {'<meta name="robots" content="noindex">' if noindex else f'<link rel="canonical" href="{canonical}">'}
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="{NAME}">
  <meta property="og:title" content="{html.escape(full_title)}">
  <meta property="og:description" content="{html.escape(description)}">
  <meta property="og:url" content="{canonical}">
  <meta property="og:image" content="{SITE}/assets/images/og-image.png">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="icon" href="favicon.ico" sizes="any">
  <link rel="icon" type="image/png" sizes="32x32" href="assets/images/favicon-32.png">
  <link rel="apple-touch-icon" href="assets/images/apple-touch-icon.png">
  <link rel="manifest" href="site.webmanifest">
  <link rel="stylesheet" href="assets/css/site.css?v={VERSION}">{ld}
</head>
<body>
{header(active, base=noindex)}
<main id="main">
{body}
</main>
{FOOTER}
<script src="assets/js/config.js?v={VERSION}"></script>
<script src="assets/js/site.js?v={VERSION}"></script>
</body>
</html>
'''
    with open(os.path.join(OUT, filename), 'w', encoding='utf-8') as f:
        f.write(doc)


ORG = {'@type': 'Organization', 'name': BUSINESS, 'email': EMAIL, 'url': SITE + '/'}

# ─────────────────────────────── Home ──────────────────────────────────────
# Real screenshots of the app (sample shop, not real customers). Made with
#   flutter test tool/screenshots/marketing_screenshots_test.dart
SHOT_W, SHOT_H = 2160, 1350


SCREENS = os.path.join(OUT, 'assets', 'images', 'screens')


def small_copy(name):
    """A 1280px JPEG next to each screenshot PNG (about a third of the size),
    made with macOS 'sips' when the PNG is newer. Returns False without it."""
    png = os.path.join(SCREENS, name + '.png')
    jpg = os.path.join(SCREENS, name + '-1280.jpg')
    if os.path.exists(png) and (not os.path.exists(jpg) or os.path.getmtime(jpg) < os.path.getmtime(png)):
        import subprocess
        try:
            subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '82',
                            '--resampleWidth', '1280', png, '--out', jpg],
                           check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError):
            return False
    return os.path.exists(jpg)


def shot(name, alt, lazy=True):
    full = f'assets/images/screens/{name}.png'
    src = f'assets/images/screens/{name}-1280.jpg' if small_copy(name) else full
    srcset = f' srcset="{src} 1280w, {full} {SHOT_W}w" sizes="(max-width: 760px) 100vw, 960px"' if src != full else ''
    load = ' loading="lazy"' if lazy else ' fetchpriority="high"'
    return (f'<div class="window"><div class="window-bar"><span></span><span></span><span></span></div>'
            f'<a href="{full}" target="_blank" rel="noopener" title="Open full size">'
            f'<img src="{src}"{srcset} width="{SHOT_W}" height="{SHOT_H}" alt="{alt}"{load}></a></div>')


PREVIEW = shot('dashboard', 'The Invoiceo dashboard: money collected and still due, a six-month sales chart, invoice status and recent invoices', lazy=False)

SHOTS = [
    ('create-invoice', 'Make a bill', 'Pick the customer, search or scan products, and change quantity and price right in the table. Totals and GST add up as you type.'),
    ('invoices', 'Every invoice in one list', 'Search, filter and sort your invoices. See what is paid, partly paid or overdue, and continue a saved draft.'),
    ('customers', 'Customers', 'Phone, GSTIN and what each customer still owes, with businesses and individuals kept apart.'),
    ('products', 'Products and stock', 'Prices, HSN codes, tax and stock levels, with low-stock and out-of-stock items easy to spot.'),
    ('reports', 'Reports', 'Billed, collected and outstanding money month by month, with profit when purchase prices are set.'),
]
home_shots = '\n'.join(
    f'''      <figure class="shot{" shot-wide" if i == 0 else ""}">{shot(n, t + " screen of Invoiceo")}<figcaption><strong>{t}</strong> {d}</figcaption></figure>'''
    for i, (n, t, d) in enumerate(
        [x for x in SHOTS if os.path.exists(os.path.join(SCREENS, x[0] + '.png'))]))

FEATURES = [
    ('percent', 'GST-ready invoices',
     'Add your GSTIN, HSN/SAC codes and tax rates. Bills show CGST and SGST, or IGST for sales to another state, under titles such as Tax Invoice or Bill of Supply.'),
    ('repeat', 'Quotations, payments and receipts',
     'Send a quotation and turn it into an invoice in one step. Record full or part payments, print payment receipts and see what each customer still owes.'),
    ('printer', 'Print on the printer you have',
     'Six invoice designs for A4, A5 and A6 paper, plus a receipt layout for 58 mm and 80 mm thermal printers. Receipts can print by themselves after every sale (Modern layout).'),
    ('globe', 'Tamil and seven other languages',
     'Use the app in English, Tamil, Hindi, Nepali, French, Spanish, Chinese or Tibetan (partly translated). Tamil product and customer names print correctly on PDFs and thermal receipts.'),
    ('package', 'Customers and products',
     'Keep your customer list and product catalogue with prices, units, stock levels, batch numbers and expiry dates. Add items to a bill with a barcode scanner.'),
    ('chart', 'Reports that answer real questions',
     'Revenue, tax, invoice status, money still to collect, daily sales and stock value. Print a statement for any customer and export your lists to CSV or PDF.'),
    ('qr', 'UPI QR and bank details',
     'Print your UPI QR code and bank account on the invoice, so customers can pay the moment they receive it.'),
    ('briefcase', 'Several businesses, several users',
     'Run more than one company from the same computer, each with its own data. Give staff their own login with admin or user rights.'),
    ('database', 'Backup and restore',
     'Back up a company in one click and restore it whenever you need to, including from a backup file you copied from another computer.'),
]

home_features = '\n'.join(
    f'''      <div class="card">{tile(i)}<h3>{t}</h3><p>{d}</p></div>''' for i, t, d in FEATURES)

home_faq = [
    ('Is Invoiceo really free?',
     'Yes. You can download it and use everything in it without paying, and there is no subscription. We only charge when you ask us to build something new for your business.'),
    ('Do I need an internet connection?',
     'No. Invoiceo runs on your computer, so you can bill, print and see reports without internet. You only need a connection to download the installer.'),
    ('Where is my data kept?',
     'On your own computer. Your customers, products and invoices are not sent to us. Use <b>Settings → Backup</b> in the app to keep a copy safe.'),
    ('Does it print on a thermal receipt printer?',
     'Yes, on 58 mm and 80 mm thermal printers, as well as on any normal printer for A4, A5 and A6 invoices.'),
]


def faq_items(items):
    return '\n'.join(
        f'''      <details><summary>{q}</summary><div class="answer">{"".join("<p>" + p + "</p>" for p in (a if isinstance(a, list) else [a]))}</div></details>'''
        for q, a in items)


home_body = f'''<section class="hero">
  <div class="container">
    <div>
      <span class="badge badge-free">{icon('gift')} Free forever · No subscription</span>
      <h1>Simple billing for your business, right on your computer</h1>
      <p class="lead">{NAME} makes GST invoices, quotations and receipts without needing the internet. Print on A4 or on a thermal receipt printer, in English, Tamil and six other languages.</p>
      <div class="hero-actions">
        <a class="btn btn-primary" href="download.html" data-os-download>{icon('download')} <span data-os-label>Download free</span></a>
        <a class="btn btn-secondary" href="#features">See what it does</a>
      </div>
      <p class="hero-note">For Windows, macOS and Linux · Version <span data-version>{VERSION}</span> · No online sign-up</p>
      <div class="notice hidden mt-2" data-mobile-note>{icon('monitor')} {NAME} runs on a Windows, Mac or Linux computer. Open <b>invoiceo.in</b> on your computer to download it.</div>
    </div>
    {PREVIEW}
  </div>
</section>

<section class="section" aria-label="Our promises">
  <div class="container">
    <div class="promises">
      <div class="promise">{tile('gift', 'green')}<div><h3>Free forever</h3><p>Every feature in the app costs nothing. No subscription, and no trial that runs out.</p></div></div>
      <div class="promise">{tile('wifi-off')}<div><h3>Works offline</h3><p>Billing carries on when the internet is down, because everything runs on your computer.</p></div></div>
      <div class="promise">{tile('hard-drive')}<div><h3>Your data stays with you</h3><p>Customers, products and invoices are saved on your computer, not on our servers.</p></div></div>
    </div>
  </div>
</section>

<section class="section section-alt" id="screens">
  <div class="container">
    <div class="section-head">
      <span class="eyebrow">See it</span>
      <h2>A clear screen for every job</h2>
      <p>These are real screens from {NAME} {VERSION}, filled with a sample shop.</p>
    </div>
    <div class="shots">
{home_shots}
    </div>
  </div>
</section>

<section class="section" id="features">
  <div class="container">
    <div class="section-head">
      <span class="eyebrow">Features</span>
      <h2>Everything a shop counter needs</h2>
      <p>From the first quotation to the final receipt, {NAME} keeps your billing in one place.</p>
    </div>
    <div class="grid grid-3">
{home_features}
    </div>
  </div>
</section>

<section class="section section-alt" id="how-it-works">
  <div class="container">
    <div class="section-head">
      <span class="eyebrow">How it works</span>
      <h2>Start billing in three steps</h2>
    </div>
    <div class="steps">
      <div class="step"><h3>Download and install</h3><p>Get the free installer for Windows, macOS or Linux and install it like any other app.</p></div>
      <div class="step"><h3>Set up your business</h3><p>Enter your company details and logo, then add your products and customers, or type them in as you bill.</p></div>
      <div class="step"><h3>Bill and print</h3><p>Search a product or scan its barcode, pick the customer and create the invoice. Print it, or save it as a PDF to share.</p></div>
    </div>
  </div>
</section>

<section class="section" id="customization">
  <div class="container split">
    <div>
      <h2>Need something made for your business?</h2>
      <p class="lead">The app is free. When your trade needs a feature or a bill format that {NAME} does not have, we can build it for you. Each request is quoted on its own before any work starts.</p>
      <ul class="check-list">
        <li>Your own invoice or bill design</li>
        <li>Extra fields on invoices and products</li>
        <li>Bill formats for your kind of business</li>
        <li>New reports</li>
        <li>Export to Tally or another accounting app</li>
      </ul>
      <a class="btn btn-primary" href="customization.html">Request a customization {icon('arrow')}</a>
    </div>
    <div class="card">
      <h3 class="mt-0">How a customization works</h3>
      <ol class="mt-2">
        <li>You tell us what you need through the request form.</li>
        <li>We ask any questions and send you a quote.</li>
        <li>You approve it, and we build, test and deliver your version.</li>
      </ol>
      <p class="small mt-2">No payment is asked for until you have seen and accepted the quote.</p>
    </div>
  </div>
</section>

<section class="section section-alt" id="faq">
  <div class="container">
    <div class="section-head">
      <span class="eyebrow">FAQ</span>
      <h2>Common questions</h2>
    </div>
    <div class="faq">
{faq_items(home_faq)}
    </div>
    <p class="center mt-2"><a href="faq.html">See all questions {icon('arrow')}</a></p>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="cta-band">
      <h2>Ready to make your first invoice?</h2>
      <p>Download {NAME} for free and start billing in a few minutes.</p>
      <div class="hero-actions">
        <a class="btn btn-primary" href="download.html">{icon('download')} Download free</a>
        <a class="btn btn-secondary" href="contact.html">Contact us</a>
      </div>
    </div>
  </div>
</section>'''

page('index.html', f'{NAME} — Free offline billing and GST invoice software',
     f'{NAME} is free billing software for Windows, macOS and Linux. Make GST invoices, quotations and receipts offline, print on A4 or thermal printers, in English, Tamil and more.',
     'home', home_body, jsonld={
         '@context': 'https://schema.org',
         '@type': 'SoftwareApplication',
         'name': NAME,
         'applicationCategory': 'BusinessApplication',
         'operatingSystem': 'Windows, macOS, Linux',
         'softwareVersion': VERSION,
         'datePublished': RELEASE_ISO,
         'description': 'Free offline billing and GST invoice software for small businesses.',
         'url': SITE + '/',
         'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'INR'},
         'publisher': ORG,
     })

# ───────────────────────────── Download ────────────────────────────────────
download_body = f'''<section class="page-head">
  <div class="container">
    <span class="badge badge-free">{icon('gift')} Free</span>
    <h1>Download {NAME}</h1>
    <p>Free for Windows, macOS and Linux. No sign-up, no licence key and no subscription.</p>
    <div class="version-row">
      <span class="badge badge-brand">Version <span data-version>{VERSION}</span></span>
      <span class="badge badge-neutral">Released <span data-release-date>{RELEASE_DATE}</span></span>
      <a href="changelog.html" class="small">What’s new</a>
    </div>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="notice hidden mt-2" data-mobile-note>{icon('monitor')} {NAME} runs on a Windows, Mac or Linux computer. Open <b>invoiceo.in</b> on your computer to download it.</div>
    <div class="recommended" data-recommended>
      <div>
        <h2>Recommended for your computer: <span data-recommended-name>Windows</span></h2>
        <p class="muted">We picked this from your browser. All versions are listed below.</p>
      </div>
      <a class="btn btn-primary" href="{DL}{FILES['windows']}" data-os-download>{icon('download')} <span data-os-label>Download</span></a>
    </div>

    <div class="grid grid-3 mt-3">
      <div class="card platform" data-platform="windows" id="windows">
        {tile('monitor')}
        <h3>Windows</h3>
        <p class="meta">Windows 10 or 11, 64-bit · .exe installer<span data-size="windows"></span></p>
        <a class="btn btn-primary" href="{DL}{FILES['windows']}" data-primary-download>{icon('download')} Download for Windows</a>
        <ol>
          <li>Open the downloaded file.</li>
          <li>If Windows shows <b>“Windows protected your PC”</b>, click <b>More info</b>, then <b>Run anyway</b>. This appears because the installer is not code-signed yet.</li>
          <li>Follow the setup. {NAME} then opens from the Start menu.</li>
        </ol>
      </div>
      <div class="card platform" data-platform="mac" id="macos">
        {tile('laptop')}
        <h3>macOS</h3>
        <p class="meta">macOS 12 Monterey or later · .dmg disk image<span data-size="mac"></span></p>
        <a class="btn btn-primary" href="{DL}{FILES['mac']}" data-primary-download>{icon('download')} Download for macOS</a>
        <ol>
          <li>Open the .dmg and drag {NAME} into Applications.</li>
          <li>Open {NAME}. If macOS says it cannot verify the app, click <b>Done</b>. This happens because the app is not notarised by Apple yet.</li>
          <li>Open <b>System Settings → Privacy &amp; Security</b>, scroll down to the message about {NAME} and click <b>Open Anyway</b>, then confirm. (On macOS 14 or older you can instead Control-click {NAME} in Applications and choose <b>Open</b>.)</li>
          <li>After that it opens normally.</li>
        </ol>
      </div>
      <div class="card platform" data-platform="linux" id="linux">
        {tile('terminal')}
        <h3>Linux</h3>
        <p class="meta">.deb for Ubuntu 22.04+, Debian 12+ and Linux Mint 21+ · AppImage for other distributions</p>
        <a class="btn btn-primary" href="{DL}{FILES['linuxDeb']}" data-primary-download>{icon('download')} Download .deb<span data-size="linuxDeb"></span></a>
        <a class="btn btn-secondary" href="{DL}{FILES['linuxAppImage']}">{icon('download')} Download AppImage<span data-size="linuxAppImage"></span></a>
        <ol>
          <li><b>.deb:</b> run <code>sudo apt install ./{FILES['linuxDeb']}</code> in the folder you downloaded it to.</li>
          <li><b>AppImage:</b> run <code>chmod +x {FILES['linuxAppImage']}</code>, then open the file.</li>
        </ol>
      </div>
    </div>

    <div class="notice free mt-3"><b>{NAME} is free.</b> You never need to pay to download it, install it on more computers or keep using it.</div>

    <div class="grid grid-2 mt-3">
      <div class="card">
        {tile('refresh')}
        <h3>Updating to a new version</h3>
        <p>Download the new installer and install it over the old version. Your data is kept, but we recommend making a backup first from <b>Settings → Backup</b> in the app.</p>
      </div>
      <div class="card">
        {tile('help')}
        <h3>Need help installing?</h3>
        <p>Read the <a href="faq.html">FAQ</a> or <a href="contact.html">contact us</a>, and we will help you get started.</p>
      </div>
    </div>
  </div>
</section>'''

page('download.html', 'Download',
     f'Download {NAME} free for Windows, macOS and Linux, with step-by-step install help.',
     'download', download_body)

# ─────────────────────────── Customization ─────────────────────────────────
CUSTOM = [
    ('file', 'Invoice and bill designs', 'A layout that matches your letterhead, your trade or a format your customers expect.'),
    ('list', 'Extra fields', 'More details on invoices, products or customers, printed where you need them.'),
    ('layout', 'Bill formats for your trade', 'Special bills for your kind of business, with the columns and totals your trade uses.'),
    ('chart', 'New reports', 'Reports and summaries built around the numbers you check every day or month.'),
    ('share', 'Exports', 'Send your data to Tally or another accounting app in the format it needs.'),
    ('sliders', 'Changes to how it works', 'Shortcuts, steps or screens adjusted to the way your counter works.'),
]
custom_cards = '\n'.join(f'      <div class="card">{tile(i, "amber")}<h3>{t}</h3><p>{d}</p></div>' for i, t, d in CUSTOM)

customization_body = f'''<section class="page-head">
  <div class="container">
    <h1>Customization</h1>
    <p>{NAME} is free to use. When your business needs something more, we can build it for you. Every request is quoted on its own, and you decide before any work starts.</p>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="section-head">
      <h2>What we can make for you</h2>
      <p>A few examples. If your idea is not on the list, ask anyway.</p>
    </div>
    <div class="grid grid-3">
{custom_cards}
    </div>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <div class="section-head"><h2>How it works</h2></div>
    <div class="steps">
      <div class="step"><h3>Tell us what you need</h3><p>Fill in the request form below. Sample bills or screenshots help a lot.</p></div>
      <div class="step"><h3>Get a quote</h3><p>We reply with any questions and a price for the work. There is no charge for the quote.</p></div>
      <div class="step"><h3>We build it</h3><p>Once you approve, we build and test it, and give you your updated version.</p></div>
    </div>
  </div>
</section>

<section class="section" id="request">
  <div class="container">
    <div class="section-head">
      <h2>Request a customization</h2>
      <p>Prices depend on the work, so we do not list fixed prices. You will always see the quote first.</p>
      <p data-block><a class="btn btn-secondary" data-href="forms.customization" data-hide-empty target="_blank" rel="noopener">Open the form in a new tab {icon('arrow')}</a></p>
    </div>
    <iframe id="customization-form" class="form-frame hidden" title="Customization request form" loading="lazy"></iframe>
    <div id="customization-form-missing" class="form-missing">
      <p><b>The request form is coming soon.</b></p>
      <p>Until then, write to us at <a href="mailto:{EMAIL}?subject=Customization%20request">{EMAIL}</a><span data-block data-whatsapp-wrap> or message us on <a data-whatsapp target="_blank" rel="noopener">WhatsApp</a></span>.</p>
    </div>
  </div>
</section>'''

page('customization.html', 'Customization',
     f'{NAME} is free; extra features, invoice designs, reports and exports for your business are built on request and quoted per job.',
     'customization', customization_body)

# ──────────────────────────────── FAQ ──────────────────────────────────────
FAQ = [
    ('Is Invoiceo really free?',
     ['Yes. The app and its updates are free, with no subscription and no trial period. You can install it on as many of your computers as you like.',
      'We only charge for work done for you on request, such as a new bill format or a report. See <a href="customization.html">Customization</a>.']),
    ('Do I need an internet connection?',
     'No. Invoiceo runs on your computer, so you can bill, print and see reports offline. You need a connection only to download the installer, to open our website or forms, or to share a PDF online.'),
    ('Do I need to create an account?',
     'No online account or sign-up is needed. The app has its own login on your computer, so you can protect it with a password and give each person their own username.'),
    ('Where is my data stored?',
     ['Everything you enter is saved on your own computer, in the app’s data folder. Your customers, products and invoices are not sent to us.',
      'Because the data is on your computer, keeping it safe is in your hands: use <b>Settings → Backup</b> in the app regularly.']),
    ('Can I use Invoiceo for GST billing?',
     ['Yes. You can add your GSTIN and your customers’ GSTINs, HSN/SAC codes and tax rates per product or for the whole invoice. Invoices show CGST and SGST, or IGST for sales to another state, and you can choose titles such as Tax Invoice or Bill of Supply.',
      'Invoiceo helps you prepare correct invoices; for filing returns, please follow your accountant’s advice.']),
    ('Which printers can I use?',
     'Any printer your computer can print to, for A4, A5 and A6 invoices. For receipts, Invoiceo supports 58 mm and 80 mm thermal printers and can print the receipt automatically after each sale (in the Modern layout).'),
    ('Can I use it in Tamil?',
     'Yes. The app can be used in English, Tamil, Hindi, Nepali, French, Spanish, Chinese and Tibetan (partly translated), and Tamil names print correctly on PDFs and thermal receipts.'),
    ('Does it work with a barcode scanner?',
     'Yes. A USB barcode scanner that types the code works on the New Invoice screen: scan a product to add it to the bill.'),
    ('Can I manage more than one business?',
     'Yes. You can add several companies on one computer. Each company keeps its own customers, products, invoices and settings.'),
    ('Can more than one person use it?',
     'Yes, on the same computer. Each person can have their own login, as an admin or a normal user.'),
    ('How do I move to a new computer?',
     'Make a backup of each company on the old computer, copy the backup file to the new one, install Invoiceo there and import the backup from <b>Settings → Backup</b>.'),
    ('Windows says “Windows protected your PC”. Is it safe?',
     'This message appears for installers that are not code-signed yet. If you downloaded Invoiceo from this website, click <b>More info</b> and then <b>Run anyway</b>.'),
    ('macOS says it cannot check the app for malicious software.',
     'The app is not notarised by Apple yet. Click <b>Done</b>, open <b>System Settings → Privacy &amp; Security</b>, scroll down to the message about Invoiceo and click <b>Open Anyway</b>. On macOS 14 or older, Control-click Invoiceo in Applications and choose <b>Open</b>. You only need to do this the first time.'),
    ('How do I update to a new version?',
     'Download the new version from the <a href="download.html">Download page</a> and install it over the old one. Your data is kept, but make a backup first to be safe. See what changed on the <a href="changelog.html">Updates page</a>.'),
    ('Can you add a feature for my business?',
     'Yes, as a paid service, quoted per request. Tell us what you need on the <a href="customization.html">Customization page</a>.'),
    ('How do I get help?',
     'Use the support form or write to us. All the ways to reach us are on the <a href="contact.html">Contact page</a>.'),
]


def strip_tags(s):
    import re
    return re.sub(r'<[^>]+>', '', s)


faq_body = f'''<section class="page-head">
  <div class="container">
    <span class="eyebrow">Help</span>
    <h1>Frequently asked questions</h1>
    <p>Short answers about {NAME}. Can’t find yours? <a href="contact.html">Ask us</a>.</p>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="faq">
{faq_items(FAQ)}
    </div>
  </div>
</section>'''

page('faq.html', 'FAQ',
     f'Answers about {NAME}: price, offline use, where data is stored, GST, printers, Tamil, barcode scanners, installing and updating.',
     'faq', faq_body, jsonld={
         '@context': 'https://schema.org',
         '@type': 'FAQPage',
         'mainEntity': [
             {'@type': 'Question', 'name': q,
              'acceptedAnswer': {'@type': 'Answer',
                                 'text': strip_tags(' '.join(a) if isinstance(a, list) else a)}}
             for q, a in FAQ],
     })

# ────────────────────────────── Contact ────────────────────────────────────
contact_body = f'''<section class="page-head">
  <div class="container">
    <span class="eyebrow">Contact</span>
    <h1>Talk to us</h1>
    <p>Questions, problems or ideas — choose whichever way suits you.</p>
  </div>
</section>

<section class="section">
  <div class="container">
    <div class="grid grid-2">
      <div class="card contact-card">
        {tile('mail')}
        <h3>Email</h3>
        <p class="value">{EMAIL}</p>
        <p>For anything about {NAME}.</p>
        <a class="btn btn-secondary btn-sm" href="mailto:{EMAIL}">Send an email</a>
      </div>
      <div class="card contact-card" data-block>
        {tile('message', 'green')}
        <h3>WhatsApp</h3>
        <p class="value"><span data-whatsapp-number></span></p>
        <p>Quick questions and help with installing.</p>
        <a class="btn btn-secondary btn-sm" data-whatsapp target="_blank" rel="noopener">Chat on WhatsApp</a>
      </div>
      <div class="card contact-card">
        {tile('help')}
        <h3>Support request</h3>
        <p>Report a problem with installing, printing or billing. Include your app version and, if you can, a screenshot.</p>
        <a class="btn btn-secondary btn-sm" data-href="forms.support" target="_blank" rel="noopener">Open the support form</a>
      </div>
      <div class="card contact-card">
        {tile('tool', 'amber')}
        <h3>Customization</h3>
        <p>Need a feature, report or bill format made for your business? It is a paid service, quoted per request.</p>
        <a class="btn btn-secondary btn-sm" href="customization.html">Request a customization</a>
      </div>
      <div class="card contact-card" data-block>
        {tile('refresh')}
        <h3>Feedback</h3>
        <p>Tell us what you like and what we should improve.</p>
        <a class="btn btn-secondary btn-sm" data-href="forms.feedback" data-hide-empty target="_blank" rel="noopener">Give feedback</a>
      </div>
      <div class="card contact-card">
        {tile('coffee', 'amber')}
        <h3>Like {NAME}?</h3>
        <p>{NAME} is free. If it saves you time, you can buy me a coffee.</p>
        <a class="btn btn-secondary btn-sm" href="{COFFEE}" target="_blank" rel="noopener">Buy me a coffee</a>
      </div>
    </div>
  </div>
</section>'''

page('contact.html', 'Contact',
     f'Contact {BUSINESS} about {NAME}: email, WhatsApp, support requests and paid customization.',
     'contact', contact_body)

# ────────────────────────────── Updates ────────────────────────────────────
changelog_body = f'''<section class="page-head">
  <div class="container">
    <span class="eyebrow">Updates</span>
    <h1>What’s new in {NAME}</h1>
    <p>Every release, newest first. Download the latest version from the <a href="download.html">Download page</a>.</p>
  </div>
</section>

<section class="section">
  <div class="container prose">
    <article class="release" id="v{VERSION}">
      <h2>Version {VERSION} <span class="badge badge-brand">Latest</span></h2>
      <p class="date">{RELEASE_DATE}</p>
      <p>The first release under the {NAME} name.</p>
      <ul>
        <li>New name, logo and a clean light design.</li>
        <li>Tamil added as an app language, alongside English, Hindi, Nepali, French, Spanish, Chinese and Tibetan (partly translated).</li>
        <li>Two screen layouts to choose from in Settings: <b>Standard</b> and the new <b>Modern</b> layout, with a grouped sidebar, a top bar with a quick “new invoice, quotation or receipt” button, and a new dashboard.</li>
        <li>Thermal receipts with Tamil and other Indian-language text now print the same way they look in the preview.</li>
        <li>Receipts can print automatically after each invoice is created (Modern layout).</li>
        <li>In the Modern layout, an unfinished invoice can be saved as a draft and continued later from the Invoices list.</li>
        <li>Barcode scanning on the New Invoice screen is more reliable.</li>
        <li>In the Modern layout, Products and Services have their own pages, each with its own columns and filters, and the Customers page shows what each customer still owes.</li>
        <li>The app tells you when a newer version is out (it checks once a day while you are online; billing never needs the internet).</li>
      </ul>
    </article>
  </div>
</section>'''

page('changelog.html', 'Updates',
     f'Release notes for {NAME}: what changed in each version.',
     'changelog', changelog_body)

# ─────────────────────────────── Privacy ───────────────────────────────────
privacy_body = f'''<section class="page-head">
  <div class="container">
    <span class="eyebrow">Legal</span>
    <h1>Privacy policy</h1>
    <p>Last updated: {RELEASE_DATE}</p>
  </div>
</section>

<section class="section">
  <div class="container prose">
    <p>This policy explains what information {BUSINESS} (“we”) handles when you use the {NAME} app and this website. If you have a question about it, write to <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>

    <h2>The {NAME} app</h2>
    <ul>
      <li><b>Your business data stays on your computer.</b> The customers, products, invoices, payments, settings and backups you create are stored on the computer where {NAME} is installed. We do not receive a copy.</li>
      <li><b>The app sends nothing to us.</b> It has no usage tracking or analytics and does not send your business data anywhere. Once a day, when you are online, it asks GitHub whether a newer version of {NAME} exists; that is an ordinary web request, so GitHub sees your IP address. Otherwise it goes online only when you click a link that opens your web browser.</li>
      <li><b>No online account.</b> The app’s usernames and passwords exist only on your computer.</li>
      <li><b>No advertising</b> and no selling of data, ever.</li>
      <li><b>Links you choose to open.</b> Some buttons in the app open a web page in your browser (for example this website, our forms or Buy Me a Coffee). What happens on those pages is covered below or by that site’s own policy.</li>
      <li><b>Backups and PDFs.</b> Files you export or share are handled by you; we have no access to them.</li>
    </ul>

    <h2>This website</h2>
    <ul>
      <li><b>Hosting.</b> This site is hosted on GitHub Pages. GitHub may record technical information such as your IP address when you visit, as described in the <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement" target="_blank" rel="noopener">GitHub Privacy Statement</a>. Installers are downloaded from GitHub as well.</li>
      <li><b>Forms.</b> Our support, customization and feedback forms are Google Forms. What you type into them (such as your name, email, phone number and message) is sent to our Google account so that we can reply. Google’s handling of it is described in the <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">Google Privacy Policy</a>.</li>
      <li><b>Analytics.</b> This website uses Google Analytics to count visits and see which pages and download buttons are used. It sets cookies in your browser for this. Google Analytics does not store IP addresses, and we have turned off its advertising features. We use it only to improve the site. You can block these cookies in your browser settings.</li>
      <li><b>Email and WhatsApp.</b> If you contact us, we keep the conversation so that we can help you and follow up.</li>
    </ul>

    <h2>How we use what you send us</h2>
    <p>Only to answer you, to provide support, to prepare and deliver customization work you asked for, and to improve {NAME}. We do not sell or rent your information.</p>

    <h2>How long we keep it</h2>
    <p>We keep form replies and messages for as long as they are useful for supporting you, and delete them when you ask us to, unless we must keep a record by law (for example, invoices for paid work).</p>

    <h2>Your choices</h2>
    <p>You can ask us what information we hold about you, ask us to correct it, or ask us to delete it, by writing to <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>

    <h2>Children</h2>
    <p>{NAME} and this website are meant for businesses and are not aimed at children.</p>

    <h2>Changes</h2>
    <p>If we change this policy, we will update this page and the date at the top.</p>

    <h2>Contact</h2>
    <p>{BUSINESS}, India · <a href="mailto:{EMAIL}">{EMAIL}</a></p>
  </div>
</section>'''

page('privacy.html', 'Privacy policy',
     f'How {BUSINESS} handles information for the {NAME} app and website. Your business data stays on your computer.',
     'privacy', privacy_body)

# ──────────────────────────────── Terms ────────────────────────────────────
terms_body = f'''<section class="page-head">
  <div class="container">
    <span class="eyebrow">Legal</span>
    <h1>Terms of use</h1>
    <p>Last updated: {RELEASE_DATE}</p>
  </div>
</section>

<section class="section">
  <div class="container prose">
    <p>These terms apply to the {NAME} app and to this website, which are provided by {BUSINESS} (“we”). By downloading or using {NAME}, you agree to them.</p>

    <h2>1. Using {NAME}</h2>
    <p>You may download, install and use {NAME} free of charge, for personal or business use, on as many of your computers as you like. You may share the link to our Download page. You may not sell {NAME}, charge others for copies of it, or present it as your own product.</p>

    <h2>2. Your data and your invoices</h2>
    <p>{NAME} stores your data on your own computer. You are responsible for keeping backups, for the details you enter, and for checking that your invoices, tax rates and returns are correct for your business. {NAME} is a tool to help you prepare invoices; it is not tax or legal advice.</p>

    <h2>3. No warranty</h2>
    <p>{NAME} is provided “as is”, without any warranty. We work to keep it reliable, but we cannot promise that it will be free of errors or suitable for every purpose.</p>

    <h2>4. Limitation of liability</h2>
    <p>To the extent the law allows, we are not liable for any loss of data, profit or business, or for any indirect damage, arising from the use of {NAME} or this website. Where liability cannot be excluded, it is limited to the amount you paid us for the work concerned.</p>

    <h2>5. Paid customization</h2>
    <p>Custom features and changes are a separate, paid service. For each request we agree in writing on what will be delivered, the price, the payment terms and an expected timeline before any work starts. Delivery dates are estimates. Work we deliver for you comes with the same terms as the rest of {NAME} unless we agree otherwise in writing.</p>

    <h2>6. Third-party software</h2>
    <p>{NAME} is built on Invoiso, which is released under the MIT License. The licence text and other notices are on the <a href="licenses.html">Licenses page</a>. Those licences apply to the parts they cover.</p>

    <h2>7. Links to other sites</h2>
    <p>This website and the app link to services we do not run, such as Google Forms, GitHub, WhatsApp and Buy Me a Coffee. Their own terms apply when you use them.</p>

    <h2>8. Changes</h2>
    <p>We may update these terms. The date at the top shows the latest version. Continuing to use {NAME} after a change means you accept the new terms.</p>

    <h2>9. Governing law</h2>
    <p>These terms are governed by the laws of India.</p>

    <h2>10. Contact</h2>
    <p>{BUSINESS}, India · <a href="mailto:{EMAIL}">{EMAIL}</a></p>
  </div>
</section>'''

page('terms.html', 'Terms of use',
     f'Terms for using the free {NAME} app, this website and paid customization from {BUSINESS}.',
     'terms', terms_body)

# ─────────────────────────────── Licenses ──────────────────────────────────
mit = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'LICENSE'), encoding='utf-8').read().strip()
licenses_body = f'''<section class="page-head">
  <div class="container">
    <span class="eyebrow">Legal</span>
    <h1>Licenses</h1>
    <p>{NAME} is based on Invoiso, whose licence is below. The licences of the open-source packages and fonts built into the app are listed in the app under <b>Settings → Software Info</b>.</p>
  </div>
</section>

<section class="section">
  <div class="container prose">
    <h2>Invoiso</h2>
    <p>{NAME} is based on Invoiso by ANOOP P, released under the MIT License:</p>
    <pre>{html.escape(mit)}</pre>

    <h2>Feather icons</h2>
    <p>Icons on this website come from Feather, released under the MIT License, © 2013–2017 Cole Bemis.</p>
  </div>
</section>'''

page('licenses.html', 'Licenses',
     f'Licences for software that {NAME} includes.',
     'licenses', licenses_body)

# ───────────────────────────────── 404 ─────────────────────────────────────
nf_body = f'''<section class="section">
  <div class="container center">
    <div class="err-code">404</div>
    <h1 class="mt-2">This page could not be found</h1>
    <p class="lead">The link may be old, or the page may have moved.</p>
    <div class="hero-actions" style="justify-content:center">
      <a class="btn btn-primary" href="index.html">Go to the home page</a>
      <a class="btn btn-secondary" href="download.html">{icon('download')} Download {NAME}</a>
    </div>
  </div>
</section>'''

page('404.html', 'Page not found', f'This page could not be found on the {NAME} website.', '', nf_body, noindex=True)

print('pages written')

# ───────────────────────── sitemap / robots / llms / manifest ──────────────
pages = ['', 'download.html', 'customization.html', 'faq.html', 'changelog.html', 'contact.html',
         'privacy.html', 'terms.html', 'licenses.html']
with open(os.path.join(OUT, 'sitemap.xml'), 'w') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n')
    for p in pages:
        f.write(f'  <url><loc>{SITE}/{p}</loc><lastmod>{RELEASE_ISO}</lastmod></url>\n')
    f.write('</urlset>\n')

with open(os.path.join(OUT, 'robots.txt'), 'w') as f:
    f.write(f'User-agent: *\nAllow: /\n\nSitemap: {SITE}/sitemap.xml\n')

with open(os.path.join(OUT, 'llms.txt'), 'w') as f:
    f.write(f'''# {NAME}

> {NAME} is free, offline billing and GST invoice software for Windows, macOS and Linux, made by {BUSINESS} (India). It creates invoices, quotations and payment receipts, prints on A4/A5/A6 paper or 58/80 mm thermal printers, and works in English, Tamil, Hindi, Nepali, French, Spanish, Chinese and Tibetan (partly translated). All business data is stored on the user's own computer. The app is free with no subscription; custom features are a paid service quoted per request.

## Pages

- [Home]({SITE}/): what {NAME} does
- [Download]({SITE}/download.html): installers for Windows, macOS and Linux, with install steps
- [Customization]({SITE}/customization.html): paid custom features, quoted per request
- [FAQ]({SITE}/faq.html): price, offline use, data storage, GST, printers, languages
- [Updates]({SITE}/changelog.html): release notes
- [Contact]({SITE}/contact.html): email {EMAIL}

## Key facts

- Price: free, no subscription; paid customization on request
- Platforms: Windows 10/11 (64-bit), macOS 12 or later, Linux (.deb and AppImage)
- Works offline; no online account needed
- GST: GSTIN, HSN/SAC, CGST + SGST or IGST, Tax Invoice / Bill of Supply titles
- Current version: {VERSION} ({RELEASE_DATE})
- Based on Invoiso by ANOOP P (MIT License)
''')

with open(os.path.join(OUT, 'site.webmanifest'), 'w') as f:
    json.dump({
        'name': NAME, 'short_name': NAME, 'start_url': '/', 'display': 'browser',
        'background_color': '#ffffff', 'theme_color': '#ffffff',
        'icons': [
            {'src': '/assets/images/icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
            {'src': '/assets/images/icon-512.png', 'sizes': '512x512', 'type': 'image/png'},
        ],
    }, f, indent=2)
    f.write('\n')
print('extras written')
