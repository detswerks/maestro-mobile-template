---
name: scan-screen
description: Inspect mobile screens on active devices, harvest UI locators, and build or update standardized Page Object Models (POMs) using a hybrid script + agent workflow.
---

# scan-screen: Screen Inspector & POM Builder

Use this skill when asked to scan a screen, harvest locators for a new page, or update an existing Page Object Model (POM) in `pom/`.

---

## Core Principles & Hybrid Workflow

This skill pairs deterministic script automation with agent curation (following `.agents/AGENTS.md` Rules 1, 2, and 5):

1. **Automated Extraction & Merge (`npm run pom:scan <screen>`):** Runs `scripts/harvest-pom.js <screen>`, which queries `maestro hierarchy`, strips 90% of raw UI noise, non-destructively writes/updates `pom/<screen>.pom.js`, and bundles all `pom/*.pom.js` files into `pom/index.js` (compatible with Maestro's GraalJS runtime without `require()`).
2. **Agent Curation & Verification:** Review the generated `pom/<screen>.pom.js` (or pass `--json` first to inspect raw candidates), refine semantic variable names, and capture any multi-slide or text-anchor locators if needed.

---

## Step-by-Step Procedure

### 1. Navigation & Clarification Check (Rule 5 Gate)
Before scanning:
* Check the connected device display. Is the target screen currently visible?
* If the screen is **NOT visible**, follow **Rule 5** in `.agents/AGENTS.md` (check `context/test-flows.md` / `steps/` first; stop and ask the user if no route is documented).
* If the screen is a **Cold-Start / Fresh-Install screen** (e.g., `onboarding`):
  * Reset and launch the app cleanly using `.env`:
    ```bash
    # Android (reads APP_ID from .env)
    set -a; source .env; set +a
    adb shell pm clear "$APP_ID"
    adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1
    ```
    *(Or on iOS simulator / cross-platform, trigger a flow with `- launchApp: { clearState: true }`.)*

---

### 2. Harvest & Generate/Update the POM
Run the POM harvester directly (automatically creates/merges `pom/<screen>.pom.js` and registers it in `pom/index.js`):

```bash
npm run pom:scan <screen_name>
# Optional flags:
# npm run pom:scan <screen_name> -- --clean     # Rebuild POM from scratch
# node scripts/harvest-pom.js <screen_name> --json  # Inspect raw candidate JSON only
```

Raw `--json` candidate output format:
```json
[
  { "selector": "com.example.app:id/nav_tab_home", "isId": true, "type": "FrameLayout" },
  { "selector": "Save", "isId": false, "type": "View" }
]
```

---

### 3. Multi-Step / Carousel Handling (Happy Path vs. Deep Test)
If the screen is a multi-slide carousel (such as **Onboarding**):
1. Harvest candidates from **Slide 1**.
2. Advance to **Slide 2** (`tapOn` forward control or swipe) and re-run `npm run pom:scan <screen_name>` (non-destructive merge preserves Slide 1 keys).
3. Repeat for all slides and ensure the POM covers both test strategies:
   * **Happy Path (Bypass / Setup):** `btnSkip`, `btnContinue`, `btnDone`
   * **Deep Test (Feature Verification):** Individual slide headers, secondary buttons, toggles.

---

### 4. Curate & Standardize Keys (`pom/<screen>.pom.js`)
Review and refine keys in `pom/<screen>.pom.js` if auto-generated names need clearer semantics:
* Structure:
  ```javascript
  // pom/<screen>.pom.js
  // Screen Locators for [<screen>]

  output.<screenName>Screen = {
    // Happy Path Controls
    btnSkip: "com.example.app:id/btn_onboarding_skip",
    btnContinue: "com.example.app:id/btn_onboarding_next",
    btnDone: "com.example.app:id/btn_onboarding_done",

    // Deep Test Anchors & Actions
    headerSlide1: "Welcome to ExampleApp",
    btnSecondaryAction: "com.example.app:id/btn_learn_more"
  };
  ```

* **Naming Conventions:**
  * Buttons / Clickables: `btn<Action>` (`btnSave`, `btnSkip`)
  * Input Fields: `input<Field>` (`inputSearch`, `inputEmail`)
  * Navigation Tabs: `nav<Tab>` (`navTabHome`, `navTabProfile`)
  * Text / Headers: `txt<Desc>` or `header<Desc>` (`headerTitle`, `txtSubtitle`)

* **Non-Destructive Merge:**
  If `pom/<screen>.pom.js` already exists, **never delete or rename existing keys** that existing steps/tests may already consume.

---

### 5. Verify `pom/index.js` Bundle & Lint
Confirm `pom/index.js` includes the updated `output.<screenName>Screen` dictionary (auto-bundled by `scripts/harvest-pom.js` for Maestro's GraalJS runtime without `require()`).

Validate existing tests and flows:
```bash
npm run lint
```
