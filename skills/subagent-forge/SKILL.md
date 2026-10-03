---
name: subagent-forge
description: >-
  Design, write, validate, and install specialized pi-subagents subagents
  (Markdown agent definitions for the pi-subagents extension). Use this
  whenever the user wants to create a new subagent, turn a workflow or set of
  instructions into a reusable subagent, scaffold an agent under
  .pi/agents/<name>/agent.md, add deterministic helper scripts to an agent,
  choose the right frontmatter (tools, model, thinking, context, runner), or
  validate/install an existing agent — even if they only say "make a reusable
  agent for this" or "turn this into a subagent".
license: MIT
---

# subagent-forge

Una skill per costruire **subagent specializzati** per l'estensione
`pi-subagents` di Pi. Trasforma un workflow, una competenza o un insieme di
istruzioni in un agente riutilizzabile e verificato, con questa forma:

```
.pi/agents/<nome-agente>/
├── agent.md          # frontmatter YAML + system prompt
└── scripts/          # (opzionale) helper deterministici, solo se riducono gli errori
```

L'agente è pronto all'uso appena scritto: viene scoperto da `pi-subagents`
(project scope `.pi/agents/**/*.md`, user scope `~/.pi/agent/agents/**/*.md`) e
selezionato dal parent in base alla `description`.

## Quando usare questa skill

Usala quando l'utente:

- Vuole creare un nuovo subagent da zero ("crea un agente per X").
- Ha un workflow ripetibile e vuole renderlo un agente riutilizzabile.
- Vuole un agente in `.pi/agents/<nome>/` con `agent.md` ed eventuali script.
- Vuole revisionare/migliorare/correggere un `agent.md` esistente.
- Chiede quali `tools`, `model`, `thinking`, `defaultContext` o `runner` usare.
- Vuole validare, installare o impacchettare un agente.

Non usarla per una semplice domanda una tantum: serve solo quando il deliverable
è un **agente riutilizzabile**.

## Documenti da leggere (progressive disclosure)

Prima di scrivere qualsiasi `agent.md`, leggi questi file relativi alla
directory della skill:

- `references/agent-schema.md` — **obbligatorio**: formato reale, campi del
  frontmatter, enum, path di discovery e precedenza, regole `external-cli`,
  risoluzione del modello.
- `references/authoring-guide.md` — **obbligatorio**: come scrivere un buon
  agente (responsabilità singola, description orientata al routing, YAML-safety,
  tool scoping, struttura del system prompt, contratto di output).
- `references/helper-scripts.md` — quando e come aggiungere script per-agente.
- `references/examples.md` — esempi completi da imitare.
- `references/validation-checklist.md` — checklist manuale da affiancare al
  validatore automatico.

## Il loop operativo

Segui questi passi in ordine. Non saltare l'intervista (passo 2): un agente
scritto su assunzioni sbagliate è peggio di nessun agente.

### 1. Capture intent

Estrai dalla conversazione tutto ciò che è già emerso: compito dell'agente,
strumenti citati, formato di input/output, correzioni richieste. Poi chiedi
solo ciò che manca davvero. Se non c'è contesto, parti da queste domande:

1. Cosa deve fare l'agente, in una frase?
2. Quando il parent deve sceglierlo (parole chiave, contesto)?
3. Cosa produce in output, e in quale formato?
4. È read-only (analisi/review) o writer (modifica file)?

### 2. Intervista guidata

Determina, chiedendo all'utente dove serve:

- **Scope**: progetto (`.pi/agents/`) o utente (`~/.pi/agent/agents/`).
  Default: progetto.
- **Nome**: lowercase, trattini, ≤64 caratteri; deve combaciare con la cartella.
- **Responsabilità singola**: un agente, un compito. Se ne emergono due,
  proponi di dividerli in due agenti.
- **Tools**: allowlist minima necessaria. Read-only → `read, grep, find, ls`
  (più `bash` solo se deve eseguire verifiche sicure). Writer → aggiungi
  `edit, write`.
- **Contesto**: `fresh` per reviewer/analisti avversariali; `fork` per lavoro
  implementativo che beneficia dello storico.
- **Modello/thinking**: `inherit` + `thinking: low` per recon economico;
  `thinking: high` per pianificazione/review.
- **Contratto di output**: di solito un singolo blocco ```json``` alla fine.
- **Script helper**: servono passi deterministici, fragili o ripetitivi? Se sì,
  leggi `references/helper-scripts.md` e pianificali.

Se un choise è davvero ambiguo o l'utente deve decidere qualcosa di
consequenziale, chiedi — non inventare.

### 3. Design del layout

