# Agent schema — formato `pi-subagents`

Fonte di verità per scrivere `agent.md`. Descrive il formato dei file agente
dell'estensione `pi-subagents`: struttura, campi del frontmatter, enum, path di
discovery, precedenza e profili runner.

## 1. Struttura di un agente

Un agente è **un file Markdown** con due parti:

1. **Frontmatter YAML** tra `---` … `---` (metadati).
2. **System prompt** (il resto del file, istruzioni per il child).

Esempio minimo:

```markdown
---
name: scout
description: Fast codebase recon
tools: read, grep, find, ls
---

Sei `scout`: l'agente di ricognizione.
```

Convenzione di questa skill: un agente vive in una **directory propria**,
`.pi/agents/<nome>/agent.md`, così può portare con sé `scripts/`. Tuttavia la
discovery è ricorsiva (`**/*.md`), quindi funzionano anche i file piatti
`.pi/agents/<nome>.md`. La directory è preferita perché il nome cartella deve
combaciare col `name` ed è il posto naturale per gli script helper.

Layout consigliato:

```
.pi/agents/<nome>/
├── agent.md          # obbligatorio
└── scripts/          # opzionale: helper deterministici
    ├── check.py
    └── run.sh
```

## 2. Discovery e precedenza

| Priorità | Scope | Path |
|---|---|---|
| Bassa | Builtin | `~/.pi/agent/extensions/subagent/agents/` |
| | Pacchetto installato | `package.json` → `pi-subagents.agents` o `pi.subagents.agents` |
| | **Utente** | `~/.pi/agent/agents/**/*.md` |
| Alta | **Progetto** | `.pi/agents/**/*.md` |

Note:

- La discovery è **ricorsiva**: `.pi/agents/<nome>/agent.md` viene trovato.
- Legacy `.agents/**/*.md` è letto per compatibilità, ma `.pi/agents/` vince
  nei conflitti.
- La precedenza è per **nome runtime**: progetto > utente > builtin. Un agente
  di progetto con lo stesso nome sovrascrive quello builtin.
- Radici extra si aggiungono con `subagents.agentScanDirs` in `.pi/settings.json`.
- Per ancorare la risoluzione alla radice git (monorepo/worktree):
  `subagents.projectRootResolution: "git-root"`.

## 3. Campi del frontmatter

| Campo | Tipo | Obbligatorio | Significato |
|---|---|---|---|
| `name` | string | **sì** | Nome runtime (chiave). Lowercase, `[a-z0-9-]`, ≤64, niente trattini iniziali/finali/doppi, combacia con la cartella. |
| `description` | string | **sì** | Ciò che il parent usa per scegliere l'agente. Dichiara cosa fa **e** quando serve. ≤1024 caratteri. |
| `aliases` | string o lista | no | Nomi alternativi (es. `worker` → `developer, coder, implementer`). |
| `tools` | string o lista | no | Allowlist di strumenti del child. Minimo privilegio. |
| `model` | string | no | Modello da usare (`inherit` per ereditare il parent). |
| `thinking` | `low`/`medium`/`high` | no | Livello di ragionamento del child. |
| `systemPromptMode` | `replace`/`append` | no | `replace` sostituisce il prompt di default; `append` lo integra. |
| `defaultContext` | `fresh`/`fork` | no | `fresh` = contesto pulito; `fork` = ramo dello storico del parent. |
| `defaultReads` | string o lista | no | File letti di default dal child (es. `context.md, plan.md`). |
| `inheritProjectContext` | bool | no | Se ereditare il contesto di progetto del parent. |
| `inheritSkills` | bool | no | Se ereditare le skill del parent. |
| `defaultProgress` | bool | no | Se mostrare l'avanzamento di default. |
| `output` | string | no | Percorso di output atteso del child. |
| `async` | bool | no | Se il lancio è asincrono (background) di default. |
| `runner` | oggetto | no | Profilo di esecuzione esterno (vedi §5). |

### Valori di `tools`

I più usati: `read`, `grep`, `find`, `ls`, `bash`, `edit`, `write`.
Altri possibili a seconda dell'installazione: `subagent` (fanout, solo se
esplicitamente autorizzato dal parent), `contact_supervisor` (escalation).

Regola pratica:

- **Read-only** (analisi, review, recon): `read, grep, find, ls` (+ `bash`
  solo per verifiche non distruttive).
- **Writer** (implementazione): aggiungi `edit, write`.
- Un agente read-only **non** deve avere `edit`/`write`.

### Scelta di `defaultContext`

- `fresh` — reviewer avversariali, auditor, validatori: nessuna narrativa del
  parent che possa condizionarli.
- `fork` — lavoro implementativo che beneficia di decisioni, drift e root-cause
  già presenti nello storico.

