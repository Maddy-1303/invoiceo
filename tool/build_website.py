#!/usr/bin/env python3
"""Builds the redesigned Invoiceo website (design system 2, October 2026).

Usage (from the invoiso-main folder):
    python3 tool/build_website.py ../invoiceo-website

Writes plain HTML pages plus sitemap.xml, robots.txt, llms.txt and
site.webmanifest. The stylesheet (assets/css/site.css) and behaviour
(assets/js/site.js) are hand-written in the website folder. Values that can
change without a rebuild (WhatsApp, form links, analytics ID, file sizes) live
in the website's assets/js/config.js, not here."""
import hashlib
import html
import json
import os
import subprocess
import sys

OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '../invoiceo-website')
SITE = 'https://invoiceo.in'
NAME = 'Invoiceo'
BUSINESS = 'Madcreations'
EMAIL = 'madhanprasat2002r@gmail.com'
VERSION = '1.0.6'
RELEASE_DATE = '9 October 2026'
RELEASE_ISO = '2026-10-09'
COFFEE = 'https://buymeacoffee.com/madcreations'
GH = 'https://github.com/Maddy-1303/invoiceo'
# Fixed-name copies the release workflow adds to every release (.github/workflows/build.yml).
DL = GH + '/releases/latest/download/'
FILES = {
    'windows': 'Invoiceo-Setup-Windows.exe',
    'mac': 'Invoiceo-macOS.dmg',
    'linuxDeb': 'Invoiceo-Linux.deb',
    'linuxAppImage': 'Invoiceo-Linux.AppImage',
}
FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">\n'
         '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
         '  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Manrope:wght@400..800&amp;display=swap">')
# The Tamil page adds Noto Sans Tamil; Manrope still draws the Latin letters.
FONTS_TA = FONTS.replace('wght@400..800&amp;', 'wght@400..800&amp;family=Noto+Sans+Tamil:wght@400..800&amp;')
TA_MONTHS = ['ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்', 'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்']
RELEASE_DATE_TA = f'{int(RELEASE_ISO[8:])} {TA_MONTHS[int(RELEASE_ISO[5:7]) - 1]} {RELEASE_ISO[:4]}'
# The home page in each language; they point at each other with hreflang.
HOMES = {'en': 'index.html', 'ta': 'ta.html'}

# Icons: Feather (MIT, © Cole Bemis) and platform marks from Simple Icons (CC0). See licenses.html.
STROKE = {
    'arrow': '<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>',
    'briefcase': '<rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>',
    'calendar': '<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>',
    'chart': '<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>',
    'check': '<polyline points="20 6 9 17 4 12"/>',
    'check-circle': '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>',
    'chevron-down': '<polyline points="6 9 12 15 18 9"/>',
    'chevron-up': '<polyline points="18 15 12 9 6 15"/>',
    'cloud-off': '<path d="M22.61 16.95A5 5 0 0 0 18 10h-1.26a8 8 0 0 0-7.05-6M5 5a8 8 0 0 0 4 15h9a5 5 0 0 0 1.7-.3"/><line x1="1" y1="1" x2="23" y2="23"/>',
    'code': '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
    'coffee': '<path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/>',
    'credit-card': '<rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/>',
    'database': '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>',
    'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>',
    'external-link': '<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/>',
    'file': '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/>',
    'gift': '<polyline points="20 12 20 22 4 22 4 12"/><rect x="2" y="7" width="20" height="5"/><line x1="12" y1="22" x2="12" y2="7"/><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"/><path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"/>',
    'globe': '<circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>',
    'hard-drive': '<line x1="22" y1="12" x2="2" y2="12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><line x1="6" y1="16" x2="6.01" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/>',
    'help': '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
    'laptop': '<rect x="3" y="4" width="18" height="12" rx="2"/><line x1="2" y1="20" x2="22" y2="20"/>',
    'layers': '<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>',
    'layout': '<rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/>',
    'list': '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
    'lock': '<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    'mail': '<path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/>',
    'menu': '<line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/>',
    'message': '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>',
    'monitor': '<rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>',
    'package': '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/>',
    'percent': '<line x1="19" y1="5" x2="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
    'printer': '<polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/>',
    'qr': '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><path d="M14 14h3v3h-3zM20 14v.01M14 20h.01M17 20h4v-3"/>',
    'refresh': '<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>',
    'repeat': '<polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>',
    'share': '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/>',
    'shield': '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
    'shopping-bag': '<path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/>',
    'sliders': '<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/>',
    'smartphone': '<rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/>',
    'terminal': '<polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/>',
    'tool': '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
    'truck': '<rect x="1" y="3" width="15" height="13"/><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/>',
    'user': '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    'users': '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    'wifi-off': '<line x1="1" y1="1" x2="23" y2="23"/><path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/><path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/><path d="M10.71 5.05A16 16 0 0 1 22.58 9"/><path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/>',
    'x': '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
    'zap': '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>',
}
BRAND = {
    'apple': 'M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701',
    'github': 'M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12',
    'linux': 'M12.504 0c-.155 0-.315.008-.48.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489a.424.424 0 00-.11.135c-.26.268-.45.6-.663.839-.199.199-.485.267-.797.4-.313.136-.658.269-.864.68-.09.189-.136.394-.132.602 0 .199.027.4.055.536.058.399.116.728.04.97-.249.68-.28 1.145-.106 1.484.174.334.535.47.94.601.81.2 1.91.135 2.774.6.926.466 1.866.67 2.616.47.526-.116.97-.464 1.208-.946.587-.003 1.23-.269 2.26-.334.699-.058 1.574.267 2.577.2.025.134.063.198.114.333l.003.003c.391.778 1.113 1.132 1.884 1.071.771-.06 1.592-.536 2.257-1.306.631-.765 1.683-1.084 2.378-1.503.348-.199.629-.469.649-.853.023-.4-.2-.811-.714-1.376v-.097l-.003-.003c-.17-.2-.25-.535-.338-.926-.085-.401-.182-.786-.492-1.046h-.003c-.059-.054-.123-.067-.188-.135a.357.357 0 00-.19-.064c.431-1.278.264-2.55-.173-3.694-.533-1.41-1.465-2.638-2.175-3.483-.796-1.005-1.576-1.957-1.56-3.368.026-2.152.236-6.133-3.544-6.139zm.529 3.405h.013c.213 0 .396.062.584.198.19.135.33.332.438.533.105.259.158.459.166.724 0-.02.006-.04.006-.06v.105a.086.086 0 01-.004-.021l-.004-.024a1.807 1.807 0 01-.15.706.953.953 0 01-.213.335.71.71 0 00-.088-.042c-.104-.045-.198-.064-.284-.133a1.312 1.312 0 00-.22-.066c.05-.06.146-.133.183-.198.053-.128.082-.264.088-.402v-.02a1.21 1.21 0 00-.061-.4c-.045-.134-.101-.2-.183-.333-.084-.066-.167-.132-.267-.132h-.016c-.093 0-.176.03-.262.132a.8.8 0 00-.205.334 1.18 1.18 0 00-.09.4v.019c.002.089.008.179.02.267-.193-.067-.438-.135-.607-.202a1.635 1.635 0 01-.018-.2v-.02a1.772 1.772 0 01.15-.768c.082-.22.232-.406.43-.533a.985.985 0 01.594-.2zm-2.962.059h.036c.142 0 .27.048.399.135.146.129.264.288.344.465.09.199.14.4.153.667v.004c.007.134.006.2-.002.266v.08c-.03.007-.056.018-.083.024-.152.055-.274.135-.393.2.012-.09.013-.18.003-.267v-.015c-.012-.133-.04-.2-.082-.333a.613.613 0 00-.166-.267.248.248 0 00-.183-.064h-.021c-.071.006-.13.04-.186.132a.552.552 0 00-.12.27.944.944 0 00-.023.33v.015c.012.135.037.2.08.334.046.134.098.2.166.268.01.009.02.018.034.024-.07.057-.117.07-.176.136a.304.304 0 01-.131.068 2.62 2.62 0 01-.275-.402 1.772 1.772 0 01-.155-.667 1.759 1.759 0 01.08-.668 1.43 1.43 0 01.283-.535c.128-.133.26-.2.418-.2zm1.37 1.706c.332 0 .733.065 1.216.399.293.2.523.269 1.052.468h.003c.255.136.405.266.478.399v-.131a.571.571 0 01.016.47c-.123.31-.516.643-1.063.842v.002c-.268.135-.501.333-.775.465-.276.135-.588.292-1.012.267a1.139 1.139 0 01-.448-.067 3.566 3.566 0 01-.322-.198c-.195-.135-.363-.332-.612-.465v-.005h-.005c-.4-.246-.616-.512-.686-.71-.07-.268-.005-.47.193-.6.224-.135.38-.271.483-.336.104-.074.143-.102.176-.131h.002v-.003c.169-.202.436-.47.839-.601.139-.036.294-.065.466-.065zm2.8 2.142c.358 1.417 1.196 3.475 1.735 4.473.286.534.855 1.659 1.102 3.024.156-.005.33.018.513.064.646-1.671-.546-3.467-1.089-3.966-.22-.2-.232-.335-.123-.335.59.534 1.365 1.572 1.646 2.757.13.535.16 1.104.021 1.67.067.028.135.06.205.067 1.032.534 1.413.938 1.23 1.537v-.043c-.06-.003-.12 0-.18 0h-.016c.151-.467-.182-.825-1.065-1.224-.915-.4-1.646-.336-1.77.465-.008.043-.013.066-.018.135-.068.023-.139.053-.209.064-.43.268-.662.669-.793 1.187-.13.533-.17 1.156-.205 1.869v.003c-.02.334-.17.838-.319 1.35-1.5 1.072-3.58 1.538-5.348.334a2.645 2.645 0 00-.402-.533 1.45 1.45 0 00-.275-.333c.182 0 .338-.03.465-.067a.615.615 0 00.314-.334c.108-.267 0-.697-.345-1.163-.345-.467-.931-.995-1.788-1.521-.63-.4-.986-.87-1.15-1.396-.165-.534-.143-1.085-.015-1.645.245-1.07.873-2.11 1.274-2.763.107-.065.037.135-.408.974-.396.751-1.14 2.497-.122 3.854a8.123 8.123 0 01.647-2.876c.564-1.278 1.743-3.504 1.836-5.268.048.036.217.135.289.202.218.133.38.333.59.465.21.201.477.335.876.335.039.003.075.006.11.006.412 0 .73-.134.997-.268.29-.134.52-.334.74-.4h.005c.467-.135.835-.402 1.044-.7zm2.185 8.958c.037.6.343 1.245.882 1.377.588.134 1.434-.333 1.791-.765l.211-.01c.315-.007.577.01.847.268l.003.003c.208.199.305.53.391.876.085.4.154.78.409 1.066.486.527.645.906.636 1.14l.003-.007v.018l-.003-.012c-.015.262-.185.396-.498.595-.63.401-1.746.712-2.457 1.57-.618.737-1.37 1.14-2.036 1.191-.664.053-1.237-.2-1.574-.898l-.005-.003c-.21-.4-.12-1.025.056-1.69.176-.668.428-1.344.463-1.897.037-.714.076-1.335.195-1.814.12-.465.308-.797.641-.984l.045-.022zm-10.814.049h.01c.053 0 .105.005.157.014.376.055.706.333 1.023.752l.91 1.664.003.003c.243.533.754 1.064 1.189 1.637.434.598.77 1.131.729 1.57v.006c-.057.744-.48 1.148-1.125 1.294-.645.135-1.52.002-2.395-.464-.968-.536-2.118-.469-2.857-.602-.369-.066-.61-.2-.723-.4-.11-.2-.113-.602.123-1.23v-.004l.002-.003c.117-.334.03-.752-.027-1.118-.055-.401-.083-.71.043-.94.16-.334.396-.4.69-.533.294-.135.64-.202.915-.47h.002v-.002c.256-.268.445-.601.668-.838.19-.201.38-.336.663-.336zm7.159-9.074c-.435.201-.945.535-1.488.535-.542 0-.97-.267-1.28-.466-.154-.134-.28-.268-.373-.335-.164-.134-.144-.333-.074-.333.109.016.129.134.199.2.096.066.215.2.36.333.292.2.68.467 1.167.467.485 0 1.053-.267 1.398-.466.195-.135.445-.334.648-.467.156-.136.149-.267.279-.267.128.016.034.134-.147.332a8.097 8.097 0 01-.69.468zm-1.082-1.583V5.64c-.006-.02.013-.042.029-.05.074-.043.18-.027.26.004.063 0 .16.067.15.135-.006.049-.085.066-.135.066-.055 0-.092-.043-.141-.068-.052-.018-.146-.008-.163-.065zm-.551 0c-.02.058-.113.049-.166.066-.047.025-.086.068-.14.068-.05 0-.13-.02-.136-.068-.01-.066.088-.133.15-.133.08-.031.184-.047.259-.005.019.009.036.03.03.05v.02h.003z',
    'windows': 'M3 5.6 10.4 4.6v7.1H3zM11.4 4.4 21 3v8.7h-9.6zM3 12.6h7.4v7.1L3 18.6zM11.4 12.6H21V21l-9.6-1.4z',
}


def asset(path):
    """path?v=<content hash>, so browsers fetch a file again only when it changes."""
    with open(os.path.join(OUT, path), 'rb') as f:
        return f'{path}?v={hashlib.sha1(f.read()).hexdigest()[:10]}'


def esc(s):
    return html.escape(s, quote=True)


def icon(name):
    if name in BRAND:
        return (f'<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" '
                f'focusable="false"><path d="{BRAND[name]}"/></svg>')
    return (f'<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">{STROKE[name]}</svg>')


# ─────────────────────────────── Components ────────────────────────────────
def btn(label, href, kind='primary', size='', ic=None, attrs='', block=False, cls=''):
    classes = ' '.join(c for c in ['btn', f'btn-{kind}', 'btn-lg' if size == 'lg' else '',
                                   'btn-block' if block else '', cls] if c)
    return f'<a class="{classes}" href="{href}"{attrs}>{icon(ic) if ic else ""}<span>{label}</span></a>'


