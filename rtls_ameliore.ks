// Script kOS - RTLS Automatique du Premier Étage avec Séparation, Trajectories & Aérofrains
// v3.1 : Correction du steering de rentrée atmosphérique et compatibilité syntaxique
GLOBAL target_geo IS SHIP:GEOPOSITION.
GLOBAL runmode IS 0. // 0: Montée & Attente niveau carburant bas, 1: Boostback, 2: Rentrée & Guidage Aérodynamique, 3: Landing Burn, 4: Posé

// Paramètres de vol
GLOBAL FUEL_THRESHOLD IS 150.
GLOBAL FUEL_SAFETY_MARGIN IS 100. // Seuil plancher de sécurité (unités)
GLOBAL ALIGN_THRESHOLD IS 0.9.   // Seuil d'alignement vitesse/cible pour arrêter le boostback (cos de l'angle)

// Fonction pour estimer le seuil de carburant dynamique nécessaire pour le RTLS
DECLARE FUNCTION calculate_fuel_threshold {
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

    IF active_count = 0 OR total_isp = 0 {
        RETURN FUEL_THRESHOLD.
    }

    LOCAL avg_isp IS total_isp / active_count.
    // Flow (t/s) = MaxThrust (kN) / (Isp * g0), densité LFO combinée ~0.005 t/unité
    LOCAL fuel_flow_rate IS SHIP:MAXTHRUST / (avg_isp * 9.81 * 0.005).

    // ~12s de boostback + ~8s de landing burn = 20s de marge moteur à pleine poussée
    LOCAL margin_seconds IS 20.
    LOCAL calculated_threshold IS fuel_flow_rate * margin_seconds.

    RETURN MAX(FUEL_SAFETY_MARGIN, calculated_threshold).
}

CLEARSCREEN.
PRINT "=== RTLS Script Initialisé ===".
PRINT "Cible KSC enregistrée : Lat " + ROUND(target_geo:LAT, 4) + " | Lon " + ROUND(target_geo:LNG, 4).

SET FUEL_THRESHOLD TO calculate_fuel_threshold().
PRINT "Seuil de carburant RTLS calculé automatiquement : " + ROUND(FUEL_THRESHOLD, 1) + " units".

// Fonction pour déployer/rétracter les aérofrains
DECLARE FUNCTION set_airbrakes {
    DECLARE PARAMETER deploy_state.
    IF deploy_state {
        BRAKES ON.
    } ELSE {
        BRAKES OFF.
    }
}

// Direction unitaire vers le KSC
DECLARE FUNCTION target_direction {
    RETURN target_geo:POSITION:NORMALIZED.
}

