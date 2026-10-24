import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

// Exported runner allows deterministic Xcode tests without touching a user's reminders.
export function runMacOSCheck(mode, { root = path.resolve(fileURLToPath(new URL('../../', import.meta.url))), run = spawnSync, read = readFileSync, output = process.stdout, error = process.stderr } = {}) {
  if (!['build', 'test'].includes(mode)) {
    error.write('사용법: node tools/macos/check.mjs build|test\n');
    return 2;
  }
  const exec = (command, args) => run(command, args, { cwd: root, encoding: 'utf8', timeout: 600000, maxBuffer: 64 * 1024 * 1024 });
  const version = exec('xcodebuild', ['-version']);
  const match = version.stdout?.match(/^Xcode (\d+)(?:\.\d+)*\s*$/m);
  if (version.status !== 0 || !match || Number(match[1]) < 26) {
    error.write('Xcode 26 이상과 macOS SDK가 필요합니다. Command Line Tools만으로는 앱을 검증할 수 없습니다. Xcode 설치 후 선택된 developer directory를 확인하세요.\n');
    return 2;
  }
  const project = ['-project', 'apps/macos/Ttak.xcodeproj'];
  if (mode === 'test') {
    let scheme;
    try { scheme = read(path.join(root, 'apps/macos/Ttak.xcodeproj/xcshareddata/xcschemes/Ttak.xcscheme'), 'utf8'); }
    catch { error.write('공유 Ttak 스킴의 테스트 구성을 확인하지 못했습니다.\n'); return 2; }
    // Use the actual selected scheme, not a target-name convention such as '*Tests'.
    if (!/<TestableReference\b(?![^>]*\bskipped="YES")[^>]*>/.test(scheme) && !/<TestPlanReference\b/.test(scheme)) {
      error.write('현재 Ttak 스킴에는 실행할 테스트 타깃·플랜이 없습니다. 테스트를 통과한 것으로 처리하지 않습니다.\n');
      return 2;
    }
  }
  const args = [...project, '-scheme', 'Ttak', '-configuration', 'Debug', '-destination', 'platform=macOS', '-derivedDataPath', '.tmp/xcode-derived-data', 'CODE_SIGNING_ALLOWED=NO', mode];
  output.write(`xcodebuild ${args.join(' ')}\n`);
  const result = exec('xcodebuild', args);
  output.write(result.stdout ?? '');
  error.write(result.stderr ?? '');
  if (result.error) error.write(`${result.error.message}\n`);
  return result.error ? 2 : result.status ?? 2;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = process.argv.length === 3 ? runMacOSCheck(process.argv[2]) : 2;
}
