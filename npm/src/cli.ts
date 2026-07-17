#!/usr/bin/env node
/*
 * cc-c — Claude Code Container
 *
 * Thin launcher that wraps the `claude` CLI in a containerized environment.
 *
 * What it does:
 *   1. Detects the project directory ($PWD) and project name (basename of $PWD).
 *   2. Exports CCC_PROJECT_DIR=<cwd> and CCC_PROJECT=<basename>.
 *   3. Writes the bundled compose.yml to a temp file and runs:
 *        docker compose -f <tmp> run --rm ccc <your args...>
 *      The compose service's entrypoint is `claude`, so every flag passed to
 *      `cc-c` is forwarded to `claude` — e.g. `cc-c --dangerously-skip-permissions`
 *      runs `claude --dangerously-skip-permissions` inside the container.
 *
 * The container (host network) mounts the host `~/.claude` (settings) → `/root/.claude`,
 * the current project directory → `/root/<project>`, and `~/.ssh` (credentials) →
 * `/root/.ssh`, then launches `claude` from `/root/<project>`.
 */

"use strict";

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { spawn, spawnSync } from "node:child_process";

/** Locate the compose.yml bundled alongside this compiled file (dist/../compose.yml). */
function resolveComposeYml(): string {
  const candidate = path.join(__dirname, "..", "compose.yml");
  if (!fs.existsSync(candidate)) {
    throw new Error(
      `cc-c: bundled compose.yml not found at ${candidate}. The install looks incomplete; ` +
        `reinstall @jiangsier/cc-c (npm install -g @jiangsier/cc-c).`
    );
  }
  return candidate;
}

/** Return true if `docker` is runnable on PATH. */
function hasDocker(): boolean {
  const r = spawnSync("docker", ["--version"], { stdio: "ignore" });
  return r.status === 0 || r.error === undefined;
}

function fail(msg: string, code = 1): never {
  process.stderr.write(msg.endsWith("\n") ? msg : msg + "\n");
  process.exit(code);
}

function main(): void {
  const args = process.argv.slice(2);

  const cwd = process.cwd();
  const project = path.basename(cwd) || "project";

  // Forward the project dir/name to compose as env vars (do NOT set CCC_IMAGE —
  // let it default to the image defined in the bundled compose.yml).
  const env: NodeJS.ProcessEnv = {
    ...process.env,
    CCC_PROJECT_DIR: cwd,
    CCC_PROJECT: project,
  };

  if (!hasDocker()) {
    fail(
      "cc-c: `docker` was not found on PATH. Install Docker (and ensure `docker compose` works) before running cc-c."
    );
  }

  // Load the bundled compose.yml and drop it into a temp file. We can't use
  // `docker compose -f -` here because `run` reserves stdin for the interactive
  // container TTY (claude's session), so the compose definition must come from a file.
  let composeYml: string;
  try {
    composeYml = fs.readFileSync(resolveComposeYml(), "utf8");
  } catch (e) {
    fail(`cc-c: ${(e as Error).message}`);
  }

  const tmpFile = path.join(os.tmpdir(), `ccc-compose-${process.pid}.yml`);
  fs.writeFileSync(tmpFile, composeYml, { mode: 0o600 });

  const cleanup = (): void => {
    try {
      fs.unlinkSync(tmpFile);
    } catch {
      /* already gone */
    }
  };

  const child = spawn(
    "docker",
    ["compose", "-f", tmpFile, "run", "--rm", "ccc", ...args],
    { env, stdio: "inherit" }
  );

  // If spawn itself fails (e.g. docker vanished mid-run), clean up and exit.
  child.on("error", (err) => {
    cleanup();
    fail(`cc-c: failed to launch docker: ${err.message}`);
  });

  // Clean up the temp file no matter how the child exits.
  child.on("exit", (code, signal) => {
    cleanup();
    if (signal) {
      // Forward the signal to ourselves so the shell sees the right status.
      process.kill(process.pid, signal as NodeJS.Signals);
    }
    process.exit(code ?? 0);
  });

  // Propagate Ctrl-C / SIGTERM to the child so claude gets a clean teardown.
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"] as NodeJS.Signals[]) {
    process.on(sig, () => child.kill(sig));
  }
}

main();
