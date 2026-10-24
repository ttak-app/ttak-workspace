import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import test from 'node:test';
import { fileURLToPath, URL } from 'node:url';
const script = fileURLToPath(new URL('./pr-check.mjs', import.meta.url));
const resume = fileURLToPath(new URL('./resume.mjs', import.meta.url));
const template = JSON.parse(
  readFileSync(
    new URL('../../docs/ai-workflow/templates/status.json', import.meta.url),
  ),
);
const fixture = (t, files = ['src/app.ts']) => {
  const root = mkdtempSync(path.join(os.tmpdir(), 'ttak-pr-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const git = (...args) =>
    execFileSync('git', args, {
      cwd: root,
      encoding: 'utf8',
      stdio: 'pipe',
    }).trim();
  const write = (file, value) => {
    mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    writeFileSync(path.join(root, file), value);
  };
  git('init', '-q');
  git('config', 'user.name', 'Test');
  git('config', 'user.email', 'test@example.invalid');
  git('config', 'core.hooksPath', '/dev/null');
  git('config', 'commit.gpgSign', 'false');
  write('.gitignore', '.tmp\n');
  git('add', '.');
  git('commit', '-qm', 'initial');
  git('update-ref', 'refs/remotes/origin/develop', 'HEAD');
  git('switch', '-qc', 'chore/harness/#114');
  const specPath = 'docs/ai-workflow/tasks/114/spec.md';
  const content =
    '# Spec\n- 이슈: [#114](https://example.invalid/114)\n- 브랜치: `chore/harness/#114`\n- specRevision: 1\n\n## 완료 조건\n- AC-1: works\n';
  write(specPath, content);
  files.forEach((file) => write(file, 'change\n'));
  git('add', '.');
  git('commit', '-qm', 'change');
  const subject = JSON.parse(
    execFileSync(process.execPath, [resume, '--json'], {
      cwd: root,
      encoding: 'utf8',
    }),
  ).subject;
  write('.tmp/evidence.log', 'actual observations\n');
  const evidence = ['.tmp/evidence.log'];
  const common = { subject, freshness: 'current', evidence };
  const check = (
    id,
    checkedAt = '2026-10-04T01:00:00.000Z',
    result = 'passed',
  ) => ({
    ...common,
    id,
    checkedAt,
    command: `npm run ${id}`,
    result,
    exitCode: result === 'passed' ? 0 : 1,
  });
  const state = {
    ...JSON.parse(JSON.stringify(template)),
    issue: 114,
    branch: 'chore/harness/#114',
    specPath,
    specRevision: 1,
    acceptance: [{ ...common, id: 'AC-1', status: 'met' }],
    checks: [
      'lint:web',
      'check-types:web',
      'build:web',
      'docs-review',
      'workflow:test',
      'workflow:harness-check',
    ].map((id) => check(id)),
    readinessEvidence: ['behavior', 'harness-validation'].map((kind) => ({
      ...common,
      kind,
      result: 'passed',
      checkedAt: '2026-10-04T01:00:00.000Z',
      reason: 'actual observed scenarios',
    })),
    review: {
      ...template.review,
      ...common,
      result: 'no-blocking-findings',
      reviewedAt: '2026-10-04T01:00:00.000Z',
      scope: [specPath, ...files],
    },
  };
  const save = () =>
    write('.tmp/ai-workflow/tasks/114/status.json', JSON.stringify(state));
  const run = (args = []) => {
    save();
    const output = spawnSync(process.execPath, [script, '--json', ...args], {
      cwd: root,
      encoding: 'utf8',
    });
    return {
      code: output.status,
      report: output.stdout ? JSON.parse(output.stdout) : null,
      stderr: output.stderr,
    };
  };
  const codes = () => run().report.blockers.map((item) => item.code);
  return {
    root,
    git,
    write,
    state,
    subject,
    check,
    run,
    codes,
    save,
    specPath,
    content,
  };
};
test('ready app/harness evidence; no filesystem or git writes; legacy checks irrelevant', (t) => {
  const f = fixture(t, ['src/app.ts', 'tools/ai-workflow/example.mjs']);
  f.state.checks.push({ ...f.check('typecheck'), result: 'not-run' });
  f.save();
  const stateBefore = readFileSync(
    path.join(f.root, '.tmp/ai-workflow/tasks/114/status.json'),
    'utf8',
  );
  const indexBefore = readFileSync(path.join(f.root, '.git/index'));
  const result = f.run();
  assert.equal(result.code, 0, JSON.stringify(result.report.blockers));
  assert.equal(
    readFileSync(
      path.join(f.root, '.tmp/ai-workflow/tasks/114/status.json'),
      'utf8',
    ),
    stateBefore,
  );
  assert.deepEqual(readFileSync(path.join(f.root, '.git/index')), indexBefore);
});
test('latest success replaces old failure; latest failure and ambiguous timestamps block', (t) => {
  const f = fixture(t);
  f.state.checks.push(f.check('lint:web', '2026-10-03T01:00:00.000Z', 'failed'));
  assert.equal(f.run().code, 0);
  f.state.checks.push(f.check('lint:web', '2026-10-05T01:00:00.000Z', 'failed'));
  assert.ok(f.codes().includes('check:lint:web'));
  f.state.checks.at(-1).result = 'passed';
  f.state.checks.at(-1).exitCode = 0;
  assert.equal(f.run().code, 0);
  f.state.checks.push(f.check('lint:web', '2026-10-05T01:00:00.000Z', 'failed'));
  assert.ok(f.codes().includes('check:lint:web'));
  f.state.checks.at(-1).checkedAt = 'malformed';
  assert.ok(f.codes().includes('check:lint:web'));
});
test('missing AC/log/manual evidence and stale acceptance block', (t) => {
  const f = fixture(t);
  f.state.acceptance[0].evidence = ['.tmp/missing'];
  assert.ok(f.codes().includes('acceptance:AC-1'));
  f.state.acceptance[0].evidence = ['.tmp/evidence.log'];
  f.state.acceptance[0].subject = { ...f.subject, headSha: 'old' };
  assert.ok(f.codes().includes('acceptance:AC-1'));
  f.state.checks[0].evidence = ['.tmp/missing.log'];
  assert.ok(f.codes().includes('check:lint:web'));
  f.state.readinessEvidence = [];
  assert.ok(f.codes().includes('manual:behavior'));
});
test('dirty staged/unstaged/untracked and post-check content changes block', (t) => {
  const f = fixture(t);
  f.write('src/app.ts', 'staged');
  f.git('add', 'src/app.ts');
  f.write('src/app.ts', 'unstaged');
  f.write('new.txt', 'untracked');
  const result = f.run();
  assert.ok(result.report.blockers.some((item) => item.code === 'dirty'));
  assert.equal(result.report.checks[0].freshness, 'needs-recheck');
});
test('docs-only needs explicit N/A and document review; same-subject failure cannot hide in N/A', (t) => {
  const f = fixture(t, ['docs/guide.md']);
  f.state.checks = f.state.checks.filter((item) => item.id !== 'workflow:test');
  f.state.checks.forEach((item) => {
    if (['lint:web', 'check-types:web', 'build:web'].includes(item.id))
      Object.assign(item, {
        result: 'not-applicable',
        reason: 'only docs',
        evidence: [],
      });
  });
  assert.equal(f.run().code, 0);
  f.state.checks[0].reason = '';
  assert.ok(f.codes().includes('check:lint:web'));
  f.state.checks[0].reason = 'only docs';
  f.state.checks.push(f.check('lint:web', '2026-10-03T01:00:00.000Z', 'failed'));
  assert.ok(f.codes().includes('check:lint:web'));
});
test('runtime Markdown and unknown files require app checks', (t) => {
  const f = fixture(t, ['src/content.md']);
  assert.ok(f.run().report.kinds.includes('app'));
  f.state.readinessEvidence = [];
  assert.ok(f.codes().includes('manual:behavior'));
});
test('review scope, High/Medium, Low reason and unverified AC impact block', (t) => {
  const f = fixture(t);
  f.state.review.scope = [];
  assert.ok(f.codes().includes('review-scope'));
  f.state.review.scope = [f.specPath, 'src/app.ts'];
  f.state.review.findings = [
    {
      id: 'R1',
      severity: 'High',
      status: 'accepted',
      file: 'src/app.ts',
      line: 1,
      description: 'bug',
      resolution: 'accepted',
    },
  ];
  assert.ok(f.codes().includes('review-findings'));
  Object.assign(f.state.review.findings[0], {
    severity: 'Low',
    resolution: '',
  });
  assert.ok(f.codes().includes('review-findings'));
  f.state.review.findings = [];
  f.state.review.unverified = ['external API'];
  assert.ok(f.codes().includes('review-unverified'));
  f.state.review.unverifiedAssessment = {
    acceptanceImpact: 'none',
    reason: 'no API touched',
    evidence: ['.tmp/evidence.log'],
  };
  assert.equal(f.run().code, 0);
});
test('three reviews may omit resolved history ID but never unresolved last state', (t) => {
  const f = fixture(t);
  const finding = {
    id: 'R1',
    severity: 'Medium',
    status: 'open',
    file: 'src/app.ts',
    line: 1,
    description: 'bug',
    resolution: '',
  };
  f.state.reviewHistory = [
    {
      ...f.state.review,
      reviewedAt: '2026-10-02T01:00:00.000Z',
      result: 'changes-required',
      findings: [finding],
    },
  ];
  assert.ok(f.codes().includes('review-history'));
  f.state.reviewHistory.push({
    ...f.state.review,
    reviewedAt: '2026-10-03T01:00:00.000Z',
    findings: [{ ...finding, status: 'resolved', resolution: 'fixed' }],
  });
  assert.equal(f.run().code, 0);
  f.state.review.reviewedAt = '2026-10-01T01:00:00.000Z';
  assert.ok(f.codes().includes('review'));
});
test('identity/base/malformed spec and unsafe evidence never ready', (t) => {
  const f = fixture(t);
  f.state.specRevision = 2;
  assert.ok(f.codes().includes('identity'));
  f.state.specRevision = 1;
  assert.equal(f.run(['--base', 'origin/missing']).code, 1);
  assert.equal(f.run(['--issue', '115']).code, 1);
  f.write(f.specPath, f.content + '- AC-1: duplicate\n');
  assert.ok(f.codes().includes('acceptance-spec'));
  f.write(f.specPath, f.content);
  f.state.acceptance[0].evidence = ['/etc/hosts'];
  assert.ok(f.codes().includes('acceptance:AC-1'));
  f.state.acceptance[0].evidence = ['../escape'];
  assert.ok(f.codes().includes('acceptance:AC-1'));
  symlinkSync('/etc/hosts', path.join(f.root, '.tmp/outside.log'));
  f.state.acceptance[0].evidence = ['.tmp/outside.log'];
  assert.ok(f.codes().includes('acceptance:AC-1'));
});
test('main/develop/detached, malformed state and invalid options block', (t) => {
  const f = fixture(t);
  f.git('switch', '-qc', 'develop');
  assert.ok(f.codes().includes('branch'));
  f.git('switch', '--detach', '-q');
  assert.ok(f.codes().includes('branch'));
  f.state.checks = ['invalid'];
  assert.ok(f.codes().includes('identity'));
  assert.equal(f.run(['--unknown']).code, 2);
});

test('malformed history/manual fields block instead of throwing or passing', (t) => {
  const f = fixture(t);
  f.state.reviewHistory = [{ reviewedAt: '2026-10-03T01:00:00.000Z' }];
  assert.ok(f.codes().includes('review-history-format'));
  f.state.reviewHistory = [];
  f.state.readinessEvidence = [null, 'bad'];
  assert.ok(f.codes().includes('manual:behavior'));
  f.state.checks[0].checkedAt = '1';
  assert.ok(f.codes().includes('check:lint:web'));
});

test('spec identity accepts exact plain/link values and blocks duplicate, empty or wrong fields', (t) => {
  const f = fixture(t);
  const issueLine = '- 이슈: [#114](https://example.invalid/114)';
  const branchLine = '- 브랜치: `chore/harness/#114`';
  const variants = [
    f.content.replace(issueLine, `${issueLine}\n- 이슈: #999`),
    f.content.replace(issueLine, `${issueLine}\n- 이슈: #114`),
    f.content.replace(branchLine, `${branchLine}\n- 브랜치: feat/other/#114`),
    f.content.replace(branchLine, `${branchLine}\n${branchLine}`),
    f.content.replace(issueLine, '- 이슈: '),
    f.content.replace(issueLine, '- 이슈: #999'),
    f.content.replace(issueLine, '- 이슈: #1140'),
    f.content.replace(issueLine, '- 이슈: #0'),
    f.content.replace(branchLine, '- 브랜치: '),
    f.content.replace(branchLine, '- 브랜치: feat/other/#114'),
    f.content.replace(branchLine, '- 브랜치: `chore/harness/#114` extra'),
  ];
  variants.forEach((content) => {
    f.write(f.specPath, content);
    assert.ok(f.codes().includes('spec-identity'), content);
  });
  [
    '- 이슈: #114',
    '- 이슈: #114 / https://example.invalid/114',
    issueLine,
  ].forEach((line) => {
    f.write(
      f.specPath,
      f.content
        .replace(issueLine, line)
        .replace(branchLine, '- 브랜치: chore/harness/#114'),
    );
    assert.ok(!f.codes().includes('spec-identity'), line);
  });
  f.write(f.specPath, f.content);
  assert.equal(f.run().code, 0);
});

test('every PR including docs-only requires current latest harness success and actual log', (t) => {
  const f = fixture(t, ['docs/guide.md']);
  assert.ok(f.run().report.requiredChecks.includes('workflow:harness-check'));
  f.state.checks = f.state.checks.filter(
    (item) => item.id !== 'workflow:harness-check',
  );
  assert.ok(f.codes().includes('check:workflow:harness-check'));
  f.state.checks.push(f.check('workflow:harness-check'));
  assert.equal(f.run().code, 0);
  f.state.checks.push(
    f.check('workflow:harness-check', '2026-10-05T01:00:00.000Z', 'failed'),
  );
  assert.ok(f.codes().includes('check:workflow:harness-check'));
  Object.assign(f.state.checks.at(-1), {
    result: 'not-applicable',
    reason: 'docs only',
  });
  assert.ok(f.codes().includes('check:workflow:harness-check'));
  Object.assign(f.state.checks.at(-1), {
    result: 'passed',
    exitCode: 0,
    evidence: ['.tmp/missing.log'],
  });
  assert.ok(f.codes().includes('check:workflow:harness-check'));
  Object.assign(f.state.checks.at(-1), {
    evidence: ['.tmp/evidence.log'],
    subject: { ...f.subject, headSha: 'old' },
  });
  assert.ok(f.codes().includes('check:workflow:harness-check'));
});

test('macOS code requires native build instead of web validation', (t) => {
  const f = fixture(t, ['apps/macos/Ttak/Features/Example.swift']);
  const report = f.run().report;
  assert.ok(report.kinds.includes('macos'));
  assert.ok(report.requiredChecks.includes('macos:build'));
  assert.ok(!report.requiredChecks.includes('build:web'));
  assert.ok(f.codes().includes('check:macos:build'));
  f.state.checks.push(f.check('macos:build'));
  assert.ok(!f.codes().includes('check:macos:build'));
  f.state.checks.push(f.check('macos:build', '2026-10-05T01:00:00.000Z', 'failed'));
  assert.ok(f.codes().includes('check:macos:build'));
});
test('Swift test changes require actual native tests, while docs do not', (t) => {
  const f = fixture(t, ['apps/macos/TtakTests/DateTests.swift']);
  assert.ok(f.run().report.requiredChecks.includes('macos:test'));
  const docs = fixture(t, ['apps/macos/README.md']);
  assert.ok(!docs.run().report.requiredChecks.includes('macos:build'));
});
