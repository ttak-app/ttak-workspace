import assert from 'node:assert/strict';
import { preview } from './preview.mjs';
import { format } from 'prettier';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
export const sourcePath = 'design-system/tokens.json';
const outputs = {
  css: 'apps/web/src/styles/tokens.css',
  catalog: 'docs/design-system/tokens.md',
  preview: 'docs/design-system/preview.html',
};
const types = new Set(['color', 'gradient', 'fontFamily', 'dimension', 'number',
  'lineHeight', 'letterSpacing', 'shadow', 'duration', 'cubicBezier']);
const statuses = new Set(['observed', 'draft-only']);
const referencePattern = /\{([a-z0-9.-]+)\}/g;
export const cssName = (name) => `--ttak-${name.replaceAll('.', '-')}`;
const references = (value) => [...value.matchAll(referencePattern)].map((match) => match[1]);
const cssValue = (value) => value.replace(referencePattern, (_, name) => `var(${cssName(name)})`);

export function compile(source) {
  assert.equal(source.version, 1, '지원하지 않는 토큰 버전');
  assert(source.tokens && typeof source.tokens === 'object', 'tokens 객체 필요');
  assert(Object.keys(source.tokens).length > 0, '빈 토큰 목록');
  assert(Array.isArray(source.overrides), 'overrides 배열 필요');
  const names = Object.keys(source.tokens);
  const emittedNames = new Set();
  for (const name of names) {
    assert(/^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*$/.test(name), `잘못된 이름: ${name}`);
    assert(!emittedNames.has(cssName(name)), `CSS 변수 충돌: ${name}`);
    emittedNames.add(cssName(name));
    const token = source.tokens[name];
    assert(types.has(token.type), `잘못된 타입: ${name}`);
    assert(statuses.has(token.status), `잘못된 상태: ${name}`);
    for (const key of ['value', 'description', 'source']) {
      assert(typeof token[key] === 'string' && token[key].trim(), `${name}.${key} 필요`);
    }
  }
  const validateValue = (value, name) => {
    assert(typeof value === 'string' && value.trim(), `빈 값: ${name}`);
    assert(!/[;\n\r]/.test(value), `선언을 벗어나는 값: ${name}`);
    const stripped = value.replace(referencePattern, '');
    assert(!/[{}]/.test(stripped), `잘못된 참조 구문: ${name}`);
    for (const reference of references(value)) {
      assert(Object.hasOwn(source.tokens, reference), `참조 누락: ${name} → ${reference}`);
    }
    const direct = /^\{([a-z0-9.-]+)\}$/.exec(value);
    if (direct) assert.equal(source.tokens[direct[1]].type, source.tokens[name].type, `참조 타입 불일치: ${name}`);
  };
  const validateGraph = (values) => {
    const visiting = new Set();
    const visited = new Set();
    const visit = (name) => {
      assert(!visiting.has(name), `순환 참조: ${name}`);
      if (visited.has(name)) return;
      visiting.add(name);
      for (const reference of references(values[name])) visit(reference);
      visiting.delete(name);
      visited.add(name);
    };
    names.forEach(visit);
  };
  const baseValues = Object.fromEntries(names.map((name) => [name, source.tokens[name].value]));
  names.forEach((name) => validateValue(baseValues[name], name));
  validateGraph(baseValues);
  // 겹치는 media query에서도 앞선 override와 함께 순환이 생기지 않는지 검사한다.
  let combined = { ...baseValues };
  for (const override of source.overrides) {
    assert(typeof override.media === 'string' && /^\([a-z0-9: .-]+\)( and \([a-z0-9: .-]+\))*$/.test(override.media), '잘못된 media query');
    assert(typeof override.description === 'string' && override.description.trim(), 'override 설명 필요');
    assert(override.values && typeof override.values === 'object', 'override 값 필요');
    for (const [name, value] of Object.entries(override.values)) {
      assert(Object.hasOwn(source.tokens, name), `override 대상 누락: ${name}`);
      validateValue(value, name);
    }
    validateGraph({ ...baseValues, ...override.values });
    combined = { ...combined, ...override.values };
    validateGraph(combined);
  }
  const block = (values) => Object.entries(values).map(([name, value]) => `  ${cssName(name)}: ${cssValue(value)};`).join('\n');
  const css = `/* Generated from ${sourcePath}. Run npm run tokens:build. */\n:root {\n${block(baseValues)}\n}\n` + source.overrides.map((override) => `\n@media ${override.media} {\n  :root {\n${block(override.values).split('\n').map((line) => `  ${line}`).join('\n')}\n  }\n}\n`).join('');
  const cell = (text) => text.replaceAll('|', '\\|').replaceAll('\n', ' ');
  const rows = names.map((name) => {
    const token = source.tokens[name];
    return `| \`${cssName(name)}\` | ${token.type} | \`${cell(token.value)}\` | ${cell(token.description)} | ${cell(token.source)} | ${token.status} |`;
  });
  const catalog = `# 디자인 토큰 목록\n\n자동 생성 파일. 수정은 [JSON 원본](../../${sourcePath})에서 하고 \`npm run tokens:build\`를 실행한다.\n\n용도와 제약은 [사용 지침](README.md), 실제 사용 근거는 [분석 기록](audit.md), 참조 파일은 [원본 목록](reference/README.md)을 확인한다.\n\n| CSS 변수 | 종류 | 원본 값 또는 참조 | 용도 | 근거 | 상태 |\n|---|---|---|---|---|---|\n${rows.join('\n')}\n` + source.overrides.map((override) => `\n## \`${override.media}\`\n\n${override.description}\n\n| CSS 변수 | 값 또는 참조 |\n|---|---|\n${Object.entries(override.values).map(([name, value]) => `| \`${cssName(name)}\` | \`${cell(value)}\` |`).join('\n')}\n`).join('');
  return { css, catalog };
}

export async function build({ check = false } = {}) {
  const source = JSON.parse(readFileSync(resolve(root, sourcePath), 'utf8'));
  for (const path of Object.values(source.sources)) readFileSync(resolve(root, path));
  const generated = { ...compile(source), preview: preview(source) };
  const formatting = JSON.parse(readFileSync(resolve(root, 'apps/web/.prettierrc.json'), 'utf8'));
  generated.css = await format(generated.css, { ...formatting, parser: 'css' });
  generated.preview = await format(generated.preview, { ...formatting, parser: 'html' });
  for (const [kind, path] of Object.entries(outputs)) {
    if (check) {
      assert.equal(readFileSync(resolve(root, path), 'utf8'), generated[kind], `${path}가 원본과 다릅니다. npm run tokens:build 실행 필요`);
    } else writeFileSync(resolve(root, path), generated[kind]);
  }
  return Object.keys(source.tokens).length;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    assert(args.length === 0 || (args.length === 1 && args[0] === '--check'), '사용법: build.mjs [--check]');
    console.log(`디자인 토큰 ${await build({ check: args[0] === '--check' })}개 ${args[0] === '--check' ? '일관성 확인' : '생성'}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
