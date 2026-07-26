// Script kOS - Maintien Haute Altitude (Pilote Automatique de Croisière)
GLOBAL target_altitude IS 8000.  // Altitude de croisière haute (8000 mètres)
GLOBAL target_heading IS 90.     // Cap de maintien (Plein Est)
GLOBAL target_speed IS 250.      // Vitesse cible (en m/s)

CLEARSCREEN.
PRINT "=== Mode Maintien Haute Altitude Initialisé ===".
PRINT "Altitude cible : " + target_altitude + " m".
PRINT "Cap cible : " + target_heading + "°".
PRINT "Vitesse cible : " + target_speed + " m/s".

RCS OFF.
SAS OFF.


UNTIL FALSE {
    // Calcul de l'assiette (tangage) dynamique en fonction de l'écart d'altitude
    LOCAL alt_error IS target_altitude - SHIP:ALTITUDE.
    // Plus l'écart est grand, plus le taux de montée/descente est prononcé (limité à +/- 15 degrés)
    LOCAL pitch_cmd IS MIN(15, MAX(-15, (alt_error / 80))).
    
    // Verrouillage de l'assiette avec roulis nul (ailes horizontales)
    LOCK STEERING TO HEADING(target_heading, pitch_cmd, 0).
    
    // Ajustement automatique de la poussée pour conserver la vitesse cible
    LOCAL speed_error IS target_speed - SHIP:VELOCITY:SURFACE:MAG.
    LOCK THROTTLE TO MIN(1.0, MAX(0.05, 0.5 + (speed_error / 40))).
    
    PRINT "Altitude : " + ROUND(SHIP:ALTITUDE) + " m (Cible : " + target_altitude + " m)   " AT (0, 4).
    PRINT "Tangage commandé : " + ROUND(pitch_cmd, 1) + "°   " AT (0, 5).
    PRINT "Vitesse : " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + " m/s (Cible : " + target_speed + " m/s)   " AT (0, 6).
    
    WAIT 0.1.
}
