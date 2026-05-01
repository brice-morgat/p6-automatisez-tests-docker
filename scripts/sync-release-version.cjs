#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const [app, version] = process.argv.slice(2);
const root = path.resolve(__dirname, "..");

if (!app || !version) {
  console.error("Usage: node scripts/sync-release-version.cjs <angular|java> <version>");
  process.exit(1);
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`);
}

function syncAngular() {
  const appPath = path.join(root, "G-rez-l-int-gration-et-la-livraison-continue-Application-Angular");
  const packagePath = path.join(appPath, "package.json");
  const lockPath = path.join(appPath, "package-lock.json");

  const packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  packageJson.version = version;
  writeJson(packagePath, packageJson);

  const lockJson = JSON.parse(fs.readFileSync(lockPath, "utf8"));
  lockJson.version = version;
  if (lockJson.packages && lockJson.packages[""]) {
    lockJson.packages[""].version = version;
  }
  writeJson(lockPath, lockJson);
}

function syncJava() {
  const buildPath = path.join(root, "G-rez-l-int-gration-et-la-livraison-continue-Application-Java", "build.gradle");
  const buildGradle = fs.readFileSync(buildPath, "utf8");
  const updated = buildGradle.replace(/^version\s*=\s*['"][^'"]+['"]/m, `version = '${version}'`);

  if (updated === buildGradle) {
    console.error("Could not find Gradle version declaration.");
    process.exit(1);
  }

  fs.writeFileSync(buildPath, updated);
}

if (app === "angular") {
  syncAngular();
} else if (app === "java") {
  syncJava();
} else {
  console.error(`Unsupported app: ${app}`);
  process.exit(1);
}
