// @ts-check
import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // Enforce explicit return types on public functions
      "@typescript-eslint/explicit-function-return-type": [
        "error",
        { allowExpressions: true },
      ],
      // No any — use unknown and narrow
      "@typescript-eslint/no-explicit-any": "error",
      // Prefer nullish coalescing
      "@typescript-eslint/prefer-nullish-coalescing": "error",
      // Consistent type imports
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports" },
      ],
      // No non-null assertion — handle nulls explicitly
      "@typescript-eslint/no-non-null-assertion": "error",
    },
  },
  {
    ignores: ["dist/**", "node_modules/**", "scripts/**", "*.config.js", "*.config.ts"],
  }
);
