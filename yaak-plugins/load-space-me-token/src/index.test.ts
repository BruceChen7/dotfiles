import { describe, expect, test, vi } from "vitest";
import { plugin, readSpaceMeToken } from "./index";
import { readFile } from "fs/promises";

vi.mock("fs/promises");

describe("load-space-me-token", () => {
  test("Exports plugin object", () => {
    expect(plugin).toBeTypeOf("object");
  });

  test("Defines me_token template function", () => {
    expect(plugin.templateFunctions).toHaveLength(1);
    const fn = plugin.templateFunctions![0];
    expect(fn.name).toBe("me_token");
    expect(fn.description).toBeDefined();
  });

  test("Uses a function name that Yaak can render as ${[me_token()]}", () => {
    const fn = plugin.templateFunctions![0];
    expect(fn.name).toBe("me_token");
    expect(fn.args).toEqual([]);
  });

  test("readSpaceMeToken reads token from file", async () => {
    vi.mocked(readFile).mockResolvedValue("test-token\n");
    await expect(readSpaceMeToken()).resolves.toBe("test-token");
  });

  test("readSpaceMeToken returns null for empty token", async () => {
    vi.mocked(readFile).mockResolvedValue("\n");
    await expect(readSpaceMeToken()).resolves.toBeNull();
  });

  test("readSpaceMeToken returns null when file not found", async () => {
    vi.mocked(readFile).mockRejectedValue(new Error("ENOENT"));
    await expect(readSpaceMeToken()).resolves.toBeNull();
  });

  test("onRender exposes token as a template function value", async () => {
    vi.mocked(readFile).mockResolvedValue("test-token\n");
    const fn = plugin.templateFunctions![0];
    const result = await fn.onRender({} as any, {} as any);
    expect(result).toBe("test-token");
  });
});
