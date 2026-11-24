# AGENTS.md: Rules & Operating Context for AI Coding Agents

You are operating inside **Maestro Mobile Template**, a mobile UI test automation repository powered by **maestro-runner** and standard **Maestro YAML** flows.

When generating, maintaining, or debugging tests in this repository, you must strictly follow these rules:

---

## 1. Strict 3-Tier Architecture

To eliminate selector duplication and ensure maintainability, all code belongs to one of three tiers:

1. **`pom/<screen>.pom.js` (Tier 1: Locators Only)**
   * Single source of truth for element IDs, accessibility labels, and text locators.
   * **Rule:** Contains **NO action commands** (no `tapOn`, `inputText`, `scroll`). Exposes pure locator dictionaries on `output.<screenName>`.
   * Register every new screen in `pom/index.js`.

2. **`steps/<feature>/<action>.yaml` (Tier 2: Reusable Actions)**
   * Reusable multi-step UI flows (e.g., login, onboarding, permissions).
   * **Rule:** Imports POMs via `runScript` and uses `${output.<screenName>.<locator>}`. Never hardcodes selectors or test data.

3. **`tests/<feature>/<scenario>.yaml` (Tier 3: Scenarios & Assertions)**
   * End-to-end test scenarios.
   * **Rule (Zero Hardcoded Selectors):** Never hardcode raw element IDs or selector texts in `tests/`.
   * Orchestrates steps using `runFlow` and asserts states using POM locators (`assertVisible: id: ${output.<screenName>.<locator>}`).

---

## 2. Live Screen Inspection & Discovery Rules

* **Never guess or hallucinate element selectors.**
* When an element ID is unknown or a screen is not yet cataloged:
  1. Inspect the live active screen using the `scan-screen` skill or:
     ```bash
     npm run pom:scan <screen_name>
     # Or directly:
     maestro-runner --platform android hierarchy --compact
     maestro-runner --platform android hierarchy --find "<keyword>"
     ```
  2. Extract the verified `id` (or text regex if no ID exists).
  3. Create/update the POM in `pom/<screen>.pom.js` and register it in `pom/index.js`.

---

## 3. Test Data Management (`data/`)

* Store static fixtures and dynamic mock generators in `data/*.js`.
* Load them in tests using `- runScript: ../../data/<fixture>.js`.
* Access data via `${output.<dataNamespace>.<fieldName>}`.

---

## 4. Test Execution & Determinism Rules

* **Mandatory Clean State (`launchApp: clearState: true`):** Every test scenario in `tests/` must begin with `- launchApp: clearState: true`. This guarantees complete test isolation, prevents cache or preference pollution across runs, and ensures tests can execute independently in any order. Any prerequisites must be declared explicitly via Tier 2 `steps/`.
* **Pre-flight Lint:** Always run `maestro-runner lint tests/` before executing to ensure no broken `runFlow` paths or syntax errors exist.
* **Preserve `appId`:** Always keep `appId: ${APP_ID}` in flow headers.
* **No Arbitrary Sleeps:** Never add `- wait: <ms>` unless waiting for external time-delayed events. Maestro commands wait automatically up to their timeout.
* **Text Input:** Always `tapOn` an input field before `inputText`, and use `eraseText` first to avoid appending characters to pre-filled fields.
* **Telemetry & Drivers:** Always include `MAESTRO_RUNNER_NO_TELEMETRY=1`. Default to `--driver uiautomator2` on Android and `--driver wda` on iOS.

---

## 5. Navigation Clarity & Clarification Gate (Zero Blind Exploration)

* **Never guess navigation paths or explore blindly:**
  If you are asked to scan a screen or automate a feature, and:
  1. The target screen is not currently visible on the active device, AND
  2. The navigation path to reach it is not documented in `context/app-description.md` or existing `steps/`,
  
  **You MUST STOP and ask the user for directions before performing any actions.**

* **When to Pause and Ask:**
  * **When Harvesting a POM:** If asked to scan a screen whose location is unknown, ask:
    > *"I am ready to scan `[screen]`, but it is not visible on the active screen. Could you explain the steps to reach it, or navigate to it on the connected device?"*
  * **When Generating a Test:** If asked to automate a feature whose entry point is unclear, ask:
    > *"I want to automate `[feature]`, but I cannot find where it is accessed from. Could you provide the starting screen and navigation steps to open it?"*

* **Strict Ban on Guessing:** It is strictly forbidden to tap random buttons, guess URLs/deep links, or click through unrelated menus hoping to stumble upon the feature.

---

## 6. Targeted Test Execution, Single-Pass Rule & Flow Knowledge Maintenance

