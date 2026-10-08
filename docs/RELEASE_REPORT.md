# Invoiceo 1.0.0 — release report

Date: 8 October 2026 (launch planned for 9 October 2026)
App repo: https://github.com/Maddy-1303/invoiceo (public, MIT, based on Invoiso © 2025 ANOOP P)
Website repo: https://github.com/Maddy-1303/invoiceo-website (GitHub Pages, custom domain invoiceo.in)

## 1. What was checked

A full audit of the app, the website and the release setup, in 8 areas. Each area was reviewed by one agent, and every finding was checked again by a second agent that tried to prove it wrong:

| Area | What it covered | Confirmed findings |
|---|---|---|
| Start | splash, login, forgot / reset password, onboarding, companies, backup and restore, session timeout, DB migrations | 12 |
| Create | the Modern New Invoice / Quotation / Receipt screen, numbering, stock, drafts, conversion | 22 |
| Lists | Invoices, Quotations, Receipts, Customers, Products, Services pages | 16 |
| Frame | sidebar, top bar, dashboard, Settings, Reports header, help | 16 |
| PDF | PDFs, printing, thermal receipts, CSV import / export, reports | 24 |
| Languages | all 8 languages, hard-coded English, dates and numbers | 17 |
| Release | git, GitHub Actions, installers, licence | 16 |
| Website | all pages, links, SEO, phone layout, downloads | 16 |

Some findings appear in two areas (for example "Logout skips the unsaved-invoice prompt").

After that, 6 agents fixed the findings in parallel, each with its own files. A second agent reviewed each group's changes and fixed 12 more problems it found in them. Then everything was merged, translated, analysed and tested.

## 2. Results

- **Tests:** all 420 pass (`flutter test -j 3 test/`). Two old failures were fixed: the leftover "counter" template test (replaced by a version check) and the currency-font test, which now checks the real PDF fallback fonts. One timing-sensitive test (auto-print snackbar) was made robust.
- **flutter analyze:** no errors. 6 old lint notes remain (unused field, unnecessary `!`, curly braces); none affects behaviour.
- **Languages:** 120 new translation keys, each in English, Tamil, Hindi, Nepali, French, Spanish and Chinese.

## 3. What was fixed

### Data safety
- **Import Backup** now asks before it replaces anything. Before, one click overwrote all data.
- **Every restore first saves the current data** as a normal backup (`…_pre_restore_…`), so a wrong restore can be undone.
- JSON restore now also restores drafts and product details (expiry, batch and so on).
- **New databases no longer contain fake company details** (123 Street, 9876543210, info@yourcompany.com). Before, these printed on the first invoices. Onboarding clears them if they are still unchanged.
- **Session timeout** (30 min) saves the invoice being made as a draft before going to Login.
- **Logout and Switch Company** now ask about unsaved invoices first.

### Billing correctness
- **"Create New" after an invoice** no longer carries over the last invoice's discount, custom PDF number, custom fields, GST title or quotation link. The tax rate also goes back to the setting.
- **New Invoice from the sidebar or the + button** always gives a fresh form, including from the "Invoice Created" screen.
- A quotation converted to an invoice keeps the company's GST title (for example "Tax Invoice"), and keeps its link even when saved as a draft. It can no longer be converted twice.
- **Trash returns stock** for invoices and receipts. Restoring from Trash takes it again. A declined invoice can no longer be edited from the dashboard, and editing one never returns stock twice.
- Tax switched off plus "price includes tax": the total now equals the line totals. Before, it was lower.
- In edit mode, the amount paid / due panel uses the live total.
- Quantity cells are red only when stock is really too low. Custom items and edited invoices are no longer red for no reason.
- A charge row with an amount but no label now counts in the total.
- "1,250" typed in price or quantity means 1250. French and Spanish keep the comma as the decimal mark.
- "Save walk-in customer" links the invoice to the customer, including when the phone number belongs to a saved customer.
- The previous balance on the screen now includes earlier same-day invoices.
- The dashboard's "Recent Invoices" no longer lists quotations as "Unpaid".
- Bulk "Mark Paid" appears only on the Invoices list. It used to add payments to quotations and receipts.
- Payments on the first day of a report period are counted. Customer statements put an invoice before a same-day payment.
- Tax rates print without float noise ("28%", not "28.000000000000004%").
- Amount in words works for 100 crore and above.
- The UPI QR prints only on INR invoices.

