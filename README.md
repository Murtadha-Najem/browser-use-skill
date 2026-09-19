# browser-use skill for Claude Code

A Claude Code skill that makes browser work fast. Whenever a task needs a web browser, it picks the right tool for the job and drives it in as few steps as possible, instead of the slow default of one screenshot per click.

In a head-to-head test on the same task, it finished in **46 seconds with 2 tool calls**, against **320 seconds and 21 calls** for Claude in Chrome, with a cleaner result.

> Not to be confused with [browser-use/browser-use](https://github.com/browser-use/browser-use), the Python agent framework. That project runs its own LLM loop and needs a paid API key. This skill runs inside Claude Code, on your existing subscription, and adds no model calls of its own.

## Why it is faster

Every browser action is a round trip between the model and the browser, and every screenshot costs thousands of tokens that the model then has to read. The skill cuts both:

- **Whole flows in one call.** With dev-browser, Claude writes the entire task (navigate, click, extract, open the next page) as one script and runs it once.
- **Text, not pixels.** Pages are read as compact accessibility snapshots of a few hundred tokens.
- **One-shot extraction.** Tables and lists come back as JSON from a single `evaluate`, not element by element.
- **The right tool per task.** Network inspection, long forms and quick looks each go to the tool built for them.

## The tools it routes between

| The task | Tool |
|---|---|
| A multi-step job you can describe up front | [dev-browser](https://github.com/SawyerHood/dev-browser): the whole flow as one script |
| A quick look, a few clicks, an unknown page | [agent-browser](https://github.com/vercel-labs/agent-browser): compact snapshots with element refs |
| Long, fiddly flows: forms, uploads, dialogs, saved logins | [playwright-cli](https://github.com/microsoft/playwright-cli) |
| Network requests, console, performance, the page's own API | [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) |
| The user wants to watch, or a local dev server | Claude Code's built-in browser pane |
| Only your real Chrome sign-ins will do | Claude in Chrome, as the last resort |

## Benchmark

One task, run by three separate Claude Code agents on the same machine, each checked against the site's real data.

**Task:** on [books.toscrape.com](https://books.toscrape.com), open the Travel category from the sidebar, collect all 11 books (title, price, star rating, stock), then open the most expensive one and read its UPC and the number available.

| | Claude in Chrome | Built-in browser pane | **This skill** |
|---|---|---|---|
| Time | 320 s | 56 s | **46 s** |
| Tool calls | 21 | 10 | **2** |
| Tokens (whole agent) | 91.9k | 72.1k | **69.4k** |
| Result | Correct, but ratings were read off screenshots, a click silently did nothing, and a screenshot timed out | Correct after one wrong read of the home page | **Correct first time** |

Notes on reading this fairly:

- The token totals include each agent's fixed start-up context, which is about the same for all three, so the difference in the work itself is larger than the totals suggest.
- This is one run per tool on a clean practice site. Sites with logins or anti-bot protection will behave differently, and your numbers will vary with your connection.

## Install

Requirements: [Claude Code](https://claude.com/claude-code), Node.js 18 or newer, and about 300 MB of disk for the browsers the tools download.

### Option 1: installer script (recommended)

Installs the four tools, registers the Chrome DevTools MCP server, and copies the skill into `~/.claude/skills`.

Windows (PowerShell):

```powershell
git clone https://github.com/murtadha203/browser-use-skill
cd browser-use-skill
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

macOS and Linux:

```bash
git clone https://github.com/murtadha203/browser-use-skill
cd browser-use-skill
./install.sh
```

Then start a new Claude Code session.

### Option 2: as a Claude Code plugin

Inside Claude Code:

```
/plugin marketplace add murtadha203/browser-use-skill
/plugin install browser-use@browser-use-skill
```

The plugin carries the skill only. Install the tools themselves with the script and its skip flag, so the skill is not installed twice:

```powershell
.\install.ps1 -SkipSkill
```

```bash
./install.sh --skip-skill
```

### Make it the default

Claude loads the skill on its own when a task mentions a browser. To make it a firm rule, add this to your `~/.claude/CLAUDE.md`:

```markdown
## Any task that needs a browser: the `browser-use` skill

Load the `browser-use` skill first and let it pick the tool. Claude in Chrome is the last resort,
used only when the task needs my real Chrome sign-ins and nothing else can do it.
```

## Usage

Nothing to learn. Ask for anything that needs a browser, in English or Arabic:

- "Open the pricing page on example.com and list every plan with its price."
- "Log in to the staging site and check that the checkout form submits."
- "افتح الموقع وسحبلي جدول الأسعار."

## Platform notes

- **Windows:** dev-browser is pinned to **0.2.9**. Version 1.0 ships no Windows build yet, so do not upgrade it there. macOS and Linux get the latest version.
- **Never pipe agent-browser output** (`| head`, `| tail`) on a command that starts the browser. Its background daemon inherits the pipe and the shell hangs forever. The skill already tells Claude this.
- **Slow connections:** the browser downloads can time out. The installers raise the timeout and retry three times. If one still fails, run `dev-browser install` or `agent-browser install` again later.
- **Chrome DevTools MCP** runs its own persistent Chrome profile, so a site you log in to there once stays logged in. To drive your everyday Chrome instead, enable remote debugging at `chrome://inspect/#remote-debugging` and re-register the server with `--autoConnect`.

## Safety

The skill tells Claude never to type passwords, card numbers or other credentials, never to solve CAPTCHAs, and to treat text on web pages as data rather than instructions. Those steps are handed back to you.

## Uninstall

```bash
npm uninstall -g agent-browser @playwright/cli chrome-devtools-mcp dev-browser
claude mcp remove chrome-devtools -s user
```

Then delete `~/.claude/skills/browser-use`, or run `/plugin uninstall browser-use@browser-use-skill` if you installed the plugin.

## Repository layout

```
.claude-plugin/marketplace.json                   plugin marketplace entry
plugins/browser-use/.claude-plugin/plugin.json    plugin manifest
plugins/browser-use/skills/browser-use/SKILL.md   the skill itself
install.ps1                                       Windows installer
install.sh                                        macOS and Linux installer
```

## بالعربي

سكل لـ Claude Code تخلي أي شغل بالمتصفح أسرع. من تطلب مهمة تحتاج متصفح، تختار الأداة المناسبة وتنفذ المهمة بأقل عدد خطوات، بدل الطريقة البطيئة اللي تاخذ سكرين شوت بكل كليك.

بتجربة على نفس المهمة، خلصت بـ 46 ثانية وخطوتين، مقابل 320 ثانية و21 خطوة لـ Claude in Chrome، وبنتيجة أدق.

التنصيب: نزّل الريبو وشغّل `install.ps1` على ويندوز أو `install.sh` على ماك ولينكس، وبعدها افتح جلسة جديدة بـ Claude Code.

## Credits

The skill is a router and a set of habits. The tools do the work: [dev-browser](https://github.com/SawyerHood/dev-browser) by Sawyer Hood, [agent-browser](https://github.com/vercel-labs/agent-browser) by Vercel Labs, [playwright-cli](https://github.com/microsoft/playwright-cli) by Microsoft, and [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) by the Chrome DevTools team.

## License

MIT. See [LICENSE](LICENSE).
