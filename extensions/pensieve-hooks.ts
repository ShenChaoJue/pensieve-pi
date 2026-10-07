import { existsSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const HOOK_TIMEOUT_MS = 15_000;
const SYNC_TIMEOUT_MS = 60_000;
const FALLBACK_SEARCH_DEPTH = 5;
const FALLBACK_SEARCH_LIMIT = 500;

let cachedAdditionalContext = "";
let injectedForSession = false;

function isDirectory(candidate: string): boolean {
	try {
		return statSync(candidate).isDirectory();
	} catch {
		return false;
	}
}

function isSkillRoot(candidate: string): boolean {
	return isDirectory(candidate) && existsSync(join(candidate, ".src", "manifest.json"));
}

function findInstalledSkillRoot(searchRoot: string): string | undefined {
	if (!existsSync(searchRoot)) return undefined;

	const queue: Array<{ directory: string; depth: number }> = [{ directory: searchRoot, depth: 0 }];
	let visited = 0;

	while (queue.length > 0 && visited < FALLBACK_SEARCH_LIMIT) {
		const current = queue.shift();
		if (!current) break;
		visited++;

		const candidate = join(current.directory, "skills", "pensieve");
		if (isSkillRoot(candidate)) return candidate;
		if (current.depth >= FALLBACK_SEARCH_DEPTH) continue;

		try {
			const entries = readdirSync(current.directory, { withFileTypes: true })
				.filter((entry) => entry.isDirectory())
				.sort((left, right) => left.name.localeCompare(right.name));
			for (const entry of entries) {
				queue.push({ directory: join(current.directory, entry.name), depth: current.depth + 1 });
			}
		} catch {
			// An unreadable fallback directory is not fatal to extension loading.
		}
	}

	return undefined;
}

function resolveSkillRoot(): string | undefined {
	try {
		const configuredRoot = process.env.PENSIEVE_SKILL_ROOT;
		if (configuredRoot && isAbsolute(configuredRoot) && isDirectory(configuredRoot)) {
			return resolve(configuredRoot);
		}

		let directory = dirname(fileURLToPath(import.meta.url));
		for (let depth = 0; depth < 10; depth++) {
			const candidate = join(directory, "skills", "pensieve");
			if (isSkillRoot(candidate)) return candidate;
			const parent = dirname(directory);
			if (parent === directory) break;
			directory = parent;
		}

		return findInstalledSkillRoot(join(homedir(), ".pi", "agent"));
	} catch {
		return undefined;
	}
}

const skillRoot = resolveSkillRoot();

function projectUsesPensieve(projectRoot: string): boolean {
	return isDirectory(join(projectRoot, ".pensieve"));
}

function execOptions(
	projectRoot: string,
	signal: AbortSignal | undefined,
	timeout: number,
): { cwd: string; signal?: AbortSignal; timeout: number } {
	return {
		cwd: projectRoot,
		timeout,
		...(signal ? { signal } : {}),
	};
}

async function runHook(
	pi: ExtensionAPI,
	scriptName: string,
	projectRoot: string,
	signal: AbortSignal | undefined,
	options: { args?: string[]; input?: string; timeout?: number } = {},
) {
	if (!skillRoot) return undefined;
	const scriptPath = join(skillRoot, ".src", "scripts", scriptName);
	const args = options.args ?? [];
	const timeout = options.timeout ?? HOOK_TIMEOUT_MS;

	if (options.input === undefined) {
		return pi.exec(
			"env",
			[
				`PENSIEVE_SKILL_ROOT=${skillRoot}`,
				`PENSIEVE_PROJECT_ROOT=${projectRoot}`,
				"bash",
				scriptPath,
				...args,
			],
			execOptions(projectRoot, signal, timeout),
		);
	}

	// pi.exec has no stdin option, so pass the JSON as a positional argument and
	// feed it to the unchanged Claude hook script from a small bash wrapper.
	return pi.exec(
		"bash",
		[
			"-c",
			'printf "%s" "$1" | env "PENSIEVE_SKILL_ROOT=$2" "PENSIEVE_PROJECT_ROOT=$3" bash "$4" "${@:5}"',
			"pensieve-hook",
			options.input,
			skillRoot,
			projectRoot,
			scriptPath,
			...args,
		],
		execOptions(projectRoot, signal, timeout),
	);
}

function parseHookOutput(stdout: string): Record<string, unknown> | undefined {
	try {
		const parsed: unknown = JSON.parse(stdout.trim());
		if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
			return parsed as Record<string, unknown>;
		}
	} catch {
		// Hook failures and non-JSON output deliberately degrade to a no-op.
	}
	return undefined;
}

function getRecord(value: unknown): Record<string, unknown> | undefined {
	return typeof value === "object" && value !== null && !Array.isArray(value)
		? (value as Record<string, unknown>)
		: undefined;
}

function isPathInsidePensieve(projectRoot: string, inputPath: string): boolean {
	const dataRoot = resolve(projectRoot, ".pensieve");
	const normalizedInput = inputPath.startsWith("@") ? inputPath.slice(1) : inputPath;
	const absolutePath = isAbsolute(normalizedInput)
		? resolve(normalizedInput)
		: resolve(projectRoot, normalizedInput);
	const relativePath = relative(dataRoot, absolutePath);
	return (
		relativePath.length > 0 &&
		relativePath !== ".." &&
		!relativePath.startsWith(`..${sep}`) &&
		!isAbsolute(relativePath)
	);
}

