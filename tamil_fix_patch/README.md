# Tamil / Indic PDF fix + Windows TEST build

Two patches, made against Invoiso v4.4.6:

| File | What it does | Send to the developer? |
|---|---|---|
| `tamil_fix.patch` | Shapes Indic text in all 7 PDF templates (as images) and prints Indic receipts on thermal printers as images. Adds tests. 16 files. | Yes (after review) |
| `test_build_identity.patch` | Makes a build that can sit next to a real Invoiso without touching it. | **No - test builds only** |

## What the identity patch changes (so real installs are untouched)
- New Windows installer ID + name "Invoiso Tamil Test": installs side by side, never replaces real Invoiso.
- Own data folder (`%APPDATA%\Invoiso Tamil Test\Invoiso Tamil Test`): does not read or change real Invoiso data.
- Update checker off: no "update available" prompts to the original project.
- Version shows as `v4.4.6-tamil-test`.

## Steps
1. On GitHub, fork `Anooppandikashala/invoiso` to your account.
2. In Terminal:
   ```bash
   git clone https://github.com/<your-username>/invoiso.git
   cd invoiso
   git checkout -b tamil-windows-test
   git apply --check /path/to/tamil_fix_patch/tamil_fix.patch
   git apply /path/to/tamil_fix_patch/tamil_fix.patch
   git apply /path/to/tamil_fix_patch/test_build_identity.patch
   git add -A && git commit -m "Tamil/Indic PDF shaping + thermal image print (test build)"
   git push -u origin tamil-windows-test
   ```
   If `git apply --check` complains, the project has changed since v4.4.6; use `git apply --3way` and resolve.
3. On your fork: **Actions** tab -> enable workflows. Then **Settings -> Secrets and variables -> Actions -> Variables** -> add `BUILD_WINDOWS` = `true`.
   Do NOT add `INVOISO_RELEASE` (that would publish a public Release).
4. Tag the commit with a `v` tag (NOT `test-v`):
   ```bash
   git tag v4.4.7
   git push origin v4.4.7
   ```
5. Open the **Actions** run, wait for "Build Windows", and download the artifact **Invoiso-Windows-Installer**. Unzip it: it contains the setup `.exe`.
6. Windows will warn (unsigned): **More info -> Run anyway**.

## Not verified
- Never built or run on Windows.
- Thermal image printing needs a PDF-to-image step (`Printing.raster`) that depends on a component fetched during the Windows build.
- Never tested on a real thermal printer.