def badge(label, tone='brand', ic=None, cls=''):
    return f'<span class="badge badge-{tone}{(" " + cls) if cls else ""}">{icon(ic) if ic else ""}<span>{label}</span></span>'


def tile(ic, tone='', size=''):
    classes = ' '.join(c for c in ['tile', f'tile-{tone}' if tone else '', f'tile-{size}' if size else ''] if c)
    return f'<span class="{classes}">{icon(ic)}</span>'


def checks(items, cls=''):
    return f'<ul class="checks{(" " + cls) if cls else ""}">' + ''.join(f'<li>{i}</li>' for i in items) + '</ul>'


def section_head(eyebrow, title, lead=None, hid=None, left=False):
    idattr = f' id="{hid}"' if hid else ''
    lead_html = f'<p class="lead">{lead}</p>' if lead else ''
    return (f'<div class="section-head{" left" if left else ""}"><p class="eyebrow">{eyebrow}</p>'
            f'<h2{idattr}>{title}</h2>{lead_html}</div>')


def section(inner, sid=None, cls='', label=None):
    idattr = f' id="{sid}"' if sid else ''
    al = f' aria-labelledby="{label}"' if label else ''
    return f'<section class="section{(" " + cls) if cls else ""}"{idattr}{al}>\n  <div class="wrap">\n{inner}\n  </div>\n</section>'


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
        try:
            subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '82',
                            '--resampleWidth', '1280', png, '--out', jpg], check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError):
            return False
    return os.path.exists(jpg)


def window(name, alt, cls='', lazy=True, sizes='(max-width: 720px) 100vw, (max-width: 1100px) 50vw, 420px'):
    full = f'assets/images/screens/{name}.png'
    small = f'assets/images/screens/{name}-1280.jpg'
    src = small if small_copy(name) else full
    srcset = f' srcset="{small} 1280w, {full} {SHOT_W}w" sizes="{sizes}"' if src != full else ''
    load = ' loading="lazy" decoding="async"' if lazy else ' fetchpriority="high"'
    return (f'<div class="window{(" " + cls) if cls else ""}"><div class="window-bar"><i></i><i></i><i></i><span>{NAME}</span></div>'
            f'<a href="{full}" target="_blank" rel="noopener" title="Open full size">'
            f'<img src="{src}"{srcset} width="{SHOT_W}" height="{SHOT_H}" alt="{esc(alt)}"{load}></a></div>')


RECEIPT = {
    'en': {'rows': [('App licence', '0.00'), ('Monthly plan', 'None'), ('Sign-up', 'Not needed'),
                    ('Internet', 'Not needed'), ('Paid add-ons', 'None')],
           'title': f'What {NAME} costs you', 'total': 'Total', 'foot': 'Free forever · Open source (MIT)'},
    'ta': {'rows': [('ஆப் உரிமம்', '0.00'), ('மாதக் கட்டணம்', 'இல்லை'), ('பதிவு', 'தேவையில்லை'),
                    ('இன்டர்நெட்', 'தேவையில்லை'), ('கூடுதல் கட்டணம்', 'இல்லை')],
           'title': f'{NAME}-க்கு நீங்கள் செலுத்துவது', 'total': 'மொத்தம்', 'foot': 'என்றும் இலவசம் · ஓப்பன் சோர்ஸ் (MIT)'},
}


def receipt(cls='', lang='en'):
    t = RECEIPT[lang]
    zig = ''.join(f'L{x - 6} 12L{x - 12} 4' for x in range(276, 0, -12))
    body = ''.join(f'<div class="receipt-row"><span>{a}</span><b>{b}</b></div>' for a, b in t['rows'])
    return (f'<div class="receipt{(" " + cls) if cls else ""}"><div class="receipt-paper">'
            f'<p class="receipt-title">{t["title"]}</p><hr>{body}<hr>'
            f'<div class="receipt-total"><span>{t["total"]}</span><b>0.00</b></div>'
            f'<p class="receipt-foot">{t["foot"]}</p></div>'
            f'<svg class="receipt-edge" viewBox="0 0 276 12" aria-hidden="true" focusable="false">'
            f'<path d="M0 0H276V4{zig}V0Z" fill="#fff"/></svg></div>')


def faq_item(q, a, open_=False):
    paras = ''.join(f'<p>{p}</p>' for p in (a if isinstance(a, list) else [a]))
    return f'<details class="faq-item"{" open" if open_ else ""}><summary>{q}</summary><div class="answer">{paras}</div></details>'


# ─────────────────────────────── Platforms ─────────────────────────────────
PLATFORMS = [
    {'key': 'windows', 'anchor': 'windows', 'icon': 'windows', 'name': 'Windows',
     'req': 'Windows 10 and 11 · 64-bit', 'short': 'Windows 10 and 11',
     'buttons': [('Download for Windows', FILES['windows'], 'windows')],
     'files': [('windows', FILES['windows'])],
     'note': 'Windows may say <b>“Windows protected your PC”</b>. Click <b>More info</b>, then <b>Run anyway</b>. '
             'The installer isn’t code-signed yet.',
     'steps': ['Open the downloaded file.',
               'If Windows shows <b>“Windows protected your PC”</b>, click <b>More info</b>, then <b>Run anyway</b>. '
               'This appears because the installer is not code-signed yet.',
               f'Follow the setup. {NAME} then opens from the Start menu.']},
    {'key': 'mac', 'anchor': 'macos', 'icon': 'apple', 'name': 'macOS',
     'req': 'macOS 12 Monterey or later', 'short': 'macOS 12 or later',
     'buttons': [('Download for macOS', FILES['mac'], 'mac')],
     'files': [('mac', FILES['mac'])],
     'note': f'Drag {NAME} to Applications. If macOS can’t check the app, open '
             '<b>System Settings → Privacy &amp; Security</b> and click <b>Open Anyway</b>.',
     'steps': [f'Open the .dmg and drag {NAME} into Applications.',
               f'Open {NAME}. If macOS says it cannot verify the app, click <b>Done</b>. '
               'This happens because the app is not notarised by Apple yet.',
               f'Open <b>System Settings → Privacy &amp; Security</b>, scroll down to the message about {NAME} and click '
               f'<b>Open Anyway</b>, then confirm. (On macOS 14 or older you can instead Control-click {NAME} in '
               'Applications and choose <b>Open</b>.)',
               'After that it opens normally.']},
    {'key': 'linux', 'anchor': 'linux', 'icon': 'linux', 'name': 'Linux',
     'req': 'Ubuntu 22.04+, Debian 12+, Mint 21+ and others', 'short': 'Ubuntu, Debian, Mint and more',
     'buttons': [('Download .deb', FILES['linuxDeb'], 'linuxDeb'), ('Download AppImage', FILES['linuxAppImage'], 'linuxAppImage')],
     'files': [('linuxDeb', FILES['linuxDeb']), ('linuxAppImage', FILES['linuxAppImage'])],
     'note': f'Install the .deb with <code>sudo apt install ./{FILES["linuxDeb"]}</code>, or run '
             f'<code>chmod +x {FILES["linuxAppImage"]}</code> and open the AppImage.',
     'steps': [f'<b>.deb</b> (Ubuntu 22.04+, Debian 12+, Linux Mint 21+): run <code>sudo apt install ./{FILES["linuxDeb"]}</code> '
               'in the folder you downloaded it to.',
               f'<b>AppImage</b> (other distributions): run <code>chmod +x {FILES["linuxAppImage"]}</code>, then open the file.']},
]
# The same cards for the Tamil page. Button and menu names stay in English,
# because that is what Windows and macOS show.
PLATFORMS_TA = [
    {**PLATFORMS[0], 'req': 'Windows 10, 11 · 64-bit', 'short': 'Windows 10, 11',
     'buttons': [('Windows-க்கு டவுன்லோட்', FILES['windows'], 'windows')],
     'steps': ['டவுன்லோட் ஆன ஃபைலைத் திறக்கவும்.',
               '<b>“Windows protected your PC”</b> என்று வந்தால், <b>More info</b> அழுத்தி, பிறகு <b>Run anyway</b> அழுத்தவும். '
               'இன்ஸ்டாலர் இன்னும் code-sign செய்யப்படாததால் இந்தச் செய்தி வருகிறது.',
               f'Setup-ஐ முடிக்கவும். பிறகு Start மெனுவில் {NAME} இருக்கும்.']},
    {**PLATFORMS[1], 'req': 'macOS 12 Monterey அல்லது அதற்குப் பிந்தையது', 'short': 'macOS 12 அல்லது பிந்தையது',
     'buttons': [('macOS-க்கு டவுன்லோட்', FILES['mac'], 'mac')],
     'steps': [f'.dmg ஃபைலைத் திறந்து {NAME}-ஐ Applications-க்குள் இழுத்து விடவும்.',
               f'{NAME}-ஐத் திறக்கவும். ஆப்பைச் சரிபார்க்க முடியவில்லை என்று macOS சொன்னால் <b>Done</b> அழுத்தவும். '
               'ஆப் இன்னும் Apple-ஆல் notarise செய்யப்படாததால் இது வருகிறது.',
               f'<b>System Settings → Privacy &amp; Security</b> திறந்து, கீழே {NAME} பற்றிய செய்தியில் <b>Open Anyway</b> '
               f'அழுத்தி உறுதிசெய்யவும். (macOS 14 அல்லது பழையதில், Applications-ல் {NAME} மேல் Control-click செய்து '
               '<b>Open</b> தேர்ந்தெடுக்கலாம்.)',
               'அதன் பிறகு வழக்கம்போல் திறக்கும்.']},
    {**PLATFORMS[2], 'req': 'Ubuntu 22.04+, Debian 12+, Mint 21+ மற்றும் பிற', 'short': 'Ubuntu, Debian, Mint மற்றும் பிற',
     'buttons': [('.deb டவுன்லோட்', FILES['linuxDeb'], 'linuxDeb'), ('AppImage டவுன்லோட்', FILES['linuxAppImage'], 'linuxAppImage')],
     'steps': [f'<b>.deb</b> (Ubuntu 22.04+, Debian 12+, Linux Mint 21+): டவுன்லோட் ஆன ஃபோல்டரில் '
               f'<code>sudo apt install ./{FILES["linuxDeb"]}</code> இயக்கவும்.',
               f'<b>AppImage</b> (மற்ற Linux): <code>chmod +x {FILES["linuxAppImage"]}</code> இயக்கி, பிறகு ஃபைலைத் திறக்கவும்.']},
]
REC_LABEL = {'en': 'Recommended for you', 'ta': 'உங்கள் கணினிக்கு'}


def dl_card(p, full=False, heading='h3', lang='en'):
    buttons = []
    for i, (label, file, _) in enumerate(p['buttons']):
        if i == 0:
            buttons.append(btn(label, DL + file, 'secondary', 'lg', 'download', block=True, cls='dl-main',
                               attrs=' data-primary-download'))
        else:
            buttons.append(btn(label, DL + file, 'ghost', '', 'download', block=True))
    files = '<br>'.join(f'{f}<span data-size="{k}"></span>' for k, f in p['files'])
    if full:
        note = '<ol>' + ''.join(f'<li>{s}</li>' for s in p['steps']) + '</ol>'
    else:
        note = f'<p>{p["note"]}</p>'
    rec = ' is-recommended' if p['key'] == 'windows' else ''
    return (f'<div class="dl-card{rec}" data-platform="{p["key"]}" data-req-short="{p["short"]}"'
            f'{(" id=" + chr(34) + p["anchor"] + chr(34)) if full else ""}>'
            f'<div class="dl-card-top">{tile(p["icon"], "neutral")}{badge(REC_LABEL[lang], "brand", cls="rec-badge")}</div>'
            f'<div><{heading}>{p["name"]}</{heading}><p class="dl-req">{p["req"]}</p></div>'
            f'<div class="dl-buttons">{"".join(buttons)}</div>'
            f'<p class="dl-file">{files}</p>'
            f'<div class="dl-note">{note}</div></div>')


def dl_grid(full=False, lang='en'):
    cards = PLATFORMS_TA if lang == 'ta' else PLATFORMS
    return '<div class="dl-grid">' + ''.join(dl_card(p, full, lang=lang) for p in cards) + '</div>'


PHONE_NOTE = (f'<div class="notice hidden" data-mobile-note>{icon("smartphone")}<span>You’re on a phone. {NAME} runs on '
              f'Windows, macOS and Linux computers. Open <b>invoiceo.in</b> on your computer to download it.</span></div>')
TRUST = ('<div class="dl-trust">' + ''.join(badge(t, 'teal', 'check') for t in
                                           ['Free forever', 'No credit card', 'No subscription', 'Open source']) + '</div>')
CHECKSUMS = (f'<p class="center small muted">Check your download with the <a href="{DL}SHA256SUMS.txt">SHA-256 checksums</a>'
             '</p>')
FIRST_STEPS = [
    ('download', 'Download', 'Pick your computer above.'),
    ('package', 'Install', 'Open the file and follow the steps.'),
    ('user', 'Sign in and set up', 'The first screen shows how to sign in. Then add your business details.'),
    ('file', 'First invoice', 'Add a customer and items, then create the invoice.'),
    ('printer', 'Print or PDF', 'Print on A4 or a thermal printer, or save a PDF.'),
]


def first_steps(level='h3', steps=FIRST_STEPS, word='Step'):
    lis = ''.join(f'<li><span class="step-label">{tile(ic, "", "sm")}{word} {i + 1}</span><{level} class="h4">{t}</{level}><p>{b}</p></li>'
                  for i, (ic, t, b) in enumerate(steps))
    return f'<ol class="steps-row">{lis}</ol>'


