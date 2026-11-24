#!/usr/bin/env node

/**
 * scripts/harvest-pom.js
 * 
 * Automatically inspects the active mobile screen via maestro-runner,
 * filters UI noise (status bars, layout containers, dynamic feed text),
 * extracts functional interactive and anchor elements, and generates/updates
 * Page Object Model (POM) locator dictionaries.
 * 
 * Supports:
 * - Scenario 1: Fresh 0 setup (generates new POM & registers in pom/index.js)
 * - Scenario 2: Existing repo (non-destructive merge: preserves existing keys & appends new elements)
 * - Flags: --clean / --force (re-harvest screen from scratch, ignoring previous file)
 * 
 * Usage:
 *   npm run pom:scan <screen_name>
 *   npm run pom:scan <screen_name> -- --clean
 *   node scripts/harvest-pom.js <screen_name> [--clean] [--platform android|ios]
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const POM_DIR = path.join(ROOT_DIR, 'pom');
const INDEX_JS = path.join(POM_DIR, 'index.js');
const APP_DESC = path.join(ROOT_DIR, 'context', 'app-description.md');

// Parse CLI Arguments
const args = process.argv.slice(2);
let screenInput = null;
let platform = 'android';
let driver = 'uiautomator2';
let device = null;
let forceClean = false;
let outputJsonOnly = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--screen' || args[i] === '-s') {
    screenInput = args[++i];
  } else if (args[i] === '--platform' || args[i] === '-p') {
    platform = args[++i];
  } else if (args[i] === '--driver' || args[i] === '-d') {
    driver = args[++i];
  } else if (args[i] === '--device') {
    device = args[++i];
  } else if (args[i] === '--clean' || args[i] === '--force' || args[i] === '-f') {
    forceClean = true;
  } else if (args[i] === '--json') {
    outputJsonOnly = true;
  } else if (!args[i].startsWith('-') && !screenInput) {
    screenInput = args[i];
  }
}

// Helper: extract candidate screens from context/app-description.md
function getKnownScreensFromContext() {
  if (!fs.existsSync(APP_DESC)) return [];
  const content = fs.readFileSync(APP_DESC, 'utf8');
  const matches = content.match(/`([a-zA-Z0-9_-]+)`\s*—/g) || [];
  return matches.map(m => m.replace(/[`—\s]/g, ''));
}

if (!screenInput) {
  console.error('\n❌ Error: Screen name is required.');
  console.log('\nUsage:');
  console.log('  npm run pom:scan <screen_name>');
  console.log('  npm run pom:scan <screen_name> -- --clean   (re-scan cleanly)');
  console.log('  e.g.: npm run pom:scan home\n');

  const knownScreens = getKnownScreensFromContext();
  if (knownScreens.length > 0) {
    console.log('Known screens defined in context/app-description.md:');
    knownScreens.forEach(s => console.log(`  - ${s}`));
    console.log('');
  }
  process.exit(1);
}

// Normalize screen name & paths
let screenName = screenInput;
let targetDir = POM_DIR;
let relPath = `${screenName}.pom.js`;

if (screenInput.includes('/')) {
  const parts = screenInput.split('/');
  const featureName = parts[0];
  screenName = parts[1];
  targetDir = path.join(POM_DIR, featureName);
  relPath = `${featureName}/${screenName}.pom.js`;
}

const targetFile = path.join(targetDir, `${screenName}.pom.js`);

// camelCase screen variable: e.g. "home" -> "homeScreen", "article_detail" -> "articleDetailScreen"
function toCamelCase(str) {
  return str
    .replace(/[^a-zA-Z0-9]+(.)/g, (_, chr) => chr.toUpperCase())
    .replace(/^[A-Z]/, c => c.toLowerCase());
}

const screenObjectVar = `${toCamelCase(screenName)}Screen`;

if (!outputJsonOnly) {
  console.log(`\n🔍 Inspecting active device screen for [${screenName}]...`);
}

// Execute maestro-runner hierarchy
let hierarchyJson;
try {
  let cmd = `MAESTRO_RUNNER_NO_TELEMETRY=1 npx maestro-runner --platform ${platform} --driver ${driver} hierarchy`;
  if (device) cmd += ` --device ${device}`;
  
  const stdout = execSync(cmd, { cwd: ROOT_DIR, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  
  const jsonStart = stdout.indexOf('{');
  if (jsonStart === -1) {
    throw new Error('Failed to find JSON in maestro-runner output:\n' + stdout);
  }
  hierarchyJson = JSON.parse(stdout.slice(jsonStart));
} catch (err) {
  console.error('\n❌ Failed to inspect screen hierarchy:');
  console.error(err.message || err);
  console.error('\nEnsure an Android emulator or device is running (check `adb devices`).');
  process.exit(1);
}

// System UI prefixes to completely prune (aborts node and all children)
const SYSTEM_UI_PREFIXES = [
  'com.android.systemui',
  'android:id/statusBarBackground',
  'android:id/navigationBarBackground'
];

// Structural layout containers and internal sub-elements to ignore
const IGNORED_CONTAINER_PATTERNS = [
  'action_bar_root',
  'fragment_container',
  'coordinator',
  'view_pager',
  'nav_tab_container',
  'nav_tab_layout',
  'nav_tab_border',
  'nav_tab_overlay_dot',
  'navigation_bar_item',
  'android:id/content'
];

// Reject dynamic dates, times, or clock timestamps
const DYNAMIC_DATE_REGEX = /(today|yesterday|tomorrow|\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b|\b\d{4}\b|\d{1,2}:\d{2})/i;

// Whitelisted UI actions and static section labels for text-based locators
const KNOWN_UI_KEYWORDS = new Set([
  'save', 'share', 'more options', 'skip', 'continue', 'next', 'done', 
  'cancel', 'search', 'back', 'close', 'got it', 'ok', 'learn more', 
  'add', 'explore', 'settings', 'view', 'community', 'for you', 
  'featured article', 'en', 'edit', 'delete', 'apply', 'filter', 'sort'
]);

// Helper: collect meaningful interactive & anchor elements
const harvestedElements = [];
const seenValues = new Set();
const capturedIds = new Set();

function traverse(node, insideCapturedParent = false) {
  if (!node) return;

  const rawId = node.id || null;
  const rawText = (node.text && typeof node.text === 'string') ? node.text.trim() : null;
  const nodeType = node.type || '';

  // 1. Completely prune System UI subtrees (Clock, Battery, Wifi, OS Nav Bar)
  if (rawId && SYSTEM_UI_PREFIXES.some(prefix => rawId.startsWith(prefix))) {
    return;
  }
  if (rawText && /notification:/i.test(rawText)) {
    return;
  }

  let capturedThisNode = false;

  // 2. Check Resource ID (Priority 1)
  if (rawId) {
    const isIgnored = IGNORED_CONTAINER_PATTERNS.some(pat => rawId.includes(pat));
    if (!isIgnored) {
      if (!seenValues.has(rawId)) {
        seenValues.add(rawId);
        capturedIds.add(rawId);
        harvestedElements.push({
          selector: rawId,
          isId: true,
          type: nodeType,
          text: rawText
        });
        capturedThisNode = true;
      }
    }
  }

  // 3. Text fallback (Priority 2): ONLY if not inside a parent already captured by ID
  if (!capturedThisNode && !insideCapturedParent && rawText) {
    const lower = rawText.toLowerCase();
    const hasPunctuation = /[.,;?!"()—]/.test(rawText);
    const hasDate = DYNAMIC_DATE_REGEX.test(rawText);
    const hasHtml = rawText.includes('<') || rawText.includes('>');

    // Only accept known static UI controls or action words (avoids dynamic article headlines / dates)
    if (!hasHtml && !hasDate && !hasPunctuation && KNOWN_UI_KEYWORDS.has(lower)) {
      if (!seenValues.has(rawText)) {
        seenValues.add(rawText);
        harvestedElements.push({
          selector: rawText,
          isId: false,
          type: nodeType,
          text: rawText
        });
      }
    }
  }

  // Traverse children
  if (node.children && Array.isArray(node.children)) {
    const passInside = insideCapturedParent || capturedThisNode;
    node.children.forEach(c => traverse(c, passInside));
  }
}

traverse(hierarchyJson);

if (outputJsonOnly) {
  process.stdout.write(JSON.stringify(harvestedElements, null, 2) + '\n');
  process.exit(0);
}

if (harvestedElements.length === 0) {
  console.log('\n⚠️  No distinct interactive or anchor elements detected on screen.');
  process.exit(0);
}

// Naming generator for new keys
function generateKeyName(item, existingKeys) {
  let base = '';
  
  if (item.isId) {
    // Extract entry name after colon/slash: e.g. "org.wikipedia.alpha:id/nav_tab_home" -> "nav_tab_home"
    let clean = item.selector.includes(':id/') ? item.selector.split(':id/')[1] : item.selector;
    // Remove redundant common prefixes
    clean = clean.replace(/^(btn_|button_|input_|edit_|txt_|text_|nav_|tab_|view_|item_)/, '');
    
    if (item.selector.includes('nav_') || item.selector.includes('tab_')) {
      base = 'nav' + toCamelCase(clean).replace(/^[a-z]/, c => c.toUpperCase());
    } else if (item.selector.includes('btn_') || item.selector.includes('button_') || item.type.includes('Button')) {
      base = 'btn' + toCamelCase(clean).replace(/^[a-z]/, c => c.toUpperCase());
    } else if (item.selector.includes('input_') || item.selector.includes('edit_') || item.selector.includes('search') || item.type.includes('EditText')) {
      base = 'input' + toCamelCase(clean).replace(/^[a-z]/, c => c.toUpperCase());
    } else if (item.selector.includes('header') || item.selector.includes('title')) {
      base = 'header' + toCamelCase(clean).replace(/^[a-z]/, c => c.toUpperCase());
    } else {
      base = toCamelCase(clean);
    }
  } else {
    // Text fallback
    const cleanText = item.selector.replace(/[^a-zA-Z0-9 ]/g, '').trim();
    const words = cleanText.split(/\s+/).slice(0, 3).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join('');
    
    if (/^(save|share|submit|ok|cancel|continue|skip|next|back|close|search|done|moreoptions|en)$/i.test(words)) {
      base = 'btn' + words;
    } else {
      base = 'txt' + words;
    }
  }

  if (!base || base.length < 2) base = 'element';

  // Ensure uniqueness
  let candidate = base;
  let counter = 2;
  while (existingKeys.has(candidate)) {
    candidate = `${base}${counter++}`;
  }
  existingKeys.add(candidate);
  return candidate;
}

// Handle Scenario 1 (Fresh 0) vs Scenario 2 (Existing POM merge)
let pomLocators = {};
let existingContent = '';
let isUpdate = false;
const existingKeysSet = new Set();
const existingValuesSet = new Set();

if (fs.existsSync(targetFile) && !forceClean) {
  isUpdate = true;
  existingContent = fs.readFileSync(targetFile, 'utf8');
  
  // Extract existing key-value pairs via regex to preserve existing keys 100%
  const entryRegex = /^\s*([a-zA-Z0-9_]+)\s*:\s*["'`](.*)["'`]\s*,?/gm;
  let match;
  while ((match = entryRegex.exec(existingContent)) !== null) {
    const key = match[1];
    const val = match[2];
    pomLocators[key] = val;
    existingKeysSet.add(key);
    existingValuesSet.add(val);
  }
}

// Add newly discovered elements
let addedCount = 0;
for (const item of harvestedElements) {
  if (existingValuesSet.has(item.selector)) {
    continue; // Already mapped
  }
  const key = generateKeyName(item, existingKeysSet);
  pomLocators[key] = item.selector;
  existingValuesSet.add(item.selector);
  addedCount++;
}

// Format POM JS file content
const lines = [];
lines.push(`// pom/${relPath}`);
lines.push(`// Screen Locators for [${screenName}]`);
lines.push(`// Auto-generated & maintained by scripts/harvest-pom.js`);
lines.push('');
lines.push(`output.${screenObjectVar} = {`);

const keys = Object.keys(pomLocators);
keys.forEach((key, idx) => {
  const isLast = idx === keys.length - 1;
  const comma = isLast ? '' : ',';
  lines.push(`  ${key}: "${pomLocators[key]}"${comma}`);
});

lines.push('};');
lines.push('');

// Write POM file
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}
fs.writeFileSync(targetFile, lines.join('\n'), 'utf8');

if (isUpdate) {
  console.log(`\n✅ Updated existing POM: pom/${relPath}`);
  console.log(`   - Preserved ${existingKeysSet.size} existing locators`);
  console.log(`   - Added ${addedCount} newly discovered locators`);
} else {
  console.log(`\n✅ Generated clean POM: pom/${relPath} (${keys.length} locators)`);
}

// Auto-register in pom/index.js if not already present
const importStmt = `require("./${relPath}");`;
let indexContent = fs.existsSync(INDEX_JS) ? fs.readFileSync(INDEX_JS, 'utf8') : '';

if (!indexContent.includes(importStmt)) {
  if (!indexContent.trim()) {
    indexContent = '// pom/index.js\n// Central POM Locator Aggregator\n\n';
  } else if (!indexContent.endsWith('\n')) {
    indexContent += '\n';
  }
  indexContent += `${importStmt}\n`;
  fs.writeFileSync(INDEX_JS, indexContent, 'utf8');
  console.log(`✅ Auto-registered in pom/index.js: ${importStmt}`);
} else {
  console.log(`ℹ️  Already registered in pom/index.js`);
}

console.log(`\n✨ Screen [${screenName}] is ready to be consumed in steps/ and tests/ via:`);
console.log(`   \${output.${screenObjectVar}.<locatorName>}\n`);
