# Guide des Commandes et Contrôles - Pilote Automatique Avion (kOS)

Ce guide récapitule le fonctionnement et les touches de contrôle du script de démarrage [boot_airplane.ks](file:///C:/Users/alpha/kos/boot_airplane.ks) qui gère le décollage automatique et le système de vol stabilisé **Fly-By-Wire (FBW)**.

---

## 1. Phase de Décollage (Automatique)
Dès le lancement du script :
* **Mise en poussée** : Les gaz sont verrouillés à 100% et les freins sont serrés pendant 1 seconde pour stabiliser l'avion.
* **Roulage** : Les freins sont relâchés. Durant le roulage initial (jusqu'à 25 m/s), la direction reste libre et stabilisée par le SAS de KSP pour éviter tout dérapage.
* **Guidage au sol** : Au-delà de 25 m/s, le cap est verrouillé sur l'axe de la piste (Cap 90° Est).
* **Rotation et Envol** : À 80 m/s, l'avion cabre à 12° de tangage. Une fois en vol (Altitude Radar > 20m), le train d'atterrissage est rentré et le système **Fly-By-Wire** s'active.

---

## 2. Commandes de Vol FBW (Vol Manuel Assisté)
Le Fly-By-Wire maintient l'avion stable dans son attitude (Tangage, Roulis, Cap) dès que vous relâchez les commandes.

| Commande | Touches (AZERTY) | Touches (QWERTY) | Description |
| :--- | :--- | :--- | :--- |
| **Tangage** (Pitch) | **`Z` / `S`** | **`W` / `S`** | Modifie l'assiette verticale cible de l'avion (limites : -15° à +25°). |
| **Roulis** (Roll) | **`Q` / `D`** | **`A` / `D`** | Modifie l'angle d'inclinaison des ailes (limite : ±45°). Se remet à plat si l'angle est < 5°. |
| **Lacet** (Yaw) | **`A` / `E`** | **`Q` / `E`** | Ajuste manuellement le cap compas cible de l'avion. |
| **Gaz** (Throttle) | **`Maj` / `Ctrl`** | **`Maj` / `Ctrl`** | Contrôle manuel classique des moteurs (KSP d'origine). |

---

## 3. Pilotes Automatiques (Maintien d'Altitude & Navigation)
Ces fonctions s'activent via les touches de translation RCS de KSP.

| Fonction | Touches | Description |
| :--- | :--- | :--- |
| **Maintien d'Altitude** (Alt Hold) | **`I`** (Monter) / **`K`** (Descendre) | Active le maintien d'altitude et l'ajuste par paliers de 150 mètres. *Désactivation (Override) : Touchez aux commandes de Tangage (`Z` / `S`).* |
| **Navigation vers l'Île** (Island Nav) | **`J`** / **`L`** | Active/désactive le guidage automatique vers l'aérodrome insulaire (Island Airfield). *Désactivation (Override) : Touchez aux commandes de Lacet (`A` / `E`).* |

---

## 4. Systèmes de Sécurité Embarqués
* **Sécurité Post-Décollage** : Les gaz sont verrouillés à 100% en dessous de 150m d'altitude pour empêcher une coupure accidentelle des moteurs si votre manette physique est à 0.
* **Sécurité GPWS (Anti-collision sol)** : Si l'avion descend **sous les 200m d'altitude** avec les freins desserrés, le système prend le contrôle d'urgence : cabrage forcé à 18°, remise à plat des ailes, et gaz poussés à 100%. Le contrôle vous est rendu dès que l'avion repasse au-dessus de 200m ou si vous sortez les freins (`B`) pour atterrir.