# ─────────────────────────────── Page frame ────────────────────────────────
def header(active, home=False, base=False, lang='en'):
    pre = '' if home else 'index.html'
    if lang == 'ta':
        links = [('வசதிகள்', '#features', 'features'), ('செயல்முறை', '#how-it-works', 'how'),
                 ('கேள்விகள்', '#faq', 'faq'), ('தொடர்பு', 'contact.html', 'contact')]
        more = [('ஸ்கிரீன்ஷாட்கள்', '#screenshots', 'screenshots'), ('புதியவை (English)', 'changelog.html', 'changelog')]
        words = {'dl': 'இலவச டவுன்லோட்', 'skip': 'உள்ளடக்கத்துக்குச் செல்ல', 'home': f'{NAME} முகப்பு',
                 'main': 'முதன்மை', 'menu': 'மெனு', 'main_menu': 'முதன்மை மெனு'}
        switch = '<a class="lang-switch" href="index.html" hreflang="en" lang="en">English</a>'
    else:
        links = [('Features', f'{pre}#features', 'features'), ('How it works', f'{pre}#how-it-works', 'how'),
                 ('FAQ', 'faq.html', 'faq'), ('Contact', 'contact.html', 'contact')]
        more = [('Screenshots', f'{pre}#screenshots', 'screenshots'), ('What’s new', 'changelog.html', 'changelog')]
        words = {'dl': 'Download free', 'skip': 'Skip to content', 'home': f'{NAME} home',
                 'main': 'Main', 'menu': 'Menu', 'main_menu': 'Main menu'}
        switch = '<a class="lang-switch" href="ta.html" hreflang="ta" lang="ta" title="தமிழில் படிக்க">தமிழ்</a>'
    cur = lambda key: ' aria-current="page"' if key == active else ''
    nav = ''.join(f'<a href="{h}"{cur(k)}>{t}</a>' for t, h, k in links)
    mobile = ''.join(f'<a href="{h}"{cur(k)}>{t}</a>' for t, h, k in links + more)
    dl_href = '#download' if home else 'download.html'
    # The 404 page has <base href="/">, where "#main" would mean the home page.
    skip = '' if base else f'<a class="skip-link" href="#main">{words["skip"]}</a>\n'
    return f'''{skip}<header class="site-header">
  <div class="wrap">
    <a class="brand" href="{HOMES[lang]}" aria-label="{words['home']}"><img src="assets/images/logo.png" alt="{NAME}" width="196" height="68"></a>
    <nav class="nav" aria-label="{words['main']}">{nav}</nav>
    <div class="header-actions">
      {switch}
      {btn(words['dl'], dl_href, 'primary', '', 'download', cls='header-cta', attrs=' aria-current="page"' if active == 'download' else '')}
      <button class="menu-toggle" type="button" aria-controls="site-nav" aria-expanded="false" aria-label="{words['menu']}">{icon('menu')}</button>
    </div>
    <nav class="mobile-nav" id="site-nav" aria-label="{words['main_menu']}">{mobile}{btn(words['dl'], dl_href, 'primary', 'lg', 'download', block=True)}</nav>
  </div>
</header>'''


def footer(home=False, lang='en'):
    pre = '' if home else 'index.html'
    col = lambda title, items: (f'<div><h2>{title}</h2><ul>' + ''.join(f'<li{" data-block" if "data-" in a else ""}><a {a}>{t}</a></li>' for t, a in items)
                                + '</ul></div>')
    support = 'data-href="forms.support" data-hide-empty target="_blank" rel="noopener"'
    whatsapp = 'data-whatsapp target="_blank" rel="noopener"'
    feedback = 'data-href="forms.feedback" data-hide-empty target="_blank" rel="noopener"'
    if lang == 'ta':
        cols = [('ஆப்', [('வசதிகள்', 'href="#features"'), ('செயல்முறை', 'href="#how-it-works"'),
                         ('ஸ்கிரீன்ஷாட்கள்', 'href="#screenshots"'), ('டவுன்லோட்', 'href="#download"'),
                         ('புதியவை (English)', 'href="changelog.html"')]),
                ('உதவி', [('கேள்விகள் (English)', 'href="faq.html"'), ('தொடர்பு', 'href="contact.html"'),
                          ('உதவி கோரிக்கை', support), ('WhatsApp', whatsapp), ('கருத்து', feedback),
                          ('தனிப்பயன் வசதிகள் (கட்டணம்)', 'href="customization.html"')]),
                ('சட்டம்', [('உரிமங்கள்', 'href="licenses.html"'), ('தனியுரிமை', 'href="privacy.html"'),
                            ('விதிமுறைகள்', 'href="terms.html"')])]
        tagline = 'Windows, macOS, Linux கணினிகளுக்கான இலவச, ஓப்பன் சோர்ஸ் பில்லிங் சாஃப்ட்வேர்.'
        coffee = 'ஒரு காபி வாங்கித் தாருங்கள்'
        credit = (f'© <span data-year>2026</span> {BUSINESS}. Invoiso-வை அடிப்படையாகக் கொண்டது, '
                  '<a href="licenses.html">MIT License</a>, © 2025 ANOOP P.')
    else:
        cols = [('Product', [('Features', f'href="{pre}#features"'), ('How it works', f'href="{pre}#how-it-works"'),
                             ('Screenshots', f'href="{pre}#screenshots"'), ('Download', 'href="download.html"'),
                             ('What’s new', 'href="changelog.html"')]),
                ('Help', [('FAQ', 'href="faq.html"'), ('Contact', 'href="contact.html"'), ('Support request', support),
                          ('WhatsApp', whatsapp), ('Feedback', feedback), ('Custom features (paid)', 'href="customization.html"')]),
                ('Legal', [('Licenses', 'href="licenses.html"'), ('Privacy', 'href="privacy.html"'), ('Terms', 'href="terms.html"')])]
        tagline = 'Free, open-source billing software for Windows, macOS and Linux.'
        coffee = 'Buy me a coffee'
        credit = (f'© <span data-year>2026</span> {BUSINESS}. Built on Invoiso, released under the '
                  '<a href="licenses.html">MIT License</a>, © 2025 ANOOP P.')
    return f'''<footer class="site-footer">
  <div class="wrap">
    <div class="foot">
      <div class="foot-brand">
        <img src="assets/images/logo.png" alt="{NAME}" width="196" height="68" loading="lazy">
        <p>{tagline}</p>
        <a class="coffee" href="{COFFEE}" target="_blank" rel="noopener">{icon('coffee')}{coffee}</a>
      </div>
      {(chr(10) + '      ').join(col(t, items) for t, items in cols)}
    </div>
    <div class="foot-bottom">
      <span>{credit}</span>
      <a href="mailto:{EMAIL}">{EMAIL}</a>
    </div>
  </div>
</footer>'''


def page(filename, title, description, active, body, jsonld=None, noindex=False, lang='en'):
    home = filename in HOMES.values()
    canonical = SITE + '/' + ('' if filename == 'index.html' else filename)
    ld = ''
    if jsonld:
        ld = '\n  <script type="application/ld+json">\n' + json.dumps(jsonld, ensure_ascii=False, indent=2) + '\n  </script>'
    full_title = title if home else f'{title} — {NAME}'
    # The two home pages name each other, so Google shows Tamil searchers the Tamil one.
    alternates = ''
    if home:
        alternates = ''.join(f'\n  <link rel="alternate" hreflang="{code}" href="{SITE}/{"" if f == "index.html" else f}">'
                             for code, f in HOMES.items())
        alternates += f'\n  <link rel="alternate" hreflang="x-default" href="{SITE}/">'
    doc = f'''<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">{chr(10) + '  <base href="/">' if noindex else ''}
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="theme-color" content="#ffffff">
  <title>{esc(full_title)}</title>
  <meta name="description" content="{esc(description)}">
  {'<meta name="robots" content="noindex">' if noindex else f'<link rel="canonical" href="{canonical}">'}{alternates}
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="{NAME}">
  <meta property="og:locale" content="{'ta_IN' if lang == 'ta' else 'en_IN'}">
  <meta property="og:title" content="{esc(full_title)}">
  <meta property="og:description" content="{esc(description)}">
  <meta property="og:url" content="{canonical}">
  <meta property="og:image" content="{SITE}/assets/images/og-image.png">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="icon" href="favicon.ico" sizes="any">
  <link rel="icon" type="image/png" sizes="32x32" href="assets/images/favicon-32.png">
  <link rel="apple-touch-icon" href="assets/images/apple-touch-icon.png">
  <link rel="manifest" href="site.webmanifest">
  {FONTS_TA if lang == 'ta' else FONTS}
  <link rel="stylesheet" href="{asset('assets/css/site.css')}">{ld}
</head>
<body>
{header(active, home=home, base=noindex, lang=lang)}
<main id="main">
{body}
</main>
{footer(home=home, lang=lang)}
<script src="{asset('assets/js/config.js')}"></script>
<script src="{asset('assets/js/site.js')}"></script>
</body>
</html>
'''
    with open(os.path.join(OUT, filename), 'w', encoding='utf-8') as f:
        f.write(doc)


def page_head(eyebrow, title, lead=None, extra=''):
    lead_html = f'<p class="lead">{lead}</p>' if lead else ''
    return (f'<section class="page-head">\n  <div class="wrap">\n    <p class="eyebrow">{eyebrow}</p>\n    <h1>{title}</h1>\n'
            f'    {lead_html}{extra}\n  </div>\n</section>')


ORG = {'@type': 'Organization', 'name': BUSINESS, 'email': EMAIL, 'url': SITE + '/'}

# ─────────────────────────────────── Home ──────────────────────────────────
hero = f'''<section class="hero" aria-labelledby="hero-title">
  <div class="wrap hero-grid">
    <div class="hero-copy">
      <div class="badges">{badge('Free &amp; open source', 'brand', 'code')}{badge('Windows · macOS · Linux', 'neutral', 'monitor')}</div>
      <h1 class="display" id="hero-title"><em>Free</em> billing software that works offline</h1>
      <p class="lead">Create GST invoices, quotations and receipts on your own computer. {NAME} is a free, open-source desktop app — no subscription, no sign-up, and your business data never leaves your PC.</p>
      <div class="cta-row">
        <a class="btn btn-primary btn-lg" href="#download" data-os-download><span data-os-icon>{icon('download')}</span><span data-os-label>Download free</span></a>
        {btn('See the features', '#features', 'secondary', 'lg')}
      </div>
      <p class="hero-meta" data-hero-meta>Free · Version <span data-version>{VERSION}</span> · For Windows, macOS and Linux</p>
      {checks(['Free forever', 'Open source', 'Works offline', 'No sign-up'], 'checks-inline')}
    </div>
    <div class="hero-visual">
      {window('create-invoice', f'The {NAME} New Invoice screen: customer Kannan, four grocery items, GST and a total of Rs. 5,829.50', cls='hero-shot', lazy=False, sizes='(max-width: 1100px) 100vw, 700px')}
      {receipt('hero-receipt')}
      <span class="hero-chip">{badge('Data stays on your computer', 'teal', 'lock')}</span>
    </div>
  </div>
</section>'''

FACTS = [('percent', 'GST &amp; UPI QR', 'CGST, SGST, IGST, HSN/SAC'), ('printer', 'A4 &amp; thermal', 'A4, A5, A6 and 58/80 mm'),
         ('globe', '8 languages', 'including Tamil and Hindi'), ('database', 'Backup &amp; restore', 'move to a new PC any time'),
         ('code', 'MIT License', 'open-source licence')]
facts = ('<div class="facts-strip"><ul class="wrap facts">'
         + ''.join(f'<li class="fact">{tile(i, "teal", "md")}<div><b>{v}</b><span>{l}</span></div></li>' for i, v, l in FACTS)
         + '</ul></div>')

WHY = [('gift', 'Free forever', 'No subscription, no trial, no paid tier. Every feature is included, for as long as you use it.'),
       ('wifi-off', 'Works offline', 'Bill, print and run reports with no internet connection. Internet down? Keep billing.'),
       ('lock', 'Your data stays with you', 'Customers, products and invoices are saved on your computer, not on someone else’s server.'),
       ('code', 'Open source', 'The source code is public under the MIT License. Anyone can check what the app does.'),
       ('monitor', 'Windows, macOS and Linux', 'One app for the computers you already have, with the same features on each.'),
       ('repeat', 'No lock-in', 'Back up any time, restore on another computer, and export your lists to CSV or PDF.')]
why = section(section_head(f'Why {NAME}', 'Billing software without the monthly bill',
                           'Everything a small business needs to bill customers is included — and it all runs on your own computer.', 'why-title')
              + '<div class="grid-auto mt-4">' + ''.join(f'<div class="card">{tile(i)}<h3>{t}</h3><p>{d}</p></div>' for i, t, d in WHY) + '</div>',
              'why', 'section-flush', 'why-title')

HOW = [('01', 'Set up your business', 'Add your company name, logo, GSTIN, bank details and UPI ID once.'),
       ('02', 'Add customers and products', 'Import a list from CSV, or add them as you bill. Barcode scanners work too.'),
       ('03', 'Create an invoice', 'Pick the customer and search or scan items. Tax and totals are worked out for you.'),
       ('04', 'Print, save or share', 'Print on A4 or a thermal printer, or save a PDF to send to your customer.'),
       ('05', 'Track payments', 'Record full or part payments, print receipts and see who still owes you.')]
how = section('<div class="flow"><div class="flow-copy">'
              + section_head('How it works', 'From setup to payment in five steps',
                             'Invoiceo follows the way a shop already bills — just faster and tidier.', 'how-title', left=True)
              + '<ol class="steps">' + ''.join(f'<li class="step"><span class="step-num">{n}</span><div><h3>{t}</h3><p>{b}</p></div></li>' for n, t, b in HOW) + '</ol></div>'
              + '<div>' + window('invoices', f'The {NAME} Invoices list: paid, unpaid and partly paid invoices with the amount still outstanding',
                                 sizes='(max-width: 1100px) 100vw, 700px') + '</div></div>',
              'how-it-works', 'section-subtle', 'how-title')

