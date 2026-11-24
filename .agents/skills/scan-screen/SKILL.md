---
name: scan-screen
description: Inspect mobile screens on active devices, harvest UI locators, and build or update standardized Page Object Models (POMs) using a hybrid script + agent workflow.
---

# scan-screen: Screen Inspector & POM Builder

Use this skill when asked to scan a screen, harvest locators for a new page, or update an existing Page Object Model (POM) in `pom/`.

---

## Core Principles & Hybrid Workflow

This skill pairs deterministic script filtering with intelligent agent curation:

1. **Low-Level Extraction:** The script `node scripts/harvest-pom.js <screen> --json` queries `maestro-runner hierarchy` and strips 90% of raw UI noise (status bars, layout containers, dynamic dates) at **zero LLM token cost**.
2. **High-Level Agent Curation:** The AI agent reviews the candidate elements, selects the essential interactive and anchor controls, categorizes them (Happy Path vs. Deep Test), standardizes variable names, and writes the final POM file.

---

## Step-by-Step Procedure

### 1. Navigation & Clarification Check (Rule 5 Gate)
Before scanning:
* Check the connected device display. Is the target screen currently visible?
* If the screen is **NOT visible** and you do not know how to reach it:
  * **STOP immediately and ask the user:**
    > *"I am ready to scan `[screen]`, but it is not currently open on the device. Could you navigate to it on the phone or explain the steps to reach it?"*
* If the screen is a **Cold-Start / Fresh-Install screen** (e.g., `onboarding`):
  * Reset the app to bring up the first launch state:
    ```bash
    adb shell pm clear ${APP_ID}
    adb shell monkey -p ${APP_ID} -c android.intent.category.LAUNCHER 1
    ```

---

### 2. Harvest Pre-Filtered Candidate Elements
Run the harvester in JSON mode to collect clean candidate elements:

```bash
node scripts/harvest-pom.js <screen_name> --json
```

This returns an array of candidates:
```json
[
  { "selector": "org.wikipedia.alpha:id/nav_tab_home", "isId": true, "type": "FrameLayout" },
  { "selector": "Save", "isId": false, "type": "View" }
]
```

---

### 3. Multi-Step / Carousel Handling (Happy Path vs. Deep Test)
If the screen is a multi-slide carousel (such as **Onboarding**):
1. Harvest candidates from **Slide 1**.
2. Tap the forward control (e.g. `tapOn: "Continue"` or swipe) to advance to **Slide 2**.
3. Harvest candidates from **Slide 2**, repeat for all slides.
4. Ensure the POM includes locators for both test strategies:
   * **Happy Path (Bypass / Setup):** `btnSkip`, `btnContinue`, `btnGetStarted`
   * **Deep Test (Feature Verification):** Individual slide headers, language add buttons, privacy toggles.

---

### 4. Curate, Standardize & Write the POM
Write the locator dictionary to `pom/<screen>.pom.js`:
* Structure:
  ```javascript
  // pom/<screen>.pom.js
  // Screen Locators for [<screen>]
  
  output.<screenName>Screen = {
    // Happy Path Controls
    btnSkip: "org.wikipedia.alpha:id/fragment_onboarding_skip_button",
    btnContinue: "org.wikipedia.alpha:id/fragment_onboarding_forward_button",
    btnGetStarted: "org.wikipedia.alpha:id/fragment_onboarding_done_button",

    // Deep Test Anchors & Actions
    headerSlide1: "The Free Encyclopedia",
    btnAddLanguage: "org.wikipedia.alpha:id/addLanguageButton"
  };
  ```

* **Naming Conventions:**
  * Buttons / Clickables: `btn<Action>` (`btnSave`, `btnSkip`)
  * Input Fields: `input<Field>` (`inputSearch`)
  * Navigation Tabs: `nav<Tab>` (`navTabHome`, `navTabSearch`)
  * Text / Headers: `txt<Desc>` or `header<Desc>` (`headerTitle`, `txtFeaturedArticle`)

* **Non-Destructive Merge (Scenario 2):**
  If `pom/<screen>.pom.js` already exists, **never delete or rename existing keys**. Keep all existing keys intact and append newly discovered elements.

---

### 5. Register in `pom/index.js` & Lint
Ensure the POM is registered in `pom/index.js`:
```javascript
runScript("./<screen>.pom.js");
```

Run pre-flight validation:
```bash
npm run lint
```
