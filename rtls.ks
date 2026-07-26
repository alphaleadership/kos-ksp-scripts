// Script kOS - RTLS Automatique du Premier Étage avec Séparation et Aérofrains
GLOBAL target_geo IS SHIP:GEOPOSITION.
GLOBAL runmode IS 0. // 0: Montée & Attente niveau carburant bas, 1: Boostback, 2: Rentrée & Guidage Aérodynamique, 3: Landing Burn, 4: Posé

// Paramètres par défaut de secours
GLOBAL FUEL_THRESHOLD IS 150. 
GLOBAL GLIDE_ANGLE IS 20.     // Angle d'attaque pour le guidage dans l'atmosphère

// Fonction pour estimer le seuil de carburant dynamique nécessaire pour le RTLS
DECLARE FUNCTION calculate_fuel_threshold {
    // Lister les moteurs actifs pour obtenir la poussée maximale et l'Isp moyenne
    LOCAL eng_list IS LIST().
    LIST ENGINES IN eng_list.
    LOCAL total_isp IS 0.
    LOCAL active_count IS 0.
    FOR eng IN eng_list {
        IF eng:IGNITION {
            SET total_isp TO total_isp + eng:ISP.
            SET active_count TO active_count + 1.
        }
    }
    
    // Si aucun moteur n'est actif ou si l'ISP cumulée est nulle, on garde la valeur de secours
    IF active_count = 0 OR total_isp = 0 {
        RETURN FUEL_THRESHOLD.
    }
    
    LOCAL avg_isp IS total_isp / active_count.
    // Consommation en unités de LiquidFuel par seconde à poussée maximale :
    // Flow (t/s) = MaxThrust (kN) / (Isp * g0)
    // En KSP, la densité du LiquidFuel et de l'Oxidizer combinés est d'environ 0.005 t/unité.
    LOCAL fuel_flow_rate IS SHIP:MAXTHRUST / (avg_isp * 9.81 * 0.005).
    
    // On estime avoir besoin de :
    // - Environ 12 secondes de poussée pour le Boostback
    // - Environ 8 secondes de poussée pour le Landing Burn
    // Total = 20 secondes de marge moteur à 100% de poussée
    LOCAL margin_seconds IS 20.
    
    LOCAL calculated_threshold IS fuel_flow_rate * margin_seconds.
    RETURN MAX(100, calculated_threshold). // Minimum de sécurité de 100 unités
}

CLEARSCREEN.
PRINT "=== RTLS Script Initialisé ===".
PRINT "Cible KSC enregistrée : Lat " + ROUND(target_geo:LAT, 4) + " | Lon " + ROUND(target_geo:LNG, 4).

// Calcul dynamique du seuil de carburant
SET FUEL_THRESHOLD TO calculate_fuel_threshold().
PRINT "Seuil de carburant RTLS calculé automatiquement : " + ROUND(FUEL_THRESHOLD, 1) + " units".

// Fonction pour déployer/rétracter les aérofrains
DECLARE FUNCTION set_airbrakes {
    DECLARE PARAMETER deploy_state. // true (déployer) ou false (rétracter)
    IF deploy_state {
        BRAKES ON.
    } ELSE {
        BRAKES OFF.
    }
}

