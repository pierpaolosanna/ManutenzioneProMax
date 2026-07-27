# PRIVACY - ISTRUZIONI

Questa sezione permette di disabilitare le funzionalità di telemetria e raccolta dati di Windows, Office, Edge e attività pianificate.  
**Tutte le operazioni richiedono privilegi amministrativi.**

---

## 🔒 Privacy Windows

Disabilita telemetria, suggerimenti, Cortana, ricerca web, segnalazioni errori e raccolta dati diagnostici di Windows.  
Agisce su chiavi di registro in `HKLM` e `HKCU` per:
- Telemetria (AllowTelemetry = 0)
- Cortana e ricerca web (CortanaEnabled = 0, DisableWebSearch = 1)
- Segnalazione errori (Disabled = 1)
- Esperienze su misura (TailoredExperiences = 0)
- Compatibilità e inventario app

---

## 📁 Privacy Office

Disabilita la telemetria e l'instrumentation di Microsoft Office (versione 16.0).  
Imposta a `0` le chiavi di registro relative a:
- Instrumentation
- Telemetry
- Debug
- Raccolta dati

---

## 🌐 Privacy Edge

Disabilita funzionalità di raccolta dati e personalizzazione in Microsoft Edge:
- Suggerimenti di ricerca (SearchSuggestEnabled)
- Compilazione automatica indirizzi/carte (Autofill)
- Report personalizzazione (PersonalizationReportingEnabled)
- Diagnostica URL (UrlDiagnosticDataEnabled)
- Pagine errore alternative e raccomandazioni

---

## ⏰ Privacy Task Scheduler

Disabilita le attività pianificate di Windows che raccolgono dati di telemetria e diagnostica.  
Vengono disabilitati i task relativi a:
- Application Experience (Compatibilità, Census, DiskDiagnostic)
- Customer Experience Improvement Program (CEIP)
- Windows Error Reporting (QueueReporting)
- Feedback (Siuf)
- NetTrace e SmartScreen
## 🚀 DISABILITA TUTTO (Privacy Completa)

Esegue in sequenza tutte e quattro le operazioni precedenti:
1. Privacy Windows
2. Privacy Office
3. Privacy Edge
4. Privacy Task Scheduler

Al termine, viene chiesto di **riavviare il PC** per applicare tutte le modifiche.

---

## 📌 Note Generali

- **Privilegi amministrativi** necessari. Se non sei admin, esegui prima "Eleva Admin".
- Le modifiche sono **permanenti** e influenzano il comportamento del sistema.
- Per ripristinare le impostazioni originali, è necessario modificare manualmente le chiavi di registro o ripristinare il sistema.
- Dopo l'esecuzione di "Disabilita Tutto", è consigliato **riavviare** per garantire l'applicazione di tutte le policy.

===============================================================================================
Per eseguire una funzione, clicca sul pulsante corrispondente a sinistra.
===============================================================================================