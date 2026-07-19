import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const output = join(root, "_site");
const assetOutput = join(output, "assets");
const embeddedAssets = await readFile(join(root, "html_report_assets.mbt"), "utf8");

function extractRawBinding(name) {
  const startMarker = `  let ${name} =\n`;
  const endMarker = `\n  ${name}\n`;
  const start = embeddedAssets.indexOf(startMarker);
  const end = embeddedAssets.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0) throw new Error(`Unable to extract MoonBit raw binding ${name}`);
  return embeddedAssets
    .slice(start + startMarker.length, end)
    .split("\n")
    .map((line) => {
      const marker = line.indexOf("#|");
      if (marker < 0) throw new Error(`Unexpected ${name} asset line: ${line}`);
      return line.slice(marker + 2);
    })
    .join("\n") + "\n";
}

await rm(output, { recursive: true, force: true });
await mkdir(assetOutput, { recursive: true });
await cp(join(root, "web"), output, { recursive: true });
await cp(join(root, "LICENSE"), join(output, "LICENSE.txt"));
await writeFile(join(assetOutput, "report-inspector.css"), extractRawBinding("styles"));
await writeFile(join(assetOutput, "report-inspector.js"), extractRawBinding("script"));
await cp(
  join(root, "_build/wasm/release/build/Milky2018/svgdiff/cmd/svgdiff_wasm/svgdiff_wasm.wasm"),
  join(assetOutput, "svgdiff_wasm.wasm"),
);
await writeFile(join(output, ".nojekyll"), "");

console.log(`GitHub Pages artifact: ${output}`);
