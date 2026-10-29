import assert from 'node:assert/strict';

export function swift(source) {
  const resolve = (value) => value.replace(/\{([a-z0-9.-]+)\}/g, (_, name) => resolve(source.tokens[name].value));
  const names = new Set();
  const colors = Object.entries(source.tokens).filter(([name, token]) => name.startsWith('color.') && token.type === 'color').map(([name, token]) => {
    const property = name.slice('color.'.length).replace(/[.-]([a-z0-9])/g, (_, character) => character.toUpperCase());
    assert(!names.has(property), `Swift 이름 충돌: ${property}`);
    names.add(property);
    const value = resolve(token.value);
    assert(/^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(value), `Swift 색상 변환 불가: ${name}`);
    const rgba = `${value.slice(1)}${value.length === 7 ? 'FF' : ''}`;
    return `        static let ${property} = TtakTokens.color(0x${rgba.slice(0, 4)}_${rgba.slice(4)})`;
  });
  return `// Generated from design-system/tokens.json. Run npm run tokens:build.\n// Brand colors only. Use system styles for native text, controls and materials.\nimport SwiftUI\n\nenum TtakTokens {\n    enum Colors {\n${colors.join('\n')}\n    }\n\n    private static func color(_ rgba: UInt32) -> Color {\n        Color(\n            .sRGB,\n            red: Double((rgba >> 24) & 255) / 255,\n            green: Double((rgba >> 16) & 255) / 255,\n            blue: Double((rgba >> 8) & 255) / 255,\n            opacity: Double(rgba & 255) / 255\n        )\n    }\n}\n`;
}
