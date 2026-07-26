// Script kOS - Atterrissage Automatique d'Avion (Approche Finale et Toucher)
// Coordonnées du seuil de la piste 09 du KSC (Extrémité Ouest de la piste, entrée face à l'Est)
GLOBAL runway_threshold IS LATLNG(-0.0486, -74.7264). 
GLOBAL runway_heading IS 90.     // Orientation de la piste (Plein Est)
GLOBAL target_speed IS 75.       // Vitesse d'approche cible (en m/s)
GLOBAL glide_angle IS 3.         // Pente d'approche standard (3 degrés)
GLOBAL runmode IS 0.             // 0: Alignement/Approche, 1: Toucher des roues (Touchdown), 2: Freinage et arrêt

CLEARSCREEN.
PRINT "=== Pilote d'Atterrissage Automatique Initialisé ===".
PRINT "Piste cible : KSC Runway 09".

// Calcul de la distance horizontale par rapport au seuil de piste
DECLARE FUNCTION get_horizontal_dist {
    LOCAL threshold_pos IS runway_threshold:POSITION.
    SET threshold_pos:Y TO 0. // Ignore l'altitude pour la distance horizontale
    RETURN threshold_pos:MAG.
}

UNTIL runmode = 2 {
    LOCAL dist IS get_horizontal_dist().
    
    IF runmode = 0 {
        PRINT "Phase 0 : Alignement et Descente" AT (0, 2).
        GEAR ON. // Déployer le train d'atterrissage
        
        // Calcul de l'altitude théorique de descente (pente de 3 degrés)
        // Altitude = Distance * tan(glide_angle) + altitude piste (~74m)
        LOCAL target_alt IS (dist * TAN(glide_angle)) + 74.
        
        // Ajuster l'assiette (pitch) pour suivre la pente
        LOCAL alt_error IS target_alt - SHIP:ALTITUDE.
        LOCAL pitch_cmd IS MIN(10, MAX(-15, (alt_error / 50))). // Limite le tangage de -15 à 10 degrés
        
        // Assurer l'alignement sur le cap de piste (90 degrés) avec correction latérale légère
        // Si on dévie à gauche/droite, on applique un léger correctif de cap
        LOCAL lateral_error IS runway_threshold:BEARING. // Déviation angulaire vers la piste
        LOCAL heading_cmd IS runway_heading + (lateral_error * 2).
        
        LOCK STEERING TO HEADING(heading_cmd, pitch_cmd, 0).
        
        // Contrôle de la vitesse par la poussée (viser 75 m/s)
        LOCAL speed_error IS target_speed - SHIP:VELOCITY:SURFACE:MAG.
        LOCK THROTTLE TO MIN(1.0, MAX(0.0, 0.4 + (speed_error / 20))).
        
        PRINT "Distance Piste : " + ROUND(dist) + " m   " AT (0, 3).
        PRINT "Alt Cible : " + ROUND(target_alt) + " m | Alt Réelle : " + ROUND(SHIP:ALTITUDE) + " m   " AT (0, 4).
        PRINT "Vitesse : " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 1) + " m/s   " AT (0, 5).
        
        // Transition vers la phase de Toucher (Arrondi/Flare) sous 25m au-dessus du sol
        IF ALT:RADAR < 25 AND dist < 1000 {
            SET runmode TO 1.
            CLEARSCREEN.
        }
        WAIT 0.05.
    }
    
    IF runmode = 1 {
        PRINT "Phase 1 : Arrondi et Touchdown" AT (0, 2).
        
        // Arrondi : On coupe les gaz et on redresse légèrement le nez (pitch de 3 degrés), ailes horizontales (roll = 0)
        LOCK THROTTLE TO 0.0.
        LOCK STEERING TO HEADING(runway_heading, 3, 0).
        
        PRINT "Arrondi en cours... Vitesse verticale : " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s   " AT (0, 3).
        
        // Attente du contact des roues avec le sol
        UNTIL SHIP:STATUS = "LANDED" OR ALT:RADAR < 2 {
            WAIT 0.05.
        }
        
        SET runmode TO 2.
        CLEARSCREEN.
    }
}

// Phase 2 : Freinage et arrêt au sol
PRINT "Phase 2 : Freinage maximal et stabilisation" AT (0, 2).
LOCK THROTTLE TO 0.0.
BRAKES ON. // Activation de tous les freins de roue
RCS OFF.
 
// Garder le nez de l'appareil pointé droit sur la piste pendant la décélération, ailes horizontales
LOCK STEERING TO HEADING(runway_heading, 0, 0).

UNTIL SHIP:VELOCITY:SURFACE:MAG < 0.2 {
    PRINT "Vitesse d'arrêt : " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 1) + " m/s   " AT (0, 3).
    WAIT 0.1.
}

UNLOCK STEERING.
BRAKES ON.
PRINT "Arrêt complet de l'appareil. Atterrissage réussi !".
