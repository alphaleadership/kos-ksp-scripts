// boot.ks - Script de démarrage partagé
// À utiliser comme "Boot File" sur CHAQUE CPU kOS de la fusée (coeur principal ET
// coeur(s) des boosters). Il détecte sur quel CPU il tourne via CORE:TAG et lance
// le bon programme automatiquement au décollage.
//
// MISE EN PLACE (une seule fois par CPU, dans le VAB/SPH) :
//   1. Place ce fichier "boot.ks", "mise_en_orbite_ameliore.ks" et "rtls_ameliore.ks"
//      sur le volume d'archive (0:/) ou copie-les localement sur chaque CPU.
//   2. Clique-droit sur chaque part CPU kOS -> champ "Tag" -> écris :
//        - "MAIN"    pour le CPU du corps principal / second étage
//        - "BOOSTER" pour le(s) CPU du/des booster(s) largable(s)
//   3. Toujours dans le clic-droit de la part CPU, choisis boot.ks comme "Boot File".
//
// Chaque CPU exécute ce même fichier au lancement, mais bifurque vers un
// programme différent selon son tag.

CLEARSCREEN.
PRINT "=== Boot séquence kOS ===".
PRINT "CPU Tag détecté : " + CORE:TAG.

IF CORE:TAG = "MAIN" {
    PRINT "-> Lancement du programme de mise en orbite (coeur principal).".
    WAIT 1.
    RUN mise_en_orbite_ameliore.
} ELSE IF CORE:TAG = "BOOSTER" {
    PRINT "-> Lancement du programme RTLS (coeur booster).".
    WAIT 1.
    RUN rtls_ameliore.
} ELSE {
    // Sécurité : si le tag n'a pas été configuré, on ne lance rien automatiquement
    // pour éviter qu'un booster n'exécute par erreur le programme de mise en orbite
    // (ou inversement).
    PRINT "ERREUR : CORE:TAG non reconnu ('" + CORE:TAG + "').".
    PRINT "Configure le tag de cette part CPU à 'MAIN' ou 'BOOSTER' dans le VAB/SPH.".
    PRINT "Aucun programme n'a été lancé automatiquement.".
}
