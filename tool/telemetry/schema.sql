-- Invoiceo usage counter: one table in a Cloudflare D1 database.
-- Paste this into the D1 database's Console and run it once.
--
-- One row per event. No business data and no IP addresses are stored:
--   install_id  random ID the app creates on first start (not a hardware ID)
--   event       'install' (first start), 'active' (once a day), 'first_invoice'
--   day         UTC date of the event, YYYY-MM-DD
--   version     app version, e.g. 1.0.3
--   os          windows / macos / linux / other
CREATE TABLE IF NOT EXISTS events (
  install_id TEXT NOT NULL,
  event      TEXT NOT NULL,
  day        TEXT NOT NULL,
  version    TEXT NOT NULL,
  os         TEXT NOT NULL,
  at         TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (install_id, event, day)
);
CREATE INDEX IF NOT EXISTS events_event_day ON events (event, day);
