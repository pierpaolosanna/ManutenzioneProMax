# BACKUP - ISTRUZIONI
Questa sezione permette di creare backup compressi di cartelle e file, escludendo automaticamente tutte le cartelle e i file che iniziano con "backup" (utile per evitare backup ricorsivi).
## 💾 Backup Files
Backup standard basato su `Compress-Archive` di PowerShell.
**Procedura:**
1. Seleziona la **cartella origine** (quella da salvare)
2. Seleziona la **cartella destinazione** (dove salvare il file .zip)
3. Conferma l'avvio
**Caratteristiche:**
- Compressione: **Optimal** (bilanciata tra dimensione e tempo)
- Esclusione automatica: esclude cartelle/file con nome che inizia con `backup*`
- Report finale: dimensione originale, dimensione compressa, rapporto di compressione, tempo impiegato
- Al termine: chiede se aprire la cartella di destinazione
**Quando usarlo:** Backup di cartelle di dimensioni medie (fino a qualche GB) o quando si preferisce la semplicità.
## 📦 Backup Avanzato (7-Zip)
Backup con **massima compressione** utilizzando 7-Zip (se disponibile).
**Prerequisito:** 7-Zip deve essere installato nel sistema o presente come `7za.exe` nella cartella `lib\` dello script.
**Installazione automatica:** Se 7-Zip non è trovato e lo script è eseguito come amministratore, tenta l'installazione tramite `winget install 7zip.7zip`.
**Procedura:**
1. Seleziona la **cartella origine** (quella da salvare)
2. Seleziona la **cartella destinazione** (dove salvare il file .zip)
3. Conferma l'avvio
**Caratteristiche:**
- Compressione: **massima (mx=9)** – riduce notevolmente le dimensioni ma richiede più tempo
- Multithreading: abilitato (`-mmt=on`) per sfruttare più core CPU
- Esclusione automatica: esclude cartelle/file con nome che inizia con `backup*`
- Report finale: dimensione originale, dimensione compressa, rapporto di compressione, tempo impiegato
- Al termine: chiede se aprire la cartella di destinazione
**Quando usarlo:** Backup di grandi dimensioni (diversi GB), quando si vuole risparmiare spazio su disco o si ha tempo a disposizione.
## ⚠️ Differenze tra i due metodi
| Caratteristica | Backup Files | Backup Avanzato |
|----------------|--------------|-----------------|
| Strumento | Compress-Archive (PowerShell) | 7-Zip |
| Compressione | Optimal | Massima (mx=9) |
| Velocità | Veloce | Più lenta |
| Dimensione file | Buona | Eccellente |
| Multithreading | No | Sì |
| Dipendenze | Nessuna | 7-Zip richiesto |
## 📌 Note Generali
- **L'esclusione "backup\*"** è automatica in entrambi i metodi per evitare di includere backup precedenti all'interno del nuovo backup.
- Se nella cartella origine sono presenti cartelle o file che iniziano con `backup`, vengono saltati automaticamente.
- Per cartelle con molti file piccoli, il backup avanzato potrebbe risultare molto più efficiente.
- Il backup standard è consigliato per backup rapidi di cartelle di dimensioni contenute.