### Screens (checked with real screenshots at 1440×900)
- Total amounts no longer wrap onto two lines. The GSTIN box shows all 15 characters, and invoice numbers and overdue dates are no longer cut.
- The Products and Customers tables fit a 1280–1366 px laptop without sideways scrolling.
- **The sidebar shows every page on short windows** (720 px and below). Before, Reports and Settings were hidden at the default Windows window size.
- On macOS the app opens at 1280×800 (or maximised on smaller screens), not 800×600.
- Tamil status pills no longer wrap. The Tamil "Partial" / "Unpaid" labels were shortened so they stay readable.
- Money now looks the same everywhere: "Rs. 1,450.00".
- After an edit, delete or payment, the Customers page stays on the same page and the Invoices list moves to the last page that still exists.
- Filtered empty lists say "try adjusting filters" instead of "create your first invoice".
- Settings keeps the open section when switching between Standard and Modern.
- Company and user names refresh after changes in Settings.

### Languages
- Translated: Login, Forgot / Change Password, Help search, Receive Payment, the Accessibility layout card, custom fields, the saved thermal printer, user stats, auto-print, the New Invoice table and panel, and the Filter-by-Customer dialog.
- Nepali no longer saves dates with Devanagari digits, which had made expiry dates disappear. Dates saved that way before are now read correctly too.
- English now says "Cheque" instead of "Check".
- The help content no longer quotes the old developer's USD prices. It points to invoiceo.in, credits Invoiso, lists Tamil and gives the correct data folders.

### Security
- **A password reset code now works only for the username it was made for.** Before, one code could reset any account, including admin. Run the tool as `dart run tool/reset_code_tool.dart sign <installation-id> <username>`. Codes issued before this change no longer work.

### PDFs, printing, CSV
- **macOS: printing works** (print entitlement added) and **backup Download works** (Downloads entitlement added).
- macOS / Linux: "thermal print" now falls back to the normal print dialog instead of a dead end.
- **CSV import** keeps leading zeros and "+" in phone numbers and HSN codes, and no longer merges rows from Excel CSVs.
- Product CSV "Overwrite" keeps the values of columns the file does not have.
- The payment receipt PDF works after the logo is removed.
- Bulk PDF download (ZIP / folder) shapes Tamil correctly.
- Customer / product export PDFs show Tamil, Hindi and other scripts (font theme added).
- Chinese text no longer disappears from invoice PDFs (it uses the system font).
- Thermal text receipts with é, £ or ¥ print as a picture instead of wrong letters.
- PDF file names keep Tamil and other non-Latin customer names.
- "All currencies" report PDFs no longer label mixed sums with one symbol. The Top Customers / Products bars use the right scale.

### Added after the first build (owner's decisions, 8 October)
- **Receipts count as sales** in Reports and on both dashboards (Sales, Collected, Tax, Profit, top products and customers). A receipt is always paid, never outstanding. Invoice counts, invoice status and Outstanding stay invoices-only. Without receipts every number is unchanged (`test/receipts_in_reports_test.dart`).
- **Tamil shaping in payment receipt, customer statement and report PDFs** (built through `ShapedTextRasterizer`, like invoices).
- **The PDF preview uses `printing`'s `PdfPreview`** (free, Apache 2.0). The Syncfusion viewer and its 4 libraries are removed, so there is no commercial licence to manage and the public repo is fully open source.
- **Settings in the Modern layout:**
  - Every section's title bar is gone, and its buttons are in the top bar, like Reports: PDF Reset / Save, Invoice Save, Company Info language / theme / Save, New Company, Backup Refresh, Users Refresh / Add User, Product Details Save.
  - Product Details shows "Customize Product Details" and uses the full width.
  - Top-bar buttons shrink on narrow windows instead of pushing the menus off the edge.
- **Keyboard shortcut list** now includes F11, Ctrl+N, Ctrl+R and Ctrl+K.

### Licence
- Software Info shows "Based on Invoiso © 2025 ANOOP P · MIT License" and a **View licenses** button. The Invoiso licence is registered on that page and bundled in the app.
- The original author's funding file and the old Invoiso build scripts are kept on disk but are not in the public repo.

## 4. Release setup (done)

- **Version 1.0.0** everywhere: pubspec, Software Info, website. CI stamps both from the tag.
- **`.gitignore` was hiding every `CMakeLists.txt`**, so Windows and Linux CI builds would have failed. This is fixed, and the font licences and docs are included now.
- **Windows installer:** has its own AppId. The old one was Invoiso's, so it would have installed over an existing Invoiso. Publisher is Madcreations, and the installer bundles the Microsoft C++ runtime DLLs so the app starts on a fresh Windows.
- **macOS:** the app is named `Invoiceo.app` (it was lowercase `invoiceo.app`).
- **Linux:** the `.deb` starts on a stock Ubuntu. The app now opens `libsqlite3.so.0` when the `-dev` link is missing. The AppImage is built with the new appimagetool, which does not need libfuse2. The deb metadata (maintainer, categories, uninstall message) is fixed.
- **GitHub Actions** (`.github/workflows/build.yml`):
  - The release is published only when every switched-on build passes.
  - `test-v*` tags become pre-releases and never "latest".
  - Fixed-name copies are added for the website: `Invoiceo-Setup-Windows.exe`, `Invoiceo-macOS.dmg`, `Invoiceo-Linux.deb` and `Invoiceo-Linux.AppImage`.
  - A `SHA256SUMS.txt` checksum file is added.
