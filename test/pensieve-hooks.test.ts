import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const skillRoot = join(dirname(fileURLToPath(import.meta.url)), "../skills/pensieve");
process.env.PENSIEVE_SKILL_ROOT = skillRoot;

type ExecResult = { code: number; stdout: string; stderr: string };
type ExecCall = {
	command: string;
	args: string[];
	options: { cwd: string; signal?: AbortSignal; timeout: number };
};
type Handler = (event: any, context: any) => unknown;

function successfulHookOutput(additionalContext?: string, updatedPrompt?: string): ExecResult {
	return {
		code: 0,
		stdout: JSON.stringify({
			...(additionalContext === undefined ? {} : { systemMessage: "Pensieve is active" }),
			hookSpecificOutput: {
				...(additionalContext === undefined ? {} : { additionalContext }),
				...(updatedPrompt === undefined ? {} : { updatedInput: { prompt: updatedPrompt } }),
			},
		}),
		stderr: "",
	};
}

function scriptName(call: ExecCall): string | undefined {
	const scriptPath = call.args.find((argument) => argument.endsWith(".sh"));
	return scriptPath && basename(scriptPath);
}

function hookPayload(call: ExecCall): Record<string, any> {
	assert.equal(call.command, "bash");
	assert.equal(call.args[0], "-c");
	return JSON.parse(call.args[3]);
}

function makeContext(cwd: string) {
	const notifications: Array<{ message: string; type: string | undefined }> = [];
	return {
		context: {
			cwd,
			signal: undefined,
			hasUI: false,
			ui: {
				notify(message: string, type?: string) {
					notifications.push({ message, type });
				},
			},
		},
		notifications,
	};
}

function beforeAgentStartEvent(pensieve?: string) {
	return {
		type: "before_agent_start",
		prompt: "user prompt",
		systemPrompt: "system prompt",
		systemPromptOptions: { sections: { ...(pensieve === undefined ? {} : { pensieve }) } },
	};
}

function toolCallEvent(toolName: string, input: Record<string, unknown>) {
	return { type: "tool_call", toolCallId: `call-${toolName}`, toolName, input };
}

function toolResultEvent(
	toolName: string,
	input: Record<string, unknown>,
	isError = false,
) {
	return {
		type: "tool_result",
		toolCallId: `result-${toolName}`,
		toolName,
		input,
		content: [],
		details: undefined,
		isError,
	};
}

