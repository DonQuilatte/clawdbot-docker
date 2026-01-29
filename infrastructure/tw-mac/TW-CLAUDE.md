# TW Mac Worker Node Configuration

> This Mac operates as a **worker node** for distributed development.
> Tasks are dispatched from the Controller Mac.

---

## Startup Checklist

1. Check for handoff files: `ls ~/handoffs/handoff-*.md`
2. Read latest handoff: `~/bin/read-handoff latest`
3. Confirm task understanding before proceeding

---

## Available Commands

- `~/bin/read-handoff [id|latest|list]` - Read task handoffs
- `~/bin/report-back <id> "summary"` - Report results to Controller

---

## Workflow Rules

1. **Always read handoff first**: Before starting work, read the handoff file
2. **Report completion**: Use `report-back` or write to response file
3. **Log significant output**: Write to `/tmp/` for debugging
4. **Keep sessions named**: Match handoff ID when possible

---

## Communication

- Handoffs arrive in: `~/handoffs/`
- Responses go to: `~/handoffs/response-<id>.md`
- Controller can see via: SMB mount

---

## Git Sync

Always pull latest before starting work:
```bash
cd ~/Development/Projects/clawdbot && git pull
```

---

## Do NOT

- Start work without reading handoff
- Modify files without confirming task scope
- Leave work unreported
- Assume context from previous sessions

---

## Process Intelligence Knowledge

> Foundation knowledge inherited from Controller Mac

**Abbreviations**:
- BPM: Business Process Management
- PI: Process Intelligence
- KPI: Key Performance Indicator
- I2P: Invoice-to-Pay
- P2P: Procure-to-Pay
- O2C: Order-to-Cash

---

*Worker Node - Reports to Controller Mac*
