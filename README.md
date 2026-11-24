# Maestro Mobile Template

> A modern, production-grade starter template for mobile UI test automation powered by **[maestro-runner](https://github.com/devicelab-dev/maestro-runner)** and standard **[Maestro](https://maestro.mobile.dev/)** YAML flows.

Built with a strict **3-Tier Architecture** (Locators ➔ Actions ➔ Scenarios), native local emulator lifecycle management, zero Java/JVM dependencies, 100% open-source drivers by default, and built-in AI coding agent skills.

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
* 📊 **Free Local Reports**: Instant HTML reports (`report.html`), JUnit XML, and Allure outputs in `./reports/` without requiring paid cloud subscriptions.

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
├── data/                           # Test data & fixtures (static & dynamic JS/JSON)
├── tests/                          # End-to-end test scenarios
├── scripts/
│   └── run.sh                      # Dynamic test runner (tags, platforms, retries)
├── .env.example                    # Environment configuration template
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

> 📖 **Need help setting up a device or emulator?**  
> Check the setup guide: **[Device & Emulator Setup Guide](file:///home/detswerks/projects/maestro-mobile-template/documents/device-setup-guide.md)** (covers real USB phones, Android Studio, CLI emulators, and maestro-runner auto-booting).

Verify your environment toolchain at any time:
```bash
npm run doctor
```

---

### 2. Installation & Setup

1. **Clone this repository:**
   ```bash
   git clone <your-repo-url> maestro-mobile-template
   cd maestro-mobile-template
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Open `.env` and set your application's package/bundle identifier:
   ```bash
   APP_ID="com.yourcompany.app"
   ANDROID_APP_ID="com.yourcompany.app"
   IOS_APP_ID="com.yourcompany.app.ios"
   ```

---

## Running Tests

### Standard NPM Scripts

| Command | Description |
| :--- | :--- |
| `npm test` | Run all test flows on connected Android device/emulator. |
| `npm run test:emulator` | Auto-boot local Android emulator, run tests, and shut down after. |
| `npm run test:ios` | Run tests on iOS Simulator using open-source WebDriverAgent (`wda`). |
| `npm run test:android` | Explicitly target Android using `uiautomator2`. |
| `npm run test:smoke` | Run only tests tagged with `smoke`. |
| `npm run test:regression` | Run only tests tagged with `regression`. |
| `npm run test:parallel` | Run tests balanced dynamically across 2 devices. |
| `npm run test:retry` | Automatically retry any failing test once within the same run. |
| `npm run test:retry-failed` | Re-run only flows that failed in the previous test run. |
| `npm run lint` | Pre-flight syntax validation and path check without booting devices. |
| `npm run scan:screen` | Dump compact element tree (1 line per element) of the active screen. |

---

### Dynamic Test Execution (`scripts/run.sh`)

You can run targeted tests dynamically using the runner script:

```bash
# Run tests with a dynamic tag:
./scripts/run.sh --tag checkout

# Auto-start an emulator, install the latest APK, and run:
./scripts/run.sh --emulator --app-file ./build/app-debug.apk --tag smoke

# Run on iOS with parallel execution:
./scripts/run.sh --platform ios --parallel 2 --tag regression
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
- runScript: ../../pom/auth/login.pom.js

- tapOn:
    id: ${output.loginScreen.inputUsername}
- eraseText
- inputText: ${username}

- tapOn:
    id: ${output.loginScreen.btnSubmit}
```

---

### Step 3: Write Test Scenarios (`tests/`)

Write clean, declarative test flows in `tests/<feature>/<scenario-name>.yaml`. **Zero hardcoded element selectors allowed!**

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
      username: ${output.authData.validUser.username}

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

Reports are automatically generated after every test run and saved in `./reports/`:

* 🌐 **HTML Report:** `./reports/<timestamp>/report.html` (interactive overview, step durations, screenshots on failure)
* 📑 **JUnit XML:** `./reports/<timestamp>/junit-report.xml` (CI-compatible test results)
* 📊 **Allure Results:** `./reports/<timestamp>/allure-results/`

To view the latest report in your browser:
```bash
open ./reports/latest/report.html    # macOS
xdg-open ./reports/*/report.html     # Linux
```

---

## Working with AI Coding Agents

This template is purpose-built for autonomous AI agents (such as Antigravity, Claude Code, or Cursor):

1. **Domain Scope & Living Navigation Graph (`context/app-description.md`, `context/test-flows.md`)**: Gives agents clear scope guardrails plus a Mermaid flowchart and routing table of verified screen transitions, parameters, and UI quirks.
2. **Compact Hierarchy Inspection (`npm run pom:scan` / `hierarchy --compact`)**: Agents discover verified element IDs with minimal token consumption (~300 tokens vs 5,000+ for raw XML).
3. **Agent Rules & 3-Tier Skills**: Configured in `.agents/AGENTS.md` alongside `.agents/skills/{scan-screen,generate-step,generate-test}/` to enforce the 3-tier architecture, mandatory `clearState: true` isolation, targeted execution, and single-pass completion.

---

## License

This template is licensed under the [Apache License 2.0](LICENSE).