// Boucle principale
UNTIL runmode = 4 {
    IF runmode = 0 {
        PRINT "Phase 0 : Surveillance du carburant pour séparation..." AT (0, 2).
        PRINT "LiquidFuel restant dans l'étage : " + ROUND(STAGE:LIQUIDFUEL, 1) + " units   " AT (0, 3).
        PRINT "Seuil de carburant RTLS calculé automatiquement : " + ROUND(FUEL_THRESHOLD, 1) + " units".

        IF STAGE:LIQUIDFUEL < FUEL_THRESHOLD {
            PRINT "Carburant bas détecté ! Séparation..." AT (0, 5).
            STAGE.
            WAIT 1.5.
            SET runmode TO 1.
            CLEARSCREEN.
        }
    }

    IF runmode = 1 {
        PRINT "Phase 1 : Boostback Burn" AT (0, 2).

        RCS ON.
        // On s'oriente vers le KSC avec un angle de pitch de 25 degrés (compromis altitude/vitesse)
        LOCK STEERING TO HEADING(target_geo:BEARING, 25).
        WAIT 4.

        LOCK THROTTLE TO 1.0.

        LOCAL boostback_done IS FALSE.
        LOCAL prev_impact_dist IS 9999999.

        UNTIL boostback_done {
            // OPTIMISATION : Utilisation de Trajectories si le mod est disponible
            IF ADDONS:TRJ:AVAILABLE {
                LOCAL impact_error_vec IS ADDONS:TRJ:IMPACTPOS:POSITION - target_geo:POSITION.
                LOCAL impact_dist IS impact_error_vec:MAG.
                
                PRINT "Distance Impact -> KSC : " + ROUND(impact_dist) + "m      " AT (0, 4).

                // On coupe si on est très proche (moins de 150m) ou si la distance recommence à augmenter (overshoot naissant)
                IF impact_dist < 150 OR (impact_dist > prev_impact_dist + 50 AND prev_impact_dist < 2000) {
                    SET boostback_done TO TRUE.
                }
                SET prev_impact_dist TO impact_dist.
            } ELSE {
                // Secours sans Trajectories : produit scalaire des vecteurs unitaires
                LOCAL align IS VDOT(SHIP:VELOCITY:SURFACE:NORMALIZED, target_direction()).
                PRINT "Alignement vitesse -> KSC : " + ROUND(align, 3) + " / " + ALIGN_THRESHOLD AT (0, 4).
                IF align > ALIGN_THRESHOLD {
                    SET boostback_done TO TRUE.
                }
            }
            WAIT 0.05.
        }

        LOCK THROTTLE TO 0.
        UNLOCK STEERING.
        RCS OFF.
        SET runmode TO 2.
        CLEARSCREEN.
    }

    IF runmode = 2 {
        PRINT "Phase 2 : Rentrée & Guidage par Aérofrains" AT (0, 2).

        RCS ON.
        // On lock sur le vecteur rétrograde de surface pour garantir la stabilité et la protection thermique de l'étage
        LOCK STEERING TO SHIP:SRFRETROGRADE.

        UNTIL SHIP:ALTITUDE < 30000 {
            PRINT "Attente de l'entrée atmosphérique. Alt : " + ROUND(SHIP:ALTITUDE) + "m   " AT (0, 3).
            WAIT 1.
        }

        UNTIL SHIP:ALTITUDE < 4000 {
            LOCAL speed_vector IS SHIP:VELOCITY:SURFACE.

            // OPTIMISATION : Contrôle des aérofreins avec la position d'impact réelle de Trajectories
            IF ADDONS:TRJ:AVAILABLE {
                LOCAL impact_error_vec IS ADDONS:TRJ:IMPACTPOS:POSITION - target_geo:POSITION.
                
                // Si l'erreur d'impact projetée sur la vitesse est positive, on est en overshoot -> freiner
                IF speed_vector:MAG > 200 AND VDOT(impact_error_vec, speed_vector) > 0 {
                    set_airbrakes(true).
                    PRINT "Aérofrains : DEPLOYÉS (Overshoot Trajectories)  " AT (0, 5).
                } ELSE {
                    set_airbrakes(false).
                    PRINT "Aérofrains : RETRACTÉS (Conservation d'énergie)" AT (0, 5).
                }
                
                PRINT "Erreur d'impact estimée : " + ROUND(impact_error_vec:MAG) + "m       " AT (0, 6).
            } else {
                // Secours sans Trajectories
                IF speed_vector:MAG > 400 AND VDOT(speed_vector:NORMALIZED, target_direction()) < 0 {
                    set_airbrakes(true).
                    PRINT "Aérofrains : DEPLOYÉS (Freinage / Overshoot)     " AT (0, 5).
                } ELSE {
                    set_airbrakes(false).
                    PRINT "Aérofrains : RETRACTÉS (Conservation d'énergie)" AT (0, 5).
                }
            }

            PRINT "Alt : " + ROUND(SHIP:ALTITUDE) + "m | Vitesse : " + ROUND(speed_vector:MAG) + " m/s   " AT (0, 3).
            WAIT 0.1.
        }

        set_airbrakes(false).
        RCS OFF.
        SET runmode TO 3.
        CLEARSCREEN.
    }

    IF runmode = 3 {
        PRINT "Phase 3 : Suicide Burn & Atterrissage" AT (0, 2).
        GEAR ON.
        RCS ON.
        LOCK STEERING TO SHIP:SRFRETROGRADE.

        LOCAL g IS SHIP:SENSORS:GRAV:MAG.
        LOCAL max_accel IS (SHIP:MAXTHRUST / SHIP:MASS) - g.

        LOCK burn_altitude TO (SHIP:VELOCITY:SURFACE:MAG^2) / (2 * MAX(0.1, max_accel)).

        UNTIL ALT:RADAR <= burn_altitude + 40 {
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
BRAKES ON.
