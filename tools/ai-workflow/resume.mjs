import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { captureSubject, assessFreshness } from './evidence-core.mjs';

const git = (args, cwd) =>
  execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' },
  });

const parseArgs = (args) => {
  const options = {
    issue: null,
    json: false,
    help: false,
    base: 'origin/develop',
  };
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--base' && args[i + 1] && !args[i + 1].startsWith('-'))
      options.base = args[++i];
    else if (args[i] === '--json') options.json = true;
    else if (args[i] === '--help') options.help = true;
    else if (
      args[i] === '--issue' &&
      options.issue === null &&
      /^[1-9]\d*$/.test(args[i + 1] ?? '')
    ) {
      options.issue = Number(args[++i]);
      if (!Number.isSafeInteger(options.issue))
        throw new Error('이슈 번호가 너무 큽니다.');
    } else
      throw new Error(
        '사용법: workflow:resume [--issue 양의정수] [--base ref] [--json] [--help]',
      );
  }
  return options;
};

const readOptional = (root, relative, warnings) => {
  try {
    return readFileSync(path.join(root, relative), 'utf8');
  } catch (error) {
    if (error.code !== 'ENOENT')
      warnings.push(`${relative}: 파일을 읽지 못했습니다 (${error.code}).`);
    return null;
  }
};

const parseChanges = (raw) => {
  const fields = raw.split('\0');
  const changes = [];
  for (let i = 0; i < fields.length; i += 1) {
    if (!fields[i]) continue;
    const index = fields[i][0];
    const worktree = fields[i][1];
    const file = fields[i].slice(3);
    const source = /[RC]/.test(index + worktree) ? fields[++i] : null;
    changes.push({ file, source, index, worktree, untracked: index === '?' });
  }
  return changes;
};

const isObject = (value) =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
const isNullableString = (value) => value === null || typeof value === 'string';
const isStrings = (value) =>
  Array.isArray(value) && value.every((item) => typeof item === 'string');
const isRevision = (value) =>
  value === null || (Number.isSafeInteger(value) && value > 0);
export const validState = (value) =>
  isObject(value) &&
  value.schemaVersion === 1 &&
  isRevision(value.issue) &&
  isRevision(value.specRevision) &&
  ['branch', 'specPath', 'updatedAt'].every((key) =>
    isNullableString(value[key]),
  ) &&
  [
    'design',
    'implementation',
    'verification',
    'review',
    'pr-ready',
    'done',
  ].includes(value.phase) &&
  isStrings(value.nextActions) &&
  isStrings(value.blockers) &&
  Array.isArray(value.acceptance) &&
  value.acceptance.every(
    (item) =>
      isObject(item) &&
      typeof item.id === 'string' &&
      ['pending', 'met', 'not-met', 'needs-recheck'].includes(item.status),
  ) &&
  Array.isArray(value.checks) &&
  value.checks.every(
    (item) =>
      isObject(item) &&
      typeof item.id === 'string' &&
      typeof item.command === 'string' &&
      ['passed', 'failed', 'not-run', 'not-applicable'].includes(item.result) &&
      ['current', 'needs-recheck', 'unknown'].includes(item.freshness) &&
      (item.subject === null || isObject(item.subject)),
  ) &&
  isObject(value.review) &&
  ['not-run', 'changes-required', 'no-blocking-findings'].includes(
    value.review.result,
  ) &&
  ['current', 'needs-recheck', 'unknown'].includes(value.review.freshness) &&
  (value.review.subject === null || isObject(value.review.subject)) &&
  ['scope', 'focusPoints', 'unverified'].every((key) =>
    isStrings(value.review[key]),
  ) &&
  Array.isArray(value.review.findings) &&
  value.review.findings.every(
    (item) =>
      isObject(item) &&
      typeof item.id === 'string' &&
      ['High', 'Medium', 'Low'].includes(item.severity) &&
      ['open', 'resolved', 'accepted'].includes(item.status),
  );

const assessRecord = (record, report) =>
  assessFreshness(record, report.subject, report.stateMismatches);

