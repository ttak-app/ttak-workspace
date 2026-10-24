import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import test from 'node:test';
import { fileURLToPath, URL } from 'node:url';
import { assessFreshness, collectScope } from './evidence-core.mjs';

const recordScript = fileURLToPath(new URL('./record.mjs', import.meta.url));
const resumeScript = fileURLToPath(new URL('./resume.mjs', import.meta.url));
const collectScript = fileURLToPath(new URL('./collect.mjs', import.meta.url));
const fixture = (t) => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'ttak-evidence-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const write = (file, content) => {
    mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    writeFileSync(path.join(root, file), content);
  };
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
  write('.gitignore', '.tmp\nnode_modules\n');
  write('tracked.txt', 'original\n');
  write(
    'package.json',
    JSON.stringify({
      scripts: {
        'workflow:harness-check':
          'node -e "console.log(\'actual harness pass\')"',
        'lint:web': 'node -e "console.log(\'actual pass\')"',
        'check-types:web':
          'node -e "console.error(\'actual failure\'); process.exit(2)"',
        'build:web':
          "node -e \"require('fs').writeFileSync('tracked.txt', 'changed during check')\"",
      },
    }),
  );
  write(
    'docs/ai-workflow/tasks/114/spec.md',
    '# Evidence spec\n\n- specRevision: 3\n\n## 목적\n증적 확인\n\n## 완료 조건\n- AC-1: 실제 검사\n',
  );
  git('add', '.');
  git('commit', '-qm', 'initial');
  git('update-ref', 'refs/remotes/origin/develop', 'HEAD');
  git('switch', '-qc', 'chore/harness/#114');
  const run = (...args) =>
    spawnSync(process.execPath, [recordScript, ...args], {
      cwd: root,
      encoding: 'utf8',
    });
  const report = () => {
    const result = spawnSync(process.execPath, [resumeScript, '--json'], {
      cwd: root,
      encoding: 'utf8',
    });
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
  };
  const statePath = '.tmp/ai-workflow/tasks/114/status.json';
  const state = () =>
    JSON.parse(readFileSync(path.join(root, statePath), 'utf8'));
  const start = () => {
    const result = run('review', '--start');
    assert.equal(result.status, 0, result.stderr);
    const file = result.stdout.match(/리뷰 시작: (.+\/input.json)/)[1];
    return {
      file,
      input: JSON.parse(readFileSync(path.join(root, file), 'utf8')),
    };
  };
  const save = (session) => {
    write(session.file, JSON.stringify(session.input));
    return run('review', '--input', session.file);
  };
  return { root, git, write, run, report, state, statePath, start, save };
};

test('actual pass and failure append logs, preserve exit status and do not mark acceptance met', (t) => {
  const f = fixture(t);
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  assert.equal(f.run('check', '--script', 'check-types:web').status, 2);
  const state = f.state();
  assert.deepEqual(
    state.checks.map((item) => item.result),
    ['passed', 'failed'],
  );
  assert.deepEqual(
    state.checks.map((item) => item.freshness),
    ['current', 'current'],
  );
  assert.match(
    readFileSync(path.join(f.root, state.checks[0].evidence[0]), 'utf8'),
    /actual pass/,
  );
  assert.match(
    readFileSync(path.join(f.root, state.checks[1].evidence[0]), 'utf8'),
    /actual failure/,
  );
  assert.equal(state.acceptance[0].status, 'pending');
  assert.equal(f.report().checks[0].effectiveFreshness, 'current');
});

test('content changes with identical porcelain status invalidate evidence, including new files and staging', (t) => {
  const f = fixture(t);
  f.write('tracked.txt', 'first change');
  f.write('new.txt', 'first new');
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  const status = f.git('status', '--porcelain');
  f.write('tracked.txt', 'second change');
  assert.equal(f.git('status', '--porcelain'), status);
  assert.equal(f.report().checks[0].effectiveFreshness, 'needs-recheck');
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  f.write('new.txt', 'second new');
  assert.equal(f.report().checks[1].effectiveFreshness, 'needs-recheck');
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  f.git('add', 'tracked.txt');
  assert.equal(f.report().checks[2].effectiveFreshness, 'needs-recheck');
});

test('checks that change their target cannot produce current evidence', (t) => {
  const f = fixture(t);
  assert.equal(f.run('check', '--script', 'build:web').status, 0);
  assert.equal(f.state().checks[0].result, 'passed');
  assert.equal(f.state().checks[0].freshness, 'needs-recheck');
});

