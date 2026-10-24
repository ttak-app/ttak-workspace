import { lstatSync, realpathSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { assessFreshness } from './evidence-core.mjs';
import { buildReport, validState } from './resume.mjs';

const isText = (value) => typeof value === 'string' && value.trim().length > 0;
const hasFiles = (root, files, extension = null) =>
  Array.isArray(files) &&
  files.length > 0 &&
  files.every((file) => {
    if (!isText(file) || path.isAbsolute(file)) return false;
    const absolute = path.resolve(root, file);
    if (!absolute.startsWith(`${root}${path.sep}`)) return false;
    try {
      const resolved = realpathSync(absolute);
      return (
        resolved.startsWith(`${realpathSync(root)}${path.sep}`) &&
        lstatSync(resolved).isFile() &&
        (!extension || file.endsWith(extension))
      );
    } catch {
      return false;
    }
  });
const getLatest = (records, field) => {
  if (
    !records.length ||
    records.some(
      (item) =>
        !item ||
        !isText(item[field]) ||
        !Number.isFinite(Date.parse(item[field])) ||
        new Date(item[field]).toISOString() !== item[field],
    )
  )
    return null;
  const ordered = [...records].sort(
    (a, b) => Date.parse(b[field]) - Date.parse(a[field]),
  );
  // Equal timestamps cannot establish which result happened last.
  if (
    ordered.length > 1 &&
    Date.parse(ordered[0][field]) === Date.parse(ordered[1][field])
  )
    return null;
  return ordered[0];
};
export const classifyChanges = (files) => {
  const kinds = new Set();
  for (const file of files) {
    if (file.endsWith('.gitkeep')) kinds.add('docs');
    else if (/^(docs\/|\.agents\/|\.github\/).*\.md$/.test(file) || /^(README|AGENTS)\.md$/.test(file) || /^apps\/(macos|web)\/(README|AGENTS)\.md$/.test(file)) kinds.add('docs');
    else if (/^(tools\/(ai-workflow|branch-review|macos)\/|docs\/ai-workflow\/templates\/)/.test(file)) kinds.add('harness');
    else if (file.startsWith('apps/macos/')) kinds.add('macos');
    else kinds.add('app'); // Web and shared dependency/build config; no web-to-macOS false pass.
  }
  return [...kinds].sort();
};

export const assessReadiness = (report) => {
  const blockers = [];
  const add = (code, reason, action) => blockers.push({ code, reason, action });
  const fresh = (record) =>
    assessFreshness(record, report.subject, report.stateMismatches)
      .effectiveFreshness === 'current';
  const { state, spec } = report;
  if (
    !/^[a-z][a-z0-9-]*\/[^\s]+\/#([1-9]\d*)$/.test(report.branch) ||
    ['main', 'develop', 'HEAD'].includes(report.branch)
  )
    add(
      'branch',
      '이슈 연결 작업 브랜치가 아닙니다.',
      '대상 이슈 작업 브랜치를 확인하세요.',
    );
  if (
    !report.baseSha ||
    report.baseRef === report.branch ||
    report.baseRef === 'HEAD'
  )
    add(
      'base',
      '명시한 기준 ref를 비교할 수 없거나 작업 브랜치 자신입니다.',
      '기준 ref를 명시적으로 확인하세요. 자동 fetch/대체는 하지 않습니다.',
    );
  if (
    !spec?.revision ||
    !state ||
    report.stateMismatches.length ||
    !report.subject
  )
    add(
      'identity',
      '명세·상태·버전·코드 대상 연결이 없거나 불일치합니다.',
      'workflow:resume으로 경고를 확인하고 실제 작업 연결을 수정하세요.',
    );
  if (!report.committedFiles.length)
    add(
      'changes',
      '기준 대비 커밋된 변경이 없습니다.',
      '대상 변경과 기준 ref를 확인하세요.',
    );
  if (report.changes.length)
    add(
      'dirty',
      'staged/unstaged/untracked 변경이 있습니다.',
      '변경을 검토하고 사용자가 승인한 커밋 절차로 처리한 뒤 증적을 재확인하세요.',
    );
  const acSections =
    spec?.content.match(/## 완료 조건\s*\n([\s\S]*?)(?=\n## |$)/g) ?? [];
  const lines =
    acSections[0]
      ?.split('\n')
      .slice(1)
      .filter((line) => line.trim()) ?? [];
  const ids = lines.map((line) => line.match(/^- (AC-[1-9]\d*):\s*\S/)?.[1]);
  if (
    acSections.length !== 1 ||
    !ids.length ||
    ids.some((id) => !id) ||
    new Set(ids).size !== ids.length
  )
    add(
      'acceptance-spec',
      '명세 완료 조건이 없거나 형식 오류/중복입니다.',
      '완료 조건을 고유한 - AC-N: 설명 형식으로 작성하세요.',
    );
  if (spec) {
    const issueFields = [...spec.content.matchAll(/^- 이슈:[ \t]*(.*)$/gm)];
    const branchFields = [...spec.content.matchAll(/^- 브랜치:[ \t]*(.*)$/gm)];
    const issueValue = issueFields[0]?.[1].trim() ?? '';
    const issueMatch =
      issueValue.match(/^#([1-9]\d*)(?:[ \t]*\/[ \t]*https?:\/\/[^\s]+)?$/) ??
      issueValue.match(/^\[#([1-9]\d*)\]\(https?:\/\/[^\s)]+\)$/);
    const branchValue = branchFields[0]?.[1].trim() ?? '';
    const branchName =
      branchValue.startsWith('`') && branchValue.endsWith('`')
        ? branchValue.slice(1, -1)
        : branchValue;
    if (
      issueFields.length !== 1 ||
      branchFields.length !== 1 ||
      !issueMatch ||
      Number(issueMatch[1]) !== report.issue ||
      branchName !== report.branch
    )
      add(
        'spec-identity',
        '명세의 이슈/브랜치 연결이 없거나 중복·불일치합니다.',
        '이슈와 브랜치 필드를 각각 정확히 하나 작성하고 실제 작업과 대조하세요.',
      );
  }
  if (state) {
    if (state.blockers.length)
      add(
        'recorded-blockers',
        '로컬 상태에 남은 막힌 사항이 있습니다.',
        '각 blocker를 해결하거나 남은 한계를 명시하세요.',
      );
    const recordedIds = state.acceptance.map((item) => item.id);
    if (
      new Set(recordedIds).size !== recordedIds.length ||
      recordedIds.some((id) => !ids.includes(id))
    )
      add(
        'acceptance-state',
        '완료 조건 기록이 중복되거나 명세에 없는 ID를 포함합니다.',
        '명세 ID와 상태 기록을 일치시키세요.',
      );
    ids.filter(Boolean).forEach((id) => {
      const item = state.acceptance.find((entry) => entry.id === id);
      if (
        item?.status !== 'met' ||
        !fresh(item) ||
        !hasFiles(report.root, item.evidence)
      )
        add(
          `acceptance:${id}`,
          `${id}의 met 판단 또는 실제 근거 파일이 없습니다.`,
          'AI가 완료 조건을 검토하고 met 상태와 근거 파일 경로를 기록하세요.',
        );
    });
  }
  const kinds = classifyChanges(report.committedFiles);
  const required = [
    'workflow:harness-check',
    ...(kinds.includes('app') ? ['lint:web', 'check-types:web', 'build:web'] : []),
    ...(kinds.includes('harness') ? ['workflow:test'] : []),
    ...(kinds.includes('macos') ? ['macos:build'] : []),
    ...(report.committedFiles.some((file) => /^apps\/macos\/.*Tests\/.*\.swift$/.test(file)) ? ['macos:test'] : []),
    ...(kinds.includes('docs') ? ['docs-review'] : []),
  ];
  const checks = [];
  if (state) {
    const checkIds = [
      ...new Set([
        ...required,
        ...(!kinds.includes('app') && !kinds.includes('harness')
          ? ['lint:web', 'check-types:web', 'build:web']
          : []),
      ]),
    ];
    checkIds.forEach((id) => {
      const record = getLatest(
        state.checks.filter((item) => item.id === id),
        'checkedAt',
      );
      const hasCurrentFailure = state.checks.some(
        (item) => item.id === id && item.result === 'failed' && fresh(item),
      );
      const isNa =
        !hasCurrentFailure &&
        record?.result === 'not-applicable' &&
        kinds.length === 1 &&
        kinds[0] === 'docs' &&
        ['lint:web', 'check-types:web', 'build:web'].includes(id) &&
        isText(record.reason);
      const isPassed = record?.result === 'passed' && record.exitCode === 0;
      const isValid =
        record &&
        fresh(record) &&
        (isNa || isPassed) &&
        (isNa || hasFiles(report.root, record.evidence, '.log')) &&
        (isNa || id === 'docs-review' || record.command === `npm run ${id}`);
      checks.push({
        id,
        result: record?.result ?? 'unknown',
        freshness: record
          ? assessFreshness(record, report.subject, report.stateMismatches)
              .effectiveFreshness
          : 'unknown',
        ready: Boolean(isValid),
      });
      if (!isValid)
        add(
          `check:${id}`,
          `${id}: 최신 성공/current/실제 로그 또는 허용된 N/A를 확인할 수 없습니다.`,
          `${id} 검사를 실행·기록하거나 문서 전용 N/A의 구체적 이유와 대상을 기록하세요.`,
        );
    });
    const manualKinds = [
      ...(kinds.includes('app') || kinds.includes('macos') ? ['behavior'] : []),
      ...(kinds.includes('harness') ? ['harness-validation'] : []),
    ];
    manualKinds.forEach((kind) => {
      const records = Array.isArray(state.readinessEvidence)
        ? state.readinessEvidence.filter((item) => item?.kind === kind)
        : [];
      const record = getLatest(records, 'checkedAt');
      if (
        !record ||
        record.result !== 'passed' ||
        !isText(record.reason) ||
        !fresh(record) ||
        !hasFiles(report.root, record.evidence)
      )
        add(
          `manual:${kind}`,
          `${kind}의 현재 동작/관련 검증 판단 근거가 없습니다.`,
          '필요한 실행 확인과 AI 판단·한계를 readinessEvidence에 기록하세요.',
        );
    });
    const history = state.reviewHistory ?? [];
    const isValidHistory =
      Array.isArray(history) &&
      history.every(
        (item) =>
          validState({ ...state, review: item }) &&
          new Set(item.findings.map((finding) => finding.id)).size ===
            item.findings.length &&
          item.findings.every(
            (finding) =>
              isText(finding.id) &&
              isText(finding.description) &&
              isText(finding.file) &&
              Number.isInteger(finding.line) &&
              finding.line > 0 &&
              typeof finding.resolution === 'string' &&
              (finding.status === 'open' || isText(finding.resolution)),
          ),
      );
    if (!isValidHistory)
      add(
        'review-history-format',
        'reviewHistory 형식을 확인할 수 없습니다.',
        '이전 리뷰 이력을 보존하고 손상된 필드/지적사항을 실제 기록과 대조하세요.',
      );
    const review = isValidHistory
      ? getLatest([...history, state.review], 'reviewedAt')
      : null;
    if (
      !review ||
      review !== state.review ||
      review.result !== 'no-blocking-findings' ||
      !fresh(review) ||
      !hasFiles(report.root, review.evidence)
    )
      add(
        'review',
        '최신 리뷰의 current/no-blocking-findings 및 근거를 확인할 수 없습니다.',
        '현재 변경을 실제로 리뷰하고 workflow:review로 기록하세요.',
      );
    if (review) {
      if (
        !Array.isArray(review.scope) ||
        report.committedFiles.some((file) => !review.scope.includes(file))
      )
        add(
          'review-scope',
          '리뷰 범위에서 실제 변경 파일이 누락되었습니다.',
          '전체 변경 범위를 검토하고 누락 파일을 포함해 리뷰를 기록하세요.',
        );
      const findings = review.findings;
      const previousFindings = new Map();
      if (Array.isArray(history))
        [...history]
          .sort((a, b) => Date.parse(a?.reviewedAt) - Date.parse(b?.reviewedAt))
          .forEach((entry) => {
            if (Array.isArray(entry?.findings))
              entry.findings.forEach((item) =>
                previousFindings.set(item?.id, item),
              );
          });
      if (
        [...previousFindings.values()].some(
          (item) =>
            item?.status !== 'resolved' &&
            !findings?.some((entry) => entry.id === item.id),
        )
      )
        add(
          'review-history',
          '이전 미해결 리뷰 지적이 최신 기록에서 누락되었습니다.',
          '이전 지적 ID를 보존하고 해결 여부와 근거를 최신 리뷰에 기록하세요.',
        );
      if (
        !Array.isArray(findings) ||
        new Set(findings.map((item) => item?.id)).size !== findings.length ||
        findings.some(
          (item) =>
            !isText(item?.id) ||
            !['High', 'Medium', 'Low'].includes(item.severity) ||
            !['open', 'resolved', 'accepted'].includes(item.status) ||
            !isText(item.description) ||
            !isText(item.file) ||
            !Number.isInteger(item.line) ||
            item.line < 1 ||
            (item.severity !== 'Low' && item.status !== 'resolved') ||
            !isText(item.resolution),
        )
      )
        add(
          'review-findings',
          '미해결 High/Medium 또는 처리 이유/형식이 누락된 지적사항이 있습니다.',
          '결함을 해결하고 Low도 처리 여부와 구체적 이유를 기록하세요.',
        );
      if (
        !Array.isArray(review.unverified) ||
        (review.unverified.length &&
          (!review.unverifiedAssessment ||
            review.unverifiedAssessment.acceptanceImpact !== 'none' ||
            !isText(review.unverifiedAssessment.reason) ||
            !hasFiles(report.root, review.unverifiedAssessment.evidence)))
      )
        add(
          'review-unverified',
          '미확인 항목의 완료 조건 영향이 불명확합니다.',
          '외부 환경 등 미확인 항목의 AC 영향과 판단 근거를 기록하세요. 영향이 있으면 검증을 완료하세요.',
        );
    }
  }
  return {
    status: blockers.length ? 'blocked' : 'ready',
    ready: blockers.length === 0,
    branch: report.branch,
    issue: report.issue,
    baseRef: report.baseRef,
    baseSha: report.baseSha,
    headSha: report.headSha,
    kinds,
    requiredChecks: required,
    checks,
    blockers,
    nextActions: [...new Set(blockers.map((item) => item.action))],
    limitations: [
      '로컬 ref의 원격 최신 여부, Xcode 라이선스·모델 가용성·미리 알림 권한·실기기 동작은 자동 보증하지 않습니다.',
      '완료 조건·동작·리뷰 기록은 AI 판단의 누락과 대상 일치 검사이며 기능의 자동 보증이 아닙니다.',
      'ready는 기술 준비 상태입니다. push/PR 게시 권한은 별도로 확인합니다.',
    ],
  };
};

const parseArgs = (args) => {
  const options = {
    issue: null,
    base: 'origin/develop',
    json: false,
    help: false,
  };
  const seen = new Set();
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (seen.has(arg)) throw new Error('중복 인자');
    seen.add(arg);
    if (arg === '--json' || arg === '--help') options[arg.slice(2)] = true;
    else if (
      ['--issue', '--base'].includes(arg) &&
      args[i + 1] &&
      !args[i + 1].startsWith('-')
    ) {
      options[arg.slice(2)] = args[++i];
    } else throw new Error('잘못된 인자');
  }
  if (options.issue !== null) {
    if (
      !/^[1-9]\d*$/.test(options.issue) ||
      !Number.isSafeInteger(Number(options.issue))
    )
      throw new Error('이슈는 양의 정수여야 합니다.');
    options.issue = Number(options.issue);
  }
  return options;
};
if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.help)
      process.stdout.write(
        'workflow:pr-check [--issue 번호] [--base ref] [--json] [--help]\n읽기 전용 로컬 PR 준비 검사. ready=0, blocked=1, 실행/인자 오류=2.\n',
      );
    else {
      const report = assessReadiness(buildReport(options));
      process.stdout.write(
        options.json
          ? `${JSON.stringify(report, null, 2)}\n`
          : [
              `PR 준비: ${report.status}`,
              `기준: ${report.baseRef} @ ${report.baseSha ?? '미확인'}`,
              ...report.blockers.map(
                (item) => `- ${item.reason}\n  다음 조치: ${item.action}`,
              ),
              ...report.limitations.map((item) => `한계: ${item}`),
            ].join('\n') + '\n',
      );
      process.exitCode = report.ready ? 0 : 1;
    }
  } catch (error) {
    process.stderr.write(`PR 준비 검사 오류: ${error.message}\n`);
    process.exitCode = 2;
  }
}
