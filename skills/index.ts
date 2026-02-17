/**
 * OVM Manager - Single MCP Server with all OVM tools
 *
 * Run: node dist/index.js
 * Test: npx @modelcontextprotocol/inspector node dist/index.js
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import * as query from "./ovm-query/index.js";
import * as deploy from "./ovm-deploy/index.js";
import * as grantRoles from "./ovm-grant-roles/index.js";
import * as revokeRoles from "./ovm-revoke-roles/index.js";
import * as distribute from "./ovm-distribute/index.js";
import * as setBeneficiary from "./ovm-set-beneficiary/index.js";
import * as setRewardRecipient from "./ovm-set-reward-recipient/index.js";
import * as withdraw from "./ovm-withdraw/index.js";

const tools = [
  { definition: query.tool, handler: query.handler },
  { definition: deploy.tool, handler: deploy.handler },
  { definition: grantRoles.tool, handler: grantRoles.handler },
  { definition: revokeRoles.tool, handler: revokeRoles.handler },
  { definition: distribute.tool, handler: distribute.handler },
  { definition: setBeneficiary.tool, handler: setBeneficiary.handler },
  { definition: setRewardRecipient.tool, handler: setRewardRecipient.handler },
  { definition: withdraw.tool, handler: withdraw.handler },
];

const handlerMap = new Map(
  tools.map((t) => [t.definition.name, t.handler])
);

const server = new Server(
  { name: "ovm-manager", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map((t) => t.definition),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const handler = handlerMap.get(request.params.name);
  if (!handler) {
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify({
            error: `Unknown tool: ${request.params.name}. Available: ${tools.map((t) => t.definition.name).join(", ")}`,
          }),
        },
      ],
    };
  }

  const result = await handler(
    (request.params.arguments ?? {}) as Record<string, unknown>
  );

  return {
    content: [{ type: "text", text: result }],
  };
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch(console.error);