test('new spec revision invalidates old acceptance but allows a fresh check', (t) => {
  const f = fixture(t);
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  const state = f.state();
  state.acceptance[0].status = 'met';
  f.write(f.statePath, JSON.stringify(state));
  f.write(
    'docs/ai-workflow/tasks/114/spec.md',
    '# Evidence spec\n- specRevision: 4\n\n## 완료 조건\n- AC-1: revised\n',
  );
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  assert.equal(f.state().acceptance[0].status, 'needs-recheck');
  assert.equal(f.state().checks[0].freshness, 'needs-recheck');
  assert.equal(f.state().checks[1].freshness, 'current');
});

test('invalid state, foreign task, active lock and unsupported commands preserve existing records', (t) => {
  const f = fixture(t);
  f.write(f.statePath, '{invalid');
  assert.equal(f.run('check', '--script', 'lint:web').status, 1);
  assert.equal(
    readFileSync(path.join(f.root, f.statePath), 'utf8'),
    '{invalid',
  );
  rmSync(path.join(f.root, f.statePath));
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  const state = f.state();
  state.branch = 'other/#114';
  f.write(f.statePath, JSON.stringify(state));
  const before = readFileSync(path.join(f.root, f.statePath), 'utf8');
  assert.equal(f.run('check', '--script', 'lint:web').status, 1);
  assert.equal(readFileSync(path.join(f.root, f.statePath), 'utf8'), before);
  mkdirSync(path.join(f.root, '.tmp/ai-workflow/tasks/114/.record-lock'));
  assert.equal(f.run('check', '--script', 'lint:web').status, 1);
  assert.equal(f.run('check', '--script', 'deploy').status, 1);
});

test('review saves the start snapshot and discloses changes made while reviewing', (t) => {
  const f = fixture(t);
  f.write('new.txt', 'reviewed content');
  const session = f.start();
  session.input.result = 'no-blocking-findings';
  f.write('new.txt', 'later content');
  assert.equal(f.save(session).status, 0);
  assert.equal(f.state().review.freshness, 'needs-recheck');
  assert.ok(f.state().review.scope.includes('new.txt'));
  assert.equal(f.report().review.effectiveFreshness, 'needs-recheck');
});

test('blocking findings cannot be dropped or accepted as passed; resolving preserves history', (t) => {
  const f = fixture(t);
  const first = f.start();
  first.input.result = 'changes-required';
  first.input.findings = [
    {
      id: 'R1',
      severity: 'High',
      file: 'tracked.txt',
      line: 1,
      description: 'incorrect behavior',
      status: 'open',
      resolution: '',
    },
  ];
  assert.equal(f.save(first).status, 0);
  const next = f.start();
  next.input.result = 'no-blocking-findings';
  assert.equal(f.save(next).status, 1);
  next.input.findings[0].status = 'accepted';
  next.input.findings[0].resolution = 'accepted exception';
  assert.equal(f.save(next).status, 1);
  next.input.findings = [];
  assert.equal(f.save(next).status, 1);
  next.input.findings = [
    {
      ...first.input.findings[0],
      status: 'resolved',
      resolution: 'verified fix',
    },
  ];
  assert.equal(f.save(next).status, 0);
  assert.equal(f.state().reviewHistory[0].findings[0].status, 'open');
  assert.equal(f.state().review.findings[0].status, 'resolved');
});

test('scope collection includes committed, staged, unstaged, renamed, deleted and untracked content', (t) => {
  const f = fixture(t);
  f.write('committed.txt', 'committed');
  f.git('add', 'committed.txt');
  f.git('commit', '-qm', 'feature');
  f.git('mv', 'tracked.txt', 'renamed.txt');
  f.write('renamed.txt', 'unstaged version');
  f.write('new\nfile.txt', 'new content');
  f.write('binary.dat', new Uint8Array([0, 1, 2]));
  symlinkSync('renamed.txt', path.join(f.root, 'link.txt'));
  rmSync(path.join(f.root, 'package.json'));
  const scope = collectScope(f.root, 'origin/develop', '.tmp/review');
  for (const file of [
    'committed.txt',
    'renamed.txt',
    'package.json',
    'new\nfile.txt',
    'binary.dat',
    'link.txt',
  ])
    assert.ok(scope.includes(file), file);
  assert.match(
    readFileSync(path.join(f.root, '.tmp/review/diff.patch'), 'utf8'),
    /committed/,
  );
  assert.match(
    readFileSync(path.join(f.root, '.tmp/review/staged.patch'), 'utf8'),
    /rename/,
  );
  assert.match(
    readFileSync(path.join(f.root, '.tmp/review/unstaged.patch'), 'utf8'),
    /unstaged version/,
  );
  assert.match(
    readFileSync(path.join(f.root, '.tmp/review/untracked.patch'), 'utf8'),
    /new content/,
  );
  assert.ok(
    readdirSync(path.join(f.root, '.tmp/review')).includes('files.json'),
  );
});

