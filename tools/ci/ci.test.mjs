import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, renameSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { classifyPaths, collectPaths, detectionOutputs, detectionSummary, flagNames } from './changes.mjs';
import { evaluateNeeds, runResult } from './result.mjs';

const selected = (...names) => Object.fromEntries(flagNames.map((name) => [name, names.includes(name)]));
const matrix = [
  ['apps/macos/Ttak/App/TtakApp.swift', ['macos']],
  ['apps/macos/Ttak.xcodeproj/project.pbxproj', ['macos']],
  ['apps/macos/.swift-format', ['macos']],
  ['apps/macos/Ttak/Resources/README.md', ['macos']],
  ['apps/web/src/App.tsx', ['web']],
  ['apps/web/public/README.md', ['web']],
  ['apps/web/.oxlintrc.json', ['web']],
  ['apps/web/.prettierrc.json', ['web']],
  ['apps/web/.prettierignore', ['web']],
  ['package-lock.json', ['web']],
  ['design-system/tokens.json', ['web', 'macos']],
  ['tools/design-tokens/build.mjs', ['web', 'macos']],
  ['tools/design-tokens/swift.test.mjs', ['web', 'macos']],
  ['docs/design-system/preview.html', ['web']],
  ['docs/design-system/reference/landing.css', ['web']],
  ['docs/design-system/reference/legacy-tokens.css', ['web']],
  ['docs/design-system/reference/legacy-tokens.json', ['web']],
  ['docs/design-system/reference/review-motion.txt', ['web']],
  ['docs/design-system/README.md', []],
  ['docs/design-system/reference/README.md', []],
  ['tools/macos/check.test.mjs', ['macos', 'harness_structure', 'harness_tests']],
  ['tools/ai-workflow/record.mjs', ['harness_structure', 'harness_tests']],
  ['tools/branch-review/collect_scope.sh', ['harness_structure', 'harness_tests']],
  ['.gitignore', ['harness_structure']],
  ['AGENTS.md', ['harness_structure']],
  ['apps/macos/AGENTS.md', ['harness_structure']],
  ['apps/web/AGENTS.md', ['harness_structure']],
  ['.agents/skills/logic-design/SKILL.md', ['harness_structure']],
  ['docs/rules/git-convention.md', ['harness_structure']],
  ['docs/ai-workflow/tasks/3/spec.md', ['harness_structure']],
  ['docs/ai-workflow/templates/status.json', ['harness_structure', 'harness_tests']],
  ['README.md', []], ['apps/macos/TtakTests/README.md', []],
  ['.coderabbit.yaml', []],
  ['apps/web/README.md', []], ['docs/notes.md', []],
  ...['docs/ci.md', 'docs/development.md', '.editorconfig', '.github/ISSUE_TEMPLATE/issue_template.md', '.github/pull_request_template.md'].map((file) => [file, ['harness_structure']]),
  ['apps/macos/Ttak/Resources/.gitkeep', []], ['.agents/.gitkeep', []],
  ...['package.json', '.nvmrc', '.github/workflows/ci.yml', 'tools/ci/changes.mjs'].map((file) => [file, flagNames]),
];

test('consumer matrix selects exactly the affected targets', () => {
  for (const [file, names] of matrix) assert.deepEqual(classifyPaths([file]).selected, selected(...names), file);
  assert.deepEqual(classifyPaths(['apps/web/src/App.tsx', 'apps/macos/Ttak/App/TtakApp.swift']).selected, selected('web', 'macos'));
  assert.deepEqual(classifyPaths(['.coderabbit.yaml', 'apps/web/src/App.tsx']).selected, selected('web'));
  assert.deepEqual(classifyPaths(['.coderabbit.yaml', 'apps/macos/Ttak/App/TtakApp.swift']).selected, selected('macos'));
  assert.equal(classifyPaths(['.gitignore', '.gitignore']).fileCount, 1);
});

