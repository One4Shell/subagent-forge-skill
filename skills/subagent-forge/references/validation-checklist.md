# Validation checklist

Checklist manuale da passare **dopo** `scripts/validate.py`. Copre ciò che un
linter non può giudicare: qualità del routing, coerenza del ruolo, sicurezza
delle boundary.

## 1. Frontmatter

- [ ] `name` conforme (`[a-z0-9-]`, ≤64, no `-` iniziale/finale/doppio) e
      **uguale** al nome della cartella.
- [ ] `description` ≤1024, specifica: dice cosa fa **e** quando usarlo.
- [ ] `description` contiene le parole chiave con cui l'utente descriverebbe il
      compito (sinonimi inclusi).
- [ ] `tools` è un'allowlist minima e coerente col ruolo.
- [ ] `thinking` è uno tra `low`/`medium`/`high`.
- [ ] `systemPromptMode` è `replace` o `append`.
- [ ] `defaultContext` è `fresh` o `fork` ed è appropriato al ruolo.
- [ ] Nessun valore YAML non quotato con `: `, `#`, `{`, `[`, `'`, `"`, `|`.
- [ ] Se `runner.type: external-cli` → `async: true` presente.

## 2. Discovery e layout

- [ ] File nel path di discovery corretto:
      `.pi/agents/<nome>/agent.md` (progetto) o
      `~/.pi/agent/agents/<nome>/agent.md` (utente).
- [ ] Nessuna collisione di `name` con un agente esistente dello stesso scope
      (progetto > utente > builtin).
- [ ] `scripts/` esiste solo se ci sono script, e ogni script è referenziato nel
      body.
- [ ] Eventuali file di supporto (`references/`, `assets/`) sono citati nel body.

## 3. System prompt

- [ ] Riga di identità chiara: ``Sei `<nome>`: <ruolo>.``
- [ ] Direttive imperative e numerate, non prosa.
- [ ] Contratto di output definito, con shape stabile (idealmente un solo blocco
      ```json```).
- [ ] Il contratto chiede **evidenze** (comandi + exit code), non
      auto-dichiarazioni.
- [ ] Boundary esplicite: cosa non può fare.
- [ ] Regole di escalation chiare (quando fermarsi e riportare un blocker).
- [ ] Nessuna scrittura possibile per gli agenti read-only.
- [ ] Gli agenti writer dichiarano la superficie di scrittura (claim).

## 4. Sicurezza

- [ ] Read-only: nessun `edit`/`write` nei `tools`, nessuna istruzione di
      scrittura nel body.
- [ ] Writer: nessun `git commit/push/stash/checkout <ref>`, nessun comando
      distruttivo, nessun install di pacchetti se non richiesto dal task.
- [ ] `subagent` concesso solo se serve fanout autorizzato.
- [ ] Gli script helper non scrivono fuori scope e non accedono alla rete.
- [ ] Input non fidato validato (niente `eval`).

## 5. Script helper

- [ ] Esiste una delle condizioni che giustifica lo script (determinismo,
      fragilità, ripetizione, verificabilità).
- [ ] Shebang presente; file eseguibile (`chmod +x`).
- [ ] Path risolti dalla directory dell'agente, non da `cwd`.
- [ ] Exit code significativi; output JSON/machine-readable su stdout.
- [ ] Idempotente e senza effetti collaterali indesiderati.
- [ ] Referenziato nel body con il percorso relativo `scripts/<file>`.

## 6. Prove finali

- [ ] `python3 scripts/validate.py <path>` esce 0 senza errori.
- [ ] `subagent({ action: "list" })` mostra l'agente col `name` dichiarato.
- [ ] (Se applicabile) prova di selezione: una richiesta in linguaggio naturale
      che dovrebbe attivare l'agente lo attiva davvero.
- [ ] (Se applicabile) una prova di esecuzione produce l'output nella shape
      attesa.

## 7. Criterio di "done"

L'agente è pronto quando:

1. Il validatore automatico esce 0.
2. Tutte le caselle §1–§6 sono spuntate.
3. È installato nel path di discovery corretto ed è visibile al parent.

Se un punto della checklist non si può soddisfare, non dichiarare l'agente
pronto: riporta il blocker e chiedi la decisione all'utente.
