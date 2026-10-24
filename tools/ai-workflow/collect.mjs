import process from 'node:process';
import { collectScope, git } from './evidence-core.mjs';
try {
  const root = git(['rev-parse', '--show-toplevel'], process.cwd()).trim();
  const files = collectScope(
    root,
    process.argv[2] ?? 'origin/develop',
    process.argv[3] ?? '.tmp/branch-review',
  );
  process.stdout.write(
    `[SKILL ACTIVE] branch-review\nChanged files: ${files.length}\nArtifacts include committed, staged, unstaged, and untracked changes.\n`,
  );
} catch (error) {
  process.stderr.write(`리뷰 범위 수집 실패: ${error.message}\n`);
  process.exitCode = 1;
}