test("pensieve extension hook bridge regression scenarios", async (t) => {
	const handlers = new Map<string, Handler>();
	const execCalls: ExecCall[] = [];
	let execImplementation: (call: ExecCall) => ExecResult | Promise<ExecResult> = () => ({
		code: 0,
		stdout: "{}",
		stderr: "",
	});
	const fakePi = {
		on(eventName: string, handler: Handler) {
			handlers.set(eventName, handler);
			return () => handlers.delete(eventName);
		},
		exec(command: string, args: string[], options: ExecCall["options"]) {
			const call = { command, args, options };
			execCalls.push(call);
			return Promise.resolve(execImplementation(call));
		},
	};

	const extensionUrl = new URL("../extensions/pensieve-hooks.ts", import.meta.url).href;
	const { default: registerPensieveHooks } = await import(extensionUrl);
	registerPensieveHooks(fakePi as any);
	assert.deepEqual([...handlers.keys()], [
		"session_start",
		"before_agent_start",
		"tool_call",
		"tool_result",
	]);

	const emit = async (eventName: string, event: Record<string, unknown>, context: any) => {
		const handler = handlers.get(eventName);
		assert.ok(handler, `expected a ${eventName} handler`);
		return await handler(event, context);
	};
	const temporaryRoots: string[] = [];
	const createProject = async (usesPensieve: boolean) => {
		const root = await mkdtemp(join(tmpdir(), "pensieve-hooks-test-"));
		temporaryRoots.push(root);
		if (usesPensieve) await mkdir(join(root, ".pensieve"));
		return root;
	};

	try {
		const plainRoot = await createProject(false);
		const projectRoot = await createProject(true);
		const { context: plainContext } = makeContext(plainRoot);
		const { context, notifications } = makeContext(projectRoot);

		await t.test("1. session_start skips projects without .pensieve", async () => {
			const initialCallCount = execCalls.length;
			await emit(
				"session_start",
				{ type: "session_start", reason: "startup" },
				plainContext,
			);
			assert.equal(execCalls.length, initialCallCount);
		});

		await t.test("2. session_start invokes the marker and caches valid context without UI", async () => {
			execImplementation = () => successfulHookOutput("cached project context");
			const initialCallCount = execCalls.length;
			await emit(
				"session_start",
				{ type: "session_start", reason: "startup" },
				context,
			);

			assert.equal(execCalls.length, initialCallCount + 1);
			const markerCall = execCalls.at(-1)!;
			assert.equal(scriptName(markerCall), "pensieve-session-marker.sh");
			assert.deepEqual(markerCall.args.slice(-2), ["--mode", "session-start"]);
			assert.equal(markerCall.options.cwd, projectRoot);
			assert.deepEqual(notifications, []);
		});

		await t.test("3. cached context is injected once per session and resets for a new session", async () => {
			const firstTurn = beforeAgentStartEvent();
			await emit("before_agent_start", firstTurn, context);
			assert.equal(firstTurn.systemPromptOptions.sections.pensieve, "cached project context");

			const secondTurn = beforeAgentStartEvent("existing second-turn section");
			await emit("before_agent_start", secondTurn, context);
			assert.equal(
				secondTurn.systemPromptOptions.sections.pensieve,
				"existing second-turn section",
			);

			execImplementation = () => successfulHookOutput("new-session context");
			await emit("session_start", { type: "session_start", reason: "new" }, context);
			const newSessionTurn = beforeAgentStartEvent();
			await emit("before_agent_start", newSessionTurn, context);
			assert.equal(newSessionTurn.systemPromptOptions.sections.pensieve, "new-session context");
		});

		await t.test("4. scout subagent is sent as Explore and receives an updated task", async () => {
			execImplementation = () => successfulHookOutput(undefined, "expanded scout task");
			const event = toolCallEvent("subagent", { agent: "scout", task: "original scout task" });
			const initialCallCount = execCalls.length;
			await emit("tool_call", event, context);

			assert.equal(execCalls.length, initialCallCount + 1);
			const call = execCalls.at(-1)!;
			assert.equal(scriptName(call), "explore-prehook.sh");
			assert.deepEqual(hookPayload(call), {
				tool_name: "Agent",
				tool_input: { subagent_type: "Explore", prompt: "original scout task" },
			});
			assert.equal(event.input.task, "expanded scout task");
			assert.equal(event.input.agent, "scout");
		});

		await t.test("5. worker passes through while plan is canonicalized to Plan", async () => {
			execImplementation = () => successfulHookOutput(undefined, "expanded plan task");
			const initialCallCount = execCalls.length;
			const workerEvent = toolCallEvent("subagent", { agent: "worker", task: "worker task" });
			await emit("tool_call", workerEvent, context);
			assert.equal(execCalls.length, initialCallCount);
			assert.equal(workerEvent.input.task, "worker task");

			const planEvent = toolCallEvent("subagent", { agent: "plan", task: "original plan task" });
			await emit("tool_call", planEvent, context);
			assert.equal(execCalls.length, initialCallCount + 1);
			assert.equal(hookPayload(execCalls.at(-1)!).tool_input.subagent_type, "Plan");
			assert.equal(planEvent.input.task, "expanded plan task");
			assert.equal(planEvent.input.agent, "plan");
		});

		await t.test("6. failed subagent hook leaves the task unchanged", async () => {
			execImplementation = () => ({ code: 1, stdout: "", stderr: "hook failed" });
			const event = toolCallEvent("subagent", { agent: "scout", task: "unchanged task" });
			const initialCallCount = execCalls.length;
			await emit("tool_call", event, context);
			assert.equal(execCalls.length, initialCallCount + 1);
			assert.equal(event.input.task, "unchanged task");
		});

		await t.test("7. Agent EXPLORE is canonicalized only in the payload and updates prompt", async () => {
			execImplementation = () => successfulHookOutput(undefined, "expanded Agent prompt");
			const event = toolCallEvent("Agent", {
				subagent_type: "EXPLORE",
				prompt: "original Agent prompt",
			});
			await emit("tool_call", event, context);

			const payload = hookPayload(execCalls.at(-1)!);
			assert.equal(payload.tool_input.subagent_type, "Explore");
			assert.equal(payload.tool_input.prompt, "original Agent prompt");
			assert.equal(event.input.prompt, "expanded Agent prompt");
			assert.equal(event.input.subagent_type, "EXPLORE");
		});

		await t.test("8. successful writes inside .pensieve trigger fire-and-forget graph sync", async () => {
			let resolveSync!: (result: ExecResult) => void;
			const syncFinished = new Promise<ExecResult>((resolve) => {
				resolveSync = resolve;
			});
			execImplementation = () => syncFinished;
			const filePath = join(projectRoot, ".pensieve", "knowledge", "note.md");
			const initialCallCount = execCalls.length;
			await emit("tool_result", toolResultEvent("write", { file_path: filePath }), context);

			assert.equal(execCalls.length, initialCallCount + 1);
			const call = execCalls.at(-1)!;
			assert.equal(scriptName(call), "sync-project-skill-graph.sh");
			assert.deepEqual(hookPayload(call), {
				tool_name: "Write",
				tool_input: { file_path: filePath },
				cwd: projectRoot,
				tool_response: { success: true },
			});
			resolveSync({ code: 0, stdout: "", stderr: "" });
			await syncFinished;
			await new Promise((resolve) => setImmediate(resolve));
		});

		await t.test("9. graph sync ignores outside paths, failed writes, and non-write tools", async () => {
			execImplementation = () => {
				throw new Error("ignored tool results must not execute hooks");
			};
			const initialCallCount = execCalls.length;
			await emit(
				"tool_result",
				toolResultEvent("write", { file_path: join(projectRoot, "outside.md") }),
				context,
			);
			await emit(
				"tool_result",
				toolResultEvent("write", { file_path: join(projectRoot, ".pensieve", "failed.md") }, true),
				context,
			);
			await emit(
				"tool_result",
				toolResultEvent("read", { file_path: join(projectRoot, ".pensieve", "note.md") }),
				context,
			);
			assert.equal(execCalls.length, initialCallCount);
		});

		await t.test("10. every executed hook has a positive timeout", () => {
			assert.ok(execCalls.length > 0);
			for (const call of execCalls) {
				assert.equal(typeof call.options.timeout, "number", scriptName(call));
				assert.ok(call.options.timeout > 0, scriptName(call));
			}
		});
	} finally {
		await Promise.all(temporaryRoots.map((root) => rm(root, { recursive: true, force: true })));
	}
});
