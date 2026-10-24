import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import {
  lstatSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { URL } from 'node:url';
import { assessFreshness, collectScope, git } from './evidence-core.mjs';
import { buildReport, validState } from './resume.mjs';

const parse = (args) => {
  const operation = args.shift();
  const options = {
    operation,
    issue: null,
    base: 'origin/develop',
    start: false,
    input: null,
    script: null,
  };
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--start') options.start = true;
    else if (
      ['--issue', '--base', '--input', '--script'].includes(args[i]) &&
      args[i + 1] &&
      !args[i + 1].startsWith('-')
    ) {
      const key = args[i].slice(2);
      options[key] = args[++i];
    } else
      throw new Error(
        '잘못된 인자입니다. check --script {명령} 또는 review --start/--input {파일}을 사용하세요.',
      );
  }
  if (options.issue !== null) {
    if (
      !/^[1-9]\d*$/.test(options.issue) ||
      !Number.isSafeInteger(Number(options.issue))
    )
      throw new Error('이슈는 양의 정수여야 합니다.');
    options.issue = Number(options.issue);
  }
  if (
    operation === 'check' &&
    (options.start ||
      options.input ||
      ![
        'lint:web',
        'check-types:web',
        'build:web',
        'macos:build',
        'macos:test',
        'workflow:test',
        'workflow:harness-check',
      ].includes(options.script))
  )
    throw new Error(
      '지원하는 검사: lint:web, check-types:web, build:web, macos:build, macos:test, workflow:test, workflow:harness-check',
    );
  if (
    operation === 'review' &&
    (options.script ||
      Number(options.start) + Number(Boolean(options.input)) !== 1)
  )
    throw new Error('review는 --start 또는 --input 중 하나를 사용하세요.');
  if (!['check', 'review'].includes(operation))
    throw new Error('check 또는 review 작업을 지정하세요.');
  return options;
};