export const buildReport = (options) => {
  let root;
  try {
    root = git(['rev-parse', '--show-toplevel'], process.cwd()).trim();
  } catch {
    throw new Error('현재 위치가 접근 가능한 Git 저장소가 아닙니다.');
  }
  let branch;
  let headSha;
  try {
    branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], root).trim();
    headSha = git(['rev-parse', 'HEAD'], root).trim();
  } catch {
    throw new Error(
      '현재 브랜치/HEAD를 읽지 못했습니다. 첫 커밋이 있는지 확인하세요.',
    );
  }
  const branchIssue = Number(branch.match(/\/#([1-9]\d*)$/)?.[1]) || null;
  const issue = options.issue ?? branchIssue;
  const report = {
    root,
    branch,
    headSha,
    issue,
    baseRef: options.base ?? 'origin/develop',
    subject: null,
    baseSha: null,
    changes: parseChanges(
      git(['status', '--porcelain=v1', '-z', '--untracked-files=all'], root),
    ),
    committedFiles: [],
    spec: null,
    state: null,
    stateMismatches: [],
    checks: [],
    review: null,
    nextActions: [],
    warnings: [],
  };
  try {
    report.baseSha = git(
      ['rev-parse', '--verify', `${report.baseRef}^{commit}`],
      root,
    ).trim();
    report.committedFiles = git(
      ['diff', '--name-only', '-z', `${report.baseRef}...HEAD`],
      root,
    )
      .split('\0')
      .filter(Boolean);
  } catch {
    report.warnings.push(
      `${report.baseRef} 조회/비교 불가. fetch 또는 기준 브랜치를 별도로 확인하세요.`,
    );
  }
  if (!issue) {
    report.warnings.push(
      '브랜치에서 이슈 번호를 찾지 못했습니다. --issue {번호}로 지정하세요.',
    );
    report.nextActions = ['대상 이슈를 지정하고 명세를 확인하세요.'];
    return report;
  }
  if (branchIssue && options.issue && branchIssue !== options.issue) {
    report.warnings.push(
      `지정한 이슈 #${issue}와 브랜치 이슈 #${branchIssue}가 다릅니다.`,
    );
    report.stateMismatches.push('branchIssue');
  }
  const specPath = `docs/ai-workflow/tasks/${issue}/spec.md`;
  const content = readOptional(root, specPath, report.warnings);
  if (content !== null) {
    const revisions = [
      ...content.matchAll(/^- specRevision: ([1-9]\d*)\s*$/gm),
    ];
    const revision = revisions.length === 1 ? Number(revisions[0][1]) : null;
    report.spec = {
      path: specPath,
      revision,
      content,
      title: content.match(/^# (.+)$/m)?.[1] ?? null,
      purpose:
        content.match(/## 목적\s*\n([\s\S]*?)(?=\n## |$)/)?.[1].trim() ?? null,
      acceptance: content.split('\n').filter((line) => /^- AC-\d+:/.test(line)),
      undecided:
        content.match(/## 미결정 사항\s*\n([\s\S]*?)(?=\n## |$)/)?.[1].trim() ??
        null,
    };
    if (!revision || !Number.isSafeInteger(revision)) {
      report.spec.revision = null;
      report.warnings.push('명세의 specRevision을 확인할 수 없습니다.');
      report.stateMismatches.push('specRevision');
    }
  } else report.warnings.push(`명세 없음: ${specPath}`);
  try {
    report.subject = captureSubject(report);
  } catch (error) {
    report.warnings.push(`코드 상태 수집 실패: ${error.message}`);
  }
  const statePath = `.tmp/ai-workflow/tasks/${issue}/status.json`;
  const rawState = readOptional(root, statePath, report.warnings);
  if (rawState === null)
    report.warnings.push(
      `로컬 상태 없음: ${statePath}. 이전 완료·검증 상태는 미확인입니다.`,
    );
  else {
    try {
      const state = JSON.parse(rawState);
      if (!validState(state)) throw new Error('지원하지 않는 상태 형식');
      report.state = state;
      const expected = {
        issue,
        branch,
        specPath,
        specRevision: report.spec?.revision ?? null,
      };
      Object.entries(expected).forEach(([key, value]) => {
        if (value === null || state[key] !== value)
          report.stateMismatches.push(key);
      });
      if (report.stateMismatches.length)
        report.warnings.push(
          `상태 연결 불일치: ${report.stateMismatches.join(', ')}. 기록을 현재 작업 완료로 인정하지 마세요.`,
        );
      report.checks = state.checks.map((record) => ({
        id: record.id,
        command: record.command,
        ...assessRecord(record, report),
      }));
      report.review = assessRecord(state.review, report);
      report.nextActions = report.stateMismatches.length
        ? ['실제 브랜치·명세와 로컬 상태의 연결을 먼저 확인하세요.']
        : [...state.nextActions];
    } catch {
      report.warnings.push(
        `상태 JSON/형식 오류: ${statePath}. 파일을 보존하고 내용을 확인하세요.`,
      );
    }
  }
  if (!report.nextActions.length)
    report.nextActions.push(
      '명세의 완료 조건과 실제 변경을 확인하고 남은 작업을 기록하세요.',
    );
  report.warnings.push(
    '복원은 기록과 현재 코드·기록된 환경을 비교합니다. 검증 재실행·외부 환경 확인·PR 준비 판정은 수행하지 않습니다.',
  );
  return report;
};

const formatReport = (report) => {
  const lines = [
    '작업 복원 (읽기 전용)',
    `저장소: ${report.root}`,
    `브랜치: ${report.branch}`,
    `이슈: ${report.issue ? `#${report.issue}` : '미연결'}`,
    `HEAD: ${report.headSha}`,
    `기준: ${report.baseRef} @ ${report.baseSha ?? '미확인'}`,
    `명세: ${report.spec?.path ?? '없음'} (버전 ${report.spec?.revision ?? '미확인'})`,
    `목적: ${report.spec?.purpose ?? '미확인'}`,
    '',
    '명세 완료 조건:',
    ...(report.spec?.acceptance.length ? report.spec.acceptance : ['- 미확인']),
    '',
    '미결정 사항:',
    report.spec?.undecided ?? '- 미확인',
    '',
    '기준 대비 커밋된 변경:',
    ...report.committedFiles.map((file) => `- ${file}`),
    '',
    '현재 작업 트리 변경:',
    ...(report.changes.length
      ? report.changes.map(
          (item) =>
            `- ${item.index}${item.worktree} ${JSON.stringify(item.file)}${item.source ? ` ← ${JSON.stringify(item.source)}` : ''}`,
        )
      : ['- 없음']),
    '',
    `기록 단계: ${report.state?.phase ?? '미확인'} (기록값이며 현재 완료 판정 아님)`,
    '완료 조건 기록:',
    ...(report.state?.acceptance ?? []).map(
      (item) => `- ${item.id}: ${item.status} (기록값)`,
    ),
    '검증 기록:',
    ...report.checks.map(
      (check) =>
        `- ${check.id}: ${check.recordedResult} / ${check.effectiveFreshness} (${check.reasons.join(', ')})`,
    ),
    ...(report.checks.length ? [] : ['- 없음']),
    `리뷰 기록: ${report.review ? `${report.review.recordedResult} / ${report.review.effectiveFreshness}` : '없음'}`,
    '리뷰 지적:',
    ...(report.state?.review.findings ?? []).map(
      (item) =>
        `- ${item.id} ${item.severity}: ${item.status} ${item.description ?? ''}`,
    ),
    '리뷰 미확인 범위:',
    ...(report.state?.review.unverified ?? []).map((item) => `- ${item}`),
    '막힌 사항:',
    ...(report.state?.blockers ?? []).map((item) => `- ${item}`),
    '',
    '다음 작업:',
    ...report.nextActions.map((item) => `- ${item}`),
    '',
    '확인 필요:',
    ...report.warnings.map((item) => `- ${item}`),
  ];
  return `${lines.join('\n')}\n`;
};

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.help)
      process.stdout.write(
        'workflow:resume [--issue 양의정수] [--base ref] [--json] [--help]\n현재 저장소의 명세·상태·Git 변경을 읽습니다. 파일 변경이나 원격 조회는 하지 않습니다.\n',
      );
    else {
      const report = buildReport(options);
      process.stdout.write(
        options.json
          ? `${JSON.stringify(report, null, 2)}\n`
          : formatReport(report),
      );
    }
  } catch (error) {
    process.stderr.write(`작업 복원 실패: ${error.message}\n`);
    process.exitCode = 1;
  }
}