- Sempre `agent.md`.
- `scripts/` **solo se** uno script riduce il margine di errore: parsing,
  validazione, trasformazioni ripetitive, chiamate API/formato fisso.
- Niente cartelle inutili: `references/` e `assets/` dentro l'agente solo se
  l'agente deve consultarle.

Dettagli e criteri in `references/helper-scripts.md`.

### 4. Scrivi `agent.md`

Ordine:

1. **Frontmatter YAML** — compila i campi secondo `references/agent-schema.md`.
   Ricorda la **YAML-safety**: se un valore contiene `: `, `#`, `{`, `[`, `'`,
   `"` o `|`, scrivilo tra virgolette singole (raddoppiando le `'` interne)
   oppure come block scalar `>-`.
2. **Body (system prompt)** — struttura consigliata:
   - Una riga di identità: `Sei \`<nome>\`: <ruolo in una frase>.`
   - `### Operational Directives` — regole numerate e imperative.
   - `### Output Contract` — il blocco ```json``` atteso, con la shape esatta.
   - `### Boundary Rules` — cosa non può fare (read-only, niente commit,
     niente scritture fuori scope, escalation).
   Vedi `references/authoring-guide.md` e `references/examples.md`.

### 5. Genera gli script helper (solo se utili)

Collocali in `.pi/agents/<nome>/scripts/`, con shebang, `chmod +x`, exit code
significativi e output JSON. L'agente li invoca con path relativo alla propria
directory. Regole complete in `references/helper-scripts.md`.

### 6. Valida

```bash
python3 scripts/validate.py <path-agente>      # una directory
python3 scripts/validate.py --all .pi/agents    # tutte
```

Il validatore controlla frontmatter, enum, `tools`, coerenza nome↔cartella,
path di discovery, script referenziati ed eseguibili. Correggi tutto ciò che
segnala. Poi passa la checklist manuale in
`references/validation-checklist.md` — copre ciò che un linter non vede
(description troppo vaga per il routing, contratto di output ambiguo, tool
scope troppo ampio).

### 7. Installa e verifica la discovery

- Scope progetto: `.pi/agents/<nome>/agent.md`.
- Scope utente: `~/.pi/agent/agents/<nome>/agent.md`.
- Se servono override di modello, aggiungili in `.pi/settings.json`
  (`subagents.agentOverrides.<nome>.model`), come da `references/agent-schema.md`.

Verifica con:

```text
subagent({ action: "list" })
```

L'agente deve comparire con il `name` dichiarato.

---

## Scaffold rapido

Per partire da un template già conforme (frontmatter precompilato, opzionale
`scripts/`):

```bash
# Scope progetto (default) → ./.pi/agents/<nome>/agent.md
bash scripts/init.sh \
  --name <nome> \
  --description 'Cosa fa e quando usarlo.' \
  --tools 'read, grep, find, ls, bash'

# Scope utente → ~/.pi/agent/agents/<nome>/agent.md
bash scripts/init.sh --name <nome> --scope user

# Con script helper Python
bash scripts/init.sh --name <nome> --with-script py
```

Opzioni complete con `bash scripts/init.sh --help`. Lo scaffold è un punto di
partenza: personalizza sempre body e frontmatter, e passa il validatore.

## Packaging

```bash
python3 scripts/package_skill.py <path-skill-dir> [--out <output.zip>]
```

Produce un archivio contenente l'albero della skill, pronto da distribuire o
copiare nelle directory skills degli agenti di destinazione.

## Errori comuni da evitare

- `description` vaga ("aiuta con il codice") → il parent non selezionerà mai
  l'agente. Dichiara cosa fa **e** quando serve.
- Frontmatter non YAML-safe con `:` non quotati → l'agente non viene caricato.
- Tool scope troppo ampio per un read-only → mina le boundary e la sicurezza.
- Claim di scrittura non espliciti in agenti writer → rischi di conflitti
  quando il parent esegue più agenti in parallelo.
- `runner: external-cli` senza `async: true` → non è async-only.
- Body-romanzo senza contratto di output → risultato non verificabile.
- Script helper non documentati nel body o non eseguibili → l'agente fallisce.

## Riferimenti rapidi

| Campo | Valori |
|---|---|
| `thinking` | `low`, `medium`, `high` |
| `systemPromptMode` | `replace`, `append` |
| `defaultContext` | `fresh`, `fork` |
| `tools` comuni | `read`, `grep`, `find`, `ls`, `bash`, `edit`, `write` |
| `runner.type` | `external-cli` (async-only, stdin) |

Per tutto il resto, `references/agent-schema.md` è la fonte di verità.
