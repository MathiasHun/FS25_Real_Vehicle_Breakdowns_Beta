
local function getIsElectricVehicle(vehicle)
	if vehicle.spec_motorized.consumers == nil then return end
	for _, consumer in pairs(vehicle.spec_motorized.consumers) do
		if consumer.fillType == FillType.ELECTRICCHARGE then
			return true
		end
	end
	return false
end
local function getBreakChance(operatingHoursPercent, threshold)
	if operatingHoursPercent < threshold then
		return 0
	end
	local p = (operatingHoursPercent - threshold) / 10
	local quadraticNum = math.min(math.floor(p * p * 60), threshold)
	--print("chance " .. quadraticNum)
	return quadraticNum
end
local function randomBreakDown(vehicle, partName, critical, preThreshold, forceCheck)
	local part = vehicle.spec_faultData and vehicle.spec_faultData.parts and vehicle.spec_faultData.parts[partName]
	if not part then return false end
	local maxLifetime = PartManager.getMaxPartLifetime(vehicle, partName)
	local percent = (part.operatingHours * 100) / maxLifetime
	if forceCheck or percent >= critical then
		return true
	end
	local chance = getBreakChance(percent, preThreshold)
	if chance == 0 then
		return false
	end
	--print("chance " .. chance)
	local result = math.random(100) <= chance
	--print("result " .. tostring(result))
	return result
	--return math.random(100) <= chance
