# AGENTS.md: Rules & Operating Context for AI Coding Agents

You are operating inside **Maestro Mobile Template**, a mobile UI test automation repository powered by the official **[Maestro CLI](https://maestro.mobile.dev/)** (`maestro`) and standard **Maestro YAML** flows.

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
     maestro hierarchy --compact
     maestro hierarchy
     ```
  2. Extract the verified `id` (or text regex if no ID exists).
  3. Create/update the POM in `pom/<screen>.pom.js` and register it in `pom/index.js`.

---

## 3. Test Data Management (`data/`)

* Store static fixtures and environment-aware (`staging` / `production`) mock generators in `data/*.js`.
* Load them in tests using `- runScript: ../../data/<fixture>.js`.
* Access data via `${output.<dataNamespace>.<fieldName>}`.

---

## 4. Test Execution & Determinism Rules

* **Mandatory Clean State (`launchApp: clearState: true`):** Every test scenario in `tests/` must begin with `- launchApp: clearState: true`. This guarantees complete test isolation, prevents cache or preference pollution across runs, and ensures tests can execute independently in any order. Any prerequisites must be declared explicitly via Tier 2 `steps/`.
* **Pre-flight Syntax Check:** Always validate modified files before executing (`maestro check-syntax tests/<feature>/<scenario>.yaml` or `maestro check-syntax steps/<feature>/<action>.yaml`, or `npm run lint`).
* **Preserve `appId`:** Always keep `appId: ${APP_ID}` in flow headers.
* **No Arbitrary Sleeps:** Never add `- wait: <ms>` unless waiting for external time-delayed events. Maestro commands wait automatically up to their timeout.
* **Text Input:** Always `tapOn` an input field before `inputText`, and use `eraseText` first to avoid appending characters to pre-filled fields.
* **Analytics Opt-Out:** Set `MAESTRO_CLI_NO_ANALYTICS=1` when running CLI commands.

---

## 5. Navigation Clarity & Clarification Gate (Zero Blind Exploration)

* **Consult `context/test-flows.md` First When Unsure:**
  Whenever you are uncertain how to reach a screen, handle a modal/popup, or pick a selector pattern, **check `context/test-flows.md` first** (the Mermaid navigation graph, routing table, and *Learned Nuances & Anti-Patterns*) before asking the user or interacting with the device.
* **Never guess navigation paths or explore blindly:**
  If you are asked to scan a screen, create a step, or automate a feature, and:
  1. The target screen is not currently visible on the active device, AND
  2. The navigation path to reach it is not documented in `context/test-flows.md`, `context/app-description.md`, or existing `steps/`,

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
  * Never run the entire `tests/` directory (`maestro test tests/`) during test generation, bug fixing, or feature verification.
  * Only execute the specific target test file being authored or modified, plus any directly affected dependent test files if shared `steps/` or `pom/` entries were updated.
* **Single-Pass Completion (No Redundant Re-Runs):**
  * When a test flow passes 100% on execution, **stop immediately**.
  * Never re-run a passing test flow to "double check" or test for flakiness unless explicitly requested by the user.
* **Living Navigation Graph (`context/test-flows.md`):**
  * **Before authoring any test:** Always consult `context/test-flows.md` to map screen transitions and reusable action steps from the starting screen to the target screen. Never reinvent or guess navigation paths if a route is documented.
  * **After completing and verifying a test:** Update `context/test-flows.md` with any new screens, screen transitions, reusable steps, parameters, or edge-case gotchas discovered during the session. Keep the Mermaid graph and routing table synchronized.

---

## 7. Official Maestro CLI Reference

### 7.1 Diagnostic & Environment Commands
```bash
# Verify Maestro CLI version and connected devices
maestro --version
maestro list-devices
```

### 7.2 Live Screen Inspection & Locator Discovery
```bash
# Print active UI hierarchy in JSON format
maestro hierarchy

# Print active UI hierarchy in compact CSV format
maestro hierarchy --compact
```

### 7.3 Test Execution & Core Flags
```bash
# Standard targeted test execution (source .env for APP_ID / APP_ENV)
set -a; source .env; set +a
MAESTRO_CLI_NO_ANALYTICS=1 maestro test -e APP_ID="$APP_ID" -e APP_ENV="$APP_ENV" tests/<feature>/<test-file>.yaml

# Or via scripts/run.sh (handles .env, tag filtering, lint, and HTML reports)
./scripts/run.sh --env staging tests/<feature>/<test-file>.yaml

# Passing dynamic environment variables
MAESTRO_CLI_NO_ANALYTICS=1 maestro test -e KEY=value -e ANOTHER_KEY=value tests/<feature>/<test-file>.yaml

# Running tests filtered by tags
MAESTRO_CLI_NO_ANALYTICS=1 maestro test -e APP_ID="$APP_ID" --include-tags smoke --exclude-tags demo tests/

# Sharded parallel execution across multiple devices
MAESTRO_CLI_NO_ANALYTICS=1 maestro test -e APP_ID="$APP_ID" --shard-split 2 tests/

# Detailed HTML report output
MAESTRO_CLI_NO_ANALYTICS=1 maestro test -e APP_ID="$APP_ID" --format HTML-DETAILED --output reports/report.html --test-output-dir reports/latest tests/<feature>/<test-file>.yaml
```

### 7.4 Pre-flight Syntax Validation
```bash
maestro check-syntax tests/<feature>/<test-file>.yaml
maestro check-syntax steps/<feature>/<action>.yaml
npm run lint # Validates all flows under steps/ and tests/
```

---

## 8. Test Reports & Failure Triage

When executed via `scripts/run.sh` (or `maestro test --test-output-dir`), outputs are saved under `./reports/<timestamp>/`:

* **`report.html`**: Detailed HTML report (`--format HTML-DETAILED` or `HTML`).
* **`manifest.json` / `commands.json`**: Execution metadata and per-step command details.
* **`logs/` & `takeScreenshot/`**: Runner logs and screenshots captured during the flow.

### Failure Triage Protocol
1. **Inspect Failed Step Details:** Check the terminal output, `report.html`, or `commands.json` inside `./reports/<timestamp>/`.
2. **Review Logs & Screenshots:** Inspect `logs/` and any failure screenshots in `./reports/<timestamp>/`.
3. **Check Live Hierarchy:** Run `maestro hierarchy` if needed to verify changed IDs, unexpected modals, or scroll state.
4. **Fix Root Cause:** Update the appropriate Tier (POM locator in Tier 1, reusable action in Tier 2, or assertion in Tier 3), then run a single targeted re-test to verify.
