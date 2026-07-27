# SISTEMA - ISTRUZIONI
Questa sezione fornisce strumenti per ottimizzare le prestazioni del sistema, modificare effetti visivi, servizi di avvio e rimuovere limitazioni hardware per Windows 11.
## 🎨 Ottimizza Effetti Visivi
Configura gli effetti visivi di Windows per bilanciare prestazioni e aspetto:
- **Modalità effetti visivi**: Personalizzata
- **Disabilita**: animazioni finestre, trasparenze, trascinamento contenuto finestre
- **Abilita**: Aero Peek, ombreggiatura finestre, ClearType, scorrimento uniforme, ombre etichette icone
**Non richiede privilegi amministrativi.**  
Al termine, **Explorer viene riavviato** per applicare le modifiche.
## ⚡ Ottimizza Avvio
Ottimizza i servizi di sistema per un avvio più rapido:
- **Abilita Avvio Veloce** nel piano energetico attivo
- Imposta i servizi di sistema:
  - `SysMain` (SuperFetch) → Automatico
  - `MapsBroker` → Disabilitato
  - `RetailDemo` → Disabilitato
  - Servizi Xbox → Manuali
**Richiede privilegi amministrativi.**
## 🔓 CPU Unlock
Sblocca le opzioni avanzate della CPU nei piani energetici di Windows.  
Rende visibili e modificabili le impostazioni di gestione energetica del processore (es. frequenza minima/massima, boosting, ecc.).  
Agisce su 14 sottopzioni del piano energetico.
**Richiede privilegi amministrativi.**
## 🖥️ Sblocco TPM/CPU/RAM per Windows 11
Rimuove le limitazioni hardware per l'upgrade a Windows 11:
- **Pulisce** chiavi di compatibilità che segnalano hardware non supportato
- **Imposta** valori falsi per SecureBoot, TPM (versione 2) e RAM minima (8 GB)
- **Abilita** policy `AllowUpgradesWithUnsupportedTPMOrCPU`
- **Imposta** flag `UpgradeEligibility` per l'utente corrente
**Non richiede privilegi amministrativi.**  
Al termine, è possibile avviare l'upgrade a Windows 11 tramite Assistente o setup.exe.  
**Nessun riavvio necessario.**
## 📌 Note Generali
- **Ottimizza Avvio** e **CPU Unlock** richiedono privilegi amministrativi.
- **Ottimizza Effetti Visivi** non richiede admin, ma riavvia Explorer.
- **Sblocco TPM/CPU/RAM** è utile solo se il PC non soddisfa i requisiti minimi per Windows 11.
- Dopo **Ottimizza Avvio**, è consigliato riavviare per applicare le modifiche ai servizi.