end
function getValidFaultVariants(vehicle, key, forceCheck)
    local def = FaultRegistry[key]
    if not def or not def.variants then return nil end
    local variants = {}
    if forceCheck then
        local weighted = {}
        local totalWeight = 0
        for name, variant in pairs(def.variants) do
            local weight = variant.severity or 1
            totalWeight = totalWeight + weight
            table.insert(weighted, {name=name, weight=weight})
        end
        local r = math.random() * totalWeight
        local acc = 0
        for _, v in ipairs(weighted) do
            acc = acc + v.weight
            if r <= acc then
                return v.name
            end
        end
    else
        for name, variant in pairs(def.variants) do
            local result = variant.threshold and variant.threshold(vehicle)
            if result == true or (type(result) == "number" and math.random() < result) then
                table.insert(variants, name)
            end
        end
        if #variants > 0 then
            return variants[math.random(#variants)]
        end
    end
    return nil
end

function applyEngineTorqueModifier(vehicle, factor)
    local motor = vehicle.spec_motorized and vehicle.spec_motorized.motor
    if not motor then return end
    if not vehicle.spec_faultData.originalGetTorque then
        vehicle.spec_faultData.originalGetTorque = motor.getTorqueCurveValue
    end
    motor.getTorqueCurveValue = function(m, rpm)
        local originalFunc = vehicle.spec_faultData.originalGetTorque
        local originalTorque = originalFunc(m, rpm)
        return originalTorque * factor
    end
    vehicle:updateMotorProperties()
end

function resetEngineTorque(vehicle)
    local motor = vehicle.spec_motorized and vehicle.spec_motorized.motor
    if not motor then return end
    if vehicle.spec_faultData.originalGetTorque then
        motor.getTorqueCurveValue = vehicle.spec_faultData.originalGetTorque
		vehicle.spec_faultData.originalGetTorque = nil
        vehicle:updateMotorProperties()
    end
end


function applySpeedLimit(vehicle, limitPercent)
    local motor = vehicle.spec_motorized and vehicle.spec_motorized.motor
    if not motor then return end

    local orig = motor.originalMaxSpeed or motor.maxForwardSpeed

    -- eredeti max sebesség mentése egyszer
    if motor.originalMaxSpeed == nil then
        motor.originalMaxSpeed = orig
    end
    -- új sebesség
    motor.maxForwardSpeed = motor.originalMaxSpeed * limitPercent
end

function resetSpeedLimit(vehicle)
    local motor = vehicle.spec_motorized.motor
    if motor == nil then return end

    if motor.originalMaxSpeed ~= nil then
        motor.maxForwardSpeed = motor.originalMaxSpeed
    end
end

THERMOSTAT = "THERMOSTAT"
LIGHTINGS = "LIGHTINGS"
GLOWPLUG = "GLOWPLUG"
WIPERS = "WIPERS"
GENERATOR = "GENERATOR"
ENGINE = "ENGINE"
SELFSTARTER = "SELFSTARTER"
BATTERY = "BATTERY"
TIREFL = "TIREFL"
TIREFR = "TIREFR"
TIRERL = "TIRERL"
TIRERR = "TIRERR"
TIRERL2 = "TIRERL2"
TIRERR2 = "TIRERR2"

g_vehicleBreakdownsPartKeys = {
    THERMOSTAT, LIGHTINGS, GLOWPLUG, WIPERS,
    GENERATOR, ENGINE, SELFSTARTER, BATTERY,
    TIREFL, TIREFR, TIRERL, TIRERR
}

WHEELTOPART = {
	[1] = TIREFL,
	[2] = TIREFR,
	[3] = TIRERL,
	[4] = TIRERR
}

HUDCOLOR = {}
HUDCOLOR.BASE = {1, 1, 1, 1}
--HUDCOLOR.DEFAULT = {1, 1, 1, 0.2}
HUDCOLOR.DEFAULT = {0.6, 0.6, 0.6, 0.1}
HUDCOLOR.DEFAULT_LIGHT = {1, 1, 1, 0.5}
HUDCOLOR.WARNING  = { 1, 0.4287, 0.0006, 1 }
HUDCOLOR.CRITICAL = {0.8069, 0.0097, 0.0097, 1}
HUDCOLOR.COOL = { 0.0097, 0.4287, 0.6445, 1 }


MS_PER_GAME_HOUR = 1000 * 60 * 60
 
RVB_DELAY = {
	PARTS_BREAKDOWNS = 100,
	PARTS_noBREAKDOWNS = 1200,
	PARTS_OPERATINGHOURS = 2000,
	LIGHTINGS_OPERATINGHOURS = 3000,
	WIPERS_OPERATINGHOURS = 2500,
	OVERHEATING_FAILURE = 3000,
	BATTERY_DRAIN = 1100,
	DIRT_HEAT = 5000,
	MOTORTEMPERATURE = 50,             -- updateMotorTemperature()
	MOTORLOAD = 800
}

DIRT_HEAT_START_HOURS = 1.0     -- 1 játékóra után = g_rvbGameplaySettings.dailyServiceInterval, tehát ez törölhető
DIRT_HEAT_MAX_HOURS   = 15.0     -- max hatás
MAX_DIRT_HEAT_BONUS   = 0.35    -- max +35% hő / -35% hűtés

DIRT_HEAT_RESTORE_START = 0.10   -- 10% kosztól kezd visszacsökkenni
DIRT_HEAT_RESTORE_FULL  = 1.00   -- 100%-nál teljes hatás

DIRT_HEAT = {
	MINFACTOR = 3,				-- min. ezzel az értékkel növekedik a defaultEnableTemp és defaultDisableTemp
	MAXFACTOR = 20,				-- max. ezzel az értékkel növekedik a defaultEnableTemp és defaultDisableTemp
	START_HOURS = 1.0,			-- 1 játékóra után
	MAX_HOURS   = 15.0,			-- max hatás
	MAX_BONUS = 0.35,			-- max +35% hő / -35% hűtés
}

BATTERY_DRAIN_TIME = 10800

BATTERY_LEVEL = {
    MOTOR = 0.10,               -- minimum töltöttség a motor indításához
    LIGHTS = 0.05,              -- első/hátsó világítás
    LIGHTS_BEACONS = 0.03,      -- villogó
    LIGHTS_TURN = 0.03,         -- index
    DISCONNECT_THRESHOLD = 0.95 -- ha ennél lejjebb esik, leválaszt akkut
}

INSPECTION = {
	TIME = 3600,
	SERVICE_MANUAL = 1,
	COST = 0.004
}

SERVICE = {
	BASE_TIME = 10800,
	TIME = 600,
	SERVICE_MANUAL = 2,
	COST = 0.005
}

REPAIR = {
	SERVICE_MANUAL = 3
}

BATTERYS = {
	SERVICE_MANUAL = 4
}

RESET = {
	SERVICE_MANUAL = 5
}

BATTERY_CHARGE_COST = 25

MAXSPEED_THRESHOLD = 0.40

MOTORTEMP_THRESHOLD = 50
MOTORTEMP_LOAD_THRESHOLD = 0.70
LOADPERCENTAGE_LOAD_THRESHOLD = 0.85
LOADPERCENTAGE_THRESHOLD = 0.95
	
JUMPERCABLE_MINRADIUS = 6
JUMPERCABLE_LENGTH = 10

FaultRegistry = {
    -- THERMOSTAT (termosztát)
    [THERMOSTAT] = {
        name = "RVB_faultText_THERMOSTAT",
        description = "A termosztát hibái, motor túlmelegedés kockázata.",
        motorState = {"STARTING", "ON"},
        isApplicable = function(vehicle) return not getIsElectricVehicle(vehicle) end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 90,
        strictBreak = false,
        repairTime = 10800,
        cost = 0.0015,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[THERMOSTAT].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, THERMOSTAT, 99, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=true, temp={default=95, cool=MOTORTEMP_THRESHOLD, warning="", critical=100}, visible=true},
        variants = {
            ["stuckClosed"] = { -- Nem nyit ki
                severity = 0.8,
                effects = {"engine_overheat", "coolant_pressure_rise", "component_wear_accelerated"},
                threshold = function(vehicle) return math.random() < 0.05 end,
                wear = function(vehicle)
                    local spec = vehicle.spec_motorized
                    return spec and spec.motorTemperature and spec.motorTemperature.value > 95
                end,
				wearMultiplier = {
					{component=ENGINE, multiplier=2},
					{component=THERMOSTAT, multiplier=1.3},
					{component=GENERATOR, multiplier=1.05},
					{component=BATTERY, multiplier=1.05}
				},
				hudcolor = function(motorTemp, gtemp)
					if motorTemp > gtemp.critical then
						return HUDCOLOR.CRITICAL
					elseif motorTemp > gtemp.default and motorTemp <= gtemp.critical then
						return HUDCOLOR.WARNING
					elseif motorTemp >= gtemp.cool and motorTemp <= gtemp.default then
						return HUDCOLOR.WARNING
					elseif motorTemp < gtemp.cool then
						return HUDCOLOR.COOL
					--else
						--return HUDCOLOR.DEFAULT
					end
				end
            },
            ["stuckOpen"] = { -- Nem zár vissza
                severity = 0.3,
                effects = {"cold_running_engine", "increased_fuel_usage", "component_wear_accelerated"},
                threshold = function(vehicle) return math.random() < 0.05 end,
                wear = function(vehicle)
                    local spec = vehicle.spec_motorized
                    return spec and spec.motorTemperature and spec.motorTemperature.value < MOTORTEMP_THRESHOLD
                end,
				wearMultiplier = {
					{component=ENGINE, multiplier=1.2},
					{component=THERMOSTAT, multiplier=1.1}
					--FUEL SYSTEM vagy INJECTOR: mert hidegen dúsabb keverék → multiplier = 1.05.
				},
				hudcolor = function(motorTemp, gtemp)
					if motorTemp < gtemp.cool then
						return HUDCOLOR.COOL
					else
						return HUDCOLOR.WARNING
					end
				end
			},
			["restrictedFlow"] = {
				severity=0.4, effects={"reduced_coolant_flow"},
				threshold=function(vehicle) return math.random() < 0.05 end,
				wear = function(vehicle)
					local spec = vehicle.spec_motorized
					return spec and spec.motorTemperature and spec.motorTemperature.value > 80
				end,
				wearMultiplier = {
					{component=ENGINE, multiplier=1.3},
					{component=THERMOSTAT, multiplier=1.1}
					--THERMOSTAT / WATERPUMP: → multiplier = 1.1
				},
				hudcolor = function(motorTemp, gtemp)
					if motorTemp > gtemp.critical then
						return HUDCOLOR.CRITICAL
					elseif motorTemp > gtemp.default and motorTemp <= gtemp.critical then
						return HUDCOLOR.WARNING
					elseif motorTemp >= gtemp.cool and motorTemp <= gtemp.default then
						return HUDCOLOR.WARNING	
					elseif motorTemp < gtemp.cool then
						return HUDCOLOR.COOL	
					--else
						--return HUDCOLOR.DEFAULT
					end
				end
			}, -- Hűtőfolyadék áramlás akadályozása
			--["mechanicalFailure"] = {severity=0.5, effects={"mechanical_failure"}, threshold=function(vehicle) return math.random() < 0.03 end}, -- Mechanikai törés / szelep deformáció
			--["coolantLeak"] = {severity=0.6, effects={"coolant_leak"}, threshold=function(vehicle) return math.random() < 0.02 end}, -- Hűtőfolyadék szivárgás
        }
    },

    -- LIGHTINGS (világítás)
    [LIGHTINGS] = {
        name = "RVB_faultText_LIGHTINGS",
        description = "Világítás hibák: égő, vezérlés, kábelezés.",
        motorState = {"STARTING", "ON"},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 95,
        strictBreak = false,
        repairTime = 5400,
        cost = 0.005,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[LIGHTINGS].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, LIGHTINGS, 99, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=true},
        variants = {
            ["burntBulb"] = {severity=0.7, effects={"burnt_bulb"}, threshold=function(vehicle) return math.random() < 0.05 end, hudcolor = HUDCOLOR.WARNING}, -- Égő kiégése
            ["wiringShort"] = {severity=0.6, effects={"wiring_short"}, threshold=function(vehicle) return math.random() < 0.04 end, hudcolor = HUDCOLOR.WARNING}, -- Rövidzárlat / szakadás a vezetékekben
            ["controlModuleFailure"] = {severity=0.5, effects={"control_module_failure"}, threshold=function(vehicle) return math.random() < 0.03 end, hudcolor = HUDCOLOR.WARNING}, -- Vezérlőmodul / relé hiba
            ["ledFailure"] = {severity=0.4, effects={"led_failure"}, threshold=function(vehicle) return math.random() < 0.02 end, hudcolor = HUDCOLOR.WARNING}, -- LED modul hiba
            ["corrodedConnector"] = {severity=0.3, effects={"corroded_connector"}, threshold=function(vehicle) return math.random() < 0.01 end, hudcolor = HUDCOLOR.WARNING}, -- Víz / korrózió a csatlakozóknál
        }
    },

    -- GLOWPLUG (izzítógyertya)
    [GLOWPLUG] = {
        name = "RVB_faultText_GLOWPLUG",
        description = "Izzítógyertya hibák, indítási problémák.",
        motorState = {"STARTING"},
        isApplicable = function(vehicle) return not getIsElectricVehicle(vehicle) end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 80,
        strictBreak = false,
        repairTime = 7200,
        cost = 0.004,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[GLOWPLUG].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, GLOWPLUG, 90, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=false},
        variants = {
            ["burntGlowPlug"] = {
				severity=0.8,
				effects={"burnt_glowplug"},
				threshold=function(vehicle) return math.random() < 0.05 end,
				wearMultiplier = {
					{component=ENGINE, multiplier=1.2},
					{component=SELFSTARTER, multiplier=1.3},
					{component=BATTERY, multiplier=1.1}
				},
				exhaustEffect = {minRpmColor = {0.9, 0.9, 0.95, 1.4}, maxRpmColor = {0.9, 0.9, 0.95, 1.6}}
			}, -- Kiégett gyertya
            ["shortCircuit"] = {
				severity=0.7,
				effects={"short_circuit"},
				threshold=function(vehicle) return math.random() < 0.05 end,
				wearMultiplier = {
					{component=GLOWPLUG, multiplier=1.2},
					{component=GENERATOR, multiplier=1.3},
					{component=BATTERY, multiplier=1.1},
					{component=SELFSTARTER, multiplier=1.4},
					{component=ENGINE, multiplier=1.1}
				},
				exhaustEffect = {minRpmColor = {0.9, 0.9, 0.95, 1.4}, maxRpmColor = {0.9, 0.9, 0.95, 1.6}}
			}, -- Rövidzár
            --["insufficientHeating"] = {severity=0.6, effects={"insufficient_heating"}, threshold=function(vehicle) return math.random() < 0.03 end}, -- Nem megfelelő felfűtés
            --["connectorIssue"] = {severity=0.5, effects={"connector_issue"}, threshold=function(vehicle) return math.random() < 0.02 end}, -- Elektromos csatlakozás hibája
            --["mechanicalDamage"] = {severity=0.4, effects={"mechanical_damage"}, threshold=function(vehicle) return math.random() < 0.01 end}, -- Mechanikai sérülés
        }
    },

    -- WIPERS (ablaktörlő)
    [WIPERS] = {
        name = "RVB_faultText_WIPERS",
        description = "Ablaktörlő hibák, motor, lapát és vezérlés.",
        motorState = {"ON"},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 70,
        strictBreak = false,
        repairTime = 1800,
        cost = 0.002,
        threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[WIPERS].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, WIPERS, 80, preThreshold, forceCheck)
		end,
		hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=true},
        variants = {
            ["motorFailure"] = {severity=0.8, effects={"motor_failure"}, threshold=function(vehicle) return math.random() < 0.05 end}, -- Motor meghibásodása
            ["wiperBladeWorn"] = {severity=0.7, effects={"wiper_blade_worn"}, threshold=function(vehicle) return math.random() < 0.05 end}, -- Lapát kopása
            ["mechanicalObstruction"] = {severity=0.6, effects={"mechanical_obstruction"}, threshold=function(vehicle) return math.random() < 0.03 end}, -- Mechanikai akadály
            ["controlFailure"] = {severity=0.5, effects={"control_failure"}, threshold=function(vehicle) return math.random() < 0.02 end}, -- Elektronikai vezérlés hibája
            ["fuseRelayFault"] = {severity=0.4, effects={"fuse_relay_fault"}, threshold=function(vehicle) return math.random() < 0.01 end}, -- Biztosíték / relé meghibásodása
        }
    },

    -- GENERATOR (generátor)
    [GENERATOR] = {
        name = "RVB_faultText_GENERATOR",
        description = "Generátor hibák, töltésproblémák, mechanikai kopás.",
        isMotorState = function(currentMotorState)
			local validStates = {MotorState.ON}
			for _, state in ipairs(validStates) do
				if currentMotorState == state then
					return true
				end
			end
			return false
		end,
		--{"STARTING", "ON"},
        isApplicable = function(vehicle) return not getIsElectricVehicle(vehicle) end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 90,
        strictBreak = false,
        repairTime = 5400,
        cost = 0.010,
        threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[GENERATOR].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, GENERATOR, 98, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=false, condition={default=90, warning={90,99}, critical=99}, visible=true},
        variants = {
			["undercharging"] = {
				severity = 0.3,  -- enyhe hiba, részleges töltésvesztés
				effects = {"battery_not_charging"},
				threshold = function(vehicle) return math.random() < 0.05 end,
				hudcolor = HUDCOLOR.WARNING
			}, 
			["statorShort"] = {
				severity = 0.7,  -- súlyos hiba, szinte teljes leállás
				effects = {"stator_short"},
				threshold = function(vehicle) return math.random() < 0.05 end,
				hudcolor = HUDCOLOR.WARNING
			}, 
			["bearingWear"] = {
				severity = 0.5,  -- közepes hiba, mechanikai kopás
				effects = {"bearing_wear"},
				threshold = function(vehicle) return math.random() < 0.03 end,
				hudcolor = HUDCOLOR.WARNING
			}, 
			["wiringIssue"] = {
				severity = 0.6,  -- közepesen súlyos, vezetékhiba
				effects = {"wiring_issue"},
				threshold = function(vehicle) return math.random() < 0.02 end,
				hudcolor = HUDCOLOR.WARNING
			}, 
			["voltageIrregularity"] = {
				severity = 0.7,  -- komolyabb hiba, túlfesz/alulfesz
				effects = {"voltage_irregularity"},
				threshold = function(vehicle) return math.random() < 0.01 end,
				hudcolor = HUDCOLOR.WARNING
			},
			["failure"] = {
				severity = 1,  -- teljes meghibásodás, nulla töltés
				effects = {"generator_failure"},
				threshold = function(vehicle) return math.random() < 0.005 end,
				hudcolor = HUDCOLOR.CRITICAL
			}
		}

    },

    -- ENGINE (motor)
    [ENGINE] = {
        name = "RVB_faultText_ENGINE",
        description = "Motor hibák, teljesítménycsökkenés, túlmelegedés, leállás.",
        motorState = {"ON"},
        isApplicable = function(vehicle) return not getIsElectricVehicle(vehicle) end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 90,
        strictBreak = false,
        repairTime = 21600,
        cost = 0.150,
        threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[ENGINE].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, ENGINE, 96, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=false, condition={default=90, warning={90,99}, critical=99}, visible=true},
        variants = {
			-- Gyújtáskimaradás
			["misfire"] = {
				severity=0.4,
				effects={"engine_misfire"},
				threshold=function(vehicle) return math.random() < 0.05 end,
				torqueFactor=0.75,
				--exhaustEffect = { minRpmColor = {0.2, 0.2, 0.2, 1.2}, maxRpmColor = {0.2, 0.2, 0.2, 1.6} },
				exhaustEffect = { minRpmColor = {0.05, 0.05, 0.05, 4.2}, maxRpmColor = {0.05, 0.05, 0.05, 5.5} },
				hudcolor = HUDCOLOR.WARNING
			},
			-- Olajnyomás csökkenése
			["lowOilPressure"] = {
				severity=0.7,
				effects={"low_oil_pressure"},
				--threshold=function(vehicle) local oil = vehicle.spec_motorized and vehicle.spec_motorized.oilPressure return oil and oil.value < 0.3 end,
				threshold=function(vehicle) return math.random() < 0.06 end,
				torqueFactor=0.7,
				limitPercent=0.5 + 0.1 * (math.random(0,100)/100),
				--exhaustEffect = {minRpmColor = {0.3, 0.3, 0.9, 1.1}, maxRpmColor = {0.3, 0.3, 0.9, 1.4}},
				exhaustEffect = {minRpmColor = {0.2, 0.3, 0.9, 1.2}, maxRpmColor = {0.2, 0.3, 0.9, 1.6}},
				hudcolor = HUDCOLOR.WARNING
			},
			-- Hengerfej tömítés hibája
			["headGasketFailure"] = {
				severity=0.6,
				effects={"head_gasket_failure"},
				threshold=function(vehicle) return math.random() < 0.03 end,
				torqueFactor=0.6,
				limitPercent=0.5 + 0.1 * (math.random(0,100)/100),
				--exhaustEffect = {minRpmColor = {0.9, 0.9, 0.9, 1.4}, maxRpmColor = {0.9, 0.9, 0.9, 1.6}},
				exhaustEffect = {minRpmColor = {0.9, 0.9, 0.95, 1.4}, maxRpmColor = {0.9, 0.9, 0.95, 1.6}},
				hudcolor = HUDCOLOR.WARNING
			},
			-- Túlmelegedés
			["overheating"] = {
				severity=0.8,
				effects={"overheating"},
				--threshold=function(vehicle) local temp = vehicle.spec_motorized and vehicle.spec_motorized.motorTemperature return temp and temp.value > 100 end,
				threshold = function(vehicle)
					local temp = vehicle.spec_motorized and vehicle.spec_motorized.motorTemperature
					local dirt = vehicle.spec_washable and vehicle.spec_washable:getDirtAmount() or 0
					if not temp then return false end
					-- alapfeltétel: túlmelegedés 100°C felett
					if temp.value <= 100 then return false end
					-- kosz növeli az esélyt 0..1 skálán
					local chance = 0.5 + dirt * 0.5  -- tiszta: 50%, nagyon koszos: 100%
					return math.random() < chance
				end,
				torqueFactor=0.5,
				limitPercent=0.4 + 0.2 * (math.random(0,100)/100),
				--exhaustEffect = {minRpmColor = {0.9, 0.9, 0.9, 1.4}, maxRpmColor = {0.9, 0.9, 0.9, 1.6}},
				exhaustEffect = {minRpmColor = {0.8, 0.8, 0.8, 1.0}, maxRpmColor = {0.8, 0.8, 0.8, 1.3}},
				hudcolor = HUDCOLOR.WARNING
			},
			-- Kopott / sérült alkatrészek
			["mechanicalWear"] = {
				severity=0.5,
				effects={"mechanical_wear"},
				threshold=function(vehicle) return math.random() < 0.05 end,
				torqueFactor=0.8,
				limitPercent=0.8 + 0.1 * (math.random(0,100)/100),
				--exhaustEffect = {minRpmColor = {0.4, 0.4, 0.4, 1.1}, maxRpmColor = {0.4, 0.4, 0.4, 1.3}},
				exhaustEffect = {minRpmColor = {0.2, 0.3, 0.9, 3.8}, maxRpmColor = {0.2, 0.3, 0.9, 1.4}},
				hudcolor = HUDCOLOR.WARNING
			},
			-- Érzékelő hibák
			["sensorFault"] = {
				severity=0.5,
				effects={"sensor_fault"},
				--threshold=function(vehicle) return math.random() < 0.02 end,
				threshold = function(vehicle)
					local dirt = vehicle.spec_washable and vehicle.spec_washable:getDirtAmount() or 0
					-- kosz növeli az érzékelőhiba esélyét
					local chance = 0.02 + dirt * 0.1 -- pl. tiszta 2%, nagyon koszos 12%
					return math.random() < chance
				end,
				--exhaustEffect = {minRpmColor = {0.3, 0.3, 0.9, 1.0}, maxRpmColor = {0.3, 0.3, 0.9, 1.3}},
				exhaustEffect = {minRpmColor = {0.4, 0.4, 0.4, 1.0}, maxRpmColor = {0.4, 0.4, 0.4, 1.2}},
				hudcolor = HUDCOLOR.WARNING
			},
			-- Hirtelen leállás
			["completeFailure"] = {
				severity=1.0,
				effects={"engine_shutdown"},
				threshold=function(vehicle) return math.random() < 0.01 end,
				torqueFactor=0.3,
				exhaustEffect = {minRpmColor = {0.01, 0.01, 0.01, 5.6}, maxRpmColor = {0.01, 0.01, 0.01, 4.3}},
				hudcolor = HUDCOLOR.CRITICAL
			}
		}
	},
			
    -- SELFSTARTER (indítómotor)
    [SELFSTARTER] = {
        name = "RVB_faultText_SELFSTARTER",
        description = "Indítómotor hibák, nehézkes vagy lehetetlen indítás.",
        motorState = {"STARTING"},
        isApplicable = function(vehicle) return not getIsElectricVehicle(vehicle) end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 83,
        strictBreak = false,
        repairTime = 5400,
        cost = 0.006,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[SELFSTARTER].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, SELFSTARTER, 93, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=false, condition={default=83, warning={83,99}, critical=99}, visible=true},
        variants = {
            ["noEngineCrank"] = {severity=0.8, effects={"no_engine_crank"}, threshold=function(vehicle) return math.random() < 0.05 end}, -- Nem indul
            ["slowCrank"] = {severity=0.6, effects={"slow_crank"}, threshold=function(vehicle)
                local battery = vehicle.spec_motorized and vehicle.spec_motorized.batteryCharge
                return battery and battery.value < 0.5
            end}, -- Lassú indítás
        --    ["starterOverheat"] = {severity=0.7, effects={"starter_overheat"}, threshold=function(vehicle) return math.random() < 0.05 end}, -- Túlmelegedés
            ["connectorIssue"] = {severity=0.4, effects={"connector_issue"}, threshold=function(vehicle) return math.random() < 0.02 end}, -- Elektromos csatlakozás hibája
            ["relayFault"] = {severity=0.3, effects={"relay_fault"}, threshold=function(vehicle) return math.random() < 0.01 end}, -- Relé / kapcsoló hiba
            ["intermittentStart"] = {severity=0.5, effects={"intermittent_start"}, threshold=function(vehicle) return math.random() < 0.02 end}, -- Időszakos indítási hiba
            ["starterClickOnly"] = {severity=0.2, effects={"starter_click_only"}, threshold=function(vehicle) return math.random() < 0.03 end}, -- Csak kattanás hallatszik
        }
    },

    -- BATTERY (akkumulátor)
    [BATTERY] = {
        name = "RVB_faultText_BATTERY",
        description = "Akkumulátor hibák: töltés, belső rövidzár, kapacitáscsökkenés.",
        motorState = {"STARTING", "ON"},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 85,
        strictBreak = false,
        repairTime = 10800,
        cost = 0.004,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[BATTERY].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, BATTERY, 95, preThreshold, forceCheck)
		end,
        hud = {temperatureBased=false, condition={default=90, warning={85,99}, critical=99}, visible=true},
        variants = {
            ["internalShort"] = {severity=0.8, effects={"internal_short"}, threshold=function(vehicle) return math.random() < 0.04 end}, -- Rövidzár belül
            ["connectorIssue"] = {severity=0.3, effects={"connector_issue"}, threshold=function(vehicle) return math.random() < 0.01 end}, -- Polaritás / csatlakozás hibája
            ["capacityLoss"] = {severity=0.6, effects={"capacity_loss"}, threshold=function(vehicle) return math.random() < 0.02 end}, -- Gyors elhasználódás / kapacitáscsökkenés
        }
    },
	[TIREFL] = {
        name = "RVB_faultText_TIREFL",
        description = "",
        motorState = {},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 70,
        strictBreak = false,
        repairTime = 1200,
        cost = 0.006,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[TIREFL].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, TIREFL, 90, preThreshold, forceCheck)
		end,
		hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=false},
        variants = {
            ["puncture"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.5 end, hudcolor = HUDCOLOR.WARNING},
			["flat_tire"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.3 end, hudcolor = HUDCOLOR.WARNING}
        }
    },
	[TIREFR] = {
        name = "RVB_faultText_TIREFR",
        description = "",
        motorState = {},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 70,
        strictBreak = false,
        repairTime = 1200,
        cost = 0.006,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[TIREFR].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, TIREFR, 90, preThreshold, forceCheck)
		end,
		hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=false},
        variants = {
            ["puncture"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.6 end, hudcolor = HUDCOLOR.WARNING},
			["flat_tire"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.4 end, hudcolor = HUDCOLOR.WARNING}
        }
    },
	[TIRERL] = {
        name = "RVB_faultText_TIRERL",
        description = "",
        motorState = {},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 70,
        strictBreak = false,
        repairTime = 2500,
        cost = 0.011,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[TIRERL].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, TIRERL, 90, preThreshold, forceCheck)
		end,
		hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=false},
        variants = {
            ["puncture"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.7 end, hudcolor = HUDCOLOR.WARNING},
			["flat_tire"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.5 end, hudcolor = HUDCOLOR.WARNING}
        }
    },
	[TIRERR] = {
        name = "RVB_faultText_TIRERR",
        description = "",
        motorState = {},
        isApplicable = function(vehicle) return true end,
        rvbSpec = function(vehicle) return vehicle and vehicle.spec_faultData or nil end,
        breakThreshold = 70,
        strictBreak = false,
        repairTime = 2500,
        cost = 0.011,
		threshold = function(vehicle, pre_random, forceCheck)
			local preThreshold = FaultRegistry[TIRERR].breakThreshold
			if pre_random > 0 then
				preThreshold = preThreshold - pre_random
			end
			return randomBreakDown(vehicle, TIRERR, 90, preThreshold, forceCheck)
		end,
		hud = {temperatureBased=false, condition={default=99, warning={}, fault={}, critical=100}, visible=false},
        variants = {
            ["puncture"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.8 end, hudcolor = HUDCOLOR.WARNING},
			["flat_tire"] = {severity=0.7, effects={}, threshold=function(vehicle) return math.random() < 0.4 end, hudcolor = HUDCOLOR.WARNING}
        }
    }
	
}


