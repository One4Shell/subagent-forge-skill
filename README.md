# subagent-forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Una skill per creare **subagent specializzati** pronti all'uso con l'estensione
[`pi-subagents`](https://www.npmjs.com/package/pi-subagents) di Pi.

`subagent-forge` trasforma un workflow, una competenza o un insieme di istruzioni
in un agente riutilizzabile, con la struttura corretta e verificata:

```
.pi/agents/<nome-agente>/
├── agent.md          # frontmatter YAML + system prompt
└── scripts/          # (opzionale) helper deterministici per ridurre gli errori
    └── ...
```

Il risultato viene validato contro lo schema reale di `pi-subagents`, quindi è
immediatamente selezionabile dal parent (`subagent({ action: "list" })`) senza
restare bloccato su frontmatter malformato o path di discovery sbagliati.

## Cosa fa la skill

Quando la attivi (o quando Pi la seleziona automaticamente), `subagent-forge`:

1. **Raccoglie l'intento** — cosa deve fare l'agente, quando il parent deve
   sceglierlo, input e output attesi.
2. **Intervista** — scope (progetto/utente), responsabilità singola, allowlist
   dei `tools`, read-only vs writer, contesto `fresh`/`fork`, modello/thinking,
   contratto di output, necessità di script helper.
3. **Progetta il layout** — di default solo `agent.md`; aggiunge `scripts/` solo
   quando uno script deterministico riduce davvero il margine di errore.
4. **Scrive `agent.md`** — frontmatter YAML-safe + system prompt strutturato
   (Operational Directives / Output Contract / Boundary Rules).
5. **Genera eventuali script helper** — sicuri, con exit code e output JSON,
   referenziati dal body dell'agente.
6. **Valida** — `scripts/validate.py` controlla frontmatter, enum, tool,
   path di discovery e script referenziati.
7. **Installa** — colloca l'agente nel path di discovery corretto e (se serve)
   registra gli override in `.pi/settings.json`.

## Requisiti

- **Pi** (`pi`).
- L'estensione `pi-subagents`:

  ```bash
  pi install npm:pi-subagents
  ```

- Per il tooling di validazione: `python3` (consigliato `PyYAML`; senza, la
  validazione usa un parser di fallback con meno controlli).
- `bash` per `scripts/init.sh` e `install.sh`.

## Installare la skill

### Opzione 1 — Da repo git (npx skills)

```bash
npx skills add One4Shell/subagent-forge-skill --skill subagent-forge
```

### Opzione 2 — Con `install.sh` (nessun npm)

```bash
# Nel progetto corrente → .agents/skills/subagent-forge
./install.sh

# A livello utente → ~/.agents/skills/subagent-forge
./install.sh --global

# Claude-style → .claude/skills/subagent-forge
./install.sh --claude
```

### Opzione 3 — Manuale

Copia `skills/subagent-forge/` in una delle directory scoperte da Pi:

| Scope | Path |
|---|---|
| Utente | `~/.agents/skills/subagent-forge/` |
| Progetto | `.agents/skills/subagent-forge/` |
| Claude | `.claude/skills/subagent-forge/` |

## Usare la skill

In linguaggio naturale:

```text
Crea un subagent specializzato per <compito>.
Trasforma questo workflow in un agente pi-subagents riutilizzabile.
Aggiungi uno script helper all'agente <nome> per ridurre gli errori.
Valida e installa l'agente <nome>.
```

Oppure forzala esplicitamente:

```text
/skill:subagent-forge crea un agente "sql-auditor" read-only che analizza query
```

## Tooling

Dentro `skills/subagent-forge/`:

| File | Cosa fa |
|---|---|
| `scripts/init.sh` | Scaffold di un agente: `.pi/agents/<nome>/agent.md` (+ `scripts/`) con frontmatter precompilato. |
| `scripts/validate.py` | Lint di `agent.md` contro lo schema `pi-subagents`; supporta `--all` su una directory. |
| `scripts/package_skill.py` | Impacchetta la skill in un archivio `.skill`/`.zip` distribuibile. |

Esempi:

```bash
# Scaffold minimo (scope progetto)
bash skills/subagent-forge/scripts/init.sh \
  --name sql-auditor \
  --description 'Audit SQL queries for missing indexes and N+1 patterns.' \
  --tools 'read, grep, find, ls, bash'

# Scaffold con script helper Python
bash skills/subagent-forge/scripts/init.sh --name data-checker --with-script py

# Installazione a livello utente
bash skills/subagent-forge/scripts/init.sh --name sql-auditor --scope user

# Validazione
python3 skills/subagent-forge/scripts/validate.py .pi/agents/sql-auditor
python3 skills/subagent-forge/scripts/validate.py --all .pi/agents

# Packaging
python3 skills/subagent-forge/scripts/package_skill.py skills/subagent-forge
```

### Verifica

Output tipico del validatore su un agente corretto:

```text
$ python3 skills/subagent-forge/scripts/validate.py .pi/agents/sql-auditor
[PASS] .pi/agents/sql-auditor/agent.md

1/1 agent(s) passed
```

Un frontmatter non YAML-safe, un `external-cli` senza `async: true` o uno
script referenziato ma assente producono `ERROR` ed exit code `1`.

## Struttura della skill

```
subagent-forge/
├── SKILL.md
├── scripts/
│   ├── init.sh
│   ├── validate.py
│   └── package_skill.py
├── references/
│   ├── agent-schema.md          # formato pi-subagents, campi, discovery
│   ├── authoring-guide.md       # come scrivere un buon agente
│   ├── helper-scripts.md        # quando e come aggiungere script per-agente
│   ├── examples.md              # esempi completi
│   └── validation-checklist.md  # checklist manuale
└── assets/
    ├── agent-template.md.tmpl
    ├── helper-script.sh.tmpl
    └── helper-script.py.tmpl
```

## Riferimenti

- Documentazione Pi: <https://github.com/badlogic/pi-mono>
- `pi-subagents`: <https://www.npmjs.com/package/pi-subagents>
- Agent Skills specification: <https://agentskills.io/specification>

## Licenza

MIT — vedi [LICENSE](./LICENSE).
