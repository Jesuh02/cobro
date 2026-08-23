import eslint from "@eslint/js";
import tseslint from "typescript-eslint";
import prettier from "eslint-config-prettier";

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  prettier,
  {
    languageOptions: {
      parserOptions: {
        project: "./tsconfig.json",
        tsconfigRootDir: import.meta.dirname
      }
    },
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-floating-promises": "error",
      "no-restricted-syntax": [
        "error",
        {
          selector: "MemberExpression[property.name='$queryRawUnsafe']",
          message: "Unsafe raw SQL is forbidden; use Prisma.sql parameters."
        },
        {
          selector: "MemberExpression[property.name='$executeRawUnsafe']",
          message: "Unsafe raw SQL is forbidden; use Prisma.sql parameters."
        },
        {
          selector: "CallExpression[callee.object.name='Prisma'][callee.property.name='raw']",
          message: "Prisma.raw is forbidden for application queries."
        }
      ]
    }
  }
);