GROUPS = [
    ('file', 'Invoicing', ['Six invoice designs plus a thermal receipt layout', 'Print or save PDF on A4, A5, A6 or 58/80 mm',
                           'Automatic invoice numbering with your prefix', 'Discounts, taxes and extra charges',
                           'Your own custom fields on invoices', 'Save unfinished invoices as drafts'], 'span-2'),
    ('briefcase', 'Running the business', ['Quotations that become invoices in one click', 'Full and part payments, with receipts',
                                           'Customers with outstanding balances', 'Products and services, stock, batch and expiry',
                                           'Sales, tax, receivables, daily and stock reports', 'Import and export lists as CSV'], 'span-2'),
    ('percent', 'India &amp; GST', ['Your GSTIN and your customer’s on every invoice', 'HSN/SAC codes per product',
                                    'CGST + SGST or IGST worked out for you', 'Tax Invoice or Bill of Supply titles',
                                    'Your UPI QR code printed on the bill'], 'span-2'),
    ('hard-drive', 'Local-first and private', ['Works with no internet connection', 'Data saved on your own computer',
                                               'Backup and restore in one click', 'Several companies on one computer',
                                               'Staff logins with admin or user roles', 'No online account needed'], 'span-3'),
    ('globe', 'Ready for anywhere', ['Choose your currency', 'English, Tamil, Hindi, Nepali, French, Spanish, Chinese and Tibetan (partly translated)',
                                     'Tamil text prints correctly on PDFs and receipts', 'USB barcode scanners',
                                     'Thermal receipts can print automatically after each sale'], 'span-3'),
]
features = section(section_head('Features', 'All the billing tools a small shop needs', 'Grouped the way you work — and every one of them is free.', 'feat-title')
                   + '<div class="bento mt-4">' + ''.join(f'<div class="group-card {c}"><div class="group-card-head">{tile(i)}<h3>{t}</h3></div>{checks(items)}</div>'
                                                          for i, t, items, c in GROUPS) + '</div>',
                   'features', '', 'feat-title')

SHOTS = [('dashboard', 'Dashboard', 'Money collected and still due, sales by month, invoice status and recent invoices.'),
         ('create-invoice', 'New invoice', 'Customer, items, GST and the total on one screen.'),
         ('invoices', 'Invoices', 'See what’s paid, unpaid or part paid, and find any bill fast.'),
         ('customers', 'Customers', 'Phone, GSTIN and what each customer still owes.'),
         ('products', 'Products', 'Prices, HSN codes, tax and stock levels, with low stock easy to spot.'),
         ('reports', 'Reports', 'Billed, collected and outstanding money month by month.')]
# Sample documents printed by the real PDF code. Made with
#   flutter test tool/screenshots/sample_documents_test.dart
#   swift tool/screenshots/pdf_to_png.swift build/sample_documents/invoice-a4.pdf ../invoiceo-website/assets/images/docs/invoice-a4.png 1240
#   swift tool/screenshots/pdf_to_png.swift build/sample_documents/receipt-80mm.pdf ../invoiceo-website/assets/images/docs/receipt-80mm.png 640
DOCS = os.path.join(OUT, 'assets', 'images', 'docs')
DOC_SHOTS = [
    ('invoice-a4', 'paper-a4', 'Printed invoice (A4)', 'A GST invoice in the Classic design, as your customer receives it.',
     f'A sample {NAME} A4 GST invoice: Sri Murugan Traders billing Kannan Stores for six items with CGST and SGST, total Rs. 7019.10'),
    ('receipt-80mm', 'paper-receipt', 'Thermal receipt (80 mm)', 'A counter receipt with Tamil item names, printed correctly.',
     'A sample 80 mm thermal receipt with three Tamil item names, paid in full, total Rs. 1036.60'),
]


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def paper(name, cls, alt):
    src = f'assets/images/docs/{name}.png'
    w, h = png_size(os.path.join(OUT, src))
    return (f'<div class="paper {cls}"><a href="{src}" target="_blank" rel="noopener" title="Open full size">'
            f'<img src="{src}" width="{w}" height="{h}" alt="{esc(alt)}" loading="lazy" decoding="async"></a></div>')


screen_cards = [(n, t, c) for n, t, c in SHOTS if os.path.exists(os.path.join(SCREENS, n + '.png'))]
doc_cards = [d for d in DOC_SHOTS if os.path.exists(os.path.join(DOCS, d[0] + '.png'))]
shots = section(section_head('Screenshots', 'See every screen before you install',
                             f'Real screens from {NAME} and documents it printed, filled with a sample shop’s data.', 'shots-title')
                + '<div class="shots mt-4">'
                + ''.join(f'<figure class="shot{" shot-wide" if i == 0 and doc_cards else ""}">{window(n, f"The {NAME} {t} screen")}'
                          f'<figcaption><b>{t}</b><span>{c}</span></figcaption></figure>' for i, (n, t, c) in enumerate(screen_cards))
                + ''.join(f'<figure class="shot">{paper(n, cls, alt)}<figcaption><b>{t}</b><span>{c}</span></figcaption></figure>'
                          for n, cls, t, c, alt in doc_cards)
                + '</div>',
                'screenshots', 'section-subtle', 'shots-title')

WHO = [('shopping-bag', 'Kirana and retail shops', 'Fast counter billing with barcode scanning and thermal receipts.'),
       ('package', 'Pharmacies and medical shops', 'Batch numbers and expiry dates on products, with low-stock warnings.'),
       ('truck', 'Traders and wholesalers', 'GST invoices with HSN codes, stock levels and customer balances.'),
       ('user', 'Freelancers and consultants', 'Clean PDF quotations and invoices, and a clear view of who has paid.'),
       ('tool', 'Service and repair shops', 'Quick bills for parts and labour, part payments and receipts.'),
       ('briefcase', 'Any small business', 'Several companies and staff logins on one computer — all free.')]
who = section(section_head('Who it’s for', 'Built for the way small businesses work', hid='who-title')
              + '<div class="grid-auto-wide mt-4">' + ''.join(f'<div class="usecase">{tile(i, "neutral")}<div><h3>{t}</h3><p>{d}</p></div></div>' for i, t, d in WHO) + '</div>',
              'who', '', 'who-title')

LANGS = [('English', ''), ('தமிழ்', 'ta'), ('हिन्दी', 'hi'), ('Nepali', ''), ('French', ''), ('Spanish', ''), ('Chinese', ''), ('Tibetan', '')]
langs = ''.join(f'<span class="chip"{(" lang=" + chr(34) + l + chr(34)) if l else ""}>{t}</span>' for t, l in LANGS)
INDIA = ['GSTIN, HSN/SAC and CGST + SGST or IGST', 'UPI QR code on your invoices', 'Amounts in rupees by default', 'Tamil and Hindi on screen and on paper']
WORLD = ['Pick the currency you bill in', 'Eight app languages (Tibetan partly translated)', 'A4, A5, A6 and 58/80 mm paper',
         'GST fields stay out of the way when you don’t need them']
local_global = section(section_head('Local and global', 'Built for local businesses. Ready for the world.',
                                    f'{NAME} is made in India for Indian billing rules, and works just as well anywhere else.', 'lg-title')
                       + '<div class="split split-stretch mt-4">'
                       + f'<div class="group-card is-subtle"><div class="group-card-head">{tile("percent")}<h3>Made for India</h3></div>{checks(INDIA)}</div>'
                       + f'<div class="group-card is-subtle"><div class="group-card-head">{tile("globe")}<h3>Works anywhere</h3></div>{checks(WORLD)}'
                       + f'<div class="stack" style="gap:10px"><p class="chips-label">App languages</p><div class="chips">{langs}</div></div></div>'
                       + '</div>', 'local-global', '', 'lg-title')

privacy = f'''<section class="section section-night on-dark" id="privacy" aria-labelledby="priv-title">
  <div class="wrap split">
    <div>
      {section_head('Privacy', 'Your business data belongs to you.', f'{NAME} keeps your business data on your computer. Nothing about your customers, prices or sales is sent to us or anyone else.', 'priv-title', left=True)}
      {checks(['Works without internet', 'Saved on your computer', 'No account, no subscription', 'Backups when you choose'], 'checks-grid mt-3')}
      <p class="mt-3 small"><a href="privacy.html" style="color: var(--night-accent)">Read the privacy policy</a></p>
    </div>
    <div class="vault">
      <div class="vault-head">{tile('monitor', 'night')}<div><b>Your computer</b><span>Everything {NAME} stores lives here</span></div></div>
      <ul class="vault-items">{''.join(f'<li>{icon(i)}{t}</li>' for i, t in [('file', 'Invoices'), ('users', 'Customers'), ('package', 'Products'), ('database', 'Backups')])}</ul>
      <hr>
      <p class="vault-foot">{icon('cloud-off')}<span><b>Your business data is never uploaded.</b> There is no {NAME} cloud and no account to sign in to.</span></p>
    </div>
  </div>
</section>'''

open_source = section(
    '<div class="split"><div>'
    + section_head('Open source', 'Built in the open', f'{NAME}’s source code is public under the MIT License. You don’t have to take our word for anything.', 'os-title', left=True)
    + checks(['Read exactly how the app handles your data', 'Free to use, copy and change under the MIT License', 'Use it free, on as many computers as you like'], 'mt-3')
    + '</div><div class="stack">'
    + f'<div class="repo-card"><div class="group-card-head">{tile("code")}<h3 class="h4">MIT License</h3></div>'
    + f'<p>{NAME} is built on Invoiso by ANOOP P, which is also released under the MIT License. '
      'Read the licence text on the <a href="licenses.html">Licenses page</a>.</p>'
    + f'<div class="badges">{badge("Open source", "neutral", "code")}{badge("Latest release <span data-version>" + VERSION + "</span>", "neutral", "download")}</div></div>'
    + f'<div class="card card-note"><h3 class="h4">How can it be free?</h3><p>{NAME} is made by {BUSINESS} and built on Invoiso, an MIT-licensed project. '
      'There is no paid version. Development is supported by optional <a href="customization.html">paid customization</a> for businesses that need '
      f'something special, and by <a href="{COFFEE}" target="_blank" rel="noopener">donations</a>.</p></div>'
    + '</div></div>', 'open-source', '', 'os-title')

download = section(
    section_head('Download', 'Start billing for free',
                 f'{NAME} <span data-version>{VERSION}</span> · released <span data-release-date>{RELEASE_DATE}</span> · <a href="changelog.html">What’s new</a>', 'dl-title')
    + f'<div class="mt-2">{TRUST}</div><div class="mt-2">{PHONE_NOTE}</div>'
    + f'<div class="mt-3">{dl_grid()}</div>'
    + f'<div class="mt-2">{CHECKSUMS}</div>'
    + f'<p class="center small mt-1"><a href="download.html">Step-by-step install help</a></p>'
    + '<h3 class="h3 center" style="margin: 72px 0 20px">Up and running in minutes</h3>'
    + first_steps('h4'),
    'download', 'section-subtle', 'dl-title')

HOME_FAQ = [
    ('Is Invoiceo really free?', 'Yes. Every feature is free, with no trial, subscription or paid tier. Install it on as many computers as you like.', True),
    ('Is Invoiceo open source?', 'Yes. It is released under the MIT License, so anyone can read, use and change the code.', True),
    ('Does it work offline?', 'Yes. You only need the internet to download it. Billing, printing and reports all work offline.', True),
    ('Do I need an account?', 'No online account. The app has its own login on your computer, so each person can have a password.', True),
    ('Where is my data stored?', 'On your computer, in Invoiceo’s data folder. Use <b>Settings → Backup</b> to keep a copy somewhere safe.', False),
    ('Does it support GST and UPI?', 'Yes — GSTIN, HSN/SAC, CGST + SGST or IGST, and your UPI QR code on invoices.', False),
    ('Which computers does it run on?', 'Windows 10 and 11 (64-bit), macOS 12 or later, and Linux (.deb or AppImage).', False),
    ('Can I move to a new computer?', 'Yes. Make a backup, install Invoiceo on the new computer and restore the backup there.', False),
    ('Can I use it outside India?', 'Yes. Choose your currency and language; GST fields can be turned off when you don’t need them.', False),
    ('Is it right for a small shop?', 'Yes — barcode scanning, thermal receipts, stock tracking and daily sales reports are built in.', False),
    ('How can it be free?', 'There’s no paid version. Optional <a href="customization.html">paid customization</a> and donations support development.', False),
    ('Why does Windows warn me when installing?', 'The installer isn’t code-signed yet. Click <b>More info</b>, then <b>Run anyway</b>.', False),
]
home_faq = section(
    section_head('FAQ', 'Questions people ask before downloading', hid='faq-title')
    + '<div class="faq-grid mt-4">' + ''.join('<div class="faq-col">' + ''.join(faq_item(q, a, o) for q, a, o in col) + '</div>'
                                             for col in (HOME_FAQ[0::2], HOME_FAQ[1::2])) + '</div>'
    + '<p class="center mt-3">Still unsure? <span data-block><a data-whatsapp target="_blank" rel="noopener">Ask us on WhatsApp</a>, </span>'
      '<a href="faq.html">read all the answers</a> or <a href="contact.html">contact us</a>.</p>',
    'faq', '', 'faq-title')

final_cta = f'''<section class="cta-section" aria-labelledby="cta-title">
  <div class="wrap">
    <div class="cta-band">
      <h2 id="cta-title">Simple billing. No monthly bill.</h2>
      <p class="lead">Download {NAME} and create your first invoice today.</p>
      <div class="cta-row">
        {btn(f'Download {NAME} — free forever', '#download', 'inverse', 'lg', 'download')}
        {btn('Contact us', 'contact.html', 'on-dark', 'lg', 'message')}
      </div>
    </div>
  </div>
</section>'''

page('index.html', f'{NAME} — Free offline billing and GST invoice software',
     f'{NAME} is free, open-source billing software for Windows, macOS and Linux. Make GST invoices, quotations and receipts offline, '
     'print on A4 or thermal printers, in English, Tamil and more.',
     'home', '\n\n'.join([hero, facts, why, how, features, shots, who, local_global, privacy, open_source, download, home_faq, final_cta]),
     jsonld={
         '@context': 'https://schema.org',
         '@type': 'SoftwareApplication',
         'name': NAME,
         'applicationCategory': 'BusinessApplication',
         'operatingSystem': 'Windows, macOS, Linux',
         'softwareVersion': VERSION,
         'datePublished': RELEASE_ISO,
         'description': 'Free, open-source offline billing and GST invoice software for small businesses.',
         'url': SITE + '/',
         'license': 'https://opensource.org/licenses/MIT',
         'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'INR'},
         'publisher': ORG,
     })

# ─────────────────────────────── Tamil home ────────────────────────────────
# ta.html: the home page in Tamil, for shops that search in Tamil. Same facts
# as the English page, no more. Screen names follow the app's Tamil labels
# (lib/l10n/app_ta.arb); the screenshots show the app in Tamil when the
# *-ta.png files exist (screenshot tool with --dart-define=SHOT_LOCALE=ta).
def ta_shot(name):
    return name + '-ta' if os.path.exists(os.path.join(SCREENS, name + '-ta.png')) else name