function checkAndShowAlertMessage(self, minute, key, textKey, interval)
	local spec = self.spec_faultData
	local RVBSET = g_currentMission.vehicleBreakdowns
	spec.alertMessage[key] = spec.alertMessage[key] or -1
	if RVBSET:getIsAlertMessage() then
		if minute % interval == 0 and spec.alertMessage[key] ~= minute then
			if self.getIsEntered and self:getIsEntered() then 
				g_currentMission:showBlinkingWarning(g_i18n:getText(textKey), 2500)
			else
				-- HUD oldali értesítés is mehetne ide
				-- g_currentMission.hud:addSideNotification(FSBaseMission.INGAME_NOTIFICATION_OK, string.format(g_i18n:getText(textKey.."_hud"), self:getFullName()), 2500)
			end
			self.rvbDebugger:info(g_i18n:getText(textKey.."_hud"), self:getFullName())
			spec.alertMessage[key] = minute
		end
	end
end

RVB_EXCLUDED_TYPES = {
	conveyorBelt = true,
	conveyorBeltUnpowered = true,
	handToolMower = true,
	highPressureWasher = true,
	inlineWrapper = true,
	locomotive = true,
	motorbike = true,
	pickupConveyorBelt = true,
	seedTreater = true,
	trainTimberTrailer = true,
	trainTrailer = true,
	["pdlc_highlandsFishingPack.boat"] = true,
	["pdlc_highlandsFishingPack.carFillableExtended"] = true,
	["pdlc_highlandsFishingPack.cargoBoat"] = true,
	["pdlc_highlandsFishingPack.selfPropelledLevelerExtended"] = true,
}

