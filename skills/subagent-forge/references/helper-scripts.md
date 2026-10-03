# Helper scripts — quando e come aggiungerli

Gli script per-agente vivono accanto ad `agent.md`:

```
.pi/agents/<nome>/
├── agent.md
└── scripts/
    ├── check.py
    └── run.sh
```

Servono a **ridurre il margine di errore**: spostano i passi deterministici e
fragili fuori dal prompt, dove il modello può sbagliarli, dentro codice
verificabile. Non servono a sostituire il giudizio dell'agente.

## 1. Quando uno script guadagna il suo posto

Aggiungi uno script **solo se** ricorre almeno una di queste condizioni:

- **Deterministico** — la stessa trasformazione/validazione deve avvenire sempre
  allo stesso modo (parsing, normalizzazione, diff, checksum).
- **Fragile** — un formato o una sintassi che il modello sbaglierebbe a mano
  (YAML/JSON rigoroso, encoding, date, regex complesse).
- **Ripetitivo** — molti dettagli meccanici che è costoso ripetere nel prompt.
- **Verificabile** — l'output è un esito booleano/exit code che l'agente può
  controllare e riportare come evidenza.

**Non** aggiungere script per:

- Logica che richiede giudizio o contesto (resta nel prompt).
- Un singolo comando già gestibile con `bash`.
- Wrapper che non fanno altro che richiamare un tool esistente.

Nel dubbio, preferisci il prompt: meno parti mobili, meno modi di fallire.
Ma se il passò è meccanico e ripetuto, lo script è la scelta giusta.

## 2. Regole di scrittura

- **Linguaggio**: `bash` per orchestrazione e comandi; `python3` per parsing,
  validazione e I/O strutturato. Coerente col tooling della skill.
- **Shebang** esplicito: `#!/usr/bin/env bash` o `#!/usr/bin/env python3`.
- **Eseguibile**: `chmod +x scripts/<file>`.
- **Path**: i file di supporto si risolvono dalla **directory dell'agente**, non
  da `cwd`. In bash:

  ```bash
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  AGENT_DIR="$(dirname -- "$SCRIPT_DIR")"
  ```

  In Python: `Path(__file__).resolve().parent`.
- **Exit code significativi**: `0` = successo, non-zero = fallimento. L'agente
  usa l'exit code come evidenza.
- **Output machine-readable**: JSON su stdout (o un blocco JSON chiaro) così
  l'agente può citarlo nel suo output contract. Diagnostica su stderr.
- **Idempotenza**: rieseguibile senza effetti collaterali indesiderati.
- **Niente dipendenze implicite**: se serve PyYAML o un binario, dichiaralo nel
  body dell'agente e degrada con un messaggio chiaro se manca.

## 3. Sicurezza degli script

Uno script per-agente eredita i boundary dell'agente. Valgono le stesse regole:

- **Nessuna scrittura fuori dallo scope**: né file né stato globale.
- **Niente rete** se non esplicitamente richiesto dal compito.
- **Niente comandi distruttivi** (`rm -rf`, drop, force push).
- **Niente `git commit`/`push`/`stash`/`checkout <ref>`**.
- **Niente install di pacchetti**.
- **Read-only per default**: se uno script serve un agente read-only, deve
  limitarsi a leggere/verificare.
- **Input non fidato**: valida gli argomenti; non `eval`-are input dell'utente.

Se un'operazione rischiosa è davvero necessaria, mettila dietro un flag
esplicito e richiedi conferma nel body dell'agente.

## 4. Come l'agente referenzia gli script

Nel body, indica il percorso relativo e il momento d'uso:

```markdown
### Operational Directives
1. Per validare il report, esegui:
   `python3 scripts/check_report.py <file>`
   Considera il report valido solo con exit code 0.

### Output Contract
Riporta in `evidence` il comando eseguito e l'exit code restituito.
```

Il validatore controlla che ogni `scripts/<file>` citato nel body **esista** e
sia **eseguibile**.

## 5. Template

La skill fornisce due stub già conformi:

- `assets/helper-script.sh.tmpl`
- `assets/helper-script.py.tmpl`

Sostituisci i placeholder (`__DESCRIPTION__`, logica) e adatta gli exit code.
Lo scaffold con `scripts/init.sh --with-script sh|py` li copia già nel posto
giusto.

## 6. Esempio: validatore JSON con exit code

`scripts/check_report.py`:

```python
#!/usr/bin/env python3
"""Valida un report JSON: exit 0 se conforme, 1 altrimenti."""
import json
import sys
from pathlib import Path

REQUIRED = {"status", "summary", "evidence"}

def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_report.py <report.json>", file=sys.stderr)
        return 2
    data = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    missing = REQUIRED - data.keys()
    if missing:
        print(json.dumps({"ok": False, "missing": sorted(missing)}))
        return 1
    print(json.dumps({"ok": True, "status": data["status"]}))
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
```

L'agente lo invoca, legge l'exit code e riporta `{"command": ..., "exit_code": ...}`
nel proprio output contract.

## 7. Checklist script

- [ ] Esiste la condizione (§1) che lo giustifica.
- [ ] Shebang + `chmod +x`.
- [ ] Path risolti dalla directory dell'agente.
- [ ] Exit code significativi.
- [ ] Output JSON/machine-readable su stdout.
- [ ] Nessuna scrittura fuori scope, niente rete, niente comandi distruttivi.
- [ ] Referenziato nel body dell'agente.
- [ ] Passa `validate.py` (esistenza + eseguibilità).
