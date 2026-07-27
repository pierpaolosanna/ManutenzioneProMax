# PULIZIA - ISTRUZIONI

Questa sezione raccoglie strumenti per liberare spazio su disco, rimuovere file temporanei, log e dump, e analizzare l'occupazione delle unità.

---

## 🧹 Pulizia Temp

Rimuove i file temporanei dalle seguenti cartelle:

- `%TEMP%` (utente corrente)
- `%LOCALAPPDATA%\Temp`
- Cache Internet Explorer (`INetCache`)
- Cartella CrashDumps
- Se eseguito come amministratore, pulisce anche `C:\Windows\Temp`

Mostra il numero di file eliminati e lo spazio liberato in MB.

---

## 💾 Disk Cleanup

Avvia lo strumento **Pulizia disco** di Windows (`cleanmgr`) con le opzioni predefinite.  
L'operazione:

- Imposta i flag per pulire tutte le categorie (file temporanei, cestino, thumbnails, ecc.)
- Esegue `cleanmgr /sagerun:100` in modalità automatica

**Richiede privilegi amministrativi.**

---

## 📝 Pulisci Log

Rimuove file di log e dump di sistema da:

- `C:\Windows\Logs\*`
- `C:\Windows\System32\LogFiles\*`
- `C:\ProgramData\Microsoft\Windows\WER\*` (segnalazioni errori)

Viene mostrato lo spazio totale liberato in MB.

---

## 📊 Analisi Disco

Fornisce un'analisi dettagliata dello spazio su tutte le unità (dischi fissi):

- Per ogni unità: spazio usato / totale (GB) e percentuale di occupazione
- Segnala se lo spazio è critico (>85%)
- Mostra totale e spazio libero complessivo
- Se lo spazio libero è inferiore al 20%, suggerisce:
  - Eseguire “Pulizia Temp” e “Disk Cleanup”
  - Verificare la cartella `Downloads` (ne indica la dimensione)
  - Usare “Spazio Disco” (Diagnostica) per individuare cartelle grandi

---

## 📌 Note Generali

- **Disk Cleanup** richiede privilegi amministrativi; le altre funzioni funzionano anche senza, ma potrebbero avere accesso limitato ad alcune cartelle.
- Le operazioni di pulizia sono **sicure** e non rimuovono file di sistema critici.
- Per una pulizia più approfondita, esegui prima "Eleva Admin" e poi usa "Disk Cleanup".

===============================================================================================
Per eseguire una funzione, clicca sul pulsante corrispondente a sinistra.
===============================================================================================