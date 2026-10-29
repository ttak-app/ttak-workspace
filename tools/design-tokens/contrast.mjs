import { readFileSync } from 'node:fs';
const { tokens } = JSON.parse(readFileSync(new URL('../../design-system/tokens.json', import.meta.url), 'utf8'));
const resolve = (name) => {
  const value = tokens[name].value;
  const alias = /^\{(.+)\}$/.exec(value);
  return alias ? resolve(alias[1]) : value;
};
const luminance = (hex) => {
  if (!/^#[0-9a-f]{6}$/i.test(hex)) throw new Error('이 검사는 불투명 sRGB 색상만 지원합니다.');
  const linear = hex.slice(1).match(/../g).map((value) => {
    const channel = Number.parseInt(value, 16) / 255;
    return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
  });
  return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
};
const pairs = [
  ['브랜드 coral', 'color.brand.coral'],
  ['브랜드 orange', 'color.brand.orange'],
  ['브랜드 강조', 'color.brand.strong'],
  ['로고 coral 끝점', 'color.logo.coral'],
  ['로고 orange 끝점', 'color.logo.orange'],
];
console.log('| 조합 | 전경 | 배경 | 대비율 | 일반 텍스트 4.5:1 |');
console.log('|---|---|---|---|---|');
for (const [label, foreground] of pairs) {
  const fg = resolve(foreground);
  const bg = '#FFFFFF'; // 대비 측정용 배경이며 공통 토큰은 아니다.
  const [light, dark] = [luminance(fg), luminance(bg)].sort((a, b) => b - a);
  const ratio = (light + 0.05) / (dark + 0.05);
  console.log(`| ${label} | ${fg} | ${bg} | ${ratio.toFixed(2)}:1 | ${ratio >= 4.5 ? '충족' : '미달'} |`);
}
