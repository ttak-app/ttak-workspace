import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import test from 'node:test';
import { fileURLToPath, URL } from 'node:url';

const script = fileURLToPath(new URL('./resume.mjs', import.meta.url));
const template = JSON.parse(
  readFileSync(
    new URL('../../docs/ai-workflow/templates/status.json', import.meta.url),
    'utf8',
  ),
);
const fixture = (t) => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'ttak-resume-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const git = (...args) =>
    execFileSync('git', args, {
      cwd: root,
      encoding: 'utf8',
      stdio: 'pipe',
    }).trim();
  git('init', '-q');
  git('config', 'user.name', 'Harness Test');
  git('config', 'user.email', 'harness@example.invalid');
  git('config', 'core.hooksPath', '/dev/null');
  git('config', 'commit.gpgSign', 'false');
  writeFileSync(path.join(root, '.gitignore'), '.tmp\n');
  writeFileSync(path.join(root, 'tracked.txt'), 'original\n');
  git('add', '.');
  git('commit', '-qm', 'initial');
  git('update-ref', 'refs/remotes/origin/develop', 'HEAD');
  git('switch', '-qc', 'chore/harness/#114');
  const write = (file, value) => {
    mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    writeFileSync(path.join(root, file), value);
  };
  const specPath = 'docs/ai-workflow/tasks/114/spec.md';
  write(
    specPath,
    '# Test spec\n\n- specRevision: 3\n\n## 목적\n복원 검증\n\n## 완료 조건\n- AC-1: 읽기 전용\n\n## 미결정 사항\n- 없음\n',
  );
  const state = {
    ...template,
    issue: 114,
    branch: 'chore/harness/#114',
    specPath,
    specRevision: 3,
  };
  const saveState = (value = state) =>
    write('.tmp/ai-workflow/tasks/114/status.json', JSON.stringify(value));
  const run = (args = [], cwd = root) =>
    spawnSync(process.execPath, [script, ...args], { cwd, encoding: 'utf8' });
  const report = (args = [], cwd = root) => {
    const result = run([...args, '--json'], cwd);
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
  };
  return { root, git, write, state, saveState, run, report, specPath };
};

test('missing state restores spec and changes without inventing completion', (t) => {
  const f = fixture(t);
  const report = f.report();
  assert.equal(report.issue, 114);
  assert.equal(report.spec.revision, 3);
  assert.equal(report.spec.purpose, '복원 검증');
  assert.equal(report.state, null);
  assert.deepEqual(report.checks, []);
  assert.match(report.warnings.join('\n'), /로컬 상태 없음/);
  assert.ok(report.nextActions.length);
});

test('matching state preserves next actions but cannot prove validation freshness', (t) => {
  const f = fixture(t);
  const subject = {
    headSha: f.git('rev-parse', 'HEAD'),
    baseRef: 'origin/develop',
    baseSha: f.git('rev-parse', 'origin/develop'),
    specRevision: 3,
  };
  f.state.phase = 'pr-ready';
  f.state.nextActions = ['남은 API 동작 확인'];
  f.state.checks = [
    {
      id: 'lint:web',
      command: 'npm lint',
      result: 'passed',
      freshness: 'current',
      subject,
    },
  ];
  f.state.review = {
    ...f.state.review,
    result: 'no-blocking-findings',
    freshness: 'current',
    subject,
  };
  f.saveState();
  const report = f.report();
  assert.deepEqual(report.nextActions, f.state.nextActions);
  assert.equal(report.checks[0].recordedResult, 'passed');
  assert.equal(report.checks[0].effectiveFreshness, 'unknown');
  assert.equal(report.review.effectiveFreshness, 'unknown');
});

