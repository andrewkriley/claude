---
name: splunk-dashboard-gen
description: Generates a Splunk Dashboard Studio dashboard with an AI-generated background image, then deploys it live to Splunk. Takes a Splunk index and SPL query, runs it, synthesises a thematic prompt, generates a background image via HuggingFace, builds the dashboard JSON, deploys it via REST API, and returns the live dashboard link. Use when the user says "generate a dashboard", "create a splunk dashboard", or "make a dashboard from a query".
argument-hint: [optional: dashboard title or theme]
---

You are generating a Splunk dashboard with an AI-generated background image and deploying it live to Splunk Dashboard Studio.

## Step 1 — Collect inputs

Ask the user for the following (all three are required). Ask in a single message:

1. **Splunk index** — which index to query (e.g. `meraki_54nr`, `main`, `*`)
2. **SPL statement** — the search/stats/chart command to run against that index (e.g. `stats count by sourcetype`, `timechart count by type`)
3. **Dashboard title** — a short name for the dashboard (e.g. "Network Events Overview")

If `$ARGUMENTS` is provided, use it as the dashboard title and skip asking for it separately.

Do not proceed until all three are provided.

## Step 2 — Run the Splunk query

Construct the full SPL as: `search index=<index> <spl_statement>`

Use the `mcp__splunk-mcp-server__splunk_run_query` tool:
- `query`: the full SPL above
- `earliest_time`: `-24h`
- `latest_time`: `now`
- `row_limit`: 50

Analyse the results. Note:
- What data domain this covers (e.g. network, auth, application, security)
- Key fields returned (e.g. `sourcetype`, `host`, `type`, `count`)
- Any patterns, spikes, or interesting distributions
- Volume and time range of events

This analysis drives both the image prompt and the dashboard panels.

## Step 3 — Craft the image generation prompt

Based on the query results analysis, write a vivid image generation prompt. Requirements:
- **Dark, clean background** — must work as a dashboard wallpaper without competing with charts and text
- **Avoid complexity** — no circuit board traces, no text or labels, no holographic grids, no busy patterns, no lines overlaid on the image. The image should feel calm and spacious.
- **Solid or photographic** — prefer real-world photography styles: dark server room ambiance, dramatic landscape, deep ocean, night sky, abstract smooth gradients, macro textures (dark metal, carbon fibre, brushed steel)
- **Domain-relevant** — loosely reflect the data domain through subject matter or colour palette (e.g. for network data: dark data centre corridor; for geo data: aerial city at night)
- **Cinematic quality** — wide depth of field, soft focus background, dramatic but subtle lighting
- Keep under 70 words (model limit)

Example prompt: *"Dark empty server room corridor, dramatic low lighting with subtle blue ambient glow, shallow depth of field, smooth dark floor reflections, cinematic wide angle, 4K professional photography, no text, no overlays"*

## Step 4 — Generate the background image

Use the `mcp__huggingface__gr1_z_image_turbo_generate` tool with:
- `prompt`: the prompt from Step 3
- `resolution`: `"1536x864 ( 16:9 )"` (landscape, best for dashboard backgrounds)
- `random_seed`: `true`
- `steps`: `8`

The tool will return an image URL. Create the output directory and download the image using the Bash tool:

```
mkdir -p "$HOME/dev/claude-created-dashboards/<slug>"
curl -sL "<image_url>" -o "$HOME/dev/claude-created-dashboards/<slug>/background.png"
```

Where `<slug>` is a lowercase, hyphenated version of the dashboard title (e.g. "Network Events Overview" → `network-events-overview`). Dashboards are saved under `$HOME/dev/claude-created-dashboards/<slug>` (not inside the repo).

The `<splunk_id>` is the same slug with hyphens replaced by underscores (e.g. `network_events_overview`). This is used as the Splunk view name.

## Step 5 — Build the Dashboard Studio JSON

Analyse the Splunk query results from Step 2 to determine the best visualisation types. Design multiple panels where the data supports it:
- `timechart` or time-series results → `splunk.line` or `splunk.area`
- `stats count by <field>` → `splunk.bar` or `splunk.pie`
- Raw events / `table` → `splunk.events` or `splunk.table`
- Single value / `stats count` → `splunk.singlevalue`

Encode the background image as base64 and embed it using the Bash tool:

```
base64 -i "$HOME/dev/claude-created-dashboards/<slug>/background.png"
```

Build the dashboard JSON using the Dashboard Studio structure below. Embed the base64 image as `"data:image/png;base64,<base64_string>"` in the `backgroundImage.src` field.