* **Targeted Test Execution (Zero Full-Suite Runs):**
  * Never run the entire `tests/` directory (`maestro-runner test tests/`) during test generation, bug fixing, or feature verification.
  * Only execute the specific target test file being authored or modified, plus any directly affected dependent test files if shared `steps/` or `pom/` entries were updated.
* **Single-Pass Completion (No Redundant Re-Runs):**
  * When a test flow passes 100% on execution, **stop immediately**.
  * Never re-run a passing test flow to "double check" or test for flakiness unless explicitly requested by the user.
* **Living Navigation Graph (`context/test-flows.md`):**
  * **Before authoring any test:** Always consult `context/test-flows.md` to map screen transitions and reusable action steps from the starting screen to the target screen. Never reinvent or guess navigation paths if a route is documented.
  * **After completing and verifying a test:** Update `context/test-flows.md` with any new screens, screen transitions, reusable steps, parameters, or edge-case gotchas discovered during the session. Keep the Mermaid graph and routing table synchronized.

---

## 7. Maestro Runner CLI & Tooling Reference

`maestro-runner` is a single Go binary that runs Maestro YAML flows directly without requiring a JVM or standard Maestro installation.

### 7.1 Diagnostic & Environment Commands
```bash
# Verify local toolchain, dependencies, and platform drivers
npx maestro-runner doctor

# List all active/connected physical devices and emulators
npx maestro-runner devices
npx maestro-runner devices --json # Machine-readable device list for automation
```

### 7.2 Live Screen Inspection & Locator Discovery
```bash
# Print active UI hierarchy in compact format (one element per line)
npx maestro-runner --platform android hierarchy --compact

# Search active screen hierarchy for specific keyword or text
npx maestro-runner --platform android hierarchy --find "Search Wikipedia"

# Capture a full screenshot of the active device screen
npx maestro-runner --platform android screenshot screenshot.png
```

### 7.3 Test Execution & Core Flags
```bash
# Standard targeted test execution (Android default)
npx maestro-runner --env-file .env --driver uiautomator2 test tests/<feature>/<test-file>.yaml

# iOS simulator / device execution
npx maestro-runner --env-file .env --platform ios --driver wda test tests/<feature>/<test-file>.yaml

# Web / Desktop Chrome execution
npx maestro-runner --platform web --headed test tests/<feature>/<test-file>.yaml

# Passing dynamic environment variables
npx maestro-runner test -e KEY=value -e ANOTHER_KEY=value tests/<feature>/<test-file>.yaml

# Running tests filtered by tags
npx maestro-runner test --include-tags smoke --exclude-tags flaky tests/

# Install app package before test execution (.apk, .app, .ipa)
npx maestro-runner --app-file app.apk test tests/<feature>/<test-file>.yaml

# Parallel execution across multiple devices
npx maestro-runner --parallel 2 test tests/

# Screen recording (saves recording.mp4 in report assets)
npx maestro-runner --record test tests/<feature>/<test-file>.yaml
```

### 7.4 Pre-flight Syntax & Flow Validation
```bash
# Validate flow syntax, references, and runFlow paths without waking a device
npx maestro-runner lint tests/
npx maestro-runner lint tests/<feature>/<test-file>.yaml
```

---

## 8. Test Reports & Failure Triage

Every execution generates structured test run results under `./reports/<timestamp>/` (or custom directory via `--output <dir>`):

### 8.1 Report Structure
* **`report.html`**: Visual, human-readable HTML test summary with step-by-step screenshots and durations.
* **`report.json`**: Top-level summary containing overall status, pass/fail counts, total duration, and flow metadata.
* **`flows/<flow-name>.json`**: Detailed per-step execution log, exact duration, status, and failure messages for each command.
* **`junit-report.xml`**: Standard JUnit XML format for CI/CD integration.
* **`assets/`**: Captured screenshots, error hierarchy dumps, and video recordings (`recording.mp4` when `--record` is used).

### 8.2 Failure Triage Protocol
When a test fails, follow this triage procedure before modifying any code:
1. **Inspect Failed Step Details:** Check the terminal output or the specific error recorded in `./reports/<timestamp>/flows/<flow-name>.json`.
2. **Review Failure Visuals:** Open the failure screenshot in `./reports/<timestamp>/assets/` to see the actual visual UI state at the moment of failure.
3. **Check Error Hierarchy:** Inspect the element tree dump in `./reports/<timestamp>/assets/` to determine if an ID changed, an unexpected modal is covering the screen, or an element is not clickable.
4. **Fix Root Cause:** Update the appropriate Tier (POM locator in Tier 1, reusable action in Tier 2, or assertion in Tier 3), then run a single targeted re-test to verify.