test('environment and base identity changes are stale, incomplete legacy records are unknown', (t) => {
  const f = fixture(t);
  assert.equal(f.run('check', '--script', 'lint:web').status, 0);
  const record = f.state().checks[0];
  assert.equal(
    assessFreshness(record, { ...record.subject, baseSha: 'different' })
      .effectiveFreshness,
    'needs-recheck',
  );
  f.write('node_modules/.package-lock.json', 'new dependency state');
  assert.equal(f.report().checks[0].effectiveFreshness, 'needs-recheck');
  assert.equal(
    assessFreshness(
      { result: 'passed', subject: { headSha: record.subject.headSha } },
      record.subject,
    ).effectiveFreshness,
    'unknown',
  );
  assert.equal(
    existsSync(path.join(f.root, '.tmp/ai-workflow/tasks/114/.record-lock')),
    false,
  );
});

test('review cannot save the initial placeholder or change generated subject and scope', (t) => {
  const f = fixture(t);
  const session = f.start();
  assert.equal(f.save(session).status, 1);
  const original = JSON.parse(JSON.stringify(session.input));
  session.input.result = 'no-blocking-findings';
  session.input.subject.headSha = 'invented';
  assert.equal(f.save(session).status, 1);
  session.input = {
    ...original,
    result: 'no-blocking-findings',
    scope: ['unrelated'],
  };
  assert.equal(f.save(session).status, 1);
  assert.equal(existsSync(path.join(f.root, f.statePath)), false);
});

test('missing base, conflicting issue and nonignored local directory block recording', (t) => {
  const f = fixture(t);
  assert.equal(f.run('check', '--script', 'lint:web', '--issue', '115').status, 1);
  assert.equal(
    f.run('check', '--script', 'lint:web', '--base', 'missing').status,
    1,
  );
  f.write('.gitignore', 'node_modules\n');
  assert.equal(f.run('check', '--script', 'lint:web').status, 1);
  assert.equal(existsSync(path.join(f.root, f.statePath)), false);
});

test('harness check is allowed, actually executes and accumulates log/subject records', (t) => {
  const f = fixture(t);
  assert.equal(f.run('check', '--script', 'workflow:harness-check').status, 0);
  assert.equal(f.run('check', '--script', 'workflow:harness-check').status, 0);
  const records = f.state().checks;
  assert.equal(records.length, 2);
  records.forEach((record) => {
    assert.equal(record.id, 'workflow:harness-check');
    assert.equal(record.command, 'npm run workflow:harness-check');
    assert.equal(record.result, 'passed');
    assert.equal(record.freshness, 'current');
    assert.deepEqual(record.subject, f.report().subject);
    assert.match(
      readFileSync(path.join(f.root, record.evidence[0]), 'utf8'),
      /actual harness pass/,
    );
  });
  assert.notEqual(records[0].evidence[0], records[1].evidence[0]);
});

test('scope collection rejects symlink directories before creating any external output, including CLI', (t) => {
  for (const link of ['.tmp', '.tmp/review', '.tmp/review/nested']) {
    const f = fixture(t);
    const outside = mkdtempSync(
      path.join(os.tmpdir(), 'ttak-scope-outside-'),
    );
    t.after(() => rmSync(outside, { recursive: true, force: true }));
    mkdirSync(path.dirname(path.join(f.root, link)), { recursive: true });
    symlinkSync(outside, path.join(f.root, link));
    assert.throws(
      () => collectScope(f.root, 'origin/develop', `${link}/output`),
      /리뷰 출력 경로가 일반 폴더가 아닙니다/,
    );
    const cli = spawnSync(
      process.execPath,
      [collectScript, 'origin/develop', `${link}/output`],
      {
        cwd: f.root,
        encoding: 'utf8',
      },
    );
    assert.equal(cli.status, 1);
    assert.match(cli.stderr, /리뷰 출력 경로가 일반 폴더가 아닙니다/);
    assert.deepEqual(readdirSync(outside), []);
  }
});

test('scope collection rejects existing artifact symlinks before any write and preserves external content', (t) => {
  const f = fixture(t);
  const outside = mkdtempSync(path.join(os.tmpdir(), 'ttak-scope-artifact-'));
  t.after(() => rmSync(outside, { recursive: true, force: true }));
  const sentinel = path.join(outside, 'sentinel.txt');
  writeFileSync(sentinel, 'preserve external content');
  mkdirSync(path.join(f.root, '.tmp/review'), { recursive: true });
  symlinkSync(sentinel, path.join(f.root, '.tmp/review/summary.md'));
  assert.throws(
    () => collectScope(f.root, 'origin/develop', '.tmp/review'),
    /리뷰 산출물이 일반 파일이 아닙니다/,
  );
  assert.equal(readFileSync(sentinel, 'utf8'), 'preserve external content');
  assert.equal(existsSync(path.join(f.root, '.tmp/review/diff.patch')), false);
});