```json
{
  "visualizations": {
    "viz_1": {
      "type": "<splunk.bar|splunk.pie|splunk.line|splunk.table|splunk.singlevalue>",
      "dataSources": { "primary": "ds_1" },
      "title": "<descriptive panel title>",
      "options": {
        "seriesColors": ["#00b4d8", "#f77f00", "#9b5de5", "#06d6a0", "#ef233c"]
      }
    }
  },
  "dataSources": {
    "ds_1": {
      "type": "ds.search",
      "options": {
        "query": "search index=<index> <spl_statement>",
        "queryParameters": {
          "earliest": "-24h",
          "latest": "now"
        }
      }
    }
  },
  "inputs": {},
  "layout": {
    "type": "absolute",
    "options": {
      "width": 1440,
      "height": 960,
      "backgroundImage": {
        "sizeType": "cover",
        "src": "data:image/png;base64,<base64_string>"
      }
    },
    "structure": [
      {
        "item": "viz_1",
        "type": "block",
        "position": { "x": 60, "y": 80, "w": 1320, "h": 480 },
        "options": { "backgroundColor": "transparent" }
      }
    ],
    "globalInputs": []
  },
  "title": "<dashboard title>",
  "description": "Generated by Claude from index=<index> | <spl_statement>"
}
```

Every item in `layout.structure` must include `"options": { "backgroundColor": "transparent" }` so panels show the background image through the graph sections rather than the default opaque panel colour.

Use the Write tool to save the final JSON to `$HOME/dev/claude-created-dashboards/<slug>/dashboard.json`.

## Step 6 — Deploy to Splunk Dashboard Studio

The Splunk REST API (`/data/ui/views`) stores Dashboard Studio dashboards as XML with the JSON embedded in a `<definition><![CDATA[...]]></definition>` block. You must wrap the dashboard JSON before posting.

**Step 6a — Generate the XML wrapper** using the Bash tool:

```bash
python3 << 'PYEOF'
import os
slug = "<slug>"
title = "<dashboard title>"
json_path = os.path.expanduser(f"~/dev/claude-created-dashboards/{slug}/dashboard.json")
with open(json_path) as f:
    dashboard_json = f.read()
xml = f"""<dashboard version="2" theme="dark">
    <label>{title}</label>
    <description>Generated by Claude</description>
    <definition><![CDATA[
{dashboard_json}
    ]]></definition>
</dashboard>"""
out = os.path.expanduser(f"~/dev/claude-created-dashboards/{slug}/dashboard_wrapped.xml")
with open(out, "w") as f:
    f.write(xml)
print(f"Written {len(xml)} chars to {out}")
PYEOF
```

**Step 6b — Check if the dashboard already exists:**
```bash
source "$HOME/.claude/env.sh"
STATUS=$(curl -sk -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $SPLUNK_API_TOKEN" \
  "https://$SPLUNK_HOST:8089/servicesNS/admin/search/data/ui/views/<splunk_id>")
echo $STATUS
```
(Use `-u "$SPLUNK_USER:$SPLUNK_PASS"` instead of the `-H` token header if using basic auth.)

**If STATUS is 200 (update existing):**
```bash
source "$HOME/.claude/env.sh"
curl -sk -X POST \
  "https://$SPLUNK_HOST:8089/servicesNS/admin/search/data/ui/views/<splunk_id>" \
  -H "Authorization: Bearer $SPLUNK_API_TOKEN" \
  --data-urlencode "eai:data@$HOME/dev/claude-created-dashboards/<slug>/dashboard_wrapped.xml" \
  -o /dev/null -w "HTTP %{http_code}"
```

**If STATUS is 404 (create new):**
```bash
source "$HOME/.claude/env.sh"
curl -sk -X POST \
  "https://$SPLUNK_HOST:8089/servicesNS/admin/search/data/ui/views" \
  -H "Authorization: Bearer $SPLUNK_API_TOKEN" \
  -d "name=<splunk_id>" \
  --data-urlencode "eai:data@$HOME/dev/claude-created-dashboards/<slug>/dashboard_wrapped.xml" \
  -o /dev/null -w "HTTP %{http_code}"
```

A response of `HTTP 200` or `HTTP 201` confirms successful deployment. If the API returns an error, report the HTTP status and response body to the user and stop — do not retry without user input.

## Step 7 — Report to the user

Tell the user:

```
Dashboard deployed: <dashboard title>

Live dashboard: https://<SPLUNK_HOST>:8000/en-US/app/search/<splunk_id>

Local files:
  Image:     ~/dev/claude-created-dashboards/<slug>/background.png
  Dashboard: ~/dev/claude-created-dashboards/<slug>/dashboard.json
```

Replace `<SPLUNK_HOST>` with the actual value of the `$SPLUNK_HOST` environment variable (read it from the shell — do not print the literal string `$SPLUNK_HOST`).
