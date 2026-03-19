# Claude — Tips, Tricks, Tools & Resources

A curated reference for getting the most out of [Claude](https://claude.ai) as a thinking partner, agent, and assistant. Covers prompt engineering techniques, reusable system-prompt profiles, integrations, skills and external resources.

---

## Table of Contents

1. [Tips & Tricks](#tips--tricks)
2. [Prompt Engineering Techniques](#prompt-engineering-techniques)
3. [Reusable System-Prompt Profiles](#reusable-system-prompt-profiles)
4. [Tools & Integrations](#tools--integrations)
5. [Skills for Working With Claude](#skills-for-working-with-claude)
6. [External Resources](#external-resources)

---

## Tips & Tricks

### General Interaction

- **Be explicit about your goal** — tell Claude *why* you need something, not just *what* you want. Context dramatically improves relevance.
- **State your audience** — "explain this to a junior developer" or "write for a non-technical executive" shapes tone and depth automatically.
- **Ask for a plan before execution** — "outline your approach before writing the code" lets you course-correct early.
- **Use iterative refinement** — treat the first response as a draft. Follow up with "make it more concise", "add examples", or "challenge the assumptions above".
- **Request multiple options** — "give me three different framings" surfaces variety you can choose from or combine.
- **Name the format upfront** — "respond as a numbered list", "use a markdown table", or "write in bullet points" saves post-processing.
- **Ask Claude to steelman opposing views** — "what is the strongest counter-argument to this position?" yields more balanced thinking.
- **Use delimiters for structured input** — wrap sections with triple backticks or XML-style tags (`<document>`, `<code>`, `<data>`) to prevent ambiguity.
- **Request confidence levels** — append "and rate your confidence 1–10 with a short reason" to gauge when to verify externally.
- **Split large tasks** — break complex requests into smaller sub-tasks across multiple turns rather than sending one giant prompt.

### Working Memory & Context

- **Summarize the conversation yourself** — paste a bullet-point recap at the start of a new session to restore context cheaply.
- **Keep a "project brief" snippet** — maintain a short block of text (goals, constraints, vocabulary, stakeholders) that you paste at the start of long projects.
- **Reference previous turns explicitly** — "based on the architecture you described in turn 3" anchors Claude to earlier content.
- **Use files for long inputs** — upload documents rather than pasting them; Claude processes them with better structure retention.

### Quality & Accuracy

- **Ask Claude to cite its reasoning** — "explain step by step" or "show your working" makes errors easier to spot.
- **Request a self-critique** — "review your answer for logical gaps or missing edge cases" often catches mistakes before you do.
- **Cross-check factual claims** — Claude can hallucinate. For anything critical, ask it to identify which parts it is least certain about and verify those independently.
- **Ask "what am I missing?"** — after a deliverable, prompt "what important considerations did you not cover?" to surface blind spots.

---

## Prompt Engineering Techniques

### Zero-Shot Prompting
Ask Claude directly without providing examples. Works well for clear, common tasks.
```
Summarize the following contract clause in plain English: [clause]
```

### Few-Shot Prompting
Provide 2–5 worked examples before the real task to anchor tone, format and logic.
```
Classify the sentiment of each review as Positive, Neutral, or Negative.

Review: "Absolutely loved it!" → Positive
Review: "It was okay, nothing special." → Neutral
Review: "Terrible experience, never again." → Negative

Review: "The product arrived late but works fine." →
```

### Chain-of-Thought (CoT)
Instruct Claude to reason step-by-step before answering. Substantially improves accuracy on reasoning-heavy tasks.
```
Think through this step by step before giving your final answer: [question]
```

### Self-Consistency
Ask for the same reasoning task multiple times (or ask Claude to reason from different angles) and take the most common answer.
```
Solve this problem three different ways, then state which answer you are most confident in and why.
```

### Role / Persona Prompting
Assign a specific role to shift style, depth and focus.
```
You are a senior security engineer with 15 years of experience in penetration testing.
Review the following code for vulnerabilities: [code]
```

### Least-to-Most Prompting
Decompose a hard problem into sub-problems solved in increasing complexity.
```
To answer the main question, first answer these simpler sub-questions:
1. [sub-question 1]
2. [sub-question 2]
3. Now use those answers to address: [main question]
```

### ReAct (Reason + Act)
Ask Claude to interleave reasoning and action steps explicitly — useful when it has tools available.
```
Thought: [reason about what to do]
Action: [tool call or step]
Observation: [result]
... (repeat)
Answer: [final answer]
```

### Tree-of-Thought
Ask Claude to explore multiple reasoning branches before converging.
```
Explore three different solution strategies for [problem]. For each one, outline the approach, list pros/cons, and rate feasibility. Then recommend the best strategy.
```

### Structured Output Prompting
Force machine-readable output for downstream processing.
```
Return your answer as a JSON object with exactly these fields:
{ "summary": "...", "action_items": [...], "confidence": 0.0–1.0 }
```

### Reflexion / Self-Correction
Ask Claude to critique and improve its own output.
```
[Initial answer from Claude]

Now review your answer critically. Identify any logical errors, missing context, or improvements, then provide a revised version.
```

---

## Reusable System-Prompt Profiles

Paste one of these into the **System Prompt** field (API / Claude.ai Projects) to create a persistent persona.

### 🧠 Thinking Partner
```
You are a rigorous thinking partner. Your job is not to agree with the user but to help them think more clearly. Push back on weak reasoning, ask clarifying questions, surface hidden assumptions, and offer alternative framings. Be direct and concise. Avoid flattery.
```

### 💻 Senior Code Reviewer
```
You are a senior software engineer conducting a code review. For every piece of code shown to you:
1. Identify bugs, security issues, and performance problems (critical first).
2. Suggest idiomatic improvements aligned with the language's best practices.
3. Note anything that is done well.
4. Keep feedback specific, actionable and numbered.
Assume the author is competent but wants honest feedback.
```

### ✍️ Writing Coach
```
You are an expert writing coach who specializes in clear, concise professional writing. When asked to review text: identify unclear sentences, passive voice, unnecessary jargon and structural issues. When asked to write: match the user's stated audience and purpose. Always explain your editorial choices.
```

### 🔬 Research Assistant
```
You are a methodical research assistant. When asked a question:
1. State what is well-established, what is contested, and what is unknown.
2. Distinguish between primary evidence and secondary interpretation.
3. Flag any claims you are uncertain about.
4. Suggest 2–3 high-quality sources or search queries for further reading.
Never fabricate citations.
```

### 📊 Data & Strategy Analyst
```
You are a strategic analyst with expertise in data interpretation and business strategy. When presented with data or a business problem: structure your analysis using frameworks (SWOT, MECE, first-principles, etc.) where appropriate, quantify impacts where possible, and always end with a clear, prioritized recommendation.
```

### 🎯 Product Manager
```
You are an experienced product manager. Help the user define problems clearly, prioritize ruthlessly, and translate user needs into actionable requirements. Use frameworks like Jobs-to-be-Done, OKRs, or MoSCoW when helpful. Ask clarifying questions before diving into solutions.
```

### 🛡️ Devil's Advocate
```
You are a devil's advocate. Your sole job is to identify weaknesses in the user's plan, argument or idea. Be thorough and constructive — find every flaw, edge case, and counterexample you can. Do not suggest solutions unless explicitly asked; only surface problems.
```

### 🗣️ Socratic Tutor
```
You are a Socratic tutor. Never give direct answers. Instead, ask targeted questions that guide the learner to discover the answer themselves. Adjust the difficulty of your questions to the learner's apparent level. Praise correct reasoning, not just correct answers.
```

---

## Tools & Integrations

### Official Interfaces
| Tool | Description | Link |
|------|-------------|------|
| Claude.ai | Web and mobile chat interface | https://claude.ai |
| Claude iOS / Android | Native mobile apps | App Store / Google Play |
| Anthropic API | REST API for building applications | https://docs.anthropic.com |
| Claude for Slack | Add Claude to Slack workspaces | https://slack.com/apps |

### API & Developer Tools
| Tool | Description |
|------|-------------|
| **Anthropic Python SDK** | Official Python client (`pip install anthropic`) |
| **Anthropic TypeScript SDK** | Official Node.js/TS client (`npm install @anthropic-ai/sdk`) |
| **LangChain** | Framework for chaining LLM calls; has a Claude integration |
| **LlamaIndex** | Data framework for RAG pipelines with Claude support |
| **Instructor** | Structured output extraction from Claude using Pydantic |
| **Haystack** | End-to-end NLP pipelines with Claude nodes |
| **Vercel AI SDK** | Streaming Claude responses in Next.js / React apps |

### Model Context Protocol (MCP)
MCP is an open standard that lets Claude (and other models) interact with external tools and data sources via a standardized interface.

| Resource | Description |
|----------|-------------|
| **MCP Specification** | https://modelcontextprotocol.io |
| **Anthropic MCP Servers** | Official reference servers (filesystem, Git, databases, web search) |
| **MCP Inspector** | Debug and test MCP servers interactively |
| **Community MCP Servers** | Growing ecosystem of third-party servers (GitHub, Notion, Jira, etc.) |

### IDE & Coding Assistants
| Tool | Claude Support |
|------|---------------|
| **Cursor** | Native Claude model selection in AI editor |
| **Continue.dev** | Open-source VS Code / JetBrains plugin; supports Claude via Anthropic API |
| **Cody (Sourcegraph)** | Code AI with Claude backend option |
| **Zed Editor** | Built-in AI assistant with Claude support |
| **Aider** | Terminal-based AI pair programmer supporting Claude |

### Workflow & Automation
| Tool | Description |
|------|-------------|
| **n8n** | Self-hostable workflow automation with Claude nodes |
| **Zapier / Make** | No-code automation connecting Claude to thousands of apps |
| **Rivet** | Visual graph-based LLM pipeline builder (supports Claude) |
| **Flowise** | Open-source drag-and-drop LLM flow builder |
| **Dify** | LLM app development platform with Claude integration |

---

## Skills for Working With Claude

### Prompt Crafting
- Write prompts like briefs: audience, goal, constraints, format, tone.
- Separate instructions from data using delimiters (`---`, triple backticks, XML tags).
- Prefer positive instructions ("respond in bullet points") over negative ones ("don't use prose").
- Iterate promptly: after each response, identify the single biggest gap and address it.

### Context Management
- Understand the context window (~200k tokens for Claude 3.x): large doesn't mean unlimited — quality degrades with noise.
- Front-load the most important instructions; Claude attends more strongly to the beginning and end of prompts.
- Use Projects (Claude.ai) or system prompts (API) to persist persona and project context across sessions.
- Summarize long conversations into a compact context block before starting new threads.

### Evaluation & Trust Calibration
- Build a habit of asking "how confident are you?" and "what would change your answer?".
- For high-stakes outputs, ask Claude to list assumptions it is making.
- Use Claude to generate test cases for its own outputs ("write 5 edge cases that would break this logic").
- Cross-verify factual claims, especially in fast-moving domains (law, medicine, recent events).

### Collaboration Patterns
- **Outline → Draft → Critique → Revise**: use Claude for each stage, not just the draft.
- **Rubber-duck debugging**: narrate your problem to Claude; articulating it often surfaces the answer.
- **Parallel ideation**: ask for 5 ideas, expand the two best, then have Claude compare them.
- **Document-first development**: write the spec/docs with Claude before writing code.

### Agent & Agentic Workflows
- Give agents a clear, single objective per task; compound goals lead to unpredictable behavior.
- Always include an explicit stopping condition ("stop when you have a complete, working solution").
- Use structured tool schemas with descriptions; vague tool names cause misuse.
- Log every tool call and response for debugging; agentic failures are hard to trace otherwise.
- Prefer human-in-the-loop checkpoints for irreversible actions (sending emails, modifying databases, etc.).

---

## External Resources

### Official Documentation
| Resource | Link |
|----------|------|
| Anthropic Docs | https://docs.anthropic.com |
| Claude Model Overview | https://docs.anthropic.com/en/docs/about-claude/models/overview |
| Prompt Engineering Guide | https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview |
| System Prompts Guide | https://docs.anthropic.com/en/docs/build-with-claude/system-prompts |
| Tool Use (Function Calling) | https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview |
| MCP Introduction | https://docs.anthropic.com/en/docs/build-with-claude/mcp |
| Anthropic Cookbook (examples) | https://github.com/anthropics/anthropic-cookbook |

### Prompt Engineering
| Resource | Description |
|----------|-------------|
| [Anthropic Prompt Library](https://docs.anthropic.com/en/prompt-library/library) | Curated prompts for common tasks |
| [Learn Prompting](https://learnprompting.org) | Free open-source course on prompt engineering |
| [Prompt Engineering Guide (DAIR.AI)](https://www.promptingguide.ai) | Comprehensive techniques reference |
| [OpenAI Prompt Engineering](https://platform.openai.com/docs/guides/prompt-engineering) | Vendor-neutral techniques also applicable to Claude |

### Community
| Resource | Link |
|----------|------|
| Anthropic Discord | https://www.anthropic.com/discord |
| r/ClaudeAI (Reddit) | https://www.reddit.com/r/ClaudeAI |
| Anthropic Forum | https://support.anthropic.com |

### Papers & Research
| Paper | Topic |
|-------|-------|
| [Constitutional AI (Anthropic, 2022)](https://arxiv.org/abs/2212.08073) | How Claude is trained to be helpful and harmless |
| [Chain-of-Thought Prompting (Wei et al., 2022)](https://arxiv.org/abs/2201.11903) | Foundational CoT paper |
| [ReAct (Yao et al., 2022)](https://arxiv.org/abs/2210.03629) | Reason+Act prompting for agents |
| [Tree of Thoughts (Yao et al., 2023)](https://arxiv.org/abs/2305.10601) | Deliberate problem solving with LLMs |
| [Self-Refine (Madaan et al., 2023)](https://arxiv.org/abs/2303.17651) | Iterative self-critique and improvement |

---

## Contributing

Contributions welcome! If you have a tip, profile, tool or resource to add, please open a pull request or issue.

---

*Maintained by the community. Not officially affiliated with Anthropic.*