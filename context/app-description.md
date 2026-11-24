# Application Context & Automation Scope

## 1. Application Overview
* **App Name:** Wikipedia / Wiki App
* **Domain:** Knowledge base & article reader
* **Summary:** An encyclopedia app used for searching, reading, and bookmarking informational articles.

## 2. Cold-Start & First Launch Behavior
* **Fresh Install Flow:** Always launches into the onboarding tutorial flow.
* **System Permissions:** None required for core guest browsing.

## 3. High-Level Screen Map
* `onboarding` — Welcome screens shown on first launch.
* `home` — Main explore feed and article discovery.
* `search` — Article search bar, search history, and live result list.
* `article_detail` — Full article reading view with save/bookmark actions.
* `saved_list` — List of bookmarked/saved articles.

## 4. Current Testing Scope (In-Scope)
* **User Persona:** Guest user only (no login / authentication).
* **Target Journeys:**
  - Complete or skip onboarding on cold start.
  - Search articles and open article details.
  - Save articles to reading list as guest.

## 5. Guardrails & Out of Scope (Do NOT Test)
* ⛔ **Authentication:** Do not test login, sign-up, or account creation flows.
* ⛔ **Restricted Features:** Do not test the "Activity" feature (only available for logged-in users).
* ⛔ **External Links:** Avoid external browser redirects or donation popups.
