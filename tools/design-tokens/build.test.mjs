import assert from 'node:assert/strict';
import test from 'node:test';
import { compile } from './build.mjs';

const token = (value) => ({ type: 'color', value, description: '검증 예시', source: 'fixture', status: 'observed' });
const fixture = () => ({ version: 1, tokens: { 'color.raw': token('#FFFFFF'), 'color.surface': token('{color.raw}') }, overrides: [] });

test('의미 토큰은 CSS 변수로 참조하고 media query에서 재정의한다', () => {
  const source = fixture();
  source.overrides.push({ media: '(max-width: 760px)', description: '예시', values: { 'color.raw': '#000000' } });
  const { css } = compile(source);
  assert.match(css, /--ttak-color-surface: var\(--ttak-color-raw\);/);
  assert.match(css, /@media \(max-width: 760px\)/);
  assert.match(css, /--ttak-color-raw: #000000;/);
});
test('누락과 순환 참조는 생성 전에 거부한다', () => {
  const source = fixture();
  source.tokens['color.surface'].value = '{color.missing}';
  assert.throws(() => compile(source), /참조 누락/);
  source.tokens['color.surface'].value = '{color.raw}';
  source.tokens['color.raw'].value = '{color.surface}';
  assert.throws(() => compile(source), /순환 참조/);
});
test('반응형 재정의에서 발생한 순환도 거부한다', () => {
  const source = fixture();
  source.overrides.push({ media: '(max-width: 760px)', description: '예시', values: { 'color.raw': '{color.surface}' } });
  assert.throws(() => compile(source), /순환 참조/);
});
test('서로 다른 토큰이 같은 CSS 변수로 출력되면 거부한다', () => {
  const source = fixture();
  source.tokens['color-raw'] = token('#FFFFFF');
  assert.throws(() => compile(source), /CSS 변수 충돌/);
});
test('타입 불일치, 선언 삽입, 잘못된 참조 구문과 override 대상을 거부한다', () => {
  const source = fixture();
  source.tokens['color.raw'].type = 'dimension';
  assert.throws(() => compile(source), /타입 불일치/);
  source.tokens['color.raw'].type = 'color';
  source.tokens['color.raw'].value = '#fff; display: none';
  assert.throws(() => compile(source), /선언을 벗어나는/);
  source.tokens['color.raw'].value = '{broken';
  assert.throws(() => compile(source), /잘못된 참조/);
  source.tokens['color.raw'].value = '#fff';
  source.overrides.push({ media: '(max-width: 760px)', description: '예시', values: { missing: '#fff' } });
  assert.throws(() => compile(source), /override 대상 누락/);
});
