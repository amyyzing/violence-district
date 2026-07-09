import { execFileSync, execSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { join, relative } from "node:path";
import { tmpdir } from "node:os";

const root = process.cwd();
const tempRoot = mkdtempSync(join(tmpdir(), "luau-parse-"));

async function collectLuauFiles(dir, out = []) {
	const entries = await readdir(dir, { withFileTypes: true });
	for (const entry of entries) {
		if (entry.name === ".git" || entry.name === "node_modules") {
			continue;
		}

		const fullPath = join(dir, entry.name);
		if (entry.isDirectory()) {
			await collectLuauFiles(fullPath, out);
		} else if (entry.isFile() && entry.name.endsWith(".luau")) {
			out.push(fullPath);
		}
	}
	return out;
}

function preprocessLuau(source) {
	return source.replace(
		/^(\s*[A-Za-z_][A-Za-z0-9_.]*)\s*([+\-*/])=\s*/gm,
		"$1 = $1 $2 "
	);
}

try {
	const sourceFiles = await collectLuauFiles(root);
	if (sourceFiles.length === 0) {
		console.log("No .luau files found.");
		process.exit(0);
	}

	sourceFiles.forEach((file, index) => {
		const source = readFileSync(file, "utf8");
		if (/[+\-*/]=/.test(source)) {
			throw new Error(`${relative(root, file)} uses compound assignment syntax`);
		}

		const tempFile = join(tempRoot, `${index}.lua`);
		writeFileSync(tempFile, preprocessLuau(source));

		if (process.platform === "win32") {
			const quotedPath = `"${tempFile.replace(/"/g, '""')}"`;
			execSync(`npx -y luaparse@0.3.1 --quiet -f ${quotedPath}`, {
				stdio: "inherit",
			});
		} else {
			execFileSync("npx", ["-y", "luaparse@0.3.1", "--quiet", "-f", tempFile], {
				stdio: "inherit",
			});
		}

		const size = statSync(file).size;
		console.log(`ok ${relative(root, file)} (${size} bytes)`);
	});
} finally {
	rmSync(tempRoot, { recursive: true, force: true });
}