test('design-system PR paths select both consumers without a root package change', () => {
  const paths = [
    'design-system/tokens.json', 'tools/design-tokens/build.mjs',
    'tools/design-tokens/build.test.mjs', 'tools/design-tokens/contrast.mjs',
    'tools/design-tokens/preview.mjs', 'tools/design-tokens/serve.mjs',
    'tools/design-tokens/swift.mjs', 'tools/design-tokens/swift.test.mjs',
    'docs/design-system/preview.html', 'docs/design-system/reference/landing.css',
    'docs/design-system/reference/legacy-tokens.css',
    'docs/design-system/reference/legacy-tokens.json',
    'docs/design-system/reference/review-motion.txt',
  ];
  assert.deepEqual(classifyPaths(paths).selected, selected('web', 'macos'));
});

test('unknown execution paths and invalid paths fail rather than silently skipping', () => {
  for (const file of ['packages/shared/index.ts', '.npmrc', '.github/workflows/new.yml', '../escape', '/absolute']) {
    assert.throws(() => classifyPaths([file]));
  }
});

test('all current tracked files have an explicit consumer classification', () => {
  const files = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' }).split('\0').filter(Boolean);
  assert.doesNotThrow(() => classifyPaths(files));
});

function gitFixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), 'ttak-ci-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q');
  git('config', 'core.hooksPath', '/dev/null');
  git('config', 'commit.gpgSign', 'false');
  git('config', 'user.email', 'test@example.invalid');
  git('config', 'user.name', 'CI Test');
  const write = (file, content) => { mkdirSync(path.dirname(path.join(root, file)), { recursive: true }); writeFileSync(path.join(root, file), content); };
  const commit = () => { git('add', '-A'); git('commit', '-qm', 'fixture'); return git('rev-parse', 'HEAD'); };
  return { root, git, write, commit };
}

test('real Git collects the full PR across commits, deletions, divergent base and cross-app moves', (t) => {
  const f = gitFixture(t);
  f.write('apps/macos/Ttak/old name.swift', 'base');
  f.write('apps/web/src/delete me.ts', 'deleted');
  const ancestor = f.commit();
  f.git('checkout', '-qb', 'feature');
  f.write('apps/macos/Ttak/old name.swift', 'swift first commit'); f.commit();
  f.write('apps/web/src/with\nnewline.ts', 'later web commit');
  unlinkSync(path.join(f.root, 'apps/web/src/delete me.ts'));
  renameSync(path.join(f.root, 'apps/macos/Ttak/old name.swift'), path.join(f.root, 'apps/web/src/moved name.ts'));
  const headSha = f.commit();
  f.git('checkout', '-qb', 'base', ancestor);
  f.write('docs/base-only.md', 'not a PR change'); const baseSha = f.commit();
  const paths = collectPaths({ cwd: f.root, baseSha, headSha });
  assert.deepEqual(new Set(paths), new Set(['apps/macos/Ttak/old name.swift', 'apps/web/src/delete me.ts', 'apps/web/src/moved name.ts', 'apps/web/src/with\nnewline.ts']));
  assert.deepEqual(classifyPaths(paths).selected, selected('macos', 'web'));
  assert.deepEqual(collectPaths({ cwd: f.root, baseSha, headSha: baseSha }), []);
});

test('detection rejects malformed SHAs, missing history, incomplete diff and git failures', (t) => {
  const f = gitFixture(t); f.write('README.md', 'base'); const sha = f.commit();
  assert.throws(() => collectPaths({ baseSha: '--help', headSha: sha }));
  assert.throws(() => collectPaths({ cwd: f.root, baseSha: 'f'.repeat(40), headSha: sha }));
  assert.throws(() => collectPaths({ baseSha: sha, headSha: sha, git: (_, args) => args[0] === 'merge-base' ? sha : 'README.md' }), /Incomplete/);
  assert.throws(() => collectPaths({ baseSha: sha, headSha: sha, git: () => { throw new Error('Git failed'); } }), /Git failed/);
});

function needsFor(paths = []) {
  const outputs = detectionOutputs(classifyPaths(paths));
  return {
    changes: { result: 'success', outputs },
    web: { result: outputs.web === 'true' ? 'success' : 'skipped', outputs: {} },
    'macos-build': { result: outputs.macos === 'true' ? 'success' : 'skipped', outputs: {} },
    harness: {
      result: outputs.harness_structure === 'true' || outputs.harness_tests === 'true' ? 'success' : 'skipped',
      outputs: { structure: outputs.harness_structure === 'true' ? 'success' : 'skipped', tests: outputs.harness_tests === 'true' ? 'success' : 'skipped' },
    },
  };
}