ta_hero = f'''<section class="hero" aria-labelledby="hero-title">
  <div class="wrap hero-grid">
    <div class="hero-copy">
      <div class="badges">{badge('இலவசம் · ஓப்பன் சோர்ஸ்', 'brand', 'code')}{badge('Windows · macOS · Linux', 'neutral', 'monitor')}</div>
      <h1 class="display" id="hero-title"><em>இலவச</em> பில்லிங் சாஃப்ட்வேர் — தமிழிலேயே</h1>
      <p class="lead">உங்கள் கணினியிலேயே GST பில், கொட்டேஷன், ரசீது போடலாம். {NAME} ஒரு இலவச, ஓப்பன் சோர்ஸ் டெஸ்க்டாப் ஆப் — மாதக் கட்டணம் இல்லை, ஆன்லைன் கணக்கு தேவையில்லை, இன்டர்நெட் இல்லாமலும் வேலை செய்யும். உங்கள் கடைத் தகவல்கள் உங்கள் கணினியை விட்டு வெளியே போகாது.</p>
      <div class="cta-row">
        <a class="btn btn-primary btn-lg" href="#download" data-os-download><span data-os-icon>{icon('download')}</span><span data-os-label>இலவச டவுன்லோட்</span></a>
        {btn('வசதிகளைப் பாருங்கள்', '#features', 'secondary', 'lg')}
      </div>
      <p class="hero-meta" data-hero-meta>இலவசம் · பதிப்பு <span data-version>{VERSION}</span> · Windows, macOS, Linux கணினிகளுக்கு</p>
      {checks(['என்றும் இலவசம்', 'ஓப்பன் சோர்ஸ்', 'இன்டர்நெட் தேவையில்லை', 'பதிவு தேவையில்லை'], 'checks-inline')}
    </div>
    <div class="hero-visual">
      {window(ta_shot('create-invoice'), f'தமிழில் {NAME}-ன் புதிய விலைப்பட்டியல் திரை: வாடிக்கையாளர் Kannan, நான்கு மளிகைப் பொருட்கள், GST, மொத்தம் Rs. 5,829.50', cls='hero-shot', lazy=False, sizes='(max-width: 1100px) 100vw, 700px')}
      {receipt('hero-receipt', 'ta')}
      <span class="hero-chip">{badge('தகவல்கள் உங்கள் கணினியிலேயே', 'teal', 'lock')}</span>
    </div>
  </div>
</section>'''

TA_FACTS = [('percent', 'GST &amp; UPI QR', 'CGST, SGST, IGST, HSN/SAC'), ('printer', 'A4 &amp; தெர்மல்', 'A4, A5, A6, 58/80 mm'),
            ('globe', 'தமிழ் உட்பட 8 மொழிகள்', 'திரையிலும் பில்லிலும் தமிழ்'), ('database', 'பேக்கப் &amp; ரீஸ்டோர்', 'புதிய கணினிக்கு மாற்றலாம்'),
            ('code', 'MIT License', 'ஓப்பன் சோர்ஸ் உரிமம்')]
ta_facts = ('<div class="facts-strip"><ul class="wrap facts">'
            + ''.join(f'<li class="fact">{tile(i, "teal", "md")}<div><b>{v}</b><span>{l}</span></div></li>' for i, v, l in TA_FACTS)
            + '</ul></div>')

TA_WHY = [('gift', 'என்றும் இலவசம்', 'சந்தா இல்லை, ட்ரையல் இல்லை, கட்டணப் பதிப்பும் இல்லை. எல்லா வசதிகளும் எப்போதும் இலவசம்.'),
          ('wifi-off', 'இன்டர்நெட் இல்லாமலும்', 'நெட் இல்லாமலே பில் போடலாம், பிரிண்ட் எடுக்கலாம், ரிப்போர்ட் பார்க்கலாம். நெட் போனாலும் பில்லிங் நிற்காது.'),
          ('lock', 'உங்கள் தகவல் உங்களிடமே', 'வாடிக்கையாளர்கள், பொருட்கள், பில்கள் எல்லாம் உங்கள் கணினியிலேயே சேமிக்கப்படும்; வேறு யாருடைய சர்வருக்கும் போகாது.'),
          ('code', 'ஓப்பன் சோர்ஸ்', 'சோர்ஸ் கோடு MIT License-ல் பொதுவில் உள்ளது. ஆப் என்ன செய்கிறது என்பதை யார் வேண்டுமானாலும் சரிபார்க்கலாம்.'),
          ('monitor', 'Windows, macOS, Linux', 'உங்களிடம் ஏற்கெனவே உள்ள கணினியிலேயே ஓடும்; எல்லாவற்றிலும் அதே வசதிகள்.'),
          ('repeat', 'எதிலும் கட்டிப்போடாது', 'எப்போது வேண்டுமானாலும் பேக்கப் எடுக்கலாம், வேறு கணினியில் ரீஸ்டோர் செய்யலாம், பட்டியல்களை CSV அல்லது PDF-ஆக எடுக்கலாம்.')]
ta_why = section(section_head(f'ஏன் {NAME}?', 'மாதக் கட்டணம் இல்லாத பில்லிங் சாஃப்ட்வேர்',
                              'ஒரு சிறு கடைக்குப் பில் போடத் தேவையான எல்லாமே இதில் உண்டு — அதுவும் உங்கள் சொந்தக் கணினியிலேயே.', 'why-title')
                 + '<div class="grid-auto mt-4">' + ''.join(f'<div class="card">{tile(i)}<h3>{t}</h3><p>{d}</p></div>' for i, t, d in TA_WHY) + '</div>',
                 'why', 'section-flush', 'why-title')

TA_HOW = [('01', 'கடை விவரங்கள்', 'கடைப் பெயர், லோகோ, GSTIN, வங்கி விவரம், UPI ID — ஒரு முறை சேர்த்தால் போதும்.'),
          ('02', 'வாடிக்கையாளர்கள், பொருட்கள்', 'CSV ஃபைலில் இருந்து பட்டியலை ஏற்றலாம், அல்லது பில் போடும்போதே சேர்க்கலாம். பார்கோடு ஸ்கேனரும் வேலை செய்யும்.'),
          ('03', 'பில் போடுங்கள்', 'வாடிக்கையாளரைத் தேர்ந்தெடுத்து, பொருட்களைத் தேடுங்கள் அல்லது ஸ்கேன் செய்யுங்கள். வரியும் மொத்தமும் தானாகக் கணக்கிடப்படும்.'),
          ('04', 'பிரிண்ட் அல்லது PDF', 'A4 அல்லது தெர்மல் பிரிண்டரில் பிரிண்ட் எடுக்கலாம்; அல்லது PDF-ஆகச் சேமித்து வாடிக்கையாளருக்கு அனுப்பலாம்.'),
          ('05', 'பணம் வசூல்', 'முழுத் தொகை அல்லது பகுதித் தொகையைப் பதிவு செய்யலாம், ரசீது பிரிண்ட் எடுக்கலாம், யார் இன்னும் தர வேண்டும் என்று பார்க்கலாம்.')]
ta_how = section('<div class="flow"><div class="flow-copy">'
                 + section_head('செயல்முறை', 'ஐந்தே படிகளில் — செட்டப் முதல் பணம் வசூல் வரை',
                                'கடையில் வழக்கமாகப் பில் போடும் அதே முறைதான் — இன்னும் வேகமாக, ஒழுங்காக.', 'how-title', left=True)
                 + '<ol class="steps">' + ''.join(f'<li class="step"><span class="step-num">{n}</span><div><h3>{t}</h3><p>{b}</p></div></li>' for n, t, b in TA_HOW) + '</ol></div>'
                 + '<div>' + window(ta_shot('invoices'), f'தமிழில் {NAME}-ன் விலைப்பட்டியல்கள் பட்டியல்: செலுத்தியவை, செலுத்தாதவை, பகுதியாகச் செலுத்தியவை, நிலுவைத் தொகையுடன்',
                                    sizes='(max-width: 1100px) 100vw, 700px') + '</div></div>',
                 'how-it-works', 'section-subtle', 'how-title')

TA_GROUPS = [
    ('file', 'பில்லிங்', ['ஆறு பில் டிசைன்கள், கூடவே தெர்மல் ரசீது வடிவம்', 'A4, A5, A6, 58/80 mm-ல் பிரிண்ட் அல்லது PDF',
                          'உங்கள் prefix-உடன் தானியங்கி பில் எண்', 'தள்ளுபடி, வரி, கூடுதல் கட்டணங்கள்',
                          'பில்லில் உங்களுக்கு வேண்டிய கூடுதல் விவரங்கள்', 'முடிக்காத பில்லை வரைவாக (draft) சேமிக்கலாம்'], 'span-2'),
    ('briefcase', 'கடை நிர்வாகம்', ['கொட்டேஷனை ஒரே கிளிக்கில் பில்லாக மாற்றலாம்', 'முழு அல்லது பகுதிப் பணம் வசூல், ரசீதுடன்',
                                     'நிலுவைத் தொகை உள்ள வாடிக்கையாளர்கள்', 'பொருட்கள், சேவைகள், இருப்பு (stock), batch, expiry',
                                     'விற்பனை, வரி, நிலுவை, தினசரி, இருப்பு ரிப்போர்ட்கள்', 'பட்டியல்களை CSV-ஆக ஏற்றலாம், எடுக்கலாம்'], 'span-2'),
    ('percent', 'இந்தியா &amp; GST', ['ஒவ்வொரு பில்லிலும் உங்கள் GSTIN, வாடிக்கையாளரின் GSTIN', 'ஒவ்வொரு பொருளுக்கும் HSN/SAC குறியீடு',
                                      'CGST + SGST அல்லது IGST தானாகக் கணக்கீடு', 'Tax Invoice அல்லது Bill of Supply தலைப்பு',
                                      'உங்கள் UPI QR குறியீடு பில்லிலேயே'], 'span-2'),
    ('hard-drive', 'உங்கள் கணினியிலேயே, பாதுகாப்பாக', ['இன்டர்நெட் இல்லாமலும் வேலை செய்யும்', 'தகவல்கள் உங்கள் கணினியிலேயே',
                                                        'ஒரே கிளிக்கில் பேக்கப், ரீஸ்டோர்', 'ஒரே கணினியில் பல நிறுவனங்கள்',
                                                        'ஊழியர்களுக்குத் தனி லாகின் (admin அல்லது user)', 'ஆன்லைன் கணக்கு தேவையில்லை'], 'span-3'),
    ('globe', 'தமிழும் மற்ற மொழிகளும்', ['தமிழ், English, இந்தி உட்பட 8 மொழிகள்', 'தமிழ் எழுத்துகள் PDF-லும் ரசீதிலும் சரியாக அச்சாகும்',
                                         'உங்கள் நாணயத்தை (currency) தேர்ந்தெடுக்கலாம்', 'USB பார்கோடு ஸ்கேனர்',
                                         'ஒவ்வொரு விற்பனைக்குப் பிறகும் தெர்மல் ரசீது தானாகப் பிரிண்ட் ஆகும்'], 'span-3'),
]
ta_features = section(section_head('வசதிகள்', 'ஒரு சிறு கடைக்குத் தேவையான எல்லா பில்லிங் வசதிகளும்',
                                   'நீங்கள் வேலை செய்யும் முறைப்படி அடுக்கப்பட்டுள்ளன — எல்லாமே இலவசம்.', 'feat-title')
                      + '<div class="bento mt-4">' + ''.join(f'<div class="group-card {c}"><div class="group-card-head">{tile(i)}<h3>{t}</h3></div>{checks(items)}</div>'
                                                             for i, t, items, c in TA_GROUPS) + '</div>',
                      'features', '', 'feat-title')

TA_SHOTS = {'dashboard': ('முகப்புப் பலகை', 'வசூலான பணம், நிலுவை, மாத விற்பனை, பில் நிலை, சமீபத்திய பில்கள்.'),
            'create-invoice': ('புதிய விலைப்பட்டியல்', 'வாடிக்கையாளர், பொருட்கள், GST, மொத்தம் — எல்லாம் ஒரே திரையில்.'),
            'invoices': ('விலைப்பட்டியல்கள்', 'எது செலுத்தப்பட்டது, எது நிலுவை என்று பார்க்கலாம்; எந்தப் பில்லையும் விரைவாகத் தேடலாம்.'),
            'customers': ('வாடிக்கையாளர்கள்', 'போன் எண், GSTIN, ஒவ்வொருவரும் தர வேண்டிய தொகை.'),
            'products': ('பொருட்கள்', 'விலை, HSN, வரி, இருப்பு — குறைந்த இருப்பு உடனே தெரியும்.'),
            'reports': ('அறிக்கைகள்', 'மாதவாரியாக பில் தொகை, வசூல், நிலுவை.')}
TA_DOCS = {'invoice-a4': ('அச்சிட்ட பில் (A4)', 'Classic டிசைனில் ஒரு GST பில் — வாடிக்கையாளர் கையில் கிடைப்பது போலவே.',
                          f'{NAME} அச்சிட்ட மாதிரி A4 GST பில்: Sri Murugan Traders, Kannan Stores-க்கு ஆறு பொருட்கள், CGST, SGST உடன், மொத்தம் Rs. 7019.10'),
           'receipt-80mm': ('தெர்மல் ரசீது (80 mm)', 'தமிழ்ப் பொருள் பெயர்களுடன், சரியாக அச்சான கவுண்டர் ரசீது.',
                            'மூன்று தமிழ்ப் பொருள் பெயர்களுடன் மாதிரி 80 mm தெர்மல் ரசீது, முழுதும் செலுத்தப்பட்டது, மொத்தம் Rs. 1036.60')}