async function syncProjectSkillGraph(
	pi: ExtensionAPI,
	projectRoot: string,
	filePath: string,
	signal: AbortSignal | undefined,
): Promise<void> {
	try {
		const payload = JSON.stringify({
			tool_name: "Write",
			tool_input: { file_path: filePath },
			cwd: projectRoot,
			tool_response: { success: true },
		});
		await runHook(pi, "sync-project-skill-graph.sh", projectRoot, signal, {
			input: payload,
			timeout: SYNC_TIMEOUT_MS,
		});
	} catch {
		// Post-write synchronization must never affect the tool result.
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		cachedAdditionalContext = "";
		injectedForSession = false;
		if (!skillRoot) return;

		const projectRoot = resolve(ctx.cwd);
		if (!projectUsesPensieve(projectRoot)) return;

		try {
			const result = await runHook(pi, "pensieve-session-marker.sh", projectRoot, ctx.signal, {
				args: ["--mode", "session-start"],
			});
			if (!result || result.code !== 0) return;

			const output = parseHookOutput(result.stdout);
			if (!output) return;
			const hookOutput = getRecord(output.hookSpecificOutput);
			const additionalContext = hookOutput?.additionalContext;
			if (typeof additionalContext === "string") cachedAdditionalContext = additionalContext;

			const systemMessage = output.systemMessage;
			if (ctx.hasUI && typeof systemMessage === "string" && systemMessage.length > 0) {
				ctx.ui.notify(systemMessage, "warning");
			}
		} catch {
			// Session startup must not be disrupted by Pensieve hook failures.
		}
	});

	pi.on("before_agent_start", (event, ctx) => {
		if (!skillRoot) return;
		const projectRoot = resolve(ctx.cwd);
		if (!projectUsesPensieve(projectRoot) || injectedForSession) return;
		injectedForSession = true;
		if (!cachedAdditionalContext) return;

		const previous = event.systemPromptOptions.sections.pensieve;
		event.systemPromptOptions.sections.pensieve = previous
			? `${previous}\n\n${cachedAdditionalContext}`
			: cachedAdditionalContext;
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!skillRoot || (event.toolName !== "Agent" && event.toolName !== "subagent")) return;

		const projectRoot = resolve(ctx.cwd);
		if (!projectUsesPensieve(projectRoot)) return;

		if (event.toolName === "subagent") {
			const agent = event.input.agent;
			const task = event.input.task;
			if (typeof agent !== "string" || typeof task !== "string") return;

			const normalizedAgent = agent.toLowerCase();
			// pi-subagents' scout agent is the equivalent of Claude's Explore agent.
			const hookSubagentType =
				normalizedAgent === "scout" || normalizedAgent === "explore"
					? "Explore"
					: normalizedAgent === "plan"
						? "Plan"
						: undefined;
			if (!hookSubagentType) return;

			try {
				const payload = JSON.stringify({
					tool_name: "Agent",
					tool_input: { subagent_type: hookSubagentType, prompt: task },
				});
				const result = await runHook(pi, "explore-prehook.sh", projectRoot, ctx.signal, {
					input: payload,
				});
				if (!result || result.code !== 0) return;

				const output = parseHookOutput(result.stdout);
				const hookOutput = getRecord(output?.hookSpecificOutput);
				const updatedInput = getRecord(hookOutput?.updatedInput);
				if (typeof updatedInput?.prompt === "string") event.input.task = updatedInput.prompt;
			} catch {
				// Preserve the original tool input on every failure path.
			}
			return;
		}

		const subagentType = event.input.subagent_type;
		const prompt = event.input.prompt;
		if (
			typeof subagentType !== "string" ||
			!/^(explore|plan)$/i.test(subagentType) ||
			typeof prompt !== "string"
		) {
			return;
		}

		// The upstream script compares these values case-sensitively. Normalize only
		// its routing payload; the original event.input.subagent_type stays untouched.
		const hookSubagentType = subagentType.toLowerCase() === "explore" ? "Explore" : "Plan";
		try {
			const payload = JSON.stringify({
				tool_name: "Agent",
				tool_input: { subagent_type: hookSubagentType, prompt },
			});
			const result = await runHook(pi, "explore-prehook.sh", projectRoot, ctx.signal, { input: payload });
			if (!result || result.code !== 0) return;

			const output = parseHookOutput(result.stdout);
			const hookOutput = getRecord(output?.hookSpecificOutput);
			const updatedInput = getRecord(hookOutput?.updatedInput);
			if (typeof updatedInput?.prompt === "string") event.input.prompt = updatedInput.prompt;
		} catch {
			// Preserve the original tool input on every failure path.
		}
	});

	pi.on("tool_result", (event, ctx) => {
		if (
			!skillRoot ||
			(event.toolName !== "write" && event.toolName !== "edit") ||
			event.isError
		) {
			return;
		}
		const projectRoot = resolve(ctx.cwd);
		if (!projectUsesPensieve(projectRoot)) return;

		const pathValue = event.input.file_path ?? event.input.path;
		if (typeof pathValue !== "string" || !isPathInsidePensieve(projectRoot, pathValue)) return;

		// Deliberately fire-and-forget: tool_result handlers are awaited by Pi, so
		// awaiting this potentially slow graph refresh would delay the model.
		void syncProjectSkillGraph(pi, projectRoot, pathValue, ctx.signal);
	});
}
