import assert from 'node:assert/strict';
const groups = [
  ['Colors', 'color.', 'Color'],
  ['Spacing', 'space.', 'CGFloat'],
  ['Radius', 'radius.', 'CGFloat'],
  ['BorderWidth', 'border.width.', 'CGFloat'],
  ['Opacity', 'opacity.', 'Double'],
  ['FontSize', 'font.size.', 'CGFloat'],
  ['Duration', 'motion.duration.', 'Double'],
  ['Delay', 'motion.delay.', 'Double'],
];
const identifier = (name) => {
  const camel = name.replace(/[.-]([a-z0-9])/g, (_, character) => character.toUpperCase());
  return /^\d/.test(camel) ? `value${camel}` : camel;
};
export function swift(source) {
  const resolve = (value) => value.replace(/\{([a-z0-9.-]+)\}/g, (_, name) => resolve(source.tokens[name].value));
  const output = groups.map(([group, prefix, type]) => {
    const names = new Set();
    const declarations = Object.entries(source.tokens).filter(([name, token]) => name.startsWith(prefix) && (group !== 'Colors' || !name.startsWith('color.palette.')) && !(group === 'Radius' && token.value.endsWith('%'))).map(([name, token]) => {
      const property = identifier(name.slice(prefix.length));
      assert(!names.has(property), `Swift 이름 충돌: ${group}.${property}`);
      names.add(property);
      const value = resolve(token.value);
      if (type === 'Color') {
        assert(/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(value), `Swift 색상 변환 불가: ${name}`);
        const rgba = `${value.slice(1)}${value.length === 7 ? 'FF' : ''}`;
        return `        static let ${property} = TtakTokens.color(0x${rgba.slice(0, 4)}_${rgba.slice(4)})`;
      }
      const number = Number.parseFloat(value);
      assert(Number.isFinite(number) && /^-?[0-9.]+(px|ms)?$/.test(value), `Swift 수치 변환 불가: ${name}`);
      const converted = value.endsWith('ms') ? number / 1000 : number;
      return `        static let ${property}: ${type} = ${converted}`;
    });
    return `    enum ${group} {\n${declarations.join('\n')}\n    }`;
  });
  return `// Generated from design-system/tokens.json. Run npm run tokens:build.\n// CGFloat dimensions are logical points. Durations and delays are seconds.\n// Web viewport typography, percentage radii and CSS effects are not converted.\nimport SwiftUI\n\nenum TtakTokens {\n${output.join('\n\n')}\n\n    private static func color(_ rgba: UInt32) -> Color {\n        Color(\n            .sRGB,\n            red: Double((rgba >> 24) & 255) / 255,\n            green: Double((rgba >> 16) & 255) / 255,\n            blue: Double((rgba >> 8) & 255) / 255,\n            opacity: Double(rgba & 255) / 255\n        )\n    }\n}\n`;
}
