# Screen layouts: Standard and Modern

The app has two screen layouts. The user picks one in **Settings → Accessibility → Screen layout**.
The choice is saved per company (setting `ui_layout`) and applies at once.

| Layout | What it is |
|---|---|
| **Standard** | The screens the app came with (the previous developer's design), kept as they are. |
| **Modern** | The new design, built page by page from the designs we are given. A page that has no Modern design yet shows its Standard page, so Modern is always complete and usable. |

**Not part of either layout:** the login, forgot / change password, and first-run onboarding screens. They look
the same in both layouts.

Colours are the same in both layouts (`lib/theme/brand_colors.dart`, `lib/theme/app_theme.dart`).
Only the structure and arrangement of a page differ.

## How it works in the code

- `lib/layouts/ui_layout.dart`: the `UiLayout` enum, the `uiLayoutProvider`, and `loadUiLayout()` which reads the
  saved choice. An install that only had the old Create Invoice choice carries over: `v2` (the previous
  developer's "New" screen) becomes Standard; `modern`, the removed `v1` Classic, or nothing becomes Modern.
- `lib/layouts/layout_page.dart`: `LayoutPage(standard: ..., modern: ...)`. `modern` is optional.
- `lib/screens/dashboard_screen.dart`, `buildScreen()`: every page is listed there through `_page(...)`.
- Default layout: **Modern** (what the app shows today: Modern Create Invoice, everything else Standard).

## The frame (sidebar and top bar)

| Part | Standard | Modern |
|---|---|---|
| Sidebar | The previous developer's sidebar (`_buildSidebar()` in `dashboard_screen.dart`) | **built**: `lib/layouts/modern/modern_shell.dart`, `ModernSidebar`. Logo, company switcher, Dashboard, then **Sales** (New Invoice, Invoices, Quotations, Receipts), **Catalog** (Customers, Products, Services — Products / Services follow the business type in Settings > Company Info: products only, services only or both), **Business** (Reports, Settings), 224 px wide, with a **reduce button** next to the logo that folds it to icons (remembered between runs). It also folds by itself below 900 px wide. **Help & Support** at the bottom, under a line (no version card). |
| Top bar | none | **built**: `ModernTopBar`. **Dashboard only:** "Search anything... (Ctrl+K)" (opens the Help & Settings search for now; Ctrl+K works on every page). **Every other page:** its title (and subtitle) in that place. Then the page's own buttons, a **+** button (New Invoice / New Quotation / New Receipt) — or the page's full **"+ Create …"** button in its place, and the user menu (Settings, Buy me a coffee, Help & Support, Logout). **No notification bell.** |

The Modern frame sits around whichever page is open. A Modern page sends its title, subtitle and buttons to the
top bar (`lib/layouts/modern/modern_page_header.dart`: `ModernHeaderScope` around the page, the page uses
`ModernHeaderPublisher.publishModernHeader` from its build). Pages that still use their Standard design show their
name in the top bar and keep their own page header under it.

## Pages

| # | Page | Standard (source) | Modern |
|---|---|---|---|
| 0 | Dashboard | `dashboard_screen.dart` (`DashboardHome`): the previous developer's design, with its own four dashboard layouts (Default, Classic, Bento, Simple Feed). The greeting banner is back to the original dark gradient. | **built**: `lib/layouts/modern/modern_dashboard.dart`. One design only (no layout picker): greeting and date range (this month by default); four cards (revenue collected, outstanding, invoices, each vs the period before; products with the low-stock count); sales overview (collected / outstanding per month, last 6 or 12 months); invoice status donut (paid, unpaid, partial, overdue); recent invoices (view, print, edit / duplicate / details); low-stock products (update stock); quick actions. Product pictures are not shown yet. |
| 1 | New Invoice / Quotation / Receipt | `create_invoice_screen_v2.dart`: the previous developer's "New" screen | **built**: `create_invoice_screen_modern.dart`. **Top bar:** title, subtitle and the **date** chip (no back button, no number chip: the number choice is in Invoice Details); when editing, a full **"+ Create Invoice"** button replaces the +. Customer box: **name** (search the saved customers or type a walk-in name), **phone, GSTIN / VAT, address** (one line on a wide window, otherwise the name on top and the rest under it), **Save customer** (a new one) or **Update customer** (a picked one that was changed; a picked customer's boxes can be changed straight away, no pencil; a changed phone asks "update this customer or save as new" first) / refresh / clear. The search box always shows; the details **open when the customer box is clicked** or a customer is picked, and **close when the product search is used**; the arrow opens / closes them by hand; no Add New dialog; items card (search, Custom Item, Items count, Clear All, Qty / Unit / Price / Discount edited in the table; no "Add another item" button); the items card runs down to the bottom of the page; right panel, 360 px wide (Invoice Details with Advanced Options, Charges & Adjustments, totals with "Tax (GST 18%)", then **Save Draft** and **Create ▾** with "Create and start a new one" and "Save & Print"; the close button folds it to a slim strip with the total, a Save Draft icon and a Create icon with its ▾). No bottom bar and no status card (a narrow window without the panel keeps the two buttons at the bottom). Ctrl+S / Ctrl+P / F11 as before. Leaving with unsaved changes asks Keep Editing / Discard / **Save Draft** (new documents only) / Save. **Created screen:** top bar "Invoice Created" with a back arrow to the list; a compact white card with a small green tick (no confetti); "{Type} Created Successfully!", the number with a copy button, tiles View Details / Preview PDF / Download PDF / Print, the save-walk-in-customer offer, "Create New Invoice" (Ctrl+N) and "Create New Receipt" (Ctrl+R) — this document's type is the filled button on the right — and "Go to Invoices / Quotations / Receipts". Drafts: `invoice_drafts` table, listed at the top of the Invoices / Quotations / Receipts pages with Continue and Delete. |
| 2 | Invoices | `invoice_management_screen_v2.dart` (`filterType: 'Invoice'`) | **built**: the same screen with `modern: true` (`_buildModern`). **Top bar:** title and subtitle, download by range, CSV, trash, refresh, and a full **"+ Create Invoice"** (Quotation / Receipt) button in place of +. **Tabs:** All Invoices (n) / Drafts (n) — saved drafts are in their own tab (customer, items, total, saved on, Continue, delete). **Filter row:** search, Customer ▾, **Filter ▾** (status all / unpaid / paid / partial / overdue, dates all / today / this month / last month / last 3 months / this year / custom, More Filters for due date, number range, hide paid / declined, Clear), **Sort ▾** (number, date, customer, either way), **Columns ▾** (show / hide Title, Date, Items, Total, Status, Outstanding; remembered: `invoice_list_hidden_columns`). No stat cards, no status chips. Table (click **Date** to sort) with Rows per page and Previous / Page x of y / Next on a padded bar at the bottom of the card. Row buttons: eye = **PDF preview** (not the details dialog), pencil = edit, ⋮ = Apply Payment, Download PDF, Print, Duplicate, Mark declined, Move to Trash. Narrow or short windows scroll the whole page; below 1000 px wide the row buttons go into ⋮. |
| 3 | Quotations | same screen, `filterType: 'Quotation'` | **built**: same Modern page (All Quotations / Drafts); Filter ▾ has dates only; ⋮ also has Convert to Invoice and Mark as sent / accepted / declined. |
| 4 | Receipts | same screen, `filterType: 'Receipt'` | **built**: same Modern page (All Receipts / Drafts); Filter ▾ has dates only. |
| 5 | Customers | `customer_management_screen_v2.dart`, with our tidy header, toolbar and table layout | **built**: the same screen with `modern: true` (`_buildModern`). **Top bar:** "Customer Management" and its subtitle, Import, Export, ⋯ (refresh, Hide / Show stat cards, the outstanding currency, Export PDF, Delete All) and a full **"+ New Customer"** button in place of + (opens the New Customer panel). Four tinted stat cards (Total Customers, Businesses, Individuals, GST Registered; no trend — the add date is not saved). Filter card: search, **Customer Type ▾**, **Columns ▾** (Contact, GST / VAT No, Type, Outstanding, Address; remembered: `customer_list_hidden_columns`) and chips All / Businesses / Individuals / GST Registered / With Outstanding / Without GST with counts. Table: tick boxes (Delete selected), #, avatar + name (info) + business / "Individual", contact (phone, email), GST / VAT No, Type pill, Outstanding; click **Name** or **Outstanding** to sort; buttons eye (view), statement, edit, ⋮ (Receive Payment, Delete). No Status column (no status is saved). Footer: "Showing x to y of z customers", Rows per page, ‹ page numbers ›. Narrow windows scroll the table sideways. |
| 6 | Products | `product_management_screen_v2.dart`, with our tidy header, toolbar and table layout (the combined products + services list) | **built**: the same screen with `modern: true, kind: 'product'`. **Top bar:** "Product Management", "Manage your products, inventory and pricing", Import, Export, ⋯ (refresh, Hide / Show stat cards, Export PDF, Delete All — products only) and a full **"+ New Product"** button in place of +. Cards: Total Products, In Stock (untracked or more than 10), Low Stock (1–10), Out of Stock (in stock + low + out = total). Filter card: search (name, alias, HSN / SAC, **SKU**), **Columns ▾** (same column choice and limit of 10 as Standard, plus Customize) and chips All / In Stock / Low Stock / Out of Stock / Expired (when the expiry field is on) with counts. Sort by clicking the Product, Selling Price or Stock heading. Hide / Show stat cards is in ⋯. Table: tick boxes (Delete selected), #, product (+ alias), the chosen columns (SKU, HSN / SAC, purchase price, …), **Selling Price** (click to sort), Stock (coloured), **Status** pill, actions eye (details), edit, **duplicate** ("… (copy)", no stock, opens its edit form) and delete (admin). No pictures, no grid view, no Category filter (not saved yet). Footer: "Showing x to y of z products", rows per page, ‹ page numbers ›. Narrow windows scroll the table sideways. |
| 9 | Services | the combined page (Standard), opened on its Services tab | **built**: the same screen with `modern: true, kind: 'service'` — its own sidebar item under Catalog. **Top bar:** "Service Management", "Manage your services and pricing", Import / Export / ⋯ (Delete All — services only) and **"+ New Service"**. Cards and chips: Total Services, With Tax (above 0%), Tax-free (0%), Without SAC. Columns ▾ (its own choice, no stock or product-only fields); sort by the Service or Price heading. No Stock or Status column. Exports contain only services. |
| 7 | Reports | `reports_screen.dart` | design kept. In the Modern frame the **top bar shows the open report** ("Revenue", "Receivables", "Tax", …, subtitle "Reports") with the refresh button, in place of the page's own "Reports" bar. The left list (reports, currency, period) scrolls as one, so a short window no longer overflows. |
| 8 | Settings | `settings/settings_screen.dart` and its sub-pages (Company info, Companies, Backup, Users, PDF settings, Invoice settings, Product columns, Customization, Accessibility, App info) | design kept. In the Modern frame the **top bar shows the open section** ("PDF Settings", "Invoice Settings", …, subtitle "Settings"). The section rail scrolls (no bottom overflow). PDF Settings below 900 px: templates and options side by side at full width, then the preview (stacked below 600 px). Invoice Settings below 900 px: only Save stays at the bottom; the custom-fields card scrolls with the form. Software Info: developer **Madhan Prasath**. |

## Adding a Modern page

1. Build the new page as its own file (for example `lib/screens/invoices_modern.dart`). Use the same providers,
   repositories and services as the Standard page, so it works the same.
2. In `buildScreen()`, pass it as `modern:` for that page:
   `_page(() => StandardPage(...), modern: () => ModernPage(...))`.
3. Add a widget test for it, and update the table above.

## Removed

- The V1 "Classic" Create Invoice screen and the old V1 pages (Customers, Invoices, Products, Users, Invoice
  Settings, PDF Settings) were removed on 2026-10-07. A copy is in
  `invoiceo-removed-classic-backup-2026-10-07` next to the project folder.
- The invoice PDF templates named "Classic" and "Grid Classic" are customer-facing invoice designs, not app
  screens. They are unchanged.
