# paseo

> Background daemon that supervises coding agent CLIs and exposes them to desktop, mobile, and CLI clients.
> More information: <https://paseo.sh>.

- First-time setup: start the daemon and print pairing instructions:

`paseo onboard`

- List agents, excluding archived ones:

`paseo ls`

- Create and start an agent with a task:

`paseo run {{prompt}}`

- Stream a running agent's output:

`paseo attach {{agent_id}}`

- Send a follow-up message to an existing agent:

`paseo send {{agent_id}} {{prompt}}`

- View an agent's activity timeline:

`paseo logs {{agent_id}}`

- Show local daemon status:

`paseo status`

- Interrupt a running agent:

`paseo stop {{agent_id}}`
