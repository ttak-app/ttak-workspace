import assert from 'node:assert/strict';
import test from 'node:test';
import { swift } from './swift.mjs';

test('공유 브랜드 색상의 별칭과 RGBA를 보존한다', () => {
  const output = swift({ tokens: {
    'color.brand.coral': { type: 'color', value: '#D75D57' },
    'color.brand.alias': { type: 'color', value: '{color.brand.coral}' },
    'color.brand.alpha': { type: 'color', value: '#D75D5780' },
  } });
  assert.match(output, /brandCoral = TtakTokens.color\(0xD75D_57FF\)/);
  assert.match(output, /brandAlias = TtakTokens.color\(0xD75D_57FF\)/);
  assert.match(output, /brandAlpha = TtakTokens.color\(0xD75D_5780\)/);
});
test('크기와 CSS 효과는 네이티브 출력에 포함하지 않는다', () => {
  const output = swift({ tokens: {
    'space.24': { type: 'dimension', value: '24px' },
    'gradient.logo': { type: 'gradient', value: 'linear-gradient(115deg, #fff, #000)' },
  } });
  assert.doesNotMatch(output, /CGFloat|Spacing|Duration|linear-gradient|24px/);
  assert.throws(() => swift({ tokens: { 'color.brand.invalid': { type: 'color', value: 'invalid' } } }), /변환 불가/);
});
