import assert from 'node:assert/strict';
import test from 'node:test';
import { swift } from './swift.mjs';

test('색상 별칭의 RGBA와 논리 크기, 초 단위 모션을 보존한다', () => {
  const output = swift({ tokens: {
    'color.palette.ink': { value: '#191F28' },
    'color.text.primary': { value: '{color.palette.ink}' },
    'color.surface.glass': { value: '#FFFFFFED' },
    'space.24': { value: '24px' },
    'motion.duration.hover': { value: '150ms' },
  } });
  assert.match(output, /textPrimary = TtakTokens.color\(0x191F_28FF\)/);
  assert.match(output, /surfaceGlass = TtakTokens.color\(0xFFFF_FFED\)/);
  assert.match(output, /value24: CGFloat = 24/);
  assert.match(output, /hover: Double = 0.15/);
});
test('웹의 상대 크기와 효과를 Swift 수치로 잘못 변환하지 않는다', () => {
  const output = swift({ tokens: {
    'typography.hero.size': { value: 'clamp(36px, 4.1vw, 62px)' },
    'radius.circle': { value: '50%' },
    'gradient.logo': { value: 'linear-gradient(115deg, #fff, #000)' },
  } });
  assert.doesNotMatch(output, /clamp|linear-gradient|50%/);
  assert.throws(() => swift({ tokens: { 'space.relative': { value: '2rem' } } }), /변환 불가/);
});
