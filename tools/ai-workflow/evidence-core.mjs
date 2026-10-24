import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  lstatSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  realpathSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export const git = (args, cwd) =>
  execFileSync('git', args, {
    cwd,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' },
  });
const digest = (value) => createHash('sha256').update(value).digest('hex');

const toolVersion = (command, args, cwd) => {
  try {
    return execFileSync(command, args, { cwd, encoding: 'utf8', stdio: 'pipe', timeout: 10000 }).trim();
  } catch { return null; }
};

export const captureSubject = (report) => {
  const entries = git(['ls-files', '--stage', '-z'], report.root);
  if (entries.split('\0').some((item) => item.startsWith('160000 ')))
    throw new Error('Git submodule 증적은 지원하지 않습니다.');
  const files = [
    ...new Set(
      git(
        ['ls-files', '--cached', '--others', '--exclude-standard', '-z'],
        report.root,
      )
        .split('\0')
        .filter(Boolean),
    ),
  ].sort();
  const hash = createHash('sha256');
  hash.update(`fingerprint-v1\0${entries}\0`);
  files.forEach((file) => {
    const absolute = path.join(report.root, file);
    let data;
    try {
      const stat = lstatSync(absolute);
      if (stat.isSymbolicLink()) data = ['symlink', readlinkSync(absolute)];
      else if (stat.isFile())
        data = ['file', stat.mode & 0o111, digest(readFileSync(absolute))];
      else throw new Error(`지원하지 않는 파일 유형: ${file}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      data = ['deleted'];
    }
    hash.update(`${JSON.stringify([file, data])}\0`);
  });
  let npm = null;
  try {
    npm = execFileSync('npm', ['--version'], {
      cwd: report.root,
      encoding: 'utf8',
      stdio: 'pipe',
    }).trim();
  } catch {
    /* An unavailable runtime keeps freshness unknown. */
  }
  let dependencyState = null;
  try {
    dependencyState = digest(
      readFileSync(path.join(report.root, 'node_modules/.package-lock.json')),
    );
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  return {
    headSha: report.headSha,
    baseRef: report.baseRef,
    baseSha: report.baseSha,
    worktreeFingerprint: hash.digest('hex'),
    specRevision: report.spec?.revision ?? null,
    environment: {
      node: process.version,
      platform: process.platform,
      arch: process.arch,
      npm,
      dependencyState,
      swift: toolVersion('xcrun', ['swift', '--version'], report.root),
      xcode: toolVersion('xcodebuild', ['-version'], report.root),
      developerDirectory: toolVersion('xcode-select', ['-p'], report.root),
      developerDirectoryOverride: process.env.DEVELOPER_DIR ?? null,
    },
  };
};

export const assessFreshness = (record, current, mismatches = []) => {
  const reasons = [];
  const missing = [];
  const names = {
    headSha: 'HEAD',
    baseRef: '기준 ref',
    baseSha: '기준 SHA',
    worktreeFingerprint: '작업 트리',
    specRevision: '명세 버전',
    environment: '환경',
  };
  if (record.freshness === 'needs-recheck')
    reasons.push('기록이 재확인 대상으로 표시됨');
  Object.entries(names).forEach(([field, label]) => {
    const old = record.subject?.[field];
    const now = current?.[field];
    if (old == null || now == null) missing.push(`${label} 미확인`);
    else if (JSON.stringify(old) !== JSON.stringify(now))
      reasons.push(`${label} 변경`);
  });
  if (!record.subject?.environment?.npm || !current?.environment?.npm)
    missing.push('npm 환경 미확인');
  if (mismatches.length) reasons.push('작업 상태 연결 불일치');
  return {
    recordedResult: record.result,
    recordedFreshness: record.freshness,
    effectiveFreshness: reasons.length
      ? 'needs-recheck'
      : missing.length
        ? 'unknown'
        : 'current',
    reasons: [...reasons, ...missing],
  };
};

export const collectScope = (root, baseRef, out) => {
  root = realpathSync(root);
  git(['rev-parse', '--verify', `${baseRef}^{commit}`], root);
  const destination = path.resolve(root, out);
  const tmpRoot = path.join(root, '.tmp');
  if (!destination.startsWith(`${tmpRoot}${path.sep}`))
    throw new Error('리뷰 산출물은 저장소 .tmp 내부에 저장해야 합니다.');
  // Check each component before creating directories; recursive mkdir follows links.
  let current = root;
  path
    .relative(root, destination)
    .split(path.sep)
    .forEach((segment) => {
      current = path.join(current, segment);
      try {
        if (!lstatSync(current).isDirectory())
          throw new Error(`리뷰 출력 경로가 일반 폴더가 아닙니다: ${current}`);
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
        mkdirSync(current);
      }
    });
  if (!realpathSync(destination).startsWith(`${tmpRoot}${path.sep}`))
    throw new Error('리뷰 산출물은 저장소 .tmp 내부에 저장해야 합니다.');
  // Existing output symlinks must not redirect writes outside the checked folder.
  [
    'diff.patch',
    'staged.patch',
    'unstaged.patch',
    'untracked.patch',
    'files.json',
    'files.txt',
    'commits.txt',
    'summary.md',
  ].forEach((file) => {
    const target = path.join(destination, file);
    try {
      if (!lstatSync(target).isFile())
        throw new Error(`리뷰 산출물이 일반 파일이 아닙니다: ${target}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  });
  const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], root).trim();
  const mergeBase = git(['merge-base', baseRef, 'HEAD'], root).trim();
  const range = `${mergeBase}..HEAD`;
  const untracked = git(
    ['ls-files', '--others', '--exclude-standard', '-z'],
    root,
  )
    .split('\0')
    .filter(Boolean);
  const changed = [
    ...new Set(
      [
        ...git(['diff', '--name-only', '-z', range], root).split('\0'),
        ...git(['diff', '--cached', '--name-only', '-z'], root).split('\0'),
        ...git(['diff', '--name-only', '-z'], root).split('\0'),
        ...untracked,
      ].filter(Boolean),
    ),
  ].sort();
  const patches = {
    'diff.patch': git(
      ['diff', '--no-ext-diff', '--no-textconv', '--unified=3', range],
      root,
    ),
    'staged.patch': git(
      ['diff', '--no-ext-diff', '--no-textconv', '--cached', '--unified=3'],
      root,
    ),
    'unstaged.patch': git(
      ['diff', '--no-ext-diff', '--no-textconv', '--unified=3'],
      root,
    ),
  };
  const newPatches = untracked
    .map((file) => {
      // Pass paths as arguments; no shell and no source execution.
      try {
        return git(
          [
            'diff',
            '--no-ext-diff',
            '--no-textconv',
            '--no-index',
            '--',
            '/dev/null',
            file,
          ],
          root,
        );
      } catch (error) {
        if (error.status === 1) return error.stdout;
        throw error;
      }
    })
    .join('\n');
  Object.entries({ ...patches, 'untracked.patch': newPatches }).forEach(
    ([name, content]) => writeFileSync(path.join(destination, name), content),
  );
  writeFileSync(
    path.join(destination, 'files.json'),
    JSON.stringify({ changed, untracked }, null, 2),
  );
  writeFileSync(
    path.join(destination, 'files.txt'),
    changed.map((file) => JSON.stringify(file)).join('\n') + '\n',
  );
  writeFileSync(
    path.join(destination, 'commits.txt'),
    git(['log', '--oneline', range], root),
  );
  writeFileSync(
    path.join(destination, 'summary.md'),
    `[SKILL ACTIVE] branch-review\n\nBranch: ${branch}\nBase ref: ${baseRef}\nMerge base: ${mergeBase}\nRange: ${range}\n\nCommitted: diff.patch\nStaged: staged.patch\nUnstaged: unstaged.patch\nNew files: untracked.patch\nPaths: files.json\n\nBinary contents require separate inspection.\n`,
  );
  return changed;
};