### Scelta di `thinking`

- `low` — recon ad alto volume e basso rischio (scout).
- `high` — pianificazione, arbitraggio, review avversariale.

## 4. Risoluzione del modello

Precedenza (dalla più forte):

```
override per-run
  → override per-provider
  → agentOverrides.<name>.model        (settings)
  → frontmatter model
  → subagents.defaultModel             (settings)
  → modello del parent
```

`model: "inherit"` nel frontmatter o negli override usa esplicitamente il
modello della sessione parent.

Configurazione in `~/.pi/agent/settings.json` o `.pi/settings.json`:

```json
{
  "subagents": {
    "defaultModel": "deepseek-v4-flash",
    "agentOverrides": {
      "validator": { "model": "deepseek-v4-pro" },
      "scout": { "thinking": "low" }
    }
  }
}
```

La tua skill può **proporre** (non imporre) questi override al passo di
installazione, se l'utente vuole differenziare modello/thinking per ruolo.

## 5. Runner esterni (`external-cli`)

Un agente può eseguire un CLI esterno (Codex, Claude Code, Cursor) invece di una
sessione Pi:

```yaml
---
name: codex-exec
description: Read-only one-shot analysis through the installed Codex CLI
runner:
  type: external-cli
  adapter: codex-exec
  command: codex
  promptDelivery: stdin
async: true
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
---
Analyze the task in read-only mode. Return a concise final answer with evidence.
```

Regole:

- Il comando gira con `shell: false`, eredita `cwd` e ambiente, riceve
  istruzioni + task via **stdin** (`promptDelivery: stdin`, default).
- Sono **async-only e one-shot**: **`async: true` è obbligatorio** (il
  validatore lo impone).
- Supportano log stdout/stderr, timeout e stop.
- **Non** supportano opzioni native Pi (model override, structured output, tool
  budgets, fork context, skills) a meno che il runner non le implementi.

Usali solo quando l'utente vuole esplicitamente delegare a un CLI esterno.

## 6. YAML-safety

Il frontmatter è YAML reale: se un valore contiene `: ` (due punti + spazio),
`#`, `{`, `[`, `'`, `"`, `|`, `>`, o inizia con un carattere speciale, va
**quotato**.

```yaml
# Sbagliato — YAML non valido ("mapping values are not allowed")
description: Crea report: settimanali e mensili

# Corretto — virgolette singole
description: 'Crea report: settimanali e mensili'

# Corretto — block scalar
description: >-
  Crea report: settimanali e mensili
```

Le virgolette singole interne si raddoppiano: `'It''s ready'`.

Il validatore (`scripts/validate.py`) segnala i casi non parsabili.

## 7. Contratto di output (convenzione)

Non è imposto da `pi-subagents`, ma è la convenzione adottata dalla fleet di
riferimento: il child restituisce l'output finale come **un singolo blocco
Markdown ```json```**, con una shape stabile. Questo permette al parent di
consumare i risultati in modo deterministico.

Nel body dell'agente:

````markdown
### Output Contract
Return your final answer as a single fenced ```json``` block:

```json
{
  "status": "done | blocked | partial",
  "summary": "<cosa è stato fatto>",
  "evidence": [{ "command": "<cosa hai eseguito>", "exit_code": 0 }]
}
```
````

Adatta la shape al dominio. Mantienila **minima e stabile**.

## 8. Boundary di sicurezza

- **Un solo writer per file/worktree**: il parent non lancia due child che
  scrivono gli stessi file. Gli agenti writer devono dichiarare cosa scrivono.
- **Nessuna delega di default**: un child non riceve il tool `subagent` a meno
  che l'agente lo elenchi in `tools` e il parent autorizzi il fanout.
- **Nesting max 2** di default.
- **Read-only reale**: elenca i tool di sola lettura e vieta le scritture nel
  body.
- **Niente commit/publish**: gli agenti writer non fanno `git commit/push`,
  `git stash`, `git checkout <ref>`, comandi distruttivi o install di pacchetti
  se non esplicitamente richiesto dal task.

Riporta queste regole in un blocco `### Boundary Rules` nel body.

## 9. Checklist minima del frontmatter

Un agente valido ha sempre:

- [ ] `name` conforme e uguale al nome della cartella.
- [ ] `description` specifica (cosa + quando), ≤1024.
- [ ] `tools` come allowlist minima.
- [ ] `systemPromptMode` esplicito (`replace` per agenti specializzati).
- [ ] `defaultContext` coerente col ruolo (`fresh`/`fork`).
- [ ] Body non vuoto con direttive + contratto di output + boundary.
- [ ] YAML parsabile (nessun `:` non quotato).
