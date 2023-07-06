import { resolve } from "path";
import { nodeResolve } from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import json from "@rollup/plugin-json";
import esbuild from "rollup-plugin-esbuild";

export default [
    {
        input: resolve("src/index.ts"),
        plugins: [
            json(),
            nodeResolve({ preferBuiltins: true }),
            commonjs(),
            esbuild({
                sourceMap: false,
                minify: process.env.NODE_ENV === "production",
                define: {
                    // strips out dotenv
                    "process.env.NODE_ENV": JSON.stringify(
                        process.env.NODE_ENV || "development"
                    ),
                },
            }),
        ],
        output: {
            dir: resolve("build"),
            format: "cjs",
        },
    },
];