test('mismatched task and stale HEAD/spec invalidate saved evidence', (t) => {
  const f = fixture(t);
  f.state.branch = 'feat/other/#114';
  f.state.specRevision = 2;
  f.state.nextActions = ['잘못된 작업 계속하기'];
  f.state.checks = [
    {
      id: 'build:web',
      command: 'npm build',
      result: 'passed',
      freshness: 'current',
      subject: { headSha: 'old', specRevision: 2 },
    },
  ];
  f.saveState();
  const report = f.report();
  assert.deepEqual(report.stateMismatches, ['branch', 'specRevision']);
  assert.equal(report.checks[0].effectiveFreshness, 'needs-recheck');
  assert.ok(report.checks[0].reasons.includes('HEAD 변경'));
  assert.ok(report.checks[0].reasons.includes('명세 버전 변경'));
  assert.notDeepEqual(report.nextActions, f.state.nextActions);
});

test('invalid JSON and malformed nested state are disclosed, not overwritten', (t) => {
  const f = fixture(t);
  f.write('.tmp/ai-workflow/tasks/114/status.json', '{invalid');
  assert.equal(f.report().state, null);
  assert.match(f.report().warnings.join('\n'), /JSON\/형식 오류/);
  assert.equal(
    readFileSync(
      path.join(f.root, '.tmp/ai-workflow/tasks/114/status.json'),
      'utf8',
    ),
    '{invalid',
  );
  f.saveState({ ...f.state, checks: ['invalid'] });
  assert.equal(f.report().state, null);
  f.saveState({ ...f.state, schemaVersion: 99 });
  assert.equal(f.report().state, null);
});

test('captures staged, unstaged, untracked and rename filenames from subdirectory without writes', (t) => {
  const f = fixture(t);
  f.write('tracked.txt', 'staged\n');
  f.git('add', 'tracked.txt');
  f.write('tracked.txt', 'unstaged\n');
  f.write('new\nfile.txt', 'new\n');
  f.saveState();
  const before = f.git('status', '--porcelain=v1');
  const stateBefore = readFileSync(
    path.join(f.root, '.tmp/ai-workflow/tasks/114/status.json'),
    'utf8',
  );
  const report = f.report([], path.join(f.root, 'docs'));
  const tracked = report.changes.find((item) => item.file === 'tracked.txt');
  assert.equal(tracked.index, 'M');
  assert.equal(tracked.worktree, 'M');
  assert.ok(
    report.changes.some(
      (item) => item.file === 'new\nfile.txt' && item.untracked,
    ),
  );
  assert.equal(f.git('status', '--porcelain=v1'), before);
  assert.equal(
    readFileSync(
      path.join(f.root, '.tmp/ai-workflow/tasks/114/status.json'),
      'utf8',
    ),
    stateBefore,
  );
  f.git('reset', '--hard', '-q');
  f.git('mv', 'tracked.txt', 'renamed file.txt');
  const renamed = f
    .report()
    .changes.find((item) => item.file === 'renamed file.txt');
  assert.equal(renamed.source, 'tracked.txt');
});

test('explicit issue supports branches without an issue, reports missing base/spec and conflicts', (t) => {
  const f = fixture(t);
  f.git('switch', '-qc', 'develop');
  assert.equal(f.report().issue, null);
  assert.equal(f.report(['--issue', '114']).spec.revision, 3);
  f.git('update-ref', '-d', 'refs/remotes/origin/develop');
  assert.match(
    f.report(['--issue', '114']).warnings.join('\n'),
    /origin\/develop/,
  );
  assert.equal(f.report(['--issue', '115']).spec, null);
  f.git('switch', 'chore/harness/#114');
  assert.match(f.report(['--issue', '115']).warnings.join('\n'), /브랜치 이슈/);
});

test('rejects invalid arguments and non-repositories with useful errors', (t) => {
  const f = fixture(t);
  for (const args of [['--issue', '../114'], ['--issue', '0'], ['--unknown']]) {
    assert.equal(f.run(args).status, 1);
  }
  const outside = mkdtempSync(path.join(os.tmpdir(), 'ttak-no-repo-'));
  t.after(() => rmSync(outside, { recursive: true, force: true }));
  const failed = f.run(['--json'], outside);
  assert.equal(failed.status, 1);
  assert.match(failed.stderr, /Git 저장소/);
});
