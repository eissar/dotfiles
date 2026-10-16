import { writeSync } from "node:fs";
import { userInfo } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (_pi: ExtensionAPI) {
  const user = userInfo().username;

  if (user !== "piagent") {
    writeSync(
      2,
      `Pi refuses to run as "${user}". Run with: sudo -u piagent -H pi\n`,
    );
    process.exit(1);
  }
}
