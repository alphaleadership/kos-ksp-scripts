// Script kOS - Décollage Automatique et Vol vers l'Aéroport Insulaire
GLOBAL runway_heading IS 90.     // Cap de la piste du KSC
GLOBAL takeoff_speed IS 85.       // Vitesse de rotation pour le décollage (en m/s)
GLOBAL cruise_altitude IS 2500.  // Altitude de croisière cible (en mètres)
GLOBAL target_speed IS 250.      // Vitesse de croisière cible (en m/s)
GLOBAL runmode IS 0.             // 0: Initialisation, 1: Roulage, 2: Rotation, 3: Montée & Virage, 4: Vol de croisière vers l'île

// Coordonnées de la piste de l'Island Airfield
GLOBAL target_island IS LATLNG(-1.5293, -71.8853).

// Variables globales de pilotage pour éviter le stack overflow
GLOBAL steer_cmd IS HEADING(runway_heading, 0, 0).
GLOBAL throttle_cmd IS 0.0.
LOCK STEERING TO steer_cmd.
LOCK THROTTLE TO throttle_cmd.

CLEARSCREEN.
PRINT "=== Pilote Automatique (Décollage & Destination Île) ===".
PRINT "Vitesse de rotation : " + takeoff_speed + " m/s".
PRINT "Altitude de croisière : " + cruise_altitude + " m".

UNTIL runmode = 5 {
    IF runmode = 0 {
        PRINT "Préparation au décollage..." AT (0, 2).
        SAS OFF.
        RCS OFF.
        GEAR ON.
        BRAKES ON.
        SET throttle_cmd TO 1.0.
        
        PRINT "Mise en puissance des moteurs..." AT (0, 3).
        STAGE. // Allume les moteurs via staging
        
        // Activation programmatique forcée de tous les moteurs
        LOCAL eng_list IS LIST().
        LIST ENGINES IN eng_list.
        FOR eng IN eng_list {
            eng:ACTIVATE.
        }
        WAIT 3.0.
        
        SET runmode TO 1.
        CLEARSCREEN.
    }
    
    if runmode = 1 {
        PRINT "Phase 1 : Roulage sur la piste" AT (0, 2).
        BRAKES OFF. // Relâche les freins
        
        // Alignement au sol
        SET steer_cmd TO HEADING(runway_heading, 0, 0).
        
        PRINT "Vitesse au sol : " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 1) + " m/s   " AT (0, 3).
        
        IF SHIP:VELOCITY:SURFACE:MAG >= takeoff_speed {
            SET runmode TO 2.
            CLEARSCREEN.
        }
        WAIT 0.1.
    }
    
    IF runmode = 2 {
        PRINT "Phase 2 : Rotation (Lifting off)" AT (0, 2).
        
        // Cabrer à 12 degrés
        SET steer_cmd TO HEADING(runway_heading, 12, 0).
        
        // Attendre d'avoir quitté le sol
        UNTIL SHIP:VERTICALSPEED > 5 AND ALT:RADAR > 20 {
            PRINT "Vitesse verticale : " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s   " AT (0, 3).
            WAIT 0.1.
        }
        
        SET runmode TO 3.
        CLEARSCREEN.
    }
    
    IF runmode = 3 {
        PRINT "Phase 3 : Montée & Alignement vers l'île" AT (0, 2).
        GEAR OFF. // Rentrer les trains
        
        // Virage vers la direction de l'île tout en montant (15°)
        SET steer_cmd TO HEADING(target_island:BEARING, 15, 0).
        
        UNTIL SHIP:ALTITUDE >= cruise_altitude - 200 {
            PRINT "Altitude : " + ROUND(SHIP:ALTITUDE) + " m | Cap Île : " + ROUND(target_island:BEARING) + "°   " AT (0, 3).
            // Mettre à jour la direction dynamiquement pendant la montée
            SET steer_cmd TO HEADING(target_island:BEARING, 15, 0).
            WAIT 0.5.
        }
        
        SET runmode TO 4.
        CLEARSCREEN.
    }
    
    IF runmode = 4 {
        // Calcul du tangage dynamique pour stabiliser l'altitude à 2500m
        LOCAL alt_error IS cruise_altitude - SHIP:ALTITUDE.
        LOCAL pitch_cmd IS MIN(10, MAX(-10, (alt_error / 50))).
        
        // Cap vers l'île, assiette de maintien, ailes horizontales
        SET steer_cmd TO HEADING(target_island:BEARING, pitch_cmd, 0).
        
        // Ajustement automatique de la poussée pour maintenir 250 m/s
        LOCAL speed_error IS target_speed - SHIP:VELOCITY:SURFACE:MAG.
        SET throttle_cmd TO MIN(1.0, MAX(0.1, 0.5 + (speed_error / 40))).
        
        PRINT "Phase 4 : Croisière vers l'Aéroport Insulaire" AT (0, 2).
        PRINT "Altitude : " + ROUND(SHIP:ALTITUDE) + " m (Cible : " + cruise_altitude + " m)   " AT (0, 3).
        PRINT "Distance restante : " + ROUND(target_island:DISTANCE / 1000, 1) + " km   " AT (0, 4).
        PRINT "Vitesse : " + ROUND(SHIP:VELOCITY:SURFACE:MAG) + " m/s (Cible : " + target_speed + " m/s)   " AT (0, 5).
        
        WAIT 0.2.
    }
}
