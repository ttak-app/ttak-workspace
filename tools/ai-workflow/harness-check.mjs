import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

export const REQUIRED_FILES = [
  'AGENTS.md', 'apps/macos/AGENTS.md', 'apps/web/AGENTS.md', 'docs/development.md',
  'docs/rules/coding-convention.md', 'docs/rules/swift-coding-convention.md',
  'docs/rules/web-coding-convention.md', 'docs/rules/git-convention.md',
  'docs/rules/ai-workflow.md', 'docs/rules/macos-development.md',
  'docs/ai-workflow/README.md', 'docs/ai-workflow/user-guide.md',
  'docs/ai-workflow/templates/spec.md', 'docs/ai-workflow/templates/status.json',
  'docs/branch-review/README.md', '.agents/checklists/preflight.md',
  '.agents/checklists/postflight.md', '.agents/checklists/debrief.md',
  ...['create-issue','logic-design','logic-architecture','branch-review','create-pr'].map((name) => `.agents/skills/${name}/SKILL.md`),
];
export const REQUIRED_SCRIPTS = {
  'workflow:resume': 'node tools/ai-workflow/resume.mjs',
  'workflow:check': 'node tools/ai-workflow/record.mjs check',
  'workflow:review': 'node tools/ai-workflow/record.mjs review',
  'workflow:pr-check': 'node tools/ai-workflow/pr-check.mjs',
  'workflow:harness-check': 'node tools/ai-workflow/harness-check.mjs',
  'workflow:test': 'node --test tools/ai-workflow/*.test.mjs tools/macos/*.test.mjs',
  'review:scope': 'node tools/ai-workflow/collect.mjs',
  'macos:build': 'node tools/macos/check.mjs build',
  'macos:test': 'node tools/macos/check.mjs test',
};
export function checkHarness(root) {
  const diagnostics = [];
  const add = (file, code, message) => diagnostics.push({ file, code, message });
  const read = (file) => {
    try { return readFileSync(path.join(root, file), 'utf8'); }
    catch (error) { add(file, 'missing-or-unreadable', error.code ?? error.message); return null; }
  };
  const documents = new Set(REQUIRED_FILES.filter((file) => file.endsWith('.md')));
  // Task records are part of the shared harness; do not inspect app code or node_modules.
  const walk = (dir) => {
    if (!existsSync(path.join(root, dir))) return;
    for (const entry of readdirSync(path.join(root, dir), { withFileTypes: true })) {
      const file = `${dir}/${entry.name}`;
      if (entry.isDirectory()) walk(file);
      else if (entry.isFile() && file.endsWith('.md')) documents.add(file);
    }
  };
  walk('docs/ai-workflow/tasks');
  for (const file of REQUIRED_FILES) if (!documents.has(file)) read(file);
  for (const file of documents) {
    const content = read(file);
    if (content === null) continue;
    for (const match of content.matchAll(/\[[^\]\n]*\]\(([^)\n]+)\)/g)) {
      let target = match[1].trim().split(/\s+"/)[0];
      if (/^(?:[a-z][a-z0-9+.-]*:|#)/i.test(target)) continue;
      target = target.replace(/^<|>$/g, '').split('#')[0];
      if (!target) continue;
      try {
        if (!existsSync(path.resolve(root, path.dirname(file), decodeURIComponent(target)))) add(file, 'broken-link', target);
      } catch { add(file, 'invalid-link', target); }
    }
    if (file.endsWith('/SKILL.md')) {
      const front = content.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)?.[1];
      const name = front?.match(/^name:\s*([^\r\n]+)$/m)?.[1]?.trim();
      const description = front?.match(/^description:\s*([^\r\n]+)$/m)?.[1]?.trim();
      if (!name || name !== path.basename(path.dirname(file)) || !/^[a-z0-9-]{1,63}$/.test(name) || !description) add(file, 'skill-frontmatter', 'name/description과 스킬 폴더를 확인하세요.');
    }
  }
  const packageRaw = read('package.json');
  try {
    const pkg = JSON.parse(packageRaw);
    for (const [name, command] of Object.entries(REQUIRED_SCRIPTS)) {
      if (pkg.scripts?.[name] !== command) add('package.json', 'script', `${name}: ${command}`);
      const target = command.split(' ')[1];
      if (target !== '--test' && !existsSync(path.join(root, target))) add('package.json', 'script-target', target);
    }
    for (const script of ['lint:web','check-types:web','build:web']) if (!pkg.scripts?.[script]) add('package.json', 'web-script', script);
  } catch { add('package.json', 'json', '유효한 package.json이 필요합니다.'); }
  for (const file of ['docs/ai-workflow/templates/status.json']) {
    try { if (JSON.parse(readFileSync(path.join(root, file),'utf8')).schemaVersion !== 1) add(file,'schema','schemaVersion 1이 필요합니다.'); }
    catch { add(file,'json','상태 템플릿 JSON을 확인하세요.'); }
  }
  const ignore = read('.gitignore');
  if (!/^\/?\.tmp\/?\s*$/m.test(ignore ?? '')) add('.gitignore', 'local-evidence', '.tmp/를 Git에서 제외하세요.');
  return { status: diagnostics.length ? 'failed' : 'passed', diagnostics, limitations: ['정해진 파일·링크·스킬·스크립트의 구조만 검사합니다. 정책 의미·Xcode 실행·제품 동작·CI·권한은 자동 검증하지 않습니다.'] };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  if (args.length > 1 || args.some((arg) => !['--json','--help'].includes(arg))) { process.stderr.write('사용법: workflow:harness-check [--json|--help]\n'); process.exitCode = 2; }
  else if (args.includes('--help')) process.stdout.write('읽기 전용 하네스 구조 검사. 성공=0, 진단=1, 인자 오류=2.\n');
  else {
    const report = checkHarness(path.resolve(fileURLToPath(new URL('../../', import.meta.url))));
    process.stdout.write(args.includes('--json') ? `${JSON.stringify(report,null,2)}\n` : `하네스 구조: ${report.status}\n${report.diagnostics.map((item) => `${item.file}: ${item.code} ${item.message}`).join('\n')}\n`);
    process.exitCode = report.diagnostics.length ? 1 : 0;
  }
}