test('gate accepts all valid selection patterns including docs-only and structure-only', () => {
  for (const [file] of matrix) assert.equal(evaluateNeeds(needsFor([file])).passed, true, file);
  assert.equal(evaluateNeeds(needsFor()).passed, true);
  const testsOnly = needsFor(['.gitignore']);
  testsOnly.changes.outputs.harness_structure = 'false';
  testsOnly.changes.outputs.harness_tests = 'true';
  testsOnly.harness.outputs = { structure: 'skipped', tests: 'success' };
  assert.equal(evaluateNeeds(testsOnly).passed, true);
});

test('gate rejects detection failure, missing completion/version, invalid or missing flags', () => {
  for (const result of ['failure', 'cancelled', 'skipped', undefined]) {
    const needs = needsFor(); needs.changes.result = result;
    assert.equal(evaluateNeeds(needs).passed, false);
  }
  for (const name of ['complete', 'version', ...flagNames]) {
    for (const value of [undefined, '', true, 'TRUE', 'false\n']) {
      const needs = needsFor(); needs.changes.outputs[name] = value;
      assert.equal(evaluateNeeds(needs).passed, false, `${name}=${value}`);
    }
  }
  assert.equal(evaluateNeeds(null).passed, false);
});

test('gate rejects selected jobs that fail, cancel, skip or disappear and unselected jobs unexpectedly running', () => {
  for (const name of ['web', 'macos-build', 'harness']) {
    for (const result of ['failure', 'cancelled', 'skipped', undefined]) {
      const needs = needsFor(['package.json']); needs[name].result = result;
      assert.equal(evaluateNeeds(needs).passed, false, `${name}:${result}`);
    }
    const needs = needsFor(); needs[name].result = 'success';
    assert.equal(evaluateNeeds(needs).passed, false);
  }
});

test('gate checks the actual Harness stage outcomes, never just job success', () => {
  for (const step of ['structure', 'tests']) {
    for (const outcome of [undefined, 'skipped', 'failure', 'cancelled']) {
      const needs = needsFor(['package.json']); needs.harness.outputs[step] = outcome;
      assert.equal(evaluateNeeds(needs).passed, false, `${step}:${outcome}`);
    }
  }
  const structureOnly = needsFor(['.gitignore']); structureOnly.harness.outputs.tests = 'success';
  assert.equal(evaluateNeeds(structureOnly).passed, false);
});

test('CLI reports failures without evaluating JSON and detection does not publish false outputs on failure', (t) => {
  const f = gitFixture(t); f.write('README.md', 'base'); const sha = f.commit();
  f.write('event.json', JSON.stringify({ pull_request: { base: { sha }, head: { sha: 'f'.repeat(40) } } }));
  const output = path.join(f.root, 'output'); const summary = path.join(f.root, 'summary');
  writeFileSync(output, '');
  const cli = path.resolve('tools/ci/changes.mjs');
  const result = spawnSync(process.execPath, [cli], { cwd: f.root, env: { ...process.env, GITHUB_EVENT_PATH: path.join(f.root, 'event.json'), GITHUB_OUTPUT: output, GITHUB_STEP_SUMMARY: summary } });
  assert.equal(result.status, 1); assert.equal(readFileSync(output, 'utf8'), '');
  f.write('event.json', JSON.stringify({ pull_request: { base: { sha }, head: { sha } } }));
  const success = spawnSync(process.execPath, [cli], { cwd: f.root, env: { ...process.env, GITHUB_EVENT_PATH: path.join(f.root, 'event.json'), GITHUB_OUTPUT: output, GITHUB_STEP_SUMMARY: summary } });
  assert.equal(success.status, 0);
  assert.deepEqual(Object.fromEntries(readFileSync(output, 'utf8').trim().split('\n').map((line) => line.split('='))), detectionOutputs(classifyPaths([])));
  assert.throws(() => runResult({ CI_NEEDS_JSON: 'process.exit(0)', GITHUB_STEP_SUMMARY: summary }));
  assert.equal(runResult({ CI_NEEDS_JSON: JSON.stringify(needsFor(['README.md'])), GITHUB_STEP_SUMMARY: summary }), 0);
  const broken = needsFor(['apps/web/src/App.tsx']); broken.web.result = 'failure';
  assert.equal(runResult({ CI_NEEDS_JSON: JSON.stringify(broken), GITHUB_STEP_SUMMARY: summary }), 1);
});

