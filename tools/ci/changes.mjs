import { appendFileSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const flagNames = ['macos', 'web', 'harness_structure', 'harness_tests'];
export const detectionVersion = '1';

function impact(path) {
  if (path.split('/').includes('..') || path.startsWith('/') || path.includes('\0') || !path) {
    throw new Error(`Invalid repository path: ${JSON.stringify(path)}`);
  }
  if (path.endsWith('/.gitkeep') || path === '.gitkeep') return [];
  // The review app consumes this configuration; it is not an app or CI build input.
  if (path === '.coderabbit.yaml') return [];
  if (path === '.github/workflows/ci.yml' || path.startsWith('tools/ci/') || ['package.json', '.nvmrc'].includes(path)) return flagNames;
  if (path === 'docs/ai-workflow/templates/status.json') return ['harness_structure', 'harness_tests'];
  if (['.gitignore', '.editorconfig', 'docs/development.md', 'docs/ci.md', '.github/pull_request_template.md'].includes(path)
    || path.startsWith('.github/ISSUE_TEMPLATE/') || path === 'AGENTS.md' || /^apps\/(macos|web)\/AGENTS\.md$/.test(path)
    || path.startsWith('.agents/') || path.startsWith('docs/rules/') || path.startsWith('docs/ai-workflow/')
    || path.startsWith('docs/branch-review/')) return ['harness_structure'];
  if (['README.md', 'apps/macos/README.md', 'apps/web/README.md', 'apps/macos/TtakTests/README.md'].includes(path)
    || /^docs\/.*\.md$/.test(path)) return [];
  // Shared brand sources and generators produce both web CSS and Swift colors.
  if (path.startsWith('design-system/') || path.startsWith('tools/design-tokens/')) return ['web', 'macos'];
  // Preview and reference assets are consumed by the web token documentation.
  if (path === 'docs/design-system/preview.html' || path.startsWith('docs/design-system/reference/')) return ['web'];
  if (path.startsWith('tools/macos/')) return ['macos', 'harness_structure', 'harness_tests'];
  if (path.startsWith('tools/ai-workflow/') || path.startsWith('tools/branch-review/')) return ['harness_structure', 'harness_tests'];
  if (path === 'package-lock.json' || path.startsWith('apps/web/')) return ['web'];
  if (path.startsWith('apps/macos/')) return ['macos'];
  throw new Error(`Unclassified path; define its consumers before running CI: ${JSON.stringify(path)}`);
}

export function classifyPaths(paths) {
  if (!Array.isArray(paths)) throw new Error('Changed paths must be an array');
  const selected = Object.fromEntries(flagNames.map((name) => [name, false]));
  const reasons = Object.fromEntries(flagNames.map((name) => [name, []]));
  for (const path of [...new Set(paths)]) {
    if (typeof path !== 'string') throw new Error('Changed paths must be strings');
    for (const name of impact(path)) {
      selected[name] = true;
      reasons[name].push(path);
    }
  }
  return { selected, reasons, fileCount: new Set(paths).size };
}

export function collectPaths({ baseSha, headSha, cwd = process.cwd(), git = execFileSync }) {
  for (const sha of [baseSha, headSha]) {
    if (typeof sha !== 'string' || !/^[a-f0-9]{40}$/.test(sha)) throw new Error('Expected full base and head commit SHAs');
  }
  const run = (args) => git('git', args, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  // Missing history, unrelated histories and truncated output must fail detection.
  const mergeBase = run(['merge-base', baseSha, headSha]).trim();
  if (!/^[a-f0-9]{40}$/.test(mergeBase)) throw new Error('Missing or invalid merge-base');
  const output = run(['diff', '--name-only', '-z', '--no-renames', mergeBase, headSha, '--']);
  if (output !== '' && !output.endsWith('\0')) throw new Error('Incomplete NUL-delimited Git diff');
  return output === '' ? [] : output.slice(0, -1).split('\0');
}

export function detectionOutputs(result) {
  return { version: detectionVersion, complete: 'true', ...Object.fromEntries(flagNames.map((name) => [name, String(result.selected[name])])) };
}

export function detectionSummary(result) {
  const rows = flagNames.map((name) => {
    // JSON escapes newlines; HTML escaping keeps filenames inert in Markdown summaries.
    const reasons = result.reasons[name].map((path) => escapeSummary(JSON.stringify(path))).join(', ');
    return `| ${name} | ${result.selected[name] ? 'run' : 'skip'} | ${reasons || 'No changed consumer'} |`;
  });
  return `## Change detection\n\n${result.fileCount} changed paths across the full PR.\n\n| Target | Decision | Changed inputs |\n| --- | --- | --- |\n${rows.join('\n')}\n`;
}

export function escapeSummary(value) {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('|', '&#124;').replaceAll('`', '&#96;');
}

export function runChanges(env = process.env) {
  const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
  const paths = collectPaths({ baseSha: event.pull_request?.base?.sha, headSha: event.pull_request?.head?.sha });
  const result = classifyPaths(paths);
  if (!env.GITHUB_OUTPUT || !env.GITHUB_STEP_SUMMARY) throw new Error('Missing Actions output paths');
  appendFileSync(env.GITHUB_STEP_SUMMARY, detectionSummary(result));
  // Write the completion marker only after collection, classification and summary succeed.
  appendFileSync(env.GITHUB_OUTPUT, `${Object.entries(detectionOutputs(result)).map(([key, value]) => `${key}=${value}`).join('\n')}\n`);
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try { runChanges(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
