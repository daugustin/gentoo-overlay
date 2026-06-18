#!/usr/bin/env bash
# Build the self-contained runtime artifact for www-apps/openchamber.
#
# OpenChamber is a Bun-managed TypeScript monorepo. Only packages/web (the
# @openchamber/web npm package = the `openchamber` CLI + Express server + the
# built web UI) is shipped. This script vendors that package's *production*
# dependency closure and pre-builds the web UI, producing a single tarball the
# ebuild consumes entirely offline.
#
# Why pre-build / pre-vendor instead of doing it in the ebuild:
#   * The repo only ships bun.lock (no package-lock.json); npm would re-resolve
#     a different tree over the network. Bun is not in ::gentoo, so the bun
#     install + the vite build must happen here, once, by the maintainer.
#   * The full install is ~1.7 GB (onnxruntime, sharp, transformers, every
#     platform's prebuilds, eslint/vite/... dev tooling). packages/web has no
#     workspace deps, so its real *runtime* closure is only ~80 MB. We prune to
#     exactly that.
#   * The compiled better-sqlite3 binary is V8-ABI specific, so we strip it and
#     let the ebuild rebuild it against the user's net-libs/nodejs. node-pty
#     ships an ABI-stable N-API prebuild, which we keep (linux only).
#
# Requirements: bun, node, git, tar, xz.
# Usage: openchamber-mkdist.sh [version]   (default version below)
# Output: openchamber-<version>-dist.tar.xz  (upload to files.hossie.de/gentoo/)
set -euo pipefail

PV="${1:-1.13.2}"
OUT="${PWD}/openchamber-${PV}-dist.tar.xz"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SRC="${WORK}/openchamber-${PV}"

echo ">>> Cloning openchamber v${PV}"
git clone --depth 1 --branch "v${PV}" \
	https://github.com/openchamber/openchamber.git "${SRC}"
cd "${SRC}"
rm -rf .git

echo ">>> bun install (applies fix-deprecation + ghostty patch, builds native)"
bun install --frozen-lockfile

echo ">>> Building the web UI (vite -> packages/web/dist)"
bun run build:web

echo ">>> Pruning node_modules to packages/web's production closure"
node - <<'NODE'
const fs = require('fs'); const path = require('path');
const root = process.cwd();
const start = path.join(root, 'packages/web');
const seen = new Set(); const queue = [start];
function deps(d){ let p; try { p = JSON.parse(fs.readFileSync(path.join(d,'package.json'),'utf8')); } catch { return []; }
  return [...new Set([...Object.keys(p.dependencies||{}),...Object.keys(p.optionalDependencies||{}),...Object.keys(p.peerDependencies||{})])]; }
function resolveFrom(from, dep){ let d=from;
  while(true){ const c=path.join(d,'node_modules',dep); if(fs.existsSync(c)) return fs.realpathSync(c);
    const u=path.dirname(d); if(u===d) break; d=u; }
  const c=path.join(root,'node_modules',dep); return fs.existsSync(c)?fs.realpathSync(c):null; }
while(queue.length){ const dir=queue.shift();
  for(const dep of deps(dir)){ const r=resolveFrom(dir,dep); if(!r||seen.has(r)) continue; seen.add(r); queue.push(r); } }
const bunDir = path.join(root,'node_modules/.bun');
const keep = new Set();
for(const p of seen){ const m=p.match(/node_modules\/\.bun\/([^/]+)\//); if(m) keep.add(m[1]); }
// keep native-build helpers needed when the ebuild rebuilds better-sqlite3
for(const x of ['node-gyp-build','prebuild-install','node-addon-api','bindings','nan'])
  for(const e of fs.readdirSync(bunDir)) if(e.startsWith(x+'@')) keep.add(e);
let removed=0;
for(const e of fs.readdirSync(bunDir)){ if(e==='node_modules') continue;
  if(!keep.has(e)){ fs.rmSync(path.join(bunDir,e),{recursive:true,force:true}); removed++; } }
console.log(`    kept ${keep.size} packages, removed ${removed}`);
NODE

echo ">>> Stripping non-amd64 native binaries"
# Keep only node-pty's linux-x64 N-API prebuild. bun-pty's Rust libs are only
# used under Bun (the ebuild runs plain node, which uses node-pty), so drop
# them all -- they otherwise trip Portage's foreign-arch QA check.
for d in "${SRC}"/node_modules/.bun/node-pty@*/node_modules/node-pty/prebuilds/*; do
	case "${d##*/}" in
		linux-x64) ;;
		*) rm -rf "${d}" ;;
	esac
done
rm -rf "${SRC}"/node_modules/.bun/bun-pty@*/node_modules/bun-pty/rust-pty/target

echo ">>> Stripping compiled better-sqlite3 (ebuild rebuilds it for ABI safety)"
rm -rf "${SRC}"/node_modules/.bun/better-sqlite3@*/node_modules/better-sqlite3/build

echo ">>> Dropping everything that isn't the web runtime"
# Keep only: node_modules/ (pruned store) + packages/web/{dist,server,bin,
# public,package.json,node_modules} -- i.e. @openchamber/web's published "files"
# plus its vendored deps. Drop the TS sources, vite config and html templates
# (the runtime serves the pre-built dist/), other workspaces, docs and scaffolding.
rm -rf "${SRC}"/packages/electron "${SRC}"/packages/ui \
	"${SRC}"/packages/vscode "${SRC}"/packages/docs "${SRC}"/scripts \
	"${SRC}"/docs "${SRC}"/patches
find "${SRC}" -maxdepth 1 -mindepth 1 \
	! -name node_modules ! -name packages -exec rm -rf {} +
rm -rf "${SRC}"/packages/web/src "${SRC}"/packages/web/index.html \
	"${SRC}"/packages/web/mobile.html "${SRC}"/packages/web/mini-chat.html \
	"${SRC}"/packages/web/tsconfig.json "${SRC}"/packages/web/vite.config.ts \
	"${SRC}"/packages/web/README.md

echo ">>> Removing dangling symlinks left by the pruned bun store"
# The hoist links every dependency, including the dev-only ones we just pruned.
# Those are never required at runtime; drop the broken links so they don't trip
# Portage QA. (The ebuild repeats this as a safety net.)
find "${SRC}"/node_modules "${SRC}"/packages -xtype l -delete

echo ">>> Creating ${OUT}"
tar -C "${WORK}" --owner=0 --group=0 --numeric-owner \
	-cf - "openchamber-${PV}" | xz -9e -T0 > "${OUT}"

echo ">>> Done: ${OUT}"
du -h "${OUT}"