const ensureDirectory = (root, relative) => {
  let current = root;
  relative.split('/').forEach((segment) => {
    current = path.join(current, segment);
    try {
      const stat = lstatSync(current);
      if (!stat.isDirectory() || stat.isSymbolicLink())
        throw new Error(`로컬 기록 경로가 일반 폴더가 아닙니다: ${current}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      mkdirSync(current);
    }
  });
};
const writeJson = (file, value) => {
  const temp = `${file}.${randomUUID()}.tmp`;
  try {
    writeFileSync(temp, `${JSON.stringify(value, null, 2)}\n`);
    renameSync(temp, file);
  } finally {
    rmSync(temp, { force: true });
  }
};
const freshContext = (options) => {
  const report = buildReport(options);
  if (
    !report.issue ||
    !report.spec?.revision ||
    !report.baseSha ||
    !report.subject
  )
    throw new Error('대상 이슈·명세·기준 ref·코드 상태를 먼저 확인하세요.');
  if (report.stateMismatches.includes('branchIssue'))
    throw new Error('브랜치와 지정한 이슈가 다릅니다.');
  const task = `.tmp/ai-workflow/tasks/${report.issue}`;
  if (git(['ls-files', '--', '.tmp'], report.root).trim())
    throw new Error('.tmp는 Git에 추적되면 안 됩니다.');
  try {
    git(
      ['check-ignore', '-q', '--no-index', '--', `${task}/status.json`],
      report.root,
    );
  } catch {
    throw new Error('.tmp 상태 파일의 Git ignore 설정이 필요합니다.');
  }
  ensureDirectory(report.root, task);
  return { report, task, directory: path.join(report.root, task) };
};
const loadState = (report, directory) => {
  let state;
  try {
    state = JSON.parse(
      readFileSync(path.join(directory, 'status.json'), 'utf8'),
    );
    if (!validState(state)) throw new Error('상태 형식 오류');
    if (
      state.issue !== report.issue ||
      state.branch !== report.branch ||
      state.specPath !== report.spec.path
    )
      throw new Error('상태가 다른 작업에 연결되어 있습니다.');
  } catch (error) {
    if (error.code !== 'ENOENT')
      throw new Error(`기존 상태를 보존합니다: ${error.message}`);
    state = JSON.parse(
      readFileSync(
        new URL(
          '../../docs/ai-workflow/templates/status.json',
          import.meta.url,
        ),
        'utf8',
      ),
    );
    Object.assign(state, {
      issue: report.issue,
      branch: report.branch,
      specPath: report.spec.path,
      specRevision: report.spec.revision,
    });
  }
  state.reviewHistory ??= [];
  if (!Array.isArray(state.reviewHistory))
    throw new Error('reviewHistory 형식 오류');
  const ids = report.spec.acceptance.map(
    (line) => line.match(/^- (AC-\d+):/)[1],
  );
  state.acceptance = ids.map((id) => {
    const old = state.acceptance.find((item) => item.id === id);
    if (!old) return { id, status: 'pending', evidence: [] };
    return state.specRevision !== report.spec.revision && old.status === 'met'
      ? { ...old, status: 'needs-recheck' }
      : old;
  });
  state.specRevision = report.spec.revision;
  state.checks.forEach((record) => {
    record.freshness = assessFreshness(
      record,
      report.subject,
    ).effectiveFreshness;
  });
  state.review.freshness = assessFreshness(
    state.review,
    report.subject,
  ).effectiveFreshness;
  return state;
};

const validateReview = (input, session, state) => {
  if (
    JSON.stringify(input.subject) !== JSON.stringify(session.subject) ||
    JSON.stringify(input.scope) !== JSON.stringify(session.scope)
  )
    throw new Error(
      '리뷰 시작 대상과 범위는 변경할 수 없습니다. 새 리뷰 세션을 시작하세요.',
    );
  if (!['changes-required', 'no-blocking-findings'].includes(input.result))
    throw new Error('실제 리뷰 후 result를 지정하세요.');
  for (const key of ['focusPoints', 'unverified', 'nextActions']) {
    if (
      !Array.isArray(input[key]) ||
      !input[key].every((item) => typeof item === 'string')
    )
      throw new Error(`${key}는 문자열 배열이어야 합니다.`);
  }
  if (!Array.isArray(input.findings)) throw new Error('findings가 필요합니다.');
  const ids = new Set();
  input.findings.forEach((item) => {
    if (
      !item ||
      typeof item.id !== 'string' ||
      !item.id ||
      ids.has(item.id) ||
      !['High', 'Medium', 'Low'].includes(item.severity) ||
      typeof item.file !== 'string' ||
      !item.file ||
      !Number.isInteger(item.line) ||
      item.line < 1 ||
      typeof item.description !== 'string' ||
      !item.description.trim() ||
      !['open', 'resolved', 'accepted'].includes(item.status) ||
      typeof item.resolution !== 'string' ||
      (item.status !== 'open' && !item.resolution.trim())
    )
      throw new Error(
        '리뷰 지적사항 ID·심각도·파일/줄·설명·상태·해결 근거를 확인하세요.',
      );
    ids.add(item.id);
  });
  state.review.findings
    .filter((item) => item.status !== 'resolved')
    .forEach((item) => {
      if (!ids.has(item.id))
        throw new Error(
          `이전 미해결 지적 ${item.id}를 누락할 수 없습니다. 해결 여부를 기록하세요.`,
        );
    });
  if (
    input.result === 'no-blocking-findings' &&
    input.findings.some(
      (item) => item.severity !== 'Low' && item.status !== 'resolved',
    )
  )
    throw new Error('미해결 High/Medium 결함은 changes-required로 기록하세요.');
};

try {
  const options = parse(process.argv.slice(2));
  const context = freshContext(options);
  const lock = path.join(context.directory, '.record-lock');
  try {
    mkdirSync(lock);
  } catch {
    throw new Error(
      '다른 기록 작업이 실행 중이거나 이전 lock이 남았습니다. 확인 후 재시도하세요.',
    );
  }
  try {
    const { report, task, directory } = freshContext(options);
    const state = loadState(report, directory);
    if (options.operation === 'check') {
      const scripts = JSON.parse(
        readFileSync(path.join(report.root, 'package.json'), 'utf8'),
      ).scripts;
      if (!scripts?.[options.script])
        throw new Error('package.json에 검사 명령이 없습니다.');
      const id = randomUUID();
      ensureDirectory(report.root, `${task}/checks`);
      const checkedAt = new Date().toISOString();
      const result = spawnSync('npm', ['run', options.script], {
        cwd: report.root,
        encoding: 'utf8',
        maxBuffer: 64 * 1024 * 1024,
        timeout: 600000,
      });
      const output = `${result.stdout ?? ''}${result.stderr ?? ''}${result.error ? `\n${result.error.message}` : ''}`;
      process.stdout.write(output);
      const after = buildReport(options);
      const record = {
        id: options.script,
        runId: id,
        command: `npm run ${options.script}`,
        result: result.status === 0 && !result.error ? 'passed' : 'failed',
        freshness: 'current',
        scope: ['저장소 전체'],
        checkedAt,
        subject: report.subject,
        exitCode: result.status ?? 1,
        reason: result.error?.message ?? null,
        evidence: [`${task}/checks/${id}.log`],
      };
      const identityChanges =
        after.branch !== report.branch || after.issue !== report.issue
          ? ['task']
          : [];
      record.freshness = assessFreshness(
        record,
        after.subject,
        identityChanges,
      ).effectiveFreshness;
      writeFileSync(path.join(directory, 'checks', `${id}.log`), output);
      writeJson(path.join(directory, 'checks', `${id}.json`), record);
      state.checks.push(record);
      state.phase = 'verification';
      state.updatedAt = new Date().toISOString();
      writeJson(path.join(directory, 'status.json'), state);
      process.stdout.write(
        `\n검사 기록: ${record.result} / ${record.freshness} → ${task}/status.json\n`,
      );
      process.exitCode = record.exitCode;
    } else if (options.start) {
      const id = randomUUID();
      const sessionDir = `${task}/reviews/${id}`;
      ensureDirectory(report.root, sessionDir);
      const scope = collectScope(report.root, report.baseRef, sessionDir);
      const after = buildReport(options);
      if (
        assessFreshness(
          { subject: report.subject, freshness: 'current' },
          after.subject,
        ).effectiveFreshness !== 'current'
      )
        throw new Error(
          '리뷰 범위 수집 중 코드가 바뀌었습니다. 다시 시작하세요.',
        );
      const session = {
        sessionId: id,
        issue: report.issue,
        branch: report.branch,
        subject: report.subject,
        scope,
        startedAt: new Date().toISOString(),
      };
      writeJson(path.join(report.root, sessionDir, 'snapshot.json'), session);
      writeJson(path.join(report.root, sessionDir, 'input.json'), {
        subject: session.subject,
        scope,
        result: 'not-run',
        focusPoints: [],
        findings: state.review.findings,
        unverified: [],
        nextActions: state.nextActions,
      });
      process.stdout.write(
        `리뷰 시작: ${sessionDir}/input.json\n대상 파일 ${scope.length}개. patch와 실제 파일을 검토한 뒤 result·findings·unverified를 작성하세요.\n`,
      );
    } else {
      const inputPath = path.resolve(report.root, options.input);
      const relative = path
        .relative(directory, inputPath)
        .split(path.sep)
        .join('/');
      if (!/^reviews\/[a-z0-9-]+\/input\.json$/.test(relative))
        throw new Error(
          '현재 작업에서 생성한 리뷰 세션 input.json만 저장할 수 있습니다.',
        );
      const session = JSON.parse(
        readFileSync(
          path.join(path.dirname(inputPath), 'snapshot.json'),
          'utf8',
        ),
      );
      if (session.issue !== report.issue || session.branch !== report.branch)
        throw new Error('리뷰 세션이 다른 작업에 연결되어 있습니다.');
      const input = JSON.parse(readFileSync(inputPath, 'utf8'));
      validateReview(input, session, state);
      const record = {
        ...input,
        sessionId: session.sessionId,
        reviewedAt: new Date().toISOString(),
        freshness: 'current',
        evidence: [
          path.relative(report.root, inputPath).split(path.sep).join('/'),
        ],
      };
      record.freshness = assessFreshness(
        record,
        report.subject,
      ).effectiveFreshness;
      if (state.review.result !== 'not-run')
        state.reviewHistory.push(state.review);
      state.review = record;
      state.nextActions = input.nextActions;
      state.phase = 'review';
      state.updatedAt = new Date().toISOString();
      writeJson(path.join(path.dirname(inputPath), 'result.json'), record);
      writeJson(path.join(directory, 'status.json'), state);
      process.stdout.write(
        `리뷰 기록: ${record.result} / ${record.freshness} → ${task}/status.json\n`,
      );
    }
  } finally {
    rmSync(lock, { recursive: true, force: true });
  }
} catch (error) {
  process.stderr.write(`증적 기록 실패: ${error.message}\n`);
  process.exitCode = 1;
}
