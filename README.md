# Maestro Mobile Template

> A modern, production-grade starter template for mobile UI test automation powered by **[maestro-runner](https://github.com/devicelab-dev/maestro-runner)** and standard **[Maestro](https://maestro.mobile.dev/)** YAML flows.

Built with a strict **3-Tier Architecture** (Locators ➔ Actions ➔ Scenarios), native local emulator lifecycle management, zero Java/JVM dependencies, 100% open-source drivers by default, and built-in AI coding agent skills.

> **Platform Status Note:** This template has been tested and verified on **Android** only (`uiautomator2`). Support flags for **iOS** (`wda`) and **Web** (`cdp`) are included from `maestro-runner`, but have **not yet been tested or verified** in this repository.

---

## Why Maestro Mobile Template?

* ⚡ **Zero JVM Overhead**: Powered by `maestro-runner`, a native Go runtime that boots in ~20ms (vs 4–6s JVM warmup) and uses ~27MB RAM.
* 📱 **Auto-Start Emulators & Simulators**: Automatically boots local Android AVDs or iOS Simulators, runs tests, and shuts them down cleanly.
* 🧩 **Strict 3-Tier Architecture**:
  * **`pom/`** ➔ Pure locator dictionaries (zero action commands, zero selector duplication).
  * **`steps/`** ➔ Reusable action subflows consuming POM locators.
  * **`tests/`** ➔ Declarative test scenarios (**100% zero hardcoded selectors**).
* 🔒 **100% Open-Source & Private**:
  * Defaults to open-source drivers (`uiautomator2` on Android, `wda` on iOS).
  * Telemetry disabled by default (`MAESTRO_RUNNER_NO_TELEMETRY=1`).
* 🤖 **AI-Agent Ready**: Includes pre-configured agent instructions (`.agents/AGENTS.md`) and custom skills (`.agents/skills/`) for agents like Antigravity, Claude Code, and Cursor.
* 🖥️ **Easy-to-Read CLI Output & Free Local Reports**: Clear terminal summary with step-by-step pass/fail/skip timings alongside instant HTML (`report.html`), JSON (`report.json`), JUnit XML, and Allure outputs in `./reports/` (with automatic on-failure screenshots and UI hierarchy dumps) without requiring paid cloud subscriptions.

---

## Repository Structure

```text
.
├── .agents/
│   ├── skills/
│   │   ├── scan-screen/            # Live screen inspection & POM builder (Tier 1)
│   │   ├── generate-step/          # Reusable action subflow generator (Tier 2)
│   │   └── generate-test/          # End-to-end test generator & verifier (Tier 3)
│   └── AGENTS.md                   # Agent rules, CLI reference, and triage protocol
├── context/
│   ├── app-description.md          # App overview, testing scope & guardrails
│   └── test-flows.md               # Living navigation graph & screen routing table
├── pom/                            # Page Object Models (Screens & locator dictionaries ONLY)
│   └── index.js                    # Central locator aggregator (loads all POMs)
├── steps/                          # Reusable action blocks / subflows (consume POM selectors)
├── data/                           # Environment-aware test data fixtures (staging & production)
├── tests/                          # End-to-end test scenarios (single source across envs)
├── scripts/
│   ├── harvest-pom.js              # Automated live screen POM harvester (`npm run pom:scan`)
│   └── run.sh                      # Interactive & CLI test runner (env, tags, lint, reports)
├── .env.example                    # Single environment configuration template
├── package.json                    # Runner version pinning, npm test scripts & configs
└── README.md                       # Getting started guide
```

---

## Getting Started

### 1. Prerequisites

* **Node.js** (v18+) & **npm**
* **For Android Testing:**
  * Android SDK Platform-Tools (`adb` and `emulator` available in your system `$PATH`).
  * At least one Android Virtual Device (AVD) created (via Android Studio or `avdmanager`), or a physical phone via USB.
* **For iOS Testing (macOS only):**
  * Xcode and Xcode Command Line Tools (`xcrun simctl`).

> Need help setting up a phone or emulator? See the [Device & Emulator Setup Guide](#device--emulator-setup-guide) at the bottom of this README.

Verify your environment toolchain at any time:
```bash
npm run doctor
```

---

### 2. Installation & Setup

1. **Create your own repository from this template:**
   * If you are building your own automation project, click **"Use this template" ➔ "Create a new repository"** on GitHub (instead of cloning this template repo directly), then clone **your** newly created repository:
     ```bash
     git clone <your-new-repo-url>
     cd <your-repo-folder>
     ```
   * *(Only clone this repository directly if you are just evaluating or contributing to the template itself.)*

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Open `.env` and set your staging and production App IDs (plus default `APP_ID` / `APP_ENV`):
   ```dotenv
   # Environment Profile & Target App IDs
   APP_ENV="staging"
   APP_ID="com.example.app.staging"
   STAGING_APP_ID="com.example.app.staging"
   PRODUCTION_APP_ID="com.example.app"

   # Runner Controls
   TEST_RETRIES="0"
   MAESTRO_RUNNER_NO_TELEMETRY=1
   MAESTRO_ENV_FILE=".env"
   ```
   *(A single `.env` file serves both local runs and CI/CD—just switch by environment name `staging` or `prod`/`production` without typing package IDs manually.)*

4. **Describe your application scope:**
   Copy `context/app-description.example.md` to `context/app-description.md` (or update the existing file) with your app overview, first-launch behavior, main screen names, and out-of-scope guardrails.

---

### 3. First-Time Quickstart (Using AI Skills)

Once `.env`, `context/app-description.md`, and your device/emulator are ready (`npm run doctor` passes), choose how you want to create your first test:

1. **Goal-First with `/generate-test` *(Recommended)*:**
   Ask your AI agent to automate your first entry/smoke scenario directly—for example:
   > `"/generate-test to dismiss onboarding and verify the Home screen"`

   The agent will automatically check `context/app-description.md` & `context/test-flows.md`, scan visible screens via `scan-screen` (`npm run pom:scan`), generate reusable `steps/` via `generate-step`, create and run the test once in `tests/`, and seed `context/test-flows.md` with your first verified route. *(If a screen isn't visible yet and no path is documented, it will pause and ask you how to reach it.)*

2. **Bottom-Up (`/scan-screen` ➔ `/generate-step` ➔ `/generate-test`):**
   If you prefer to curate your locators screen-by-screen first:
   * Navigate to a screen on your device and ask **`/scan-screen`** to harvest `pom/<screen>.pom.js` and register it in `pom/index.js`.
   * Use **`/generate-step`** to build reusable actions in `steps/`.
   * Use **`/generate-test`** to combine those steps into isolated E2E tests in `tests/`.

---

## Running Tests

> **Note:** `maestro-runner` is installed locally as a project `devDependency`, so invoke it via `npx maestro-runner`, `npm run ...`, or `./scripts/run.sh`.

### Standard NPM Scripts

| Command | Description |
| :--- | :--- |
| `npm run test:staging` | Run via `scripts/run.sh --env staging` (`STAGING_APP_ID` + `staging` data). |
| `npm run test:prod` | Run via `scripts/run.sh --env production` (`PRODUCTION_APP_ID` + `production` data). |
| `npm test -- tests/<path>.yaml` | Run a targeted test flow or directory on connected Android device/emulator. |
| `npm run test:emulator` | Auto-boot local Android emulator, run tests, and shut down after. |
| `npm run test:ios` | Run tests on iOS Simulator using open-source WebDriverAgent (`wda`). |
| `npm run test:android` | Explicitly target Android using `uiautomator2`. |
| `npm run test:smoke` | Run only tests tagged with `smoke`. |
| `npm run test:regression` | Run only tests tagged with `regression`. |
| `npm run test:parallel` | Run tests balanced dynamically across 2+ connected devices. |
| `npm run test:retry` | Automatically retry any failing test once within the same run. |
| `npm run test:retry-failed` | Re-run only flows that failed in the previous test run. |
| `npm run lint` | Pre-flight syntax validation across `steps/` and `tests/` without booting devices. |
| `npm run scan:screen` | Dump compact element tree (1 line per element) of the active screen. |
| `npm run pom:scan <screen>` | Auto-harvest screen locators into `pom/<screen>.pom.js` and register in `pom/index.js`. |

You can forward flags to `test:staging` / `test:prod` using `--`:
```bash
npm run test:staging -- -t smoke -x demo --open
npm run test:prod -- tests/search/search-and-save-article.yaml
```

---

### Interactive & Dynamic Runner (`scripts/run.sh`)

Run `./scripts/run.sh` with no arguments to launch the **interactive step-by-step prompt**, which lets you:
1. Pick App ID / environment (`staging`, `production`, or custom)
2. Pick **include tags** (auto-discovered from `tests/`, comma-separated or `all`)
3. Pick **exclude tags** (default `none`, comma-separated)
4. Choose screenshot / artifacts config (`on-failure`, `always`, `never`)
5. Set `--retries`, toggle `--disable-animations`, and choose whether to auto-open `report.html` (`--open`)

By default, `scripts/run.sh` checks device readiness, lints only the tag-filtered tests, executes them, and prints the report path (pass `--dry-run` to preview the resolved commands without running):

```bash
# Interactive wizard (executes after prompts):
./scripts/run.sh

# Dry-run preview for staging smoke tests (excluding demo):
./scripts/run.sh --dry-run --env staging -t smoke,onboarding -x demo --retries 1 --open

# Execute directly on staging or production:
./scripts/run.sh --env staging -t smoke -x demo --open
./scripts/run.sh --env prod -t regression -x demo

# Auto-start an emulator, install an APK, and execute:
./scripts/run.sh --emulator --app-file ./build/app-debug.apk -t smoke -x demo
```

---

## How to Author New Tests (3-Step Workflow)

This template strictly follows the **3-Tier Separation**:
1. **`pom/`** ➔ Where elements are located.
2. **`steps/`** ➔ How actions are performed.
3. **`tests/`** ➔ What scenarios are tested and asserted.

---

### Step 1: Scan the Screen & Register POM (`pom/`)

Never guess selectors! With the target screen open on your device or emulator, run:
```bash
npm run scan:screen
```
This outputs a token-efficient, 1-line-per-element list of verified element IDs:
```text
[android.widget.EditText] id=input_username text="Email"
[android.widget.Button] id=btn_submit text="Sign In"
```

1. **Add locators to `pom/<screen>.pom.js`:**
   ```javascript
   // pom/login.pom.js
   output.loginScreen = {
     inputUsername: "input_username",
     btnSubmit: "btn_submit",
     headerWelcome: "header_welcome"
   };
   ```
2. **Register the screen in `pom/index.js`**:
   ```javascript
   // pom/index.js
   require("./login.pom.js");
   ```

---

### Step 2: Create Reusable Action Steps (`steps/`)

Create reusable action subflows in `steps/<feature>/<action>.yaml` that consume POM locators dynamically:

```yaml
# steps/auth/login-user.yaml
- runScript: ../../pom/login.pom.js

- tapOn:
    id: ${output.loginScreen.inputUsername}
- eraseText
- inputText: ${username}

- tapOn:
    id: ${output.loginScreen.btnSubmit}
```

---

### Step 3: Write Test Data (`data/`) & Scenarios (`tests/`)

Keep `tests/` single-source across environments by storing `staging` and `production` data maps in `data/<feature>-data.js` selected via `APP_ENV`:

```javascript
// data/auth-data.js
(function () {
  var envData = {
    staging: { username: "staging_user@example.com" },
    production: { username: "prod_user@example.com" }
  };
  var activeEnv = (typeof APP_ENV !== "undefined" && envData[APP_ENV]) ? APP_ENV : "staging";
  output.authData = envData[activeEnv];
})();
```

Then write clean, declarative test flows in `tests/<feature>/<scenario-name>.yaml`. **Zero hardcoded element selectors allowed!**

```yaml
appId: ${APP_ID}
tags:
  - smoke
  - auth
---
# 1. Load Data & POM Locators
- runScript: ../../data/auth-data.js
- runScript: ../../pom/index.js

# 2. Launch
- launchApp:
    clearState: true

# 3. Action via Step Subflow
- runFlow:
    file: ../../steps/auth/login-user.yaml
    env:
      username: ${output.authData.username}

# 4. Assert State via POM Locator
- assertVisible:
    id: ${output.dashboardScreen.headerWelcome}
```

Validate your flows before running:
```bash
npm run lint
```

---

## Viewing Test Reports

Reports are automatically generated after every test run and saved in `./reports/<timestamp>/`:

* 🌐 **HTML Report:** `./reports/<timestamp>/report.html` (self-contained overview, step durations, screenshots & hierarchy on failure)
* 🧾 **JSON Summary:** `./reports/<timestamp>/report.json` (used by `--retry-failed` and automation pipelines)
* 📑 **JUnit XML:** `./reports/<timestamp>/junit-report.xml` (CI-compatible test results)
* 📊 **Allure Results:** `./reports/<timestamp>/allure-results/`
* 📸 **Failure Assets:** `./reports/<timestamp>/assets/` (screenshots and UI hierarchy XML captured `--artifacts on-failure` by default)

To view the latest report in your browser:
```bash
explorer.exe "$(wslpath -w "$(ls -td reports/*/report.html | head -n 1)")" # WSL2 (Windows host)
open "$(ls -td reports/*/report.html | head -n 1)"                           # macOS
xdg-open "$(ls -td reports/*/report.html | head -n 1)"                       # Linux
```

### Managing & Cleaning Up Old Reports

Every test run creates a new timestamped folder inside `./reports/` (already ignored by `.gitignore`), so screenshots, videos, and logs can accumulate over time. Keep an eye on report size and prune old runs periodically:

```bash
# Check total disk space used by reports
du -sh reports/

# Keep only the 5 most recent report runs and delete older ones
ls -td reports/*/ | tail -n +6 | xargs -r rm -rf

# Clear all generated reports
rm -rf reports/*
```

*(Tip: If you don't need historical timestamps locally, pass `--output ./reports/latest --flatten` to `maestro-runner` to overwrite the same folder on every run.)*

---

## Working with AI Coding Agents

This template is purpose-built for autonomous AI agents (such as Antigravity, Claude Code, or Cursor):

1. **Domain Scope & Living Navigation Graph (`context/app-description.md`, `context/test-flows.md`)**: Gives agents clear scope guardrails plus a Mermaid flowchart and routing table of verified screen transitions, parameters, and UI quirks.
2. **Compact Hierarchy Inspection (`npm run pom:scan` / `hierarchy --compact`)**: Agents discover verified element IDs with minimal token consumption (~300 tokens vs 5,000+ for raw XML).
3. **Agent Rules & 3-Tier Skills**: Configured in `.agents/AGENTS.md` alongside `.agents/skills/{scan-screen,generate-step,generate-test}/` to enforce the 3-tier architecture, mandatory `clearState: true` isolation, targeted execution, and single-pass completion.

---

## Device & Emulator Setup Guide

A high-level directional guide for setting up an Android device or emulator to run UI automation with **Maestro Mobile Template** and **maestro-runner**.

### Setup Options Overview

| Option | Approach | Best For | Prerequisites |
| :--- | :--- | :--- | :--- |
| **Option A** | **Physical Device** | Fastest execution & real hardware performance. | USB cable + Developer Options enabled. |
| **Option B** | **Android Studio (GUI)** | Beginner-friendly visual setup. | Android Studio installed on host PC. |
| **Option C** | **Command Line Tools (CLI)** | Lightweight, terminal-first setups & CI/CD. | Java 17+ and Android `cmdline-tools`. |

### Toolchain Health Check

Before or after setting up, run the built-in diagnostic tool to verify SDK paths and detected devices (`npm run doctor`), and verify your device or emulator appears in the active ADB list (`adb devices`).

### Option A: Physical Android Device

Use a physical Android phone connected over USB:
1. Enable **Developer Options** and **USB Debugging** on the device.
2. Connect the phone to your computer via USB and accept the debugging authorization prompt on screen.
3. Confirm the device status shows as `device` in `adb devices`.

### Option B: Android Studio Emulator (GUI)

Set up and manage virtual devices visually through the official Android Studio interface:

> **Tip (Windows + WSL2 Users):** Run the emulator natively on the **Windows host** (for direct GPU hardware acceleration) and connect WSL2 to it via ADB.

1. Install [Android Studio](https://developer.android.com/studio).
2. Use the built-in **Device Manager** to create a virtual device (AVD) using your desired system image (e.g. Pixel with Google APIs).
3. Start the virtual device from Device Manager and verify via `adb devices`.

### Option C: Command Line Tools Emulator (CLI)

Set up a lightweight, headless-capable emulator without installing the full Android Studio IDE:
1. Ensure **Java 17+** is installed.
2. Download Android **Command-Line Tools (`cmdline-tools`)** and configure your environment variables (`ANDROID_HOME` and `PATH`).
3. Use `sdkmanager` and `avdmanager` to download the emulator/system image and create your AVD.
4. Launch the emulator via `emulator -avd <avd_name>` (or use `npm run test:emulator` to let `maestro-runner` auto-start it).

### Troubleshooting & AI Assistance

> **Note:** Environment issues (virtualization, KVM, USB permissions, or `PATH` configuration) vary across OS environments. If you encounter an error at any stage, copy the terminal output and ask your AI coding agent to resolve it — it will identify your OS and guide you through the exact fix.

---

## License

This template is licensed under the [Apache License 2.0](LICENSE).
