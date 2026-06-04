import { readFile } from "fs/promises";
import { join } from "path";
import { homedir } from "os";
import type { PluginDefinition } from "@yaakapp/api";

const TOKEN_PATH = join(homedir(), ".space", "token");

export async function readSpaceMeToken(): Promise<string | null> {
  try {
    const token = await readFile(TOKEN_PATH, "utf-8");
    const trimmedToken = token.trim();

    return trimmedToken || null;
  } catch {
    return null;
  }
}

export const plugin: PluginDefinition = {
  templateFunctions: [
    {
      name: "me_token",
      description: "Read the SPACE platform token from ~/.space/token",
      args: [],
      async onRender(_ctx) {
        return readSpaceMeToken();
      },
    },
  ],
};