ta_shots = section(section_head('ஸ்கிரீன்ஷாட்கள்', 'இன்ஸ்டால் செய்யும் முன்பே எல்லாத் திரைகளையும் பாருங்கள்',
                                f'தமிழில் இயங்கும் {NAME}-ன் உண்மையான திரைகளும் அது அச்சிட்ட பில்களும், ஒரு மாதிரிக் கடையின் தகவல்களுடன்.', 'shots-title')
                   + '<div class="shots mt-4">'
                   + ''.join(f'<figure class="shot{" shot-wide" if i == 0 and doc_cards else ""}">{window(ta_shot(n), f"தமிழில் {NAME}-ன் {TA_SHOTS[n][0]} திரை")}'
                             f'<figcaption><b>{TA_SHOTS[n][0]}</b><span>{TA_SHOTS[n][1]}</span></figcaption></figure>' for i, (n, _, _) in enumerate(screen_cards))
                   + ''.join(f'<figure class="shot">{paper(n, cls, TA_DOCS[n][2])}<figcaption><b>{TA_DOCS[n][0]}</b><span>{TA_DOCS[n][1]}</span></figcaption></figure>'
                             for n, cls, _, _, _ in doc_cards)
                   + '</div>',
                   'screenshots', 'section-subtle', 'shots-title')

TA_WHO = [('shopping-bag', 'மளிகை, சில்லறைக் கடைகள்', 'பார்கோடு ஸ்கேனிங், தெர்மல் ரசீதுடன் வேகமான கவுண்டர் பில்லிங்.'),
          ('package', 'மருந்தகங்கள், மெடிக்கல் ஷாப்கள்', 'பொருட்களுக்கு batch எண், expiry தேதி; இருப்பு குறைந்தால் எச்சரிக்கை.'),
          ('truck', 'வியாபாரிகள், மொத்த விற்பனையாளர்கள்', 'HSN குறியீடுகளுடன் GST பில், இருப்பு நிலை, வாடிக்கையாளர் நிலுவை.'),
          ('user', 'ஃப்ரீலான்சர்கள், ஆலோசகர்கள்', 'தெளிவான PDF கொட்டேஷன், பில்; யார் பணம் தந்தார்கள் என்று தெளிவாகத் தெரியும்.'),
          ('tool', 'சர்வீஸ், ரிப்பேர் கடைகள்', 'பாகங்கள், கூலிக்கு விரைவான பில்; பகுதிப் பணம், ரசீது.'),
          ('briefcase', 'எந்தச் சிறு வணிகமும்', 'ஒரே கணினியில் பல நிறுவனங்கள், ஊழியர் லாகின்கள் — எல்லாம் இலவசம்.')]
ta_who = section(section_head('யாருக்கு?', 'சிறு வணிகங்கள் வேலை செய்யும் முறைக்கே ஏற்றது', hid='who-title')
                 + '<div class="grid-auto-wide mt-4">' + ''.join(f'<div class="usecase">{tile(i, "neutral")}<div><h3>{t}</h3><p>{d}</p></div></div>' for i, t, d in TA_WHO) + '</div>',
                 'who', '', 'who-title')

TA_INDIA = ['GSTIN, HSN/SAC, CGST + SGST அல்லது IGST', 'பில்லில் UPI QR குறியீடு', 'இயல்பாக ரூபாயில் தொகை', 'திரையிலும் பில்லிலும் தமிழ், இந்தி']
TA_TAMIL = ['மெனு, பட்டன்கள், பெரும்பாலான திரைகள் தமிழில்', 'பொருள், வாடிக்கையாளர் பெயர்களைத் தமிழில் சேமிக்கலாம்',
            'தமிழ்ப் பெயர்கள் PDF-லும் தெர்மல் ரசீதிலும் சரியாக அச்சாகும்', 'எப்போது வேண்டுமானாலும் English-க்கு மாற்றலாம்']
ta_tamil = section(section_head('தமிழில்', 'தமிழிலேயே பயன்படுத்துங்கள், தமிழிலேயே பிரிண்ட் எடுங்கள்',
                                f'{NAME} இந்தியாவில், இந்திய பில்லிங் விதிகளுக்காக உருவாக்கப்பட்டது. ஆப்பின் மொழியைத் தமிழாக மாற்றினால் போதும்.', 'lg-title')
                   + '<div class="split split-stretch mt-4">'
                   + f'<div class="group-card is-subtle"><div class="group-card-head">{tile("globe")}<h3>தமிழில் பில்லிங்</h3></div>{checks(TA_TAMIL)}'
                   + f'<div class="stack" style="gap:10px"><p class="chips-label">ஆப் மொழிகள்</p><div class="chips">{langs}</div></div></div>'
                   + f'<div class="group-card is-subtle"><div class="group-card-head">{tile("percent")}<h3>இந்தியாவுக்காக</h3></div>{checks(TA_INDIA)}</div>'
                   + '</div>', 'tamil', '', 'lg-title')

ta_privacy = f'''<section class="section section-night on-dark" id="privacy" aria-labelledby="priv-title">
  <div class="wrap split">
    <div>
      {section_head('தனியுரிமை', 'உங்கள் வணிகத் தகவல் உங்களுக்கே சொந்தம்.', f'{NAME} உங்கள் வணிகத் தகவல்களை உங்கள் கணினியிலேயே வைத்திருக்கும். வாடிக்கையாளர்கள், விலைகள், விற்பனை பற்றிய எதுவும் எங்களுக்கோ வேறு யாருக்குமோ அனுப்பப்படுவதில்லை.', 'priv-title', left=True)}
      {checks(['இன்டர்நெட் இல்லாமலும் வேலை செய்யும்', 'உங்கள் கணினியிலேயே சேமிப்பு', 'கணக்கும் இல்லை, சந்தாவும் இல்லை', 'நீங்கள் விரும்பும்போது பேக்கப்'], 'checks-grid mt-3')}
      <p class="mt-3 small"><a href="privacy.html" style="color: var(--night-accent)">தனியுரிமைக் கொள்கையைப் படிக்க (English)</a></p>
    </div>
    <div class="vault">
      <div class="vault-head">{tile('monitor', 'night')}<div><b>உங்கள் கணினி</b><span>{NAME} சேமிக்கும் எல்லாம் இங்கேதான்</span></div></div>
      <ul class="vault-items">{''.join(f'<li>{icon(i)}{t}</li>' for i, t in [('file', 'பில்கள்'), ('users', 'வாடிக்கையாளர்கள்'), ('package', 'பொருட்கள்'), ('database', 'பேக்கப்கள்')])}</ul>
      <hr>
      <p class="vault-foot">{icon('cloud-off')}<span><b>உங்கள் வணிகத் தகவல் ஒருபோதும் அப்லோட் ஆகாது.</b> {NAME}-க்கு கிளவுடும் இல்லை, லாகின் செய்ய ஆன்லைன் கணக்கும் இல்லை.</span></p>
    </div>
  </div>
</section>'''

ta_free = section(
    '<div class="split"><div>'
    + section_head('ஓப்பன் சோர்ஸ்', 'எல்லோரும் பார்க்கும்படி உருவாக்கப்பட்டது',
                   f'{NAME}-ன் சோர்ஸ் கோடு MIT License-ல் பொதுவில் உள்ளது. நாங்கள் சொல்வதை நம்ப வேண்டியதில்லை — நீங்களே சரிபார்க்கலாம்.', 'os-title', left=True)
    + checks(['உங்கள் தகவலை ஆப் எப்படிக் கையாள்கிறது என்று நேரடியாகப் படிக்கலாம்', 'MIT License-ல் இலவசமாகப் பயன்படுத்தலாம், மாற்றலாம்',
              'எத்தனை கணினிகளில் வேண்டுமானாலும் இலவசமாகப் பயன்படுத்தலாம்'], 'mt-3')
    + '</div><div class="stack">'
    + f'<div class="card card-note"><h3 class="h4">இது எப்படி இலவசம்?</h3><p>{NAME}-ஐ {BUSINESS} உருவாக்குகிறது; இது ANOOP P உருவாக்கிய, MIT உரிமம் பெற்ற '
      'Invoiso-வை அடிப்படையாகக் கொண்டது. கட்டணப் பதிப்பு எதுவும் இல்லை. தனி வசதி தேவைப்படும் வணிகங்களுக்கான '
      f'<a href="customization.html">கட்டண customization</a> சேவையும், <a href="{COFFEE}" target="_blank" rel="noopener">நன்கொடைகளும்</a> இதன் வளர்ச்சிக்கு உதவுகின்றன.</p></div>'
    + f'<div class="repo-card"><div class="group-card-head">{tile("code")}<h3 class="h4">MIT License</h3></div>'
    + '<p>உரிம விவரங்கள் <a href="licenses.html">Licenses பக்கத்தில்</a> (English) உள்ளன.</p>'
    + f'<div class="badges">{badge("ஓப்பன் சோர்ஸ்", "neutral", "code")}{badge("சமீபத்திய பதிப்பு <span data-version>" + VERSION + "</span>", "neutral", "download")}</div></div>'
    + '</div></div>', 'open-source', '', 'os-title')

TA_TRUST = ('<div class="dl-trust">' + ''.join(badge(t, 'teal', 'check') for t in
                                              ['என்றும் இலவசம்', 'கிரெடிட் கார்டு தேவையில்லை', 'சந்தா இல்லை', 'ஓப்பன் சோர்ஸ்']) + '</div>')
TA_PHONE_NOTE = (f'<div class="notice hidden" data-mobile-note>{icon("smartphone")}<span>நீங்கள் போனில் பார்க்கிறீர்கள். {NAME} '
                 'Windows, macOS, Linux கணினிகளில் இயங்கும் ஆப். டவுன்லோட் செய்ய உங்கள் கணினியில் <b>invoiceo.in/ta.html</b> திறக்கவும்.</span></div>')
TA_FIRST_STEPS = [
    ('download', 'டவுன்லோட்', 'மேலே உங்கள் கணினியைத் தேர்ந்தெடுங்கள்.'),
    ('package', 'இன்ஸ்டால்', 'ஃபைலைத் திறந்து வழிமுறைகளைப் பின்பற்றுங்கள்.'),
    ('user', 'லாகின், செட்டப்', 'எப்படி லாகின் செய்வது என்று முதல் திரையே காட்டும். பிறகு உங்கள் கடை விவரங்களைச் சேர்க்கவும்.'),
    ('file', 'முதல் பில்', 'வாடிக்கையாளரையும் பொருட்களையும் சேர்த்து, பில்லை உருவாக்குங்கள்.'),
    ('printer', 'பிரிண்ட் அல்லது PDF', 'A4 அல்லது தெர்மல் பிரிண்டரில் பிரிண்ட் எடுக்கலாம், அல்லது PDF-ஆகச் சேமிக்கலாம்.'),
]
ta_download = section(
    section_head('டவுன்லோட்', 'இன்றே இலவசமாகப் பில் போடத் தொடங்குங்கள்',
                 f'{NAME} <span data-version>{VERSION}</span> · வெளியீடு {RELEASE_DATE_TA} · <a href="changelog.html">புதியவை (English)</a>', 'dl-title')
    + f'<div class="mt-2">{TA_TRUST}</div><div class="mt-2">{TA_PHONE_NOTE}</div>'
    + f'<div class="mt-3">{dl_grid(full=True, lang="ta")}</div>'
    + f'<div class="mt-2"><p class="center small muted">டவுன்லோடைச் சரிபார்க்க: <a href="{DL}SHA256SUMS.txt">SHA-256 checksums</a></p></div>'
    + '<h3 class="h3 center" style="margin: 72px 0 20px">சில நிமிடங்களில் தொடங்கலாம்</h3>'
    + first_steps('h4', TA_FIRST_STEPS, 'படி'),
    'download', 'section-subtle', 'dl-title')

TA_FAQ = [
    (f'{NAME} உண்மையிலேயே இலவசமா?', 'ஆம். எல்லா வசதிகளும் இலவசம் — ட்ரையல், சந்தா, கட்டணப் பதிப்பு எதுவும் இல்லை. எத்தனை கணினிகளில் வேண்டுமானாலும் இன்ஸ்டால் செய்யலாம்.', True),
    ('தமிழில் பயன்படுத்தலாமா?', 'ஆம். ஆப்பைத் தமிழில் பயன்படுத்தலாம்; தமிழ்ப் பெயர்கள் PDF-லும் தெர்மல் ரசீதிலும் சரியாக அச்சாகும். English, இந்தி உட்பட மொத்தம் 8 மொழிகள் உண்டு.', True),
    ('இன்டர்நெட் இல்லாமல் வேலை செய்யுமா?', 'ஆம். டவுன்லோட் செய்ய மட்டும் இன்டர்நெட் தேவை. பில், பிரிண்ட், ரிப்போர்ட் எல்லாம் இன்டர்நெட் இல்லாமலே வேலை செய்யும்.', True),
    ('ஆன்லைன் கணக்கு தொடங்க வேண்டுமா?', 'இல்லை. ஆப்பிலேயே உங்கள் கணினிக்கான லாகின் உண்டு; ஒவ்வொருவருக்கும் தனி பாஸ்வேர்டு வைக்கலாம்.', True),
    ('என் தகவல்கள் எங்கே சேமிக்கப்படும்?', f'உங்கள் கணினியிலேயே, {NAME}-ன் data ஃபோல்டரில். பாதுகாப்புக்கு <b>அமைப்புகள் → காப்புப்பிரதி</b> மூலம் அடிக்கடி பேக்கப் எடுங்கள்.', False),
    ('GST, UPI வசதி உண்டா?', 'ஆம் — GSTIN, HSN/SAC, CGST + SGST அல்லது IGST, பில்லில் உங்கள் UPI QR குறியீடு.', False),
    ('எந்தக் கணினிகளில் ஓடும்?', 'Windows 10, 11 (64-bit), macOS 12 அல்லது பிந்தையது, Linux (.deb அல்லது AppImage). போன் ஆப் இல்லை.', False),
    ('புதிய கணினிக்கு மாற முடியுமா?', f'ஆம். பழைய கணினியில் பேக்கப் எடுத்து, புதிய கணினியில் {NAME}-ஐ இன்ஸ்டால் செய்து, அந்த பேக்கப்பை ரீஸ்டோர் செய்யுங்கள்.', False),
    ('சிறு கடைக்கு ஏற்றதா?', 'ஆம் — பார்கோடு ஸ்கேனிங், தெர்மல் ரசீது, இருப்பு கண்காணிப்பு, தினசரி விற்பனை ரிப்போர்ட் எல்லாம் உண்டு.', False),
    ('இது எப்படி இலவசம்?', 'கட்டணப் பதிப்பு இல்லை. தேவைப்படுவோருக்கான கட்டண <a href="customization.html">customization</a> சேவையும் நன்கொடைகளும் வளர்ச்சிக்கு உதவுகின்றன.', False),
    ('இன்ஸ்டால் செய்யும்போது Windows ஏன் எச்சரிக்கிறது?', 'இன்ஸ்டாலர் இன்னும் code-sign செய்யப்படவில்லை. <b>More info</b>, பிறகு <b>Run anyway</b> அழுத்துங்கள்.', False),
    ('என் கடைக்கென்று தனி வசதி செய்து தர முடியுமா?', 'ஆம், கட்டண சேவையாக — ஒவ்வொரு கோரிக்கைக்கும் தனியாக விலை சொல்வோம். <a href="customization.html">Customization பக்கத்தில்</a> கேளுங்கள், அல்லது WhatsApp-ல் தொடர்பு கொள்ளுங்கள்.', False),
]
ta_faq = section(
    section_head('கேள்விகள்', 'டவுன்லோட் செய்யும் முன் கேட்கப்படும் கேள்விகள்', hid='faq-title')
    + '<div class="faq-grid mt-4">' + ''.join('<div class="faq-col">' + ''.join(faq_item(q, a, o) for q, a, o in col) + '</div>'
                                             for col in (TA_FAQ[0::2], TA_FAQ[1::2])) + '</div>'
    + '<p class="center mt-3">இன்னும் சந்தேகமா? <span data-block><a data-whatsapp target="_blank" rel="noopener">WhatsApp-ல் கேளுங்கள்</a>, </span>'
      '<a href="faq.html">எல்லாப் பதில்களையும் படியுங்கள் (English)</a> அல்லது <a href="contact.html">எங்களைத் தொடர்பு கொள்ளுங்கள்</a>.</p>',
    'faq', '', 'faq-title')

