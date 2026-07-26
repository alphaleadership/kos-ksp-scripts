// Script kOS - Mise en Orbite Automatique (Fusée 2 Étages + Capsule)
GLOBAL target_apoapsis IS 80000. // Altitude cible de l'orbite (80 km)
GLOBAL target_direction IS 90.   // Direction équatoriale (Est)
GLOBAL runmode IS 0.             // 0: Pré-lancement, 1: Décollage, 2: Gravity Turn, 3: Attente Apoapsis, 4: Circularisation, 5: Orbite atteinte

CLEARSCREEN.
PRINT "=== Script de Mise en Orbite Initialisé ===".
PRINT "Orbite cible : " + (target_apoapsis / 1000) + " km".

UNTIL runmode = 5 {
    IF runmode = 0 {
        PRINT "Prêt pour le lancement. Lancement dans 3 secondes..." AT (0, 2).
        FROM {local i is 3.} UNTIL i = 0 STEP {set i to i - 1.} DO {
            PRINT "Compte à rebours : " + i + "   " AT (0, 3).
            WAIT 1.
        }
        SET runmode TO 1.
        CLEARSCREEN.
    }
    
    IF runmode = 1 {
        PRINT "Phase 1 : Décollage !" AT (0, 2).
        RCS ON. // Activation immédiate du RCS pour aider à la stabilisation aérodynamique
        LOCK THROTTLE TO 1.0.
        LOCK STEERING TO UP.
        STAGE. // Allumage des moteurs du premier étage
        SET runmode TO 2.
        WAIT 2.
        CLEARSCREEN.
    }
    
    IF runmode = 2 {
        PRINT "Phase 2 : Gravity Turn (Guidage de montée)" AT (0, 2).
        
        // Calcul du pitch (inclinaison) en fonction de l'altitude
        // De 90 degrés (vertical) au sol à 0 degré (horizontal) à 45000m
        LOCK target_pitch TO MAX(5, 90 * (1 - (SHIP:ALTITUDE / 45000))).
        LOCK STEERING TO HEADING(target_direction, target_pitch).
        
        // Détection du carburant restant dans les boosters pour le RTLS (nécessite le tag "booster_tank")
        LOCAL booster_fuel IS 0.
        LOCAL tanks_found IS SHIP:PARTSTAGGED("booster_tank").
        FOR tank IN tanks_found {
            FOR res IN tank:RESOURCES {
                IF res:NAME = "LIQUIDFUEL" {
                    SET booster_fuel TO booster_fuel + res:AMOUNT.
                }
            }
        }
        
        // Détection de secours par flameout
        LOCAL has_flameout IS FALSE.
        LOCAL eng_list IS LIST().
        LIST ENGINES IN eng_list.
        FOR eng IN eng_list {
            IF eng:FLAMEOUT {
                SET has_flameout TO TRUE.
            }
        }
        
        // Séparation si le fuel des boosters est sous le seuil de freinage (320 unités)
        // Ou en secours si un moteur s'éteint et qu'aucun tag n'est configuré
        LOCAL should_separate IS FALSE.
        IF tanks_found:LENGTH > 0 {
            IF booster_fuel < 320 {
                SET should_separate TO TRUE.
            }
        } ELSE {
            IF has_flameout {
                SET should_separate TO TRUE.
            }
        }
        
        IF should_separate {
            PRINT "Carburant bas boosters ! Séparation..." AT (0, 4).
            LOCK THROTTLE TO 0.0. // Coupe temporairement la poussée pour laisser dériver les boosters
            STAGE. // Découplage du premier étage (Le booster lance son script RTLS sur sa CPU)
            WAIT 2.0. // Laisse le temps aux boosters de s'écarter
            LOCK THROTTLE TO 1.0. // Rétablit la puissance pour le second étage
            
            // Sécurité : n'activer l'étape suivante (allumage) que si aucun moteur ne pousse
            IF SHIP:MAXTHRUST = 0 {
                STAGE. // Allumage du moteur du second étage
            }
            PRINT "Moteur du second étage allumé." AT (0, 5).
        }
        
        PRINT "Apoapsis actuelle : " + ROUND(SHIP:APOAPSIS) + " m   " AT (0, 3).
        
        IF SHIP:APOAPSIS >= target_apoapsis {
            LOCK THROTTLE TO 0.
            SET runmode TO 3.
            CLEARSCREEN.
        }
        WAIT 0.1.
    }
    
    IF runmode = 3 {
        PRINT "Phase 3 : Coasting vers l'Apoapsis" AT (0, 2).
        // Rétraction ou largage de la coiffe si l'altitude est suffisante (> 50 km)
        IF SHIP:ALTITUDE > 50000 {
            // Déploiement des panneaux solaires et antennes (Action Group standard ou PANELS)
            PANELS ON.
            PRINT "Panneaux solaires déployés." AT (0, 4).
        }
        
        RCS ON. // Active le RCS pour l'orientation dans le vide
        LOCK STEERING TO SHIP:PROGRADE.
        
        LOCAL time_to_ap IS ETA:APOAPSIS.
        PRINT "Temps avant Apoapsis : " + ROUND(time_to_ap) + " s   " AT (0, 3).
        
        // On attend d'être proche de l'apoapsis pour circulariser (ex: 20 secondes)
        IF time_to_ap < 20 {
            SET runmode TO 4.
            CLEARSCREEN.
        }
        WAIT 0.5.
    }
    
    IF runmode = 4 {
        PRINT "Phase 4 : Circularisation" AT (0, 2).
        RCS ON.
        LOCK STEERING TO SHIP:PROGRADE.
        
        // Calcul du delta-V nécessaire pour circulariser à l'Apoapsis
        // Vis-Viva : V_circular = sqrt(mu / r)
        LOCAL mu IS SHIP:BODY:MU.
        LOCAL orbit_radius IS SHIP:APOAPSIS + SHIP:BODY:RADIUS.
        LOCAL v_target IS SQRT(mu / orbit_radius).
        
        // Vitesse actuelle estimée à l'apoapsis
        LOCAL v_ap IS VELOCITYAT(SHIP, TIME + ETA:APOAPSIS):ORBIT:MAG.
        LOCAL dv IS v_target - v_ap.
        
        // Temps de burn estimé
        LOCAL max_accel IS SHIP:MAXTHRUST / SHIP:MASS.
        IF max_accel = 0 { SET max_accel TO 10. } // Évite la division par zéro
        LOCAL burn_duration IS dv / max_accel.
        
        PRINT "Delta-V requis : " + ROUND(dv, 1) + " m/s" AT (0, 3).
        PRINT "Durée estimée du burn : " + ROUND(burn_duration, 1) + " s" AT (0, 4).
        
        // Attente de la moitié du temps de burn avant l'apoapsis pour centrer la poussée
        LOCAL burn_start_time IS ETA:APOAPSIS - (burn_duration / 2).
        IF burn_start_time > 0 {
            PRINT "Attente du point de burn : " + ROUND(burn_start_time) + " s   " AT (0, 5).
            WAIT burn_start_time.
        }
        
        PRINT "Allumage pour circularisation !" AT (0, 6).
        LOCK THROTTLE TO 1.0.
        
        // On pousse jusqu'à ce que la Périapsis soit proche de l'Apoapsis (orbite stable)
        UNTIL SHIP:PERIAPSIS >= target_apoapsis - 2000 OR SHIP:VELOCITY:ORBIT:MAG >= v_target {
            PRINT "Périapsis actuelle : " + ROUND(SHIP:PERIAPSIS) + " m   " AT (0, 7).
            WAIT 0.05.
        }
        
        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        RCS OFF.
        SET runmode TO 5.
        CLEARSCREEN.
    }
}

PRINT "Félicitations ! Orbite stable établie.".
PRINT "Apoapsis : " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
PRINT "Périapsis : " + ROUND(SHIP:PERIAPSIS/1000, 1) + " km".
RCS OFF.

