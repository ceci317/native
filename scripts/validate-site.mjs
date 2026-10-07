import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const mirror = await readFile(new URL('../native.html', import.meta.url), 'utf8');

if (index !== mirror) {
  throw new Error('index.html and native.html must contain identical content');
}
if (!/^\s*<!doctype html>/i.test(index)) {
  throw new Error('index.html must start with an HTML doctype');
}

const scripts = [...index.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
if (scripts.length === 0) {
  throw new Error('No inline JavaScript found');
}
for (const [i, match] of scripts.entries()) {
  new vm.Script(match[1], { filename: `inline-script-${i + 1}.js` });
}

console.log(`Static site validated: identical HTML files and ${scripts.length} JavaScript block(s)`);
