# Application Context & Automation Scope (Template / Example)

> **Instructions for QA:** Copy this file to `context/app-description.md` and fill in the sections below. This document serves as the high-level domain guide and guardrails for the AI agent when inspecting the app, organizing Page Object Models (`pom/`), and authoring test flows.

---

## 1. Application Overview
* **App Name:** [e.g. MyStore / ChatApp / FoodDelivery]
* **Domain:** [e.g. E-commerce / Social / Fintech / Healthcare]
* **Summary:** [1-2 sentences explaining what the app does and its primary user purpose]

## 2. Cold-Start & First Launch Behavior
* **Fresh Install Flow:** [e.g. Shows 3-screen onboarding carousel with Skip button / Directly opens Home screen]
* **System Permissions:** [e.g. Requests notification or location permission on first launch / No permissions requested]

## 3. High-Level Screen Map
List the known major screens, tabs, or modal flows. The AI agent uses these names to structure Tier-1 Page Object Models (`pom/<screen>.pom.js`):
* `[screen_name]` — [Brief description, e.g. login, onboarding, home, checkout, product_detail, settings]
* `[screen_name]` — [Brief description]
* `[screen_name]` — [Brief description]

## 4. Current Testing Scope (In-Scope)
Define the boundaries and priority test journeys for the current test suite:
* **Target User Persona:** [e.g. Guest user (unauthenticated) / Registered standard user]
* **Target Journeys:**
  - [Journey 1: e.g. Cold start ➔ dismiss onboarding ➔ verify Home screen]
  - [Journey 2: e.g. Search for item ➔ verify results list ➔ open detail screen]
  - [Journey 3: e.g. Add item to cart/favorites ➔ verify counter badge updates]

## 5. Guardrails & Out of Scope (Do NOT Test)
Explicitly list features that exist in the app but MUST NOT be tested or clicked into by the agent:
* ⛔ **Authentication:** [e.g. Do not test login/signup flows]
* ⛔ **Restricted Features:** [e.g. Do not touch payment gateway, in-app purchases, or account deletion]
* ⛔ **External Links:** [e.g. Do not tap external web links, ads, or social share dialogs]
