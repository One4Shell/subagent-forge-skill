# Authoring guide — come scrivere un buon subagent

Questa guida copre le scelte di progettazione che rendono un agente
selezionabile, affidabile e sicuro. Leggila prima di scrivere un `agent.md`:
sono convenzioni che non si deducono a prima vista.

## 1. Responsabilità singola

Un agente = un compito. Il parent seleziona gli agenti in base alla
`description`; un agente che fa cinque cose non viene scelto per nessuna.

Se durante l'intervista emergono due responsabilità distinte (es. "analizza e
poi scrive"), proponi di dividerle in **due agenti** con description diverse.
È meglio di un agente onnivoro con tool scope enorme.

## 2. La `description` decide il routing

La `description` è l'**unica** cosa che il parent legge per scegliere l'agente.
Deve dire:

1. **Cosa** fa l'agente.
2. **Quando** usarlo (parole chiave, tipo di compito, contesto).

Bene:

```yaml
description: >-
  Fast read-only codebase recon: maps relevant files, symbols, commands, and
  risks for a target area. Use when the parent needs precise context before
  planning or implementing, especially for multi-file or unfamiliar code.
```

Male:

```yaml
description: Helps with code.
```

Tecniche utili:

- Includi i sinonimi con cui l'utente potrebbe riferirsi al compito.
- Nomina esplicitamente il "quando" ("Use when…", "Usalo quando…").
- Evita di essere generico: se vale per qualsiasi agente, non seleziona nessuno.
- Lunghezza ≤1024 caratteri. Un block scalar `>-` è comodo e YAML-safe.

## 3. Naming e struttura del body

- `name`: lowercase, cifre e trattini; ≤64; niente trattini iniziali/finali o
  doppi; **deve combaciare con il nome della cartella** (portabilità).
- Body consigliato, in quest'ordine:

```markdown
Sei `<nome>`: <ruolo in una frase>.

### Operational Directives
1. <regola imperativa>
2. <regola imperativa>

### Output Contract
Return your final answer as a single fenced ```json``` block:
```json
{ "..." : "..." }
```

### Boundary Rules
- Cosa l'agente non può fare.
- Quando e come escalare (`contact_supervisor`).
```

- **Direttive imperative e numerate**, non un saggio. Frasi brevi, verificabili.
- Il body non deve ripetere il frontmatter: qui vivono i dettagli operativi.
- Evita prosa decorativa: ogni frase deve cambiare il comportamento del child.

## 4. Tool scope (minimo privilegio)

Scegli l'allowlist più piccola che basta:

| Ruolo | Tools |
|---|---|
| Recon / analisi | `read, grep, find, ls` |
| Review con verifiche | `read, grep, find, ls, bash` |
| Implementazione | `read, grep, find, ls, bash, edit, write` |
| Escalation al parent | `+ contact_supervisor` |

Regole:

- Non concedere `edit`/`write` a un agente che non deve modificare nulla.
- `bash` in un read-only va giustificato: solo comandi non distruttivi e
  ripetibili (build, grep, test mirati). Vieta scritture e rete se non
  necessarie.
- Non concedere `subagent` se non per fanout esplicitamente autorizzato.

## 5. Read-only vs writer

Rendila esplicita nel body, non solo nei `tools`:

- **Read-only**: "Non modificare file. Esegui solo comandi non distruttivi."
- **Writer**: dichiara la superficie di scrittura. Se il parent esegue più
  agenti in parallelo, ogni writer deve avere claim esclusivi su file distinti.
  Nel body: "Scrivi solo dentro <scope>; se ti serve altro, escala."

## 6. Contesto e thinking

- `defaultContext`:
  - `fresh` → reviewer, auditor, validatori. Nessuna contaminazione dallo
    storico del parent.
  - `fork` → implementazione, quando decisioni e root-cause dello storico
    servono.
- `thinking`: `low` per recon ad alto volume; `high` per pianificazione e
  review.

## 7. Contratto di output

Un agente senza formato di output stabile è difficile da consumare. Definisci
**una** shape, meglio se JSON in un singolo blocco:

- Campi minimi: stato/verdict, sommario, evidenze (comandi + exit code),
  eventuali blocker/deviazioni.
- Non cambiare la shape tra esecuzioni.
- Se l'agente verifica qualcosa, il contratto deve chiedere **prove**
  (comando eseguito + risultato), non auto-dichiarazioni.

## 8. YAML-safety (riepilogo)

Quota sempre i valori con `: `, `#`, `{}`, `[]`, `'`, `"`, `|`, `>`. Usa
virgolette singole (con `''` per le interne) o block scalar `>-`. Vedi
`agent-schema.md` §6.

## 9. Script helper: quando servono

Aggiungi `scripts/` solo se riduce il margine di errore:

- Un passo che è **deterministico** (parsing, validazione, trasformazione).
- Un formato fragile che l'agente sbaglierebbe a mano.
- Un'operazione ripetitiva con molti dettagli.

Se la logica richiede giudizio, resta nel prompt. Dettagli in
`helper-scripts.md`.

## 10. Anti-pattern

- **Description vaga** → non viene mai selezionato.
- **Agente onnivoro** (troppe responsabilità, tool scope ampio).
- **Writer senza claim** → conflitti con agenti paralleli.
- **Read-only con `write`** → rischio sicurezza.
- **Frontmatter rotto** (`:` non quotati) → l'agente non viene caricato.
- **Body romanzo** senza contratto di output.
- **Script non documentati** nel body o non eseguibili.
- **external-cli senza `async: true`**.
- **Fork context per un reviewer** → perde l'imparzialità.

## 11. Procedura di scrittura (checklist operativa)

1. Leggi `agent-schema.md`.
2. Scrivi il frontmatter (name, description, tools, model, thinking,
   systemPromptMode, defaultContext).
3. Scrivi il body (identità → direttive → output contract → boundary).
4. Se servono script, creali e referenziali nel body.
5. Esegui `python3 scripts/validate.py <path>`.
6. Correggi i warning/errori.
7. Passa la checklist in `validation-checklist.md`.
8. Installa nel path corretto e verifica `subagent({ action: "list" })`.
