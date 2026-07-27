# RIPARAZIONE - ISTRUZIONI
Questa sezione fornisce strumenti per ripristinare e riparare il sistema operativo.
## ⏱️ Crea Punto di Ripristino
Crea un punto di ripristino del sistema con descrizione `PRO MAX DD/MM HH:mm`.  
**Richiede privilegi amministrativi.**  
L'operazione:
- Abilita il ripristino sull'unità di sistema (se non già attivo)
- Aggira temporaneamente il limite di 24 ore tra un punto e l'altro
- Crea il punto di ripristino
**Importante:** Esegui sempre questa operazione prima di qualsiasi modifica importante del sistema.
## 🔨 Riparazione Sistema (SFC + DISM)
Esegue in sequenza:
1. **SFC /scannow** – controlla e ripara i file di sistema protetti
2. **DISM /Online /Cleanup-Image /RestoreHealth** – ripara l'immagine di sistema (Windows Update)
**Richiede privilegi amministrativi.**  
L'operazione può richiedere diversi minuti; la barra di avanzamento indica lo stato.  
Al termine, viene mostrato l'esito di entrambi i comandi.
## 📌 Note Generali
- Entrambe le funzioni richiedono **privilegi amministrativi**. Se non sei admin, esegui prima "Eleva Admin".
- **Crea Ripristino** è consigliato prima di eseguire qualsiasi modifica o riparazione.
- Se **DISM** fallisce, assicurati di avere una connessione Internet attiva (per il download dei file di riparazione).
- Dopo SFC e DISM, è consigliato **riavviare** il PC.
