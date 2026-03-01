module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    // ── Kept from default ────────────────────────────────────────────────────
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],

    // ── Overrides of eslint-config-google ────────────────────────────────────

    // google defaults to "never"; TypeScript community convention is "always".
    // { foo } is more readable than {foo} in imports and destructuring.
    "object-curly-spacing": ["error", "always"],

    // google defaults to 80; 120 is the modern industry standard and avoids
    // forcing artificial line breaks in template literals and long log strings.
    "max-len": ["error", { "code": 120 }],

    // TypeScript's static type system makes JSDoc @param/@return tags
    // redundant and hard to keep in sync. Disable both JSDoc rules.
    "valid-jsdoc": "off",
    "require-jsdoc": "off",
  },
};