ta_cta = f'''<section class="cta-section" aria-labelledby="cta-title">
  <div class="wrap">
    <div class="cta-band">
      <h2 id="cta-title">எளிய பில்லிங். மாதக் கட்டணம் இல்லை.</h2>
      <p class="lead">{NAME}-ஐ டவுன்லோட் செய்து, இன்றே உங்கள் முதல் பில்லைப் போடுங்கள்.</p>
      <div class="cta-row">
        {btn(f'{NAME} டவுன்லோட் — என்றும் இலவசம்', '#download', 'inverse', 'lg', 'download')}
        {btn('தொடர்பு கொள்ள', 'contact.html', 'on-dark', 'lg', 'message')}
      </div>
    </div>
  </div>
</section>'''

page('ta.html', f'இலவச பில்லிங் சாஃப்ட்வேர் தமிழில் — GST பில், ஆஃப்லைன் | {NAME}',
     f'{NAME} — கடைகளுக்கான இலவச பில்லிங் சாஃப்ட்வேர். தமிழிலேயே GST பில், கொட்டேஷன், ரசீது போடலாம். '
     'இன்டர்நெட் இல்லாமலும் வேலை செய்யும். Windows, Mac, Linux-க்கு இலவச டவுன்லோட்.',
     'home', '\n\n'.join([ta_hero, ta_facts, ta_why, ta_how, ta_features, ta_shots, ta_who, ta_tamil, ta_privacy, ta_free,
                          ta_download, ta_faq, ta_cta]),
     lang='ta',
     jsonld={
         '@context': 'https://schema.org',
         '@type': 'SoftwareApplication',
         'name': NAME,
         'inLanguage': 'ta',
         'applicationCategory': 'BusinessApplication',
         'operatingSystem': 'Windows, macOS, Linux',
         'softwareVersion': VERSION,
         'datePublished': RELEASE_ISO,
         'description': 'சிறு கடைகளுக்கான இலவச, ஓப்பன் சோர்ஸ், ஆஃப்லைன் பில்லிங் மற்றும் GST பில் சாஃப்ட்வேர்.',
         'url': SITE + '/ta.html',
         'license': 'https://opensource.org/licenses/MIT',
         'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'INR'},
         'publisher': ORG,
     })

# ──────────────────────────────── Download ─────────────────────────────────
download_body = page_head(
    'Download', f'Download {NAME}', 'Free for Windows, macOS and Linux. No sign-up, no licence key and no subscription.',
    f'\n    <div class="badges">{badge("Version <span data-version>" + VERSION + "</span>", "brand")}'
    f'{badge("Released <span data-release-date>" + RELEASE_DATE + "</span>", "neutral")}</div>'
    f'\n    <p class="small"><a href="changelog.html">What’s new in this version</a></p>') + f'''

<section class="page-body" aria-label="Installers">
  <div class="wrap">
    {TRUST}
    <div class="mt-2">{PHONE_NOTE}</div>
    <div class="mt-3">{dl_grid(full=True)}</div>
    <div class="mt-2">{CHECKSUMS}</div>
  </div>
</section>

<section class="section section-subtle" aria-labelledby="first-steps">
  <div class="wrap">
    {section_head('After installing', 'Up and running in minutes', hid='first-steps')}
    <div class="mt-4">{first_steps()}</div>
  </div>
</section>

<section class="section section-flush" aria-label="More help">
  <div class="wrap">
    <div class="grid-auto">
      <div class="card">{tile('refresh')}<h2 class="h4">Updating to a new version</h2><p>Download the new installer and install it over the old version. Your data is kept, but make a backup first from <b>Settings → Backup</b> in the app.</p></div>
      <div class="card">{tile('help')}<h2 class="h4">Need help installing?</h2><p>Read the <a href="faq.html">FAQ</a> or <a href="contact.html">contact us</a>, and we will help you get started.</p></div>
      <div class="card">{tile('gift', 'teal')}<h2 class="h4">Free, on every computer</h2><p>You never need to pay to download {NAME}, install it on more computers or keep using it.</p></div>
    </div>
  </div>
</section>'''

page('download.html', 'Download',
     f'Download {NAME} free for Windows, macOS and Linux, with step-by-step install help.',
     'download', download_body)

# ────────────────────────────── Customization ──────────────────────────────
CUSTOM = [
    ('file', 'Invoice and bill designs', 'A layout that matches your letterhead, your trade or a format your customers expect.'),
    ('list', 'Extra fields', 'More details on invoices, products or customers, printed where you need them.'),
    ('layout', 'Bill formats for your trade', 'Special bills for your kind of business, with the columns and totals your trade uses.'),
    ('chart', 'New reports', 'Reports and summaries built around the numbers you check every day or month.'),
    ('share', 'Exports', 'Send your data to Tally or another accounting app in the format it needs.'),
    ('sliders', 'Changes to how it works', 'Shortcuts, steps or screens adjusted to the way your counter works.'),
]
CUSTOM_STEPS = [('message', 'Tell us what you need', 'Fill in the request form below. Sample bills or screenshots help a lot.'),
                ('file', 'Get a quote', 'We reply with any questions and a price for the work. There is no charge for the quote.'),
                ('package', 'We build it', 'Once you approve, we build and test it, and give you your updated version.')]
customization_body = page_head(
    'Custom features', 'Customization',
    f'{NAME} is free to use. When your business needs something more, we can build it for you. Every request is quoted on its own, and you decide before any work starts.') + f'''

<section class="page-body" aria-labelledby="what-title">
  <div class="wrap">
    {section_head('What we can make', 'Made for your business', 'A few examples. If your idea is not on the list, ask anyway.', 'what-title')}
    <div class="grid-auto mt-4">{''.join(f'<div class="card">{tile(i, "neutral")}<h3>{t}</h3><p>{d}</p></div>' for i, t, d in CUSTOM)}</div>
  </div>
</section>

<section class="section section-subtle" aria-labelledby="custom-how">
  <div class="wrap">
    {section_head('How it works', 'Three steps, and you decide', hid='custom-how')}
    <ol class="steps-row steps-3 mt-4">{''.join(f'<li><span class="step-label">{tile(ic, "", "sm")}Step {n + 1}</span><h3 class="h4">{t}</h3><p>{b}</p></li>' for n, (ic, t, b) in enumerate(CUSTOM_STEPS))}</ol>
  </div>
</section>

<section class="section section-flush" id="request" aria-labelledby="request-title">
  <div class="wrap narrow">
    {section_head('Request', 'Request a customization', 'Prices depend on the work, so we do not list fixed prices. You will always see the quote first.', 'request-title')}
    <p class="center mt-2" data-block>{btn('Open the form in a new tab', '#', 'secondary', '', 'external-link', attrs=' data-href="forms.customization" data-hide-empty target="_blank" rel="noopener"')}</p>
    <iframe id="customization-form" class="form-frame hidden mt-3" title="Customization request form" loading="lazy"></iframe>
    <div id="customization-form-missing" class="form-missing mt-3">
      <p><b>The request form is coming soon.</b></p>
      <p>Until then, write to us at <a href="mailto:{EMAIL}?subject=Customization%20request">{EMAIL}</a><span data-block> or message us on <a data-whatsapp target="_blank" rel="noopener">WhatsApp</a></span>.</p>
    </div>
  </div>
</section>'''

page('customization.html', 'Customization',
     f'{NAME} is free; extra features, invoice designs, reports and exports for your business are built on request and quoted per job.',
     'customization', customization_body)

# ─────────────────────────────────── FAQ ───────────────────────────────────
FAQ_GROUPS = [
    ('About Invoiceo', [
        ('Is Invoiceo really free?',
         ['Yes. The app and its updates are free, with no subscription and no trial period. You can install it on as many of your computers as you like.',
          'We only charge for work done for you on request, such as a new bill format or a report. See <a href="customization.html">Customization</a>.']),
        ('Is Invoiceo open source?',
         f'Yes. {NAME} is released under the MIT License, so anyone can read, use and change the code. It is based on Invoiso by ANOOP P, which is also MIT-licensed.'),
        ('How can it be free?',
         f'There is no paid version. Development is supported by optional <a href="customization.html">paid customization</a> for businesses that need something special, and by <a href="{COFFEE}" target="_blank" rel="noopener">donations</a>.'),
        ('Do I need an internet connection?',
         'No. Invoiceo runs on your computer, so you can bill, print and see reports offline. You need a connection only to download the installer, to open our website or forms, or to share a PDF online.'),
        ('Do I need to create an account?',
         'No online account or sign-up is needed. The app has its own login on your computer, so you can protect it with a password and give each person their own username.'),
        ('Where is my data stored?',
         ['Everything you enter is saved on your own computer, in the app’s data folder. Your customers, products and invoices are not sent to us.',
          'Because the data is on your computer, keeping it safe is in your hands: use <b>Settings → Backup</b> in the app regularly.']),
        ('Does Invoiceo collect any data?',
         ['Only a few anonymous usage counts, so we know how many people use the app: when it is first opened, once a day while it is used, and once when the first invoice is made. Each count carries a random ID, the app version and the operating system, nothing else.',
          'Your customers, products, invoices, amounts and company details are never sent. You can turn the counts off in <b>Settings → Software Info</b>. See the <a href="privacy.html">privacy policy</a>.']),
    ]),
    ('Billing and printing', [
        ('Can I use Invoiceo for GST billing?',
         ['Yes. You can add your GSTIN and your customers’ GSTINs, HSN/SAC codes and tax rates per product or for the whole invoice. Invoices show CGST and SGST, or IGST for sales to another state, and you can choose titles such as Tax Invoice or Bill of Supply.',
          'Invoiceo helps you prepare correct invoices; for filing returns, please follow your accountant’s advice.']),
        ('Can I use it outside India?',
         'Yes. Choose the currency you bill in and one of eight app languages. GST fields can be turned off in the invoice settings when you don’t need them.'),
        ('Which printers can I use?',
         'Any printer your computer can print to, for A4, A5 and A6 invoices. For receipts, Invoiceo supports 58 mm and 80 mm thermal printers and can print the receipt automatically after each sale (in the Modern layout).'),
        ('Can I use it in Tamil?',
         'Yes. The app can be used in English, Tamil, Hindi, Nepali, French, Spanish, Chinese and Tibetan (partly translated), and Tamil names print correctly on PDFs and thermal receipts.'),
        ('Does it work with a barcode scanner?',
         'Yes. A USB barcode scanner that types the code works on the New Invoice screen: scan a product to add it to the bill.'),
        ('Is it right for a small shop?',
         'Yes. Barcode scanning, thermal receipts, stock levels, batch and expiry dates, and daily sales reports are built in.'),
        ('Can I manage more than one business?',
         'Yes. You can add several companies on one computer. Each company keeps its own customers, products, invoices and settings.'),
        ('Can more than one person use it?',
         'Yes, on the same computer. Each person can have their own login, as an admin or a normal user.'),
    ]),
    ('Installing and updating', [
        ('Which computers does it run on?',
         'Windows 10 and 11 (64-bit), macOS 12 Monterey or later, and Linux: a .deb for Ubuntu 22.04+, Debian 12+ and Linux Mint 21+, and an AppImage for other distributions. There is no phone app.'),
        ('Windows says “Windows protected your PC”. Is it safe?',
         'This message appears for installers that are not code-signed yet. If you downloaded Invoiceo from this website, click <b>More info</b> and then <b>Run anyway</b>.'),
        ('macOS says it cannot check the app for malicious software.',
         'The app is not notarised by Apple yet. Click <b>Done</b>, open <b>System Settings → Privacy &amp; Security</b>, scroll down to the message about Invoiceo and click <b>Open Anyway</b>. On macOS 14 or older, Control-click Invoiceo in Applications and choose <b>Open</b>. You only need to do this the first time.'),
        ('How do I update to a new version?',
         'Download the new version from the <a href="download.html">Download page</a> and install it over the old one. Your data is kept, but make a backup first to be safe. See what changed on the <a href="changelog.html">What’s new page</a>.'),
        ('How do I move to a new computer?',
         'Make a backup of each company on the old computer, copy the backup file to the new one, install Invoiceo there and import the backup from <b>Settings → Backup</b>.'),
    ]),
    ('Help and custom work', [
        ('Can you add a feature for my business?',
         'Yes, as a paid service, quoted per request. Tell us what you need on the <a href="customization.html">Customization page</a>.'),
        ('How do I get help?',
         f'Use the support form or write to us. All the ways to reach us are on the <a href="contact.html">Contact page</a>.'),
    ]),
]
FAQ = [qa for _, items in FAQ_GROUPS for qa in items]


