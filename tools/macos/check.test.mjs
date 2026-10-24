import assert from 'node:assert/strict';
import test from 'node:test';
import { runMacOSCheck } from './check.mjs';

function fixture(version = 'Xcode 26.1\nBuild version test\n', hasTests = false) {
  const calls = [];
  let output = '';
  const run = (command, args, options) => {
    calls.push({ command, args, options });
    if (args.includes('-version')) return { status: 0, stdout: version };
    return { status: 0, stdout: 'BUILD SUCCEEDED\n' };
  };
  const write = { write: (text) => { output += text; } };
  return { calls, run, options: { root: '/tmp/ttak-native-fixture', run, read: () => hasTests ? '<Scheme><TestAction><TestableReference skipped="NO"></TestableReference></TestAction></Scheme>' : '<Scheme><TestAction><Testables/></TestAction></Scheme>', output: write, error: write }, output: () => output };
}
test('Command Line Tools and old Xcode cannot report a macOS pass', () => {
  for (const version of ['', 'Xcode 16.4\n', 'Apple Swift version 5.9\n']) {
    const f = fixture(version);
    assert.equal(runMacOSCheck('build', f.options), 2);
    assert.equal(f.calls.length, 1);
    assert.match(f.output(), /Xcode 26/);
  }
});
test('missing executable reports environment failure', () => {
  const f = fixture();
  f.options.run = () => ({ status: null, error: new Error('ENOENT') });
  assert.equal(runMacOSCheck('build', f.options), 2);
});
test('build uses macOS destination, unsigned Debug and isolated derived data', () => {
  const f = fixture();
  assert.equal(runMacOSCheck('build', f.options), 0);
  const call = f.calls.at(-1);
  assert.equal(call.command, 'xcodebuild');
  assert.ok(call.args.includes('platform=macOS'));
  assert.ok(call.args.includes('CODE_SIGNING_ALLOWED=NO'));
  assert.ok(call.args.includes('.tmp/xcode-derived-data'));
  assert.equal(call.args.at(-1), 'build');
  assert.equal(call.options.cwd, '/tmp/ttak-native-fixture');
});
test('no test target never becomes a passing test run', () => {
  const f = fixture();
  assert.equal(runMacOSCheck('test', f.options), 2);
  assert.equal(f.calls.length, 1);
  assert.match(f.output(), /테스트 타깃·플랜이 없습니다/);
});
test('configured tests execute test action and failures propagate', () => {
  const f = fixture(undefined, true);
  assert.equal(runMacOSCheck('test', f.options), 0);
  assert.equal(f.calls.at(-1).args.at(-1), 'test');
  const original = f.run;
  f.options.run = (cmd, args, options) => args.at(-1) === 'test' ? { status: 65, stderr: 'test failed' } : original(cmd,args,options);
  assert.equal(runMacOSCheck('test', f.options), 65);
});
test('invalid operation cannot execute xcodebuild', () => {
  const f = fixture();
  assert.equal(runMacOSCheck('deploy', f.options), 2);
  assert.equal(f.calls.length, 0);
});

test('skipped testables do not become test success, explicit test plans are supported', () => {
  const f = fixture();
  f.options.read = () => '<TestableReference skipped="YES"></TestableReference>';
  assert.equal(runMacOSCheck('test', f.options), 2);
  f.options.read = () => '<TestPlanReference reference="container:Ttak.xctestplan"/>';
  assert.equal(runMacOSCheck('test', f.options), 0);
});
