import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { detectionVersion, flagNames, escapeSummary } from './changes.mjs';

export function evaluateNeeds(needs) {
  const failures = [];
  const decisions = [];
  const changes = needs?.changes;
  const outputs = changes?.outputs;
  if (changes?.result !== 'success') failures.push('Changes did not succeed');
  if (outputs?.version !== detectionVersion || outputs?.complete !== 'true') failures.push('Missing detection version or completion marker');
  for (const flag of flagNames) {
    if (!['true', 'false'].includes(outputs?.[flag])) failures.push(`Invalid or missing flag: ${flag}`);
  }
  if (failures.length) return { passed: false, failures, decisions };

  function job(name, selected) {
    const expected = selected ? 'success' : 'skipped';
    const actual = needs?.[name]?.result;
    decisions.push(`${name}: ${selected ? 'selected' : 'not selected'}, expected ${expected}, observed ${actual ?? 'missing'}`);
    if (actual !== expected) failures.push(`${name}: expected ${expected}, observed ${actual ?? 'missing'}`);
  }
  job('web', outputs.web === 'true');
  job('macos-build', outputs.macos === 'true');
  const harnessSelected = outputs.harness_structure === 'true' || outputs.harness_tests === 'true';
  job('harness', harnessSelected);
  if (harnessSelected) {
    for (const [flag, step] of [['harness_structure', 'structure'], ['harness_tests', 'tests']]) {
      const expected = outputs[flag] === 'true' ? 'success' : 'skipped';
      const actual = needs.harness?.outputs?.[step];
      decisions.push(`harness ${step}: expected ${expected}, observed ${actual ?? 'missing'}`);
      if (actual !== expected) failures.push(`harness ${step}: expected ${expected}, observed ${actual ?? 'missing'}`);
    }
  }
  return { passed: failures.length === 0, failures, decisions };
}

export function resultSummary(result) {
  return `## CI Result: ${result.passed ? 'passed' : 'failed'}\n\n${[...result.decisions, ...result.failures].map((line) => `- ${escapeSummary(line)}`).join('\n')}\n`;
}

export function runResult(env = process.env) {
  const result = evaluateNeeds(JSON.parse(env.CI_NEEDS_JSON));
  if (!env.GITHUB_STEP_SUMMARY) throw new Error('Missing Actions summary path');
  appendFileSync(env.GITHUB_STEP_SUMMARY, resultSummary(result));
  console.log(resultSummary(result));
  return result.passed ? 0 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try { process.exitCode = runResult(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
