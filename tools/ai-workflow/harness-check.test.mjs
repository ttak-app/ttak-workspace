import assert from 'node:assert/strict';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkHarness } from './harness-check.mjs';
const source = fileURLToPath(new URL('../../', import.meta.url));
function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(),'ttak-harness-'));
  t.after(() => rmSync(root,{ recursive:true,force:true }));
  for (const file of ['AGENTS.md','apps/macos/AGENTS.md','docs','.agents','.github','tools','package.json','.gitignore']) {
    mkdirSync(path.dirname(path.join(root,file)),{recursive:true});
    cpSync(path.join(source,file),path.join(root,file),{recursive:true});
  }
  return root;
}
test('Codex-only harness validates without Claude files or CI', t => {
  const root = fixture(t);
  assert.deepEqual(checkHarness(root).diagnostics,[]);
});
test('missing skill is actionable and never silently skipped', t => {
  const root = fixture(t);
  rmSync(path.join(root,'.agents/skills/create-pr/SKILL.md'));
  const report = checkHarness(root);
  assert.equal(report.status,'failed');
  assert.ok(report.diagnostics.some(item => item.file.includes('create-pr') && item.code==='missing-or-unreadable'));
});
test('links resolve relative to actual skill directory', t => {
  const root = fixture(t);
  const file = path.join(root,'.agents/skills/logic-design/SKILL.md');
  writeFileSync(file,readFileSync(file,'utf8').replace('../../../docs/rules/ai-workflow.md','../../docs/rules/ai-workflow.md'));
  assert.ok(checkHarness(root).diagnostics.some(item => item.code==='broken-link'));
});
test('fake script success cannot replace a real evidence entry point', t => {
  const root = fixture(t);
  const file = path.join(root,'package.json');
  const pkg = JSON.parse(readFileSync(file,'utf8'));
  pkg.scripts['workflow:check']='echo passed';
  writeFileSync(file,JSON.stringify(pkg));
  assert.ok(checkHarness(root).diagnostics.some(item => item.code==='script'));
});
test('local evidence must be ignored and status schema must parse', t => {
  const root = fixture(t);
  writeFileSync(path.join(root,'.gitignore'),'node_modules/\n');
  writeFileSync(path.join(root,'docs/ai-workflow/templates/status.json'),'{broken');
  const codes = checkHarness(root).diagnostics.map(item=>item.code);
  assert.ok(codes.includes('local-evidence'));
  assert.ok(codes.includes('json'));
});
