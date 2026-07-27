# SICUREZZA - ISTRUZIONI
Questa sezione fornisce strumenti per la sicurezza del sistema: scansione antivirus, analisi eventi e health check generale.
## 🛡️ Scan Defender
Avvia una **scansione rapida** con Windows Defender tramite `MpCmdRun.exe -Scan -ScanType 1`.  
Cerca automaticamente l’eseguibile di Defender nelle posizioni standard.  
Mostra l’avanzamento e l’esito della scansione.
## 📋 Event Log
Visualizza gli ultimi **10 errori critici** del registro eventi di sistema (**System**) degli ultimi 7 giorni.  
Ogni evento mostra data/ora e il messaggio troncato.  
Se non ci sono errori, viene segnalato `[OK] Nessun errore critico`.
## 🏥 Health Check
Esegue un controllo completo dello stato del sistema:
- **SFC /verifyonly** – verifica l’integrità dei file di sistema (senza riparare)
- **DISM /Online /Cleanup-Image /CheckHealth** – controlla lo stato dell’immagine di sistema
- **Eventi critici recenti** – conta errori critici degli ultimi 7 giorni
- **Memoria disponibile** – calcola la percentuale di RAM libera
Al termine mostra un riepilogo con lo stato di ogni test.
## 📌 Note Generali
- **Scan Defender** non richiede privilegi amministrativi, ma per alcune operazioni potrebbe essere necessario.
- **Event Log** e **Health Check** leggono informazioni senza modificare il sistema.
- Se **Health Check** segnala problemi, esegui **"SFC + DISM"** dalla sezione **Riparazione** per risolverli.
===============================================================================================
Per eseguire una funzione, clicca sul pulsante corrispondente a sinistra.
===============================================================================================