RVB_EXCLUDED_MODS = {
	-- base
	["antonioCarraro/tigrecar3200"] = true,
	["jungheinrich/efgS50S"] = true,
	["kubota/rtvx1140"] = true,
	["kubota/rtvxG850"] = true,
	["kubota/svl972"] = true,
	["newHolland/l318"] = true,
	["piaggio/ape50"] = true,
	-- DLC
	-- highlandsFishingPack
	["canAm/defender"] = true,
	["canAm/outlanderMax"] = true,
	["canAm/outlanderPro"] = true,
	-- mods
	["FS25_AGCO_GoKart"] = true,
	["FS25_AN2"] = true,
	["FS25_ASM_FarmyardTrailerDolly"] = true,
	["FS25_Astec_Hopper_Feeder"] = true,
	["FS25_ATC200"] = true,
	["FS25_CanAmOutlander800"] = true,
	["FS25_dromadar"] = true,
	["FS25_Efg_S50_Lux"] = true,
	["FS25_EFG_S50_Pack"] = true,
	["FS25_electricCar"] = true,
	["FS25_ERE120"] = true,
	["FS25_ere120"] = true,
	["FS25_ETV_216i"] = true,
	["FS25_FeuerwehrGabelstapler_COM"] = true,
	["FS25_FLC253"] = true,
	["FS25_gameplay_Real_Vehicle_Breakdowns"] = true,
	["FS25_hubtexMaxX45"] = true,
	["FS25_Husqvarna_MZ54"] = true,
	["FS25_Husqvarna_TS146XK"] = true,
	["FS25_JCB_Powerpack"] = true,
	["FS25_jenzBA725D"] = true,
	["FS25_JohnDeere56"] = true,
	["FS25_JohnDeere110_112_RoundFender"] = true,
	["FS25_JohnDeere445"] = true,
	["FS25_JohnDeereGator6x4"] = true,
	["FS25_JohnDeereGatorCX"] = true,
	["FS25_johnDeereXUV865M"] = true,
	["FS25_johnDeereXUV865M_forestry"] = true,
	["FS25_JohnDeere_330_LawnTractor"] = true,
	["FS25_JohnDeere_Gator_Pack"] = true,
	["FS25_John_Deere_XUV845E"] = true,
	["FS25_Jungheinrich_EFG_S50_240"] = true,
	["FS25_Jungheinrich_EFG_S50_PRO"] = true,
	["FS25_Kart_Pallet"] = true,
	["FS25_Kubota_SVL75"] = true,
	["FS25_lizardGolfCart"] = true,
	["FS25_Lizard_AGT450"] = true,
	["FS25_Lizard_Banshee"] = true,
	["FS25_Lizard_Blaster"] = true,
	["FS25_Lizard_FourTrax300"] = true,
	["FS25_Lizard_Kart"] = true,
	["FS25_Lizard_Mini_Buggy"] = true,
	["FS25_Lizard_MountainBike"] = true,
	["FS25_Lizard_Old_Bike"] = true,
	["FS25_Lizard_QuadBigBear"] = true,
	["FS25_Lizard_The_Beast_1000"] = true,
	["FS25_Lizard_TRA_500"] = true,
	["FS25_Lizard_Trold"] = true,
	["FS25_lovaskocsi"] = true,
	["FS25_lovaskocsi_tradicio"] = true,
	["FS25_lsfmFarmEquipmentPack"] = true,
	["FS25_meridianTL1239AL"] = true,
	["FS25_marha_es_lo_mod"] = true,
	["FS25_Moffett_Forklift"] = true,
	["FS25_MrChow_Heli_Bell_47"] = true,
	["FS25_PaggioApePlus"] = true,
	["FS25_PiaggioApe"] = true,
	["FS25_polishWheelbarrow"] = true,
	["FS25_Profihopper"] = true,
	["FS25_RefillableIBCTank"] = true,
	["FS25_Retriever_Plus"] = true,
	["FS25_seed_treater"] = true,
	["FS25_Sluicifer_Washplant"] = true,
	["FS25_TailLiftPack"] = true,
	["FS25_talicska"] = true,
	["FS25_Vermeer_S450TX"] = true,
	["FS25_Wheelbarrow"] = true,
	["Hashy_2025_Bennington_QLINE_Pontoon_Boat"] = true,
	["Hashy_2025_Polaris_Ranger_2_4dr"] = true,
	["Hashy_2025_RZR_1000_XP"] = true,
	["Hashy_Lowe_FM_1775_Boat"] = true,
	["TSN25_2doordefender"] = true,
}