- **Repo variables** set on Maddy-1303/invoiceo:
  - On: `BUILD_WINDOWS`, `BUILD_MACOS`, `BUILD_LINUX_DEB22`, `BUILD_APPIMAGE22`, `INVOICEO_RELEASE`.
  - Off: `BUILD_LINUX_DEB24`, `BUILD_APPIMAGE24`. The 22.04 builds also run on newer Ubuntu.
- **Update check:** once a day the app asks GitHub for the newest release of Maddy-1303/invoiceo, skipping the check when offline. The website privacy page says so.

## 5. Website (done)

- Real screenshots of the Modern app (dashboard, new invoice, invoices, customers, products, reports) with a sample shop. The phone numbers are fake (`12345 000NN`) so no real person gets calls. A 1280 px JPEG is shown, and tapping it opens the full PNG.
- Download buttons point to `https://github.com/Maddy-1303/invoiceo/releases/latest/download/<fixed name>`.
- Mac steps for macOS 15 (Privacy & Security → Open Anyway) and "macOS 12 or later".
- Phones and iPads get a note that Invoiceo needs a computer.
- "Settings → Backup" wording (there is no Backup page).
- Tibetan is marked "partly translated", and auto-print is marked "Modern layout".
- The privacy page mentions the daily update check.
- The 404 page's skip link is fixed, and the site can no longer be "installed" as an app on Android.

## 6. Things you must do

1. **GoDaddy DNS for invoiceo.in** (the site shows GoDaddy's parking page until then):
   - Remove the forwarding and the two parking **A** records for `@` (3.33.130.190 and 15.197.148.33).
   - Add four **A** records for `@`: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
   - Point the **CNAME** for `www` at `maddy-1303.github.io`.
   - When the GitHub certificate is ready (usually within an hour of DNS working), turn on **Enforce HTTPS** at Settings → Pages in the invoiceo-website repo.
2. **Try each installer once before announcing:**
   - On a Mac: install the .dmg, open it via Privacy & Security, print an invoice, and download a backup.
   - On Windows: install the .exe; SmartScreen shows "More info → Run anyway".
   - On Ubuntu: run `sudo apt install ./Invoiceo-Linux.deb`.
3. **Password reset codes** now need the username: `dart run tool/reset_code_tool.dart sign <installation-id> <username>`.

## 7. Known issues (not fixed for 1.0.0)

These were confirmed but left alone because they need a product decision or are larger than a safe day-before-release change:

- Customer / product export PDFs have English column headings.
- Hindi, Nepali, French, Spanish and Chinese each miss 48 older strings, which show in English. Tibetan is about 87% done.
- Stock is counted in whole units: fractional quantities (0.5 kg) are rounded when stock changes.
- In a catalogue with more than 30 products, the "too much quantity" red mark on edited invoices is checked only for products already loaded on screen.
- The UPI QR still prints on quotations (some shops want advance payment). Decide.
- Language and theme can be changed only by an admin (Settings → Company Info).
- Opening an invoice to edit and coming back resets the list's search and filters.
- While still inside Settings, a business-type change shows in the sidebar only after leaving Settings.
- A services-only business still sees product cards on the dashboard.
- Deleting a company leaves its backups in a folder the app no longer lists.
- Dark mode: some white-on-light-blue chips have low contrast.
- The payment dialogs ignore the date-format setting.
- Help answers show links as plain text (not clickable).
- **Existing invoices with tax off and tax-inclusive products** now show their true, higher total, and can turn from Paid to Partial. Check any such invoices after updating.
- Thermal printing on macOS / Linux uses the normal print dialog (the USB plugin works only on Windows).
- **Unsigned installers:** Windows SmartScreen and macOS Gatekeeper show warnings until the apps are code-signed (Windows) and notarised (Apple Developer ID).
- The first website commit (now replaced) showed real-looking phone numbers in two screenshots. GitHub may keep that old commit reachable by its id for a while.

## 8. How to make the next release

1. Change `version:` in `pubspec.yaml` and `AppConfig.version` (CI also stamps them from the tag).
2. Commit, then `git tag -a v1.0.1 -m "Invoiceo 1.0.1"` and `git push origin main v1.0.1`.
3. Watch Actions. The release appears only if all builds pass, and the website's download buttons pick it up automatically.
4. For a trial build, use a `test-v1.0.1` tag. It becomes a pre-release and the website does not change.
5. To refresh the website pictures, run `flutter test tool/screenshots/marketing_screenshots_test.dart`, then `python3 tool/build_website.py ../invoiceo-website`, then commit and push in `invoiceo-website`.