test('summary filenames cannot inject rows, HTML or newlines', () => {
  const summary = detectionSummary(classifyPaths(['apps/web/public/a\n|<script>`x`.md']));
  assert.ok(summary.includes('\\n&#124;&lt;script&gt;&#96;x&#96;'));
  assert.ok(!summary.includes('<script>'));
});

test('workflow uses default PR events, selected jobs and an always-running gate', () => {
  const source = readFileSync(new URL('../../.github/workflows/ci.yml', import.meta.url), 'utf8');
  const trigger = source.split('on:\n')[1].split('\npermissions:')[0];
  // Match the reference PR: omitted types means opened, synchronize and reopened.
  assert.equal(trigger.trim(), 'pull_request:\n    branches: [main, develop]');
  assert.ok(!source.includes('github.event.action'));
  assert.ok(!source.includes('github.event.changes.base'));
  assert.ok(!source.includes('metadata edit'));
  assert.ok(!source.includes('noop-'));
  assert.match(source, /group: \$\{\{ github.workflow \}\}-pr-\$\{\{ github.event.pull_request.number \}\}/);
  const blocks = Object.fromEntries([...source.split('jobs:\n')[1].matchAll(/^  ([a-z-]+):\n([\s\S]*?)(?=^  [a-z-]+:\n|$(?![\s\S]))/gm)].map((match) => [match[1], match[2]]));
  assert.deepEqual(Object.keys(blocks), ['changes', 'harness', 'web', 'macos-build', 'ci-result']);
  for (const [id, name] of [['changes', 'Changes'], ['harness', 'Harness'], ['web', 'Web'], ['macos-build', 'macOS Build'], ['ci-result', 'CI Result']]) {
    assert.match(blocks[id], new RegExp(`^    name: ${name}$`, 'm'));
  }
  assert.ok(!/^    if:/m.test(blocks.changes));
  assert.match(blocks.changes, /fetch-depth: 0/);
  assert.match(blocks['ci-result'], /needs: \[changes, harness, web, macos-build\]/);
  assert.match(blocks['ci-result'], /^    if: always\(\)$/m);
  assert.match(blocks['ci-result'], /CI_NEEDS_JSON: \$\{\{ toJSON\(needs\) \}\}/);
  assert.match(blocks.harness, /structure: \$\{\{ steps.structure.outcome \}\}/);
  assert.match(blocks.harness, /tests: \$\{\{ steps.tests.outcome \}\}/);
  assert.match(blocks.harness, /npm run workflow:test\n\s+node --test tools\/ci\/\*\.test\.mjs/);
  assert.match(blocks.web, /run: npm run format:check:web/);
  assert.match(blocks['macos-build'], /run: npm run format:check:macos/);
  assert.match(blocks['macos-build'], /run: npm run macos:test/);
  assert.ok(!blocks['macos-build'].includes('run: npm run macos:build'));
  assert.ok(!source.includes('continue-on-error'));
  for (const name of ['web', 'harness', 'macos-build']) {
    const condition = blocks[name].match(/^    if: (.+)$/m)[1];
    const expression = condition.replaceAll(/needs.changes.outputs.([a-z_]+)/g, 'flags.$1');
    const evaluate = new Function('flags', `return (${expression});`);
    for (let bits = 0; bits < 16; bits += 1) {
      const flags = Object.fromEntries(flagNames.map((flag, i) => [flag, bits & (1 << i) ? 'true' : 'false']));
      const expected = name === 'harness' ? flags.harness_structure === 'true' || flags.harness_tests === 'true'
        : flags[name === 'web' ? 'web' : 'macos'] === 'true';
      assert.equal(evaluate(flags), expected, `${name}:${bits}`);
    }
  }
});
