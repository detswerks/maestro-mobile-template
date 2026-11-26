#!/usr/bin/env node
/**
 * scripts/lint.js
 * Validates Maestro YAML flow files using `maestro check-syntax`.
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const targets = process.argv.slice(2);
if (targets.length === 0) {
  targets.push('steps/', 'tests/');
}

const files = [];
function walk(p) {
  if (!fs.existsSync(p)) return;
  const st = fs.statSync(p);
  if (st.isDirectory()) {
    for (const entry of fs.readdirSync(p).sort()) {
      walk(path.join(p, entry));
    }
  } else if (/\.ya?ml$/i.test(p)) {
    files.push(p);
  }
}

targets.forEach(walk);

if (files.length === 0) {
  console.error('Error: no flow files found in ' + targets.join(', '));
  process.exit(1);
}

let failed = 0;
for (const f of files) {
  try {
    execFileSync('maestro', ['check-syntax', f], { stdio: 'pipe' });
    console.log(`✓ ${f}`);
  } catch (err) {
    failed++;
    const msg = (err.stderr && err.stderr.toString()) || (err.stdout && err.stdout.toString()) || err.message;
    console.error(`✗ ${f}: ${msg.trim()}`);
  }
}

console.log(`\n${files.length} flow(s) checked, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