// Boucle principale
UNTIL runmode = 4 {
    IF runmode = 0 {
        PRINT "Phase 0 : Surveillance du carburant pour séparation..." AT (0, 2).
        PRINT "LiquidFuel restant dans l'étage : " + ROUND(STAGE:LIQUIDFUEL, 1) + " units   " AT (0, 3).
        
        // Si le carburant descend sous le seuil, on sépare
        IF STAGE:LIQUIDFUEL < FUEL_THRESHOLD {
            PRINT "Carburant bas détecté ! Séparation..." AT (0, 5).
            STAGE. // Déclenche le découplage
            WAIT 1.5. // Attente de sécurité pour s'éloigner du second étage
            SET runmode TO 1.
            CLEARSCREEN.
        }
    }
    
    IF runmode = 1 {
        PRINT "Phase 1 : Boostback Burn" AT (0, 2).
        
        // Calcul de la direction du KSC
        RCS ON. // Active le RCS pour aider à la réorientation rapide dans le vide/haute atmosphère
        LOCK STEERING TO HEADING(target_geo:BEARING, 20).
        WAIT 4. // Laisse le temps au booster de pivoter vers le KSC
        
        LOCK THROTTLE TO 1.0.
        
        // On pousse jusqu'à ce que la vitesse de surface pointe vers le KSC (retour)
        UNTIL VDOT(SHIP:VELOCITY:SURFACE, target_geo:POSITION) > 50 {
            PRINT "Distance restante KSC : " + ROUND(target_geo:DISTANCE) + "m   " AT (0, 4).
            WAIT 0.1.
        }
        
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        RCS OFF.
        SET runmode TO 2.
        CLEARSCREEN.
    }
    
    IF runmode = 2 {
        PRINT "Phase 2 : Rentrée & Guidage par Aérofrains" AT (0, 2).
        
        // Orientation initiale retrograde pour la rentrée
        RCS ON.
        LOCK STEERING TO SHIP:RETROGRADE.
        
        UNTIL SHIP:ALTITUDE < 30000 {
            PRINT "Attente de l'entrée atmosphérique. Alt : " + ROUND(SHIP:ALTITUDE) + "m   " AT (0, 3).
            WAIT 1.
        }
        
        // Guidage atmosphérique actif
        UNTIL SHIP:ALTITUDE < 4000 {
            // Calcul de la déviation de trajectoire par rapport au KSC
            LOCAL dist_to_ksc IS target_geo:DISTANCE.
            LOCAL speed_vector IS SHIP:VELOCITY:SURFACE.
            
            // Si on va trop vite ou qu'on dépasse le KSC (overshoot), on déploie les aérofrains
            // Si on est trop court (undershoot), on les ferme pour planer plus loin
            IF speed_vector:MAG > 400 AND VDOT(speed_vector, target_geo:POSITION) < 0 {
                // On va trop vite et on s'éloigne ou on dépasse -> freinage maximum
                set_airbrakes(true).
                PRINT "Aérofrains : DEPLOYÉS (Freinage / Overshoot)" AT (0, 5).
            } ELSE {
                set_airbrakes(false).
                PRINT "Aérofrains : RETRACTÉS (Conservation d'énergie)" AT (0, 5).
            }
            
            // Guidage aérodynamique par inclinaison (pitch/yaw) vers la cible
            // Ajustement de la direction vers le KSC
            LOCK STEERING TO HEADING(target_geo:BEARING, GLIDE_ANGLE).
            
            PRINT "Alt : " + ROUND(SHIP:ALTITUDE) + "m | Vitesse : " + ROUND(speed_vector:MAG) + " m/s   " AT (0, 3).
            WAIT 0.2.
        }
        
        set_airbrakes(false). // Rétractation avant le landing burn pour éviter d'endommager les gouvernes
        RCS OFF.
        SET runmode TO 3.
        CLEARSCREEN.
    }
    
    IF runmode = 3 {
        PRINT "Phase 3 : Suicide Burn & Atterrissage" AT (0, 2).
        GEAR ON.
        RCS ON. // RCS activé pour stabiliser la descente finale verticale
        LOCK STEERING TO SHIP:RETROGRADE.
        
        LOCAL g IS SHIP:SENSORS:GRAV:MAG.
        LOCAL max_accel IS (SHIP:MAXTHRUST / SHIP:MASS) - g.
        
        LOCK burn_altitude TO (SHIP:VELOCITY:SURFACE:MAG^2) / (2 * MAX(0.1, max_accel)).
        
        UNTIL SHIP:ALTITUDE - target_geo:ALTITUDE <= burn_altitude + 40 {
            PRINT "Altitude Radar : " + ROUND(ALT:RADAR) + "m | Hauteur de Burn : " + ROUND(burn_altitude) + "m   " AT (0, 3).
            WAIT 0.05.
        }
        
        PRINT "Déclenchement du Landing Burn !" AT (0, 5).
        LOCAL throttle_setting IS 1.0.
        LOCK THROTTLE TO throttle_setting.
        
        UNTIL SHIP:VELOCITY:SURFACE:MAG < 1.5 OR ALT:RADAR < 3 {
            LOCAL target_accel IS (SHIP:VELOCITY:SURFACE:MAG^2) / (2 * MAX(0.1, ALT:RADAR)).
            LOCAL ship_accel IS SHIP:MAXTHRUST / SHIP:MASS.
            IF ship_accel = 0 { SET ship_accel TO 10. }
            SET throttle_setting TO MIN(1.0, MAX(0.0, (target_accel + g) / ship_accel)).
            WAIT 0.01.
        }
        
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        SET runmode TO 4.
        CLEARSCREEN.
    }
}

PRINT "Atterrissage réussi !".
LADDERS ON.
Brakes ON.