def strip_tags(s):
    import re
    return re.sub(r'<[^>]+>', '', s)


faq_body = page_head('Help', 'Frequently asked questions', f'Short answers about {NAME}. Can’t find yours? <a href="contact.html">Ask us</a>.') + '\n\n<section class="page-body">\n  <div class="wrap measure">\n' + '\n'.join(
    f'    <h2 class="h3{" mt-4" if i else ""}" id="{strip_tags(t).lower().replace(" ", "-")}">{t}</h2>\n    <div class="faq-list mt-2">'
    + ''.join(faq_item(q, a) for q, a in items) + '</div>'
    for i, (t, items) in enumerate(FAQ_GROUPS)) + '\n  </div>\n</section>'

page('faq.html', 'FAQ',
     f'Answers about {NAME}: price, open source, offline use, where data is stored, GST, printers, Tamil, barcode scanners, installing and updating.',
     'faq', faq_body, jsonld={
         '@context': 'https://schema.org',
         '@type': 'FAQPage',
         'mainEntity': [
             {'@type': 'Question', 'name': q,
              'acceptedAnswer': {'@type': 'Answer', 'text': strip_tags(' '.join(a) if isinstance(a, list) else a)}}
             for q, a in FAQ],
     })

# ───────────────────────────────── Contact ─────────────────────────────────
NEW_TAB = ' target="_blank" rel="noopener"'
contact_cards = [
    ('mail', '', 'Email', f'<p class="value">{EMAIL}</p><p>For anything about {NAME}.</p>', btn('Send an email', f'mailto:{EMAIL}', 'secondary'), ''),
    ('message', 'teal', 'WhatsApp', '<p class="value"><span data-whatsapp-number></span></p><p>Quick questions and help with installing.</p>',
     btn('Chat on WhatsApp', '#', 'secondary', attrs=' data-whatsapp' + NEW_TAB), ' data-block'),
    ('help', '', 'Support request', '<p>Report a problem with installing, printing or billing. Include your app version and, if you can, a screenshot.</p>',
     btn('Open the support form', '#', 'secondary', attrs=' data-href="forms.support"' + NEW_TAB), ''),
    ('refresh', '', 'Feedback', '<p>Tell us what you like and what we should improve.</p>',
     btn('Give feedback', '#', 'secondary', attrs=' data-href="forms.feedback" data-hide-empty' + NEW_TAB), ' data-block'),
    ('tool', 'note', 'Customization', '<p>Need a feature, report or bill format made for your business? It is a paid service, quoted per request.</p>',
     btn('Request a customization', 'customization.html', 'secondary'), ''),
    ('coffee', 'note', f'Like {NAME}?', f'<p>{NAME} is free. If it saves you time, you can buy me a coffee.</p>',
     btn('Buy me a coffee', COFFEE, 'secondary', attrs=NEW_TAB), ''),
]
contact_body = page_head('Contact', 'Talk to us', 'Questions, problems or ideas — choose whichever way suits you.') + f'''

<section class="page-body">
  <div class="wrap">
    <div class="grid-auto">
{chr(10).join(f'      <div class="card contact-card"{blk}>{tile(i, tone)}<h2 class="h4">{t}</h2>{body}{b}</div>' for i, tone, t, body, b, blk in contact_cards)}
    </div>
  </div>
</section>'''

page('contact.html', 'Contact',
     f'Contact {BUSINESS} about {NAME}: email, WhatsApp, support requests and paid customization.',
     'contact', contact_body)

# ───────────────────────────────── Updates ─────────────────────────────────
changelog_body = page_head('Updates', f'What’s new in {NAME}', 'Every release, newest first. Download the latest version from the <a href="download.html">Download page</a>.') + f'''

<section class="page-body">
  <div class="wrap measure">
    <article class="release" id="v{VERSION}">
      <h2>Version {VERSION} {badge('Latest', 'brand')}</h2>
      <p class="date">{RELEASE_DATE}</p>
      <ul>
        <li><b>Tamil Settings screens read better.</b> PDF Settings, Invoice Settings, Company Info and Software Info now show the full Tamil words: the Reset to default button, template descriptions, and the notes under the invoice settings boxes are no longer cut off.</li>
        <li>Software Info shows the app description in Tamil, and the “Buy me a coffee” button reads clearly in Tamil.</li>
        <li>Shorter, clearer Tamil wording for a few settings labels.</li>
      </ul>
    </article>
    <article class="release" id="v1.0.5">
      <h2>Version 1.0.5</h2>
      <p class="date">{RELEASE_DATE}</p>
      <ul>
        <li><b>Tamil screens read better.</b> Long Tamil labels are no longer cut off with “…”: the sidebar, page titles, dashboard cards and charts, the invoice, customer and product lists, and the Reports menu now show the full words.</li>
        <li>On the New Invoice screen, when the buttons are too narrow for their names, Create goes full width with Save Draft under it.</li>
        <li>Shorter, clearer Tamil wording for a few page subtitles and card notes.</li>
      </ul>
    </article>
    <article class="release" id="v1.0.4">
      <h2>Version 1.0.4</h2>
      <p class="date">{RELEASE_DATE}</p>
      <ul>
        <li>Anonymous usage counts are now on, so we can see how many shops use {NAME}: a short message when the app is first opened, once a day while it is used, and once when the first invoice is made. They never include your business data. Turn them off any time in Settings → Software Info (see the <a href="privacy.html">privacy policy</a>).</li>
      </ul>
    </article>
    <article class="release" id="v1.0.3">
      <h2>Version 1.0.3</h2>
      <p class="date">{RELEASE_DATE}</p>
      <ul>
        <li><b>Automatic backup.</b> Turn it on in Settings → Backup: every day or every week, while the app is open, a copy of your company’s data is saved by itself. Choose a folder inside Google Drive or OneDrive and the copies reach the cloud automatically.</li>
        <li>Keep the last 5, 10 or 30 automatic copies; older automatic copies are removed, and nothing else in the folder is touched.</li>
        <li>A clearer Backup page: saved backups show what they are (automatic, manual, before restore, JSON) with the right date and time.</li>
        <li>A warning on the dashboard if an automatic backup could not be saved, for example when the Drive folder is not available.</li>
      </ul>
    </article>
    <article class="release" id="v1.0.2">
      <h2>Version 1.0.2</h2>
      <p class="date">{RELEASE_DATE}</p>
      <p>The app is the same as version 1.0.1: there are no new features or fixes in this release. If you already have 1.0.1, you don’t need to update.</p>
    </article>
    <article class="release" id="v1.0.1">
      <h2>Version 1.0.1</h2>
      <p class="date">{RELEASE_DATE}</p>
      <p>Fixes and improvements from release testing.</p>
      <ul>
        <li>Stock can be a decimal number, so selling 0.5 kg takes exactly 0.5 from stock.</li>
        <li>Receipts now count as sales in Reports and on the dashboard.</li>
        <li>Tamil text prints correctly on payment receipts, customer statements and report PDFs.</li>
        <li>PDF Settings shows a real sample invoice with your company details as its preview.</li>
        <li>Every user can change their own password from the user menu.</li>
        <li>Importing a backup now checks the file first and never replaces your data with an empty or wrong file.</li>
        <li>Safer billing: a discount cannot make a line negative, quantity 0 is not accepted, and a converted quotation cannot be converted twice.</li>
        <li>The Windows installer also works on ARM laptops, and the Linux AppImage works on newer Ubuntu versions.</li>
      </ul>
    </article>
    <article class="release" id="v1.0.0">
      <h2>Version 1.0.0</h2>
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

page('changelog.html', 'What’s new',
     f'Release notes for {NAME}: what changed in each version.',
     'changelog', changelog_body)

# ───────────────────────────────── Privacy ─────────────────────────────────
privacy_body = page_head('Legal', 'Privacy policy', f'Last updated: {RELEASE_DATE}') + f'''

<section class="page-body">
  <div class="wrap">
    <div class="prose">
    <p>This policy explains what information {BUSINESS} (“we”) handles when you use the {NAME} app and this website. If you have a question about it, write to <a href="mailto:{EMAIL}">{EMAIL}</a>.</p>

    <h2>The {NAME} app</h2>
    <ul>
      <li><b>Your business data stays on your computer.</b> The customers, products, invoices, payments, settings and backups you create are stored on the computer where {NAME} is installed. We do not receive a copy.</li>
      <li><b>Anonymous usage counts.</b> So that we know how many people use {NAME}, the app (from version 1.0.4) sends us a short message when it is first opened, once a day while it is used, and once when the first invoice is created. Each message carries only a random ID made for this purpose, the app version and the operating system (Windows, macOS or Linux). It never includes your customers, products, invoices, amounts or company details. The messages go to a small server we run on Cloudflare, which does not store IP addresses; Cloudflare’s handling is described in the <a href="https://www.cloudflare.com/privacypolicy/" target="_blank" rel="noopener">Cloudflare Privacy Policy</a>. You can turn this off in the app under <b>Settings → Software Info</b>.</li>
      <li><b>Update check.</b> Once a day, when you are online, the app asks GitHub whether a newer version of {NAME} exists; that is an ordinary web request, so GitHub sees your IP address. Apart from this and the usage counts, the app goes online only when you click a link that opens your web browser.</li>
      <li><b>No online account.</b> The app’s usernames and passwords exist only on your computer.</li>
      <li><b>No advertising</b> and no selling of data, ever.</li>
      <li><b>Links you choose to open.</b> Some buttons in the app open a web page in your browser (for example this website, our forms or Buy Me a Coffee). What happens on those pages is covered below or by that site’s own policy.</li>
      <li><b>Backups and PDFs.</b> Files you export or share are handled by you; we have no access to them.</li>
    </ul>

    <h2>This website</h2>
    <ul>
      <li><b>Hosting.</b> This site is hosted on GitHub Pages. GitHub may record technical information such as your IP address when you visit, as described in the <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement" target="_blank" rel="noopener">GitHub Privacy Statement</a>. Installers are downloaded from GitHub as well.</li>
      <li><b>Fonts.</b> The text font (Manrope) is loaded from Google Fonts, so your browser fetches it from Google’s servers when a page opens. Google’s handling of this is described in the <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">Google Privacy Policy</a>.</li>
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
  </div>
</section>'''

page('privacy.html', 'Privacy policy',
     f'How {BUSINESS} handles information for the {NAME} app and website. Your business data stays on your computer.',
     'privacy', privacy_body)

# ────────────────────────────────── Terms ──────────────────────────────────
terms_body = page_head('Legal', 'Terms of use', f'Last updated: {RELEASE_DATE}') + f'''

<section class="page-body">
  <div class="wrap">
    <div class="prose">
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
  </div>
</section>'''

page('terms.html', 'Terms of use',
     f'Terms for using the free {NAME} app, this website and paid customization from {BUSINESS}.',
     'terms', terms_body)

# ───────────────────────────────── Licenses ────────────────────────────────
mit = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'LICENSE'), encoding='utf-8').read().strip()
licenses_body = page_head('Legal', 'Licenses',
                          f'{NAME} is based on Invoiso, whose licence is below. The licences of the open-source packages and fonts built into the app are listed in the app under <b>Settings → Software Info</b>.') + f'''

<section class="page-body">
  <div class="wrap">
    <div class="prose">
    <h2>Invoiso</h2>
    <p>{NAME} is based on Invoiso by ANOOP P, released under the MIT License:</p>
    <pre>{html.escape(mit)}</pre>

    <h2>This website</h2>
    <ul>
      <li><b>Feather icons</b>, released under the MIT License, © 2013–2017 Cole Bemis.</li>
      <li><b>Platform logos</b> (Windows, Apple, Linux) from Simple Icons, released under CC0 1.0. The logos are trademarks of their owners.</li>
      <li><b>Manrope</b> typeface by Mikhail Sharanda, released under the SIL Open Font License 1.1, served by Google Fonts.</li>
    </ul>
    </div>
  </div>
</section>'''

page('licenses.html', 'Licenses',
     f'Licences for software that {NAME} includes.',
     'licenses', licenses_body)

# ─────────────────────────────────── 404 ───────────────────────────────────
nf_body = f'''<section class="wrap not-found">
  <div class="err-code" aria-hidden="true">404</div>
  <h1 class="h2">This page could not be found</h1>
  <p class="lead">The link may be old, or the page may have moved.</p>
  <div class="cta-row" style="justify-content: center">
    {btn('Go to the home page', 'index.html', 'primary', 'lg')}
    {btn(f'Download {NAME}', 'download.html', 'secondary', 'lg', 'download')}
  </div>
</section>'''

page('404.html', 'Page not found', f'This page could not be found on the {NAME} website.', '', nf_body, noindex=True)

print('pages written')

# ───────────────────────── sitemap / robots / llms / manifest ──────────────
pages = ['', 'ta.html', 'download.html', 'customization.html', 'faq.html', 'changelog.html', 'contact.html',
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

> {NAME} is free, open-source (MIT) offline billing and GST invoice software for Windows, macOS and Linux, made by {BUSINESS} (India). It creates invoices, quotations and payment receipts, prints on A4/A5/A6 paper or 58/80 mm thermal printers, and works in English, Tamil, Hindi, Nepali, French, Spanish, Chinese and Tibetan (partly translated). All business data is stored on the user's own computer. The app is free with no subscription; custom features are a paid service quoted per request.

## Pages

- [Home]({SITE}/): what {NAME} does
- [Home in Tamil]({SITE}/ta.html): the same page in Tamil (தமிழ்)
- [Download]({SITE}/download.html): installers for Windows, macOS and Linux, with install steps
- [Customization]({SITE}/customization.html): paid custom features, quoted per request
- [FAQ]({SITE}/faq.html): price, open source, offline use, data storage, GST, printers, languages
- [What's new]({SITE}/changelog.html): release notes
- [Contact]({SITE}/contact.html): email {EMAIL}

## Key facts

- Price: free, no subscription; paid customization on request
- Open source: MIT License
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
