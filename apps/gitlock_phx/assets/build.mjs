import * as esbuild from "esbuild";
import sveltePlugin from "esbuild-svelte";

const args = process.argv.slice(2);
const watch = args.includes("--watch");
const deploy = args.includes("--deploy");

/** @type {import('esbuild').BuildOptions} */
const buildOptions = {
  entryPoints: ["js/app.js"],
  bundle: true,
  target: "es2022",
  outdir: "../priv/static/assets/js",
  external: ["/fonts/*", "/images/*"],
  mainFields: ["svelte", "browser", "module", "main"],
  conditions: ["svelte", "browser"],
  logLevel: "info",
  nodePaths: ["../../../deps"],
  plugins: [
    sveltePlugin({
      compilerOptions: {
        css: "injected",
      },
    }),
  ],
  loader: {
    ".svg": "text",
  },
};

if (deploy) {
  buildOptions.minify = true;
  buildOptions.sourcemap = false;
} else {
  buildOptions.sourcemap = "inline";
}

if (watch) {
  const ctx = await esbuild.context(buildOptions);
  await ctx.watch();
  console.log("[esbuild+svelte] watching for changes...");
} else {
  await esbuild.build(buildOptions);
}
