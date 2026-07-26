// Script kOS de Boot - Automatisation de la séquence de vol Ghidorah Heavy (Falcon Heavy)
// Ce script doit être assigné comme script de boot sur les kOS CPU dans le VAB.

WAIT UNTIL SHIP:UNPACKED.
CLEARSCREEN.
PRINT "================================================".
PRINT "      kOS BOOT SYSTEM - GHIDORAH HEAVY          ".
PRINT "================================================".
PRINT "CPU Tag détecté : " + CORE:TAG.

// 1. Cas du Booster Latéral (Tag: "booster")
IF CORE:TAG = "booster" {
    PRINT "Booster configuré. Attente de la séparation...".
    
    // Attendre que le booster se détache du vaisseau principal (changement de vaisseau kOS)
    LOCAL parent_vessel IS SHIP.
    WAIT UNTIL SHIP != parent_vessel.
    
    PRINT "--- SÉPARATION DÉTECTÉE ---".
    PRINT "Lancement du script de retour RTLS...".
    
    // Lancer le script RTLS
    RUNPATH("0:/rtls.ks").
} 
// 2. Cas du Core Central ou de la Capsule (Tag: "core" ou vide)
ELSE {
    PRINT "Vaisseau principal configuré.".
    PRINT "Lancement du script de mise en orbite...".
    
    // Lancer le script de mise en orbite standard
    RUNPATH("0:/launch_orbit.ks").
}
