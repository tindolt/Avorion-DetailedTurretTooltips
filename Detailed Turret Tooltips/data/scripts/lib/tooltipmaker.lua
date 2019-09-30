-- Detailed Turret Tooltips by lyravega, .., MrMors, MassCraxx, Mp70
-- v2.1
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("randomext")
include ("stringutility")
if replaceFactionNames==nil then include ("cargotransportlicenseutility") end -- removed in 0.26
include ("inventoryitemprice")

local next, ceil = next, math.ceil

local lyr_burstCheck = 2

local iconColor = ColorRGB(0.5, 0.5, 0.5)
local fadedIconColor = ColorRGB(0.25, 0.25, 0.25)
local textColor = ColorRGB(0.9, 0.9, 0.9)
local fadedTextColor = ColorRGB(0.725, 0.725, 0.725)
local fadedCenterTextColor = ColorRGB(0.375, 0.375, 0.375)
local blackColor = ColorRGB(0, 0, 0)

local fontSize = 14 --14
local lineHeight = 17 --20	
local descriptionFontSize = 12
local descriptionLineHeight = 14
local headlineFontSize = 16
local headlineHeight = 18

local showFighterDpsPerSize = false
local showVanillaDPS = true	

local linesAdded = 0

local function addEmptyLine(tooltip,lineSize)
	linesAdded = 0
	local size = lineSize or 15
	tooltip:addLine(TooltipLine(size, size))
end

local function addLine(tooltip,line)
	linesAdded = linesAdded + 1

	if (linesAdded % 2 == 1) then
		line.iconColor = iconColor
	else
		line.lcolor = fadedTextColor
		line.rcolor = fadedTextColor
		line.iconColor = fadedIconColor
	end
	tooltip:addLine(line)
end

local function fillVanillaDPS(obj,tooltip,dps)
	-- vanilla dps
	if showVanillaDPS and obj.damage > 0 then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Raw DPS"%_t
		line.rtext = round(obj.dps, 1)
		line.icon = "data/textures/icons/screen-impact.png";
		addLine(tooltip,line)
		
		-- per slot
		--local line = TooltipLine(lineHeight, fontSize)
		--line.ltext = "- /slot"%_t
		--line.icon = "data/textures/icons/screen-impact.png";
		--if typ == "turret" and obj.slots > 1 then
		--	line.rtext =  round(obj.dps / obj.slots, 1)
		--	addLine(tooltip,line)
		--elseif typ == "fighter" and obj.volume > 1 then
		--	line.rtext =  round(obj.dps / obj.volume, 1)
		--	addLine(tooltip,line)
		--end

		addEmptyLine(tooltip)
	end	
end

local function fillWeaponTooltipData(obj, tooltip, wpn, typ)
	local lyr = {}
	
	lyr.activeWeaponsPerTurret = obj.simultaneousShooting and obj.numWeapons > 1 and obj.numWeapons or 1
	lyr.projectilesPerTurret = lyr.activeWeaponsPerTurret * wpn.shotsFired
	lyr.damagePerProjectile = wpn.damage
	lyr.damagePerShot = lyr.projectilesPerTurret * lyr.damagePerProjectile
	lyr.shotsPerSecond = obj.fireRate
	lyr.damagePerSecond = lyr.damagePerShot * lyr.shotsPerSecond
	
	lyr.generatesHeat = obj.maxHeat > 0 and obj.heatPerShot > 0
	lyr.demandsPower = obj.coolingType == 2
	lyr.drainsEnergy = obj.coolingType == 1
	
	--lyr.isBurstFire = obj.shootingTime < lyr_burstCheck
	lyr.isMultiShot = lyr.projectilesPerTurret > 1
	
	if lyr.demandsPower or lyr.drainsEnergy then
		lyr.baseEnergyPerShot = lyr.activeWeaponsPerTurret * obj.heatPerShot
		
		if obj.energyIncreasePerSecond > 0 then
			lyr.energyNormalizationPerSecond = obj.coolingRate
			lyr.energyAccumulationPerSecond = lyr.activeWeaponsPerTurret * obj.energyIncreasePerSecond
			lyr.energyAccumulationPerShot = lyr.activeWeaponsPerTurret * (obj.energyIncreasePerSecond / lyr.shotsPerSecond)
		else
			lyr.noAccumulation = true
		end
	elseif lyr.generatesHeat then
		lyr.heatPerShot = lyr.activeWeaponsPerTurret * obj.heatPerShot
		lyr.coolingPerSecond = obj.coolingRate
		lyr.coolingPerShot = lyr.coolingPerSecond / lyr.shotsPerSecond
		
		lyr.instantlyOverheats = lyr.heatPerShot >= obj.maxHeat
		lyr.neverOverheats = not lyr.instantlyOverheats and lyr.coolingPerShot >= lyr.heatPerShot
		
		if not lyr.neverOverheats then
			lyr.accumulatedHeat = lyr.heatPerShot
			lyr.timeToCooldown = 0
			lyr.timeToOverheat = 0
			lyr.shotsToOverheat = 1
			lyr.secondsPerShot = 1/lyr.shotsPerSecond
			
			if lyr.instantlyOverheats then
				lyr.timeToCooldown = lyr.accumulatedHeat / lyr.coolingPerSecond
				
				if lyr.timeToCooldown > lyr.secondsPerShot then
					lyr.shotsPerSecond = 1/lyr.timeToCooldown
					lyr.damagePerSecond = lyr.damagePerShot * lyr.shotsPerSecond
					
					lyr.usesEDPS = true
				end
				
				lyr.isBurstFire = false
			else
				lyr.adjustedHeatPerShot = lyr.heatPerShot - lyr.coolingPerShot
				lyr.adjustedMaxHeat = obj.maxHeat - lyr.heatPerShot
				
				lyr.shotsToOverheat = ceil( lyr.adjustedMaxHeat / lyr.adjustedHeatPerShot ) +1
				lyr.accumulatedHeat = lyr.accumulatedHeat + ( lyr.shotsToOverheat -1) * lyr.adjustedHeatPerShot
				
				lyr.timeToOverheat = lyr.timeToOverheat + ( lyr.shotsToOverheat -1) * lyr.secondsPerShot
				lyr.timeToCooldown = lyr.accumulatedHeat / lyr.coolingPerSecond
				lyr.cycle = lyr.timeToCooldown + lyr.timeToOverheat
				
				lyr.projectilesPerCycle = lyr.shotsToOverheat * lyr.projectilesPerTurret
				--lyr.damagePerCycle = lyr.shotsToOverheat * lyr.damagePerShot
				lyr.damagePerCycle = lyr.projectilesPerCycle * lyr.damagePerProjectile
				lyr.damagePerSecond = lyr.damagePerCycle / lyr.cycle
				
				--lyr.isBurstFire = lyr.timeToOverheat < lyr_burstCheck
				lyr.isBurstFire = obj.shootingTime < lyr_burstCheck
				lyr.usesEDPS = true
			end
		else
			lyr.generatesHeat = false
			lyr.isBurstFire = false
		end
	end

    if lyr.damagePerProjectile > 0 and not isCivilTurret(wpn) then 
		-- weapon turrets
		if wpn.hullDamageMultiplicator == wpn.shieldDamageMultiplicator then
			-- uniform damage weapons
			local line = TooltipLine(lineHeight, fontSize)
			local dps
			if typ == "turret" and obj.slots > 0 then
				line.ltext = (lyr.usesEDPS and "eDPS" or "DPS").." /slot" --lyr_nt
				dps = round((lyr.damagePerSecond * wpn.hullDamageMultiplicator) / obj.slots, 1)
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = (lyr.usesEDPS and "eDPS" or "DPS").." /size" --lyr_nt
				dps = round((lyr.damagePerSecond * wpn.hullDamageMultiplicator) / obj.volume, 1)
			else
				line.ltext = lyr.usesEDPS and "eDPS" or "DPS" --lyr_nt
				dps = round(lyr.damagePerSecond * wpn.hullDamageMultiplicator, 1)
			end
			line.rtext = dps
			line.icon = "data/textures/icons/screen-impact.png";
			addLine(tooltip,line)
			
			fillVanillaDPS(obj, tooltip, dps)
			
			local line = TooltipLine(lineHeight, fontSize)
			if wpn.continuousBeam then
				line.ltext = "Tick Damage" --lyr_nt
				line.rtext = round(lyr.damagePerShot * wpn.hullDamageMultiplicator, 1)
			elseif lyr.isBurstFire then
				line.ltext = "Burst Damage" --lyr_nt
				line.rtext = lyr.projectilesPerCycle.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			else
				line.ltext = "Damage" --lyr_nt
				line.rtext = lyr.isMultiShot and lyr.projectilesPerTurret.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1) or round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/screen-impact.png";
			addLine(tooltip,line)
		else
			-- unequal damage to shield and hull
			local line = TooltipLine(lineHeight, fontSize)
			local hDPS = lyr.damagePerSecond * wpn.hullDamageMultiplicator
			local sDPS = lyr.damagePerSecond * wpn.shieldDamageMultiplicator
			local aDPS = (hDPS + sDPS)/2;

			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Average "..(lyr.usesEDPS and "eDPS" or "DPS").." /slot" --lyr_nt
				line.rtext = round((aDPS) / obj.slots, 1)
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Average "..(lyr.usesEDPS and "eDPS" or "DPS").." /size" --lyr_nt
				line.rtext = round((aDPS) / obj.volume, 1)
			else
				line.ltext = "Average "..(lyr.usesEDPS and "eDPS" or "DPS") --lyr_nt
				line.rtext = round(aDPS, 1)
			end
			line.icon = "data/textures/icons/screen-impact.png";
			addLine(tooltip,line)

			local line = TooltipLine(lineHeight, fontSize)
			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Hull "..(lyr.usesEDPS and "eDPS" or "DPS").." /slot" --lyr_nt
				line.rtext = round((hDPS) / obj.slots, 1)
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Hull "..(lyr.usesEDPS and "eDPS" or "DPS").." /size" --lyr_nt
				line.rtext = round((hDPS) / obj.volume, 1)
			else
				line.ltext = "Hull "..(lyr.usesEDPS and "eDPS" or "DPS") --lyr_nt
				line.rtext = round(hDPS, 1)
			end
			line.icon = "data/textures/icons/health-normal.png";
			addLine(tooltip,line)
			
			local line = TooltipLine(lineHeight, fontSize)
			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Shield "..(lyr.usesEDPS and "eDPS" or "DPS").." /slot" --lyr_nt
				line.rtext = round((sDPS) / obj.slots, 1)
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Shield "..(lyr.usesEDPS and "eDPS" or "DPS").." /size" --lyr_nt
				line.rtext = round((sDPS) / obj.volume, 1)
			else
				line.ltext = "Shield "..(lyr.usesEDPS and "eDPS" or "DPS") --lyr_nt
				line.rtext = round(sDPS, 1)
			end
			line.icon = "data/textures/icons/shield.png";
			addLine(tooltip,line)

			fillVanillaDPS(obj, tooltip)
			
			local line = TooltipLine(lineHeight, fontSize)
			if wpn.continuousBeam then
				line.ltext = "Hull Tick Damage" --lyr_nt
				line.rtext = round(lyr.damagePerShot * wpn.hullDamageMultiplicator, 1)
			elseif lyr.isBurstFire then
				line.ltext = "Hull Burst Damage" --lyr_nt
				line.rtext = lyr.projectilesPerCycle.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			else
				line.ltext = "Hull Damage" --lyr_nt
				line.rtext = lyr.isMultiShot and lyr.projectilesPerTurret.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1) or round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/health-normal.png";
			addLine(tooltip,line)
			
			local line = TooltipLine(lineHeight, fontSize)
			if wpn.continuousBeam then
				line.ltext = "Shield Tick Damage" --lyr_nt
				line.rtext = round(lyr.damagePerShot * wpn.shieldDamageMultiplicator, 1)
			elseif lyr.isBurstFire then
				line.ltext = "Shield Burst Damage" --lyr_nt
				line.rtext = lyr.projectilesPerCycle.."x"..round(lyr.damagePerProjectile * wpn.shieldDamageMultiplicator, 1)
			else
				line.ltext = "Shield Damage" --lyr_nt
				line.rtext = lyr.isMultiShot and lyr.projectilesPerTurret.."x"..round(lyr.damagePerProjectile * wpn.shieldDamageMultiplicator, 1) or round(lyr.damagePerProjectile * wpn.shieldDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/shield.png";
			addLine(tooltip,line)
		end
    elseif isCivilTurret(wpn) then 
        local tType = getCivilTurretType(wpn)		

        if tType.type == "Mining" then
            -- mining turrets
			local line = TooltipLine(lineHeight, fontSize)
			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Mining DPS /slot" --lyr_nt
				line.rtext = round((lyr.damagePerSecond*wpn.stoneDamageMultiplicator) / obj.slots, 1)
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Mining DPS /size" --lyr_nt
				line.rtext = round((lyr.damagePerSecond*wpn.stoneDamageMultiplicator) / obj.volume, 1)
			else
				line.ltext = "Mining DPS" --lyr_nt
				line.rtext = round(lyr.damagePerSecond*wpn.stoneDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/mining.png";
			addLine(tooltip,line)

			fillVanillaDPS(obj, tooltip)
			
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Mining Efficiency" --lyr_nt
			line.rtext = round(wpn[tType.access] * 100, 1).."%"
			line.icon = "data/textures/icons/mining.png";
			addLine(tooltip,line)
		end
		
        if tType.type == "Salvaging" then
			-- salvaging turrets
			local line = TooltipLine(lineHeight, fontSize)
			local dps
			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Salvaging DPS /slot" --lyr_nt
				dps = round((lyr.damagePerSecond * wpn.hullDamageMultiplicator) / obj.slots, 1)
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Salvaging DPS /size" --lyr_nt
				dps = round((lyr.damagePerSecond * wpn.hullDamageMultiplicator) / obj.volume, 1)
			else
				line.ltext = "Salvaging DPS" --lyr_nt
				dps = round(lyr.damagePerSecond * wpn.hullDamageMultiplicator, 1)
			end
			line.rtext = dps
			line.icon = "data/textures/icons/recycle.png";
			addLine(tooltip,line)

			fillVanillaDPS(obj, tooltip, dps)
			
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Salvaging Efficiency" --lyr_nt
			line.rtext = round(wpn[tType.access] * 100, 1).."%"
			line.icon = "data/textures/icons/recycle.png";
			addLine(tooltip,line)
		end
	elseif wpn.otherForce ~= 0 or wpn.selfForce ~= 0 then
		-- force turrets
		if wpn.otherForce > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Push"%_t
			line.rtext = toReadableValue(wpn.otherForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			addLine(tooltip,line)
		elseif wpn.otherForce < 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Pull"%_t
			line.rtext = toReadableValue(-wpn.otherForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			addLine(tooltip,line)
		end
		
		if wpn.selfForce > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Self Push"%_t
			line.rtext = toReadableValue(wpn.selfForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			addLine(tooltip,line)
		elseif wpn.selfForce < 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Self Pull"%_t
			line.rtext = toReadableValue(-wpn.selfForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			addLine(tooltip,line)
		end
	elseif wpn.hullRepair > 0 or wpn.shieldRepair > 0 then
		if wpn.hullRepair > 0 then
			-- hull repair turrets
			local line = TooltipLine(lineHeight, fontSize)
			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Hull HPS /slot" --lyr_nt
				line.rtext = round(obj.hullRepairRate / obj.slots, 1) 
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Hull HPS /size" --lyr_nt
				line.rtext = round(obj.hullRepairRate / obj.volume, 1) 
			else
				line.ltext = "Hull HPS" --lyr_nt
				line.rtext = round(obj.hullRepairRate, 1)
			end
			line.icon = "data/textures/icons/health-normal.png";
			addLine(tooltip,line)
		end
	
		if wpn.shieldRepair > 0 then
			-- shield Repair Turrets
			local line = TooltipLine(lineHeight, fontSize)
			if typ == "turret" and obj.slots > 0 then
				line.ltext = "Shield HPS /slot" --lyr_nt
				line.rtext = round(obj.shieldRepairRate / obj.slots, 1) 
			elseif showFighterDpsPerSize and typ == "fighter" and obj.volume > 0 then
				line.ltext = "Shield HPS /size" --lyr_nt
				line.rtext = round(obj.shieldRepairRate / obj.volume, 1) 
			else
				line.ltext = "Shield HPS" --lyr_nt
				line.rtext = round(obj.shieldRepairRate, 1)
			end
			line.icon = "data/textures/icons/shield.png";
			addLine(tooltip,line)
		end
	end

	if wpn.continuousBeam then
		-- beam gun attribute
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Tick Rate" --lyr_nt
		line.rtext = round(lyr.shotsPerSecond, 2)
		line.icon = "data/textures/icons/bullets.png";
		addLine(tooltip,line)
	elseif lyr.isBurstFire then
		-- burst gun attribute
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Burst Cycle" --lyr_nt
		line.rtext = round(lyr.cycle, 2).."s"
		line.icon = "data/textures/icons/bullets.png";
		addLine(tooltip,line)
	else
		-- fire rate gun attribute
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Fire Rate" --lyr_nt
		line.rtext = round(lyr.shotsPerSecond, 2)
		line.icon = "data/textures/icons/bullets.png";
		addLine(tooltip,line)
	end
	
	addEmptyLine(tooltip)

	if wpn.name == "Railgun" or wpn.shieldPenetration > 0 then
		-- penetration
		if wpn.name == "Railgun" then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Hull Penetration" --lyr_nt
			line.rtext = (wpn.blockPenetration+1).." blocks"
			line.icon = "data/textures/icons/drill.png";
			addLine(tooltip,line)
		end
		
		if wpn.shieldPenetration > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Shield Penetration" --lyr_nt
			line.rtext = round(wpn.shieldPenetration*100, 1).."%"
			line.icon = "data/textures/icons/slashed-shield.png";
			addLine(tooltip,line)
		end
		
		addEmptyLine(tooltip)
	end

	-- weapon independent attributes
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Accuracy"%_t
	line.rtext = (wpn.continuousBeam or wpn.accuracy == 1) and "Absolute" or round(wpn.accuracy * 100, 1).."%"
	line.icon = "data/textures/icons/gunner.png";
	addLine(tooltip,line)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Velocity" --lyr_nt
	line.rtext = wpn.isBeam and "Instant" or round(wpn.pvelocity*10, 0).."m/s"
	line.icon = "data/textures/icons/speedometer.png";
	addLine(tooltip,line)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Range"%_t
	line.rtext = (wpn.isBeam and round(wpn.blength*10/1000, 2) or round(wpn.pvelocity*wpn.pmaximumTime*10/1000, 2)).."km"
	line.icon = "data/textures/icons/target-shot.png";
	addLine(tooltip,line)

	if typ == "turret" then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Tracking Speed" --lyr_nt
		line.rtext = round(obj.turningSpeed, 1)
		line.icon = "data/textures/icons/clockwise-rotation.png";
		addLine(tooltip,line)
	end
	
	addEmptyLine(tooltip)
	
	if lyr.demandsPower then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Requires Power" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Base Demand" --lyr_nt
		line.rtext = toReadableValue(lyr.baseEnergyPerShot*1000000, "W/s")
		line.icon = "data/textures/icons/electric.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Accumulation" --lyr_nt
		line.rtext = lyr.noAccumulation and "None" or "+"..toReadableValue(lyr.energyAccumulationPerSecond*1000000, "W/s")
		line.icon = "data/textures/icons/electric.png";
		line.lcolor = fadedTextColor
		line.rcolor = fadedTextColor
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
	
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Normalization" --lyr_nt
		line.rtext = lyr.noAccumulation and "-" or toReadableValue(lyr.energyNormalizationPerSecond*1000000, "W/s")
		line.icon = "data/textures/icons/electric.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		addEmptyLine(tooltip)
	elseif lyr.drainsEnergy then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Consumes Energy" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Base Drain" --lyr_nt
		line.rtext = toReadableValue(lyr.baseEnergyPerShot*1000000, "J/shot")
		line.icon = "data/textures/icons/battery-pack-alt.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Accumulation" --lyr_nt
		line.rtext = lyr.noAccumulation and "None" or "+"..toReadableValue(lyr.energyAccumulationPerShot*1000000, "J/shot")
		line.icon = "data/textures/icons/battery-pack-alt.png";
		line.lcolor = fadedTextColor
		line.rcolor = fadedTextColor
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
	
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Normalization" --lyr_nt
		line.rtext = lyr.noAccumulation and "-" or toReadableValue(lyr.energyNormalizationPerSecond*1000000, "J/s")
		line.icon = "data/textures/icons/battery-pack-alt.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		addEmptyLine(tooltip)
	elseif lyr.generatesHeat then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Generates Heat" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Continuous Shots"
		line.rtext = lyr.shotsToOverheat
		line.icon = "data/textures/icons/bullets.png";
		line.iconColor = iconColor
		tooltip:addLine(line)

		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Buildup" --lyr_nt
		line.ctext = "+"..round(lyr.heatPerShot*10, 0).."%/shot"
		line.ccolor = fadedCenterTextColor
		line.rtext = lyr.instantlyOverheats and "Instant" or lyr.neverOverheats and "Never" or round(lyr.timeToOverheat, 2).."s"
		line.icon = "data/textures/icons/flame.png";
		line.iconColor = ColorRGB(0.7, 0.4, 0.4)
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Dissipation" --lyr_nt
		line.ctext = "-"..round(lyr.coolingPerSecond*10, 0).."%/s"
		line.ccolor = fadedCenterTextColor
		line.rtext = lyr.neverOverheats and "-" or round(lyr.timeToCooldown, 2).."s"
		line.icon = "data/textures/icons/snowflake-2.png";
		line.iconColor = ColorRGB(0.4, 0.4, 0.7)
		tooltip:addLine(line)
		
		addEmptyLine(tooltip)
	end
	
	local addEmptyLine
	
	if wpn.shieldDamageMultiplicator == 0 then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Ineffective against Shield" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		addEmptyLine = true
	end
	
	if wpn.stoneDamageMultiplicator == 0 then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Ineffective against Stone" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		addEmptyLine = true
	end
	
	if addEmptyLine then
		tooltip:addLine(TooltipLine(15, 15))
	end
end

local function fillDescriptions(obj, tooltip, isFighter)
	
	local extraLines =  0
	local ignoreList = {["Ionized Projectiles"] = true, ["Burst Fire"] = true, ["Consumes Energy"] = true, ["Overheats"] = true, ["%s%% Chance of penetrating shields"] = true}
	local additional = {}
	local descriptions = obj:getDescriptions()
	
	if not isFighter and obj.automatic then
		additional[#additional+1] = {
			ltext = "Independent Targeting", --lyr_nt
			lcolor = ColorRGB(0.6, 1.0, 0.0),
			icon = "data/textures/icons/processor.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	-- coaxial weaponry
	if not isFighter and obj.coaxial then
		additional[#additional+1] = {
			ltext = "Coaxial Weapon", --lyr_nt
			lcolor = ColorRGB(0.8, 0.2, 0.2),
			icon = "data/textures/icons/cog.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
    end
	
	if obj.simultaneousShooting and obj.numWeapons > 1 then
		additional[#additional+1] = {
			ltext = "Synchronized Weapons", --lyr_nt
			lcolor = ColorRGB(0.45, 1.0, 0.15),
			icon = "data/textures/icons/missile-pod.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.shotsPerFiring > 1 then
		additional[#additional+1] = {
			ltext = "Multiple Projectiles", --lyr_nt
			lcolor = ColorRGB(0.30, 1.0, 0.3),
			icon = "data/textures/icons/missile-swarm.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.shootingTime < lyr_burstCheck and obj.shootingTime > 0 then
		additional[#additional+1] = {
			ltext = "Burst Fire", --lyr_nt
			lcolor = ColorRGB(0.15, 1.0, 0.45),
			icon = "data/textures/icons/bullets.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.seeker then
		additional[#additional+1] = {
			ltext = "Guided Missiles", --lyr_nt
			lcolor = ColorRGB(0.0, 1.0, 0.6),
			icon = "data/textures/icons/rocket-thruster.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end

	if descriptions["Ionized Projectiles"] then
		additional[#additional+1] = {
			ltext = "Ionized Projectiles", --lyr_nt
			lcolor = ColorRGB(0.0, 0.6, 1.0),
			icon = "data/textures/icons/slashed-shield.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end

 	for desc, value in next, descriptions do
		if not ignoreList[desc] then
			extraLines = extraLines + 1
		end
	end

    if obj.flavorText ~= "" or not nil then
		local line = TooltipLine(descriptionLineHeight, descriptionFontSize)
		line.ltext = obj.flavorText
		line.lcolor = ColorRGB(1.0, 0.7, 0.7)
		tooltip:addLine(line)
		extraLines = extraLines + 1
	end

	for i = 1, 4 - extraLines do
		tooltip:addLine(TooltipLine(descriptionLineHeight, descriptionFontSize))
	end

	for desc, value in next, descriptions do
		if not ignoreList[desc] then
			local line = TooltipLine(descriptionLineHeight, descriptionFontSize)
			
			if value == "" then
				line.ltext = desc % _t
			else
				line.ltext = string.format(desc % _t, value)
			end
			
			tooltip:addLine(line)
		end
	end
	
	for _, additionalLine in next, additional do
		local line = TooltipLine(lineHeight+2, fontSize+2)
		line.ltext = additionalLine.ltext
		line.lcolor = additionalLine.lcolor
		--line.icon = additionalLine.icon
		line.iconColor = additionalLine.iconColor
		tooltip:addLine(line)
    end
    
    if obj.metalRawEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize-2)
        line.ltext = "Breaks Alloys down into Scrap Metal"
        line.litalic = true
        tooltip:addLine(line)
    end
    if obj.stoneRawEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize-2)
        line.ltext = "Breaks Stone down into Ores"
        line.litalic = true
        tooltip:addLine(line)
    end
    if obj.stoneRefinedEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize-2)
        line.ltext = "Refinement: Refines Stone into Resources"
        line.litalic = true
        tooltip:addLine(line)
    end
    if obj.metalRefinedEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize-2)
        line.ltext = "Refinement: Refines Alloys into Resources"
        line.litalic = true
        tooltip:addLine(line)
    end
end

local function fillObjectTooltipHeader(obj, tooltip, title, isValidObject, typ)
	local line = TooltipLine(headlineHeight, headlineFontSize)
	line.ctext = title
	line.ccolor = obj.rarity.color
	tooltip:addLine(line)
	
	local line = TooltipLine(5, 12)
	if typ == "torpedo" then
		line.ltext = "Tech: "..round(obj.tech, 1)  --lyr_nt
		line.ctext = tostring(obj.rarity)
		--line.rtext = obj.material.name
		line.ccolor = obj.rarity.color
		--line.rcolor = obj.material.color
	else
		line.ltext = "Tech: "..round(obj.averageTech, 1)  --lyr_nt
		line.ctext = tostring(obj.rarity)
		line.rtext = obj.material.name
		line.ccolor = obj.rarity.color
		line.rcolor = obj.material.color
	end
	tooltip:addLine(line)
	
	tooltip:addLine(TooltipLine(25,15))
	
	if not isValidObject then 
		local line = TooltipLine(lineHeight, fontSize)
		line.ccolor = ColorRGB(0.775, 0.225, 0.225)
		line.ctext = ""; tooltip:addLine(line)
		line.ctext = "WARNING: INVALID OBJECT"; tooltip:addLine(line)
		line.citalic = true
		line.ctext = "this "..typ.." has no weapons"; tooltip:addLine(line)
		line.ctext = typ.."s must have at least one"; tooltip:addLine(line)
		line.ctext = "skipping DTT mod calculations"; tooltip:addLine(line)
		line.ctext = ""; tooltip:addLine(line)
	end;
end

function makeTurretTooltip(turret)
	local wpn = turret:getWeapons()
	
	local tooltip = Tooltip()

	-- title & tooltip icon
	local title = ""
	tooltip.icon = turret.weaponIcon

	local weapon = turret.weaponPrefix .. " /* Weapon Prefix*/"
	weapon = weapon % _t

	local tbl = {material = turret.material.name, weaponPrefix = weapon}

	-- if turret.numVisibleWeapons == 1 then
	-- 	title = "${weaponPrefix} Turret"%_t % tbl
	-- elseif turret.numVisibleWeapons == 2 then
	-- 	title = "Double ${weaponPrefix} Turret"%_t % tbl
	-- elseif turret.numVisibleWeapons == 3 then
	-- 	title = "Triple ${weaponPrefix} Turret"%_t % tbl
	-- elseif turret.numVisibleWeapons == 4 then
	-- 	title = "Quad ${weaponPrefix} Turret"%_t % tbl
	-- else
	-- 	title = "Multi ${weaponPrefix} Turret"%_t % tbl
    -- end
    if turret.stoneRefinedEfficiency > 0 or turret.metalRefinedEfficiency > 0
        or turret.stoneRawEfficiency > 0 or turret.metalRawEfficiency > 0  then
        if turret.numVisibleWeapons == 1 then
            title = "${material} ${weaponPrefix} Turret"%_t % tbl
        elseif turret.numVisibleWeapons == 2 then
            title = "Double ${material} ${weaponPrefix} Turret"%_t % tbl
        elseif turret.numVisibleWeapons == 3 then
            title = "Triple ${material} ${weaponPrefix} Turret"%_t % tbl
        elseif turret.numVisibleWeapons == 4 then
            title = "Quad ${material} ${weaponPrefix} Turret"%_t % tbl
        else
            title = "Multi ${material} ${weaponPrefix} Turret"%_t % tbl
        end
    elseif turret.coaxial then
        if turret.numVisibleWeapons == 1 then
            title = "Coaxial ${weaponPrefix}"%_t % tbl
        elseif turret.numVisibleWeapons == 2 then
            title = "Double Coaxial ${weaponPrefix}"%_t % tbl
        elseif turret.numVisibleWeapons == 3 then
            title = "Triple Coaxial ${weaponPrefix}"%_t % tbl
        elseif turret.numVisibleWeapons == 4 then
            title = "Quad Coaxial ${weaponPrefix}"%_t % tbl
        else
            title = "Coaxial Multi ${weaponPrefix}"%_t % tbl
        end
    else
        if turret.numVisibleWeapons == 1 then
            title = "${weaponPrefix} Turret"%_t % tbl
        elseif turret.numVisibleWeapons == 2 then
            title = "Double ${weaponPrefix} Turret"%_t % tbl
        elseif turret.numVisibleWeapons == 3 then
            title = "Triple ${weaponPrefix} Turret"%_t % tbl
        elseif turret.numVisibleWeapons == 4 then
            title = "Quad ${weaponPrefix} Turret"%_t % tbl
        else
            title = "Multi ${weaponPrefix} Turret"%_t % tbl
        end
    end
	
	-- fill header area and weapon data /lyr
	fillObjectTooltipHeader(turret, tooltip, title, wpn and true or false,"turret")
	if wpn then fillWeaponTooltipData(turret, tooltip, wpn, "turret") end
    
    -- Refinement
    if turret.stoneRefinedEfficiency > 0 or turret.metalRefinedEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Refinement"%_t
        line.icon = "data/textures/icons/metal-bar.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end
	-- crew requirements
	local crew = turret:getCrew()

	for crewman, amount in next, crew:getMembers() do
		if amount > 0 then
			local profession = crewman.profession

			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = profession:name(amount)
			line.rtext = round(amount)
			line.icon = profession.icon;
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
	end
	
	-- size
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Size"%_t
	line.rtext = round(turret.size, 1)
	line.icon = "data/textures/icons/shotgun.png";
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)

	-- slots
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Slots"%_t
	line.rtext = round(turret.slots, 1)
	line.icon = "data/textures/icons/small-square.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	tooltip:addLine(TooltipLine(5, 5))

	fillDescriptions(turret, tooltip, false)
	if fillModDescriptions then fillModDescriptions(turret, tooltip) end

	if replaceFactionNames~=nil then replaceFactionNames(tooltip) end
	return tooltip
end

function makeFighterTooltip(fighter)
	local wpn
	local isValidObject

	local tooltip = Tooltip()

	-- title & icon
	local title; if fighter.type == FighterType.Fighter then
		wpn = fighter:getWeapons()
		isValidObject = wpn and true or false
		
		title = "${weaponPrefix} Fighter"%_t % fighter
		tooltip.icon = fighter.weaponIcon
	elseif fighter.type == FighterType.CargoShuttle then
		isValidObject = true
		
		title = "Cargo Shuttle"%_t
		tooltip.icon = "data/textures/icons/crate.png"
	elseif fighter.type == FighterType.CrewShuttle then
		isValidObject = true
		
		title = "Crew Shuttle"%_t
		tooltip.icon = "data/textures/icons/crew.png"
	end
	
	-- fill header area and weapon data /lyr
	fillObjectTooltipHeader(fighter, tooltip, title, isValidObject, "fighter")
	if wpn then fillWeaponTooltipData(fighter, tooltip, wpn, "fighter") end
	
	-- durability
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Durability"%_t
	line.rtext = round(fighter.durability)
	line.icon = "data/textures/icons/health-normal.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Shield"%_t
	line.rtext = fighter.shield > 0 and round(fighter.durability) or "None"
	line.icon = "data/textures/icons/shield.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	tooltip:addLine(TooltipLine(15, 15))

	-- size
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Size"%_t
	line.rtext = round(fighter.volume) --what's the unit?
	line.icon = "data/textures/icons/fighter.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	-- maneuverability
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Maneuverability"%_t
	line.rtext = round(fighter.turningSpeed, 2) --what's the unit?
	line.icon = "data/textures/icons/dodge.png";
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)
	
	-- velocity
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Speed"%_t
	line.rtext = round(fighter.maxVelocity * 10.0).."m/s" --lyr_nt
	line.icon = "data/textures/icons/speedometer.png";
	line.iconColor = iconColor
	tooltip:addLine(line)
	
	tooltip:addLine(TooltipLine(15, 15))

	-- crew requirements
	local pilot = CrewProfession(CrewProfessionType.Pilot)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = pilot:name(fighter.crew)
	line.rtext = round(fighter.crew)
	line.icon = pilot.icon
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)
	
	local num, postfix = getReadableNumber(FighterPrice(fighter))
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Prod. Effort"%_t
	line.rtext = "${num} ${amount}"%_t % {num = tostring(num), amount = postfix}
	line.icon = "data/textures/icons/cog.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	tooltip:addLine(TooltipLine(15, 15))

	fillDescriptions(fighter, tooltip, true)

	if replaceFactionNames~=nil then replaceFactionNames(tooltip) end
	return tooltip
end

function makeTorpedoTooltip(torpedo)
    -- create tool tip
    local tooltip = Tooltip()
    tooltip.icon = torpedo.icon

	fillObjectTooltipHeader(torpedo, tooltip, torpedo.name, true, "torpedo")

    if torpedo.hullDamage > 0 and torpedo.damageVelocityFactor == 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Hull Damage"%_t
        line.rtext = toReadableValue(round(torpedo.hullDamage), "")
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    elseif torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Hull Damage"%_t
        line.rtext = "up to ${damage}"%_t % {damage = toReadableValue(round(torpedo.maxVelocity * torpedo.damageVelocityFactor), "")}
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    if torpedo.shieldDamage > 0 and torpedo.shieldDamage ~= torpedo.hullDamage then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Shield Damage"%_t
        line.rtext = toReadableValue(round(torpedo.shieldDamage), "")
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    -- maneuverability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Maneuverability"%_t
    line.rtext = round(torpedo.turningSpeed, 2)
    line.icon = "data/textures/icons/dodge.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Speed"%_t
    line.rtext = round(torpedo.maxVelocity * 10.0)
    line.icon = "data/textures/icons/speedometer.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    if torpedo.acceleration > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Acceleration"%_t
        line.rtext = round(torpedo.acceleration * 10.0)
        line.icon = "data/textures/icons/acceleration.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Range"%_t
    line.rtext = "${range} km" % {range = round(torpedo.reach * 10 / 1000, 2)}
    line.icon = "data/textures/icons/target-shot.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Storage Energy"%_t
        line.rtext = toReadableValue(round(torpedo.storageEnergyDrain), "W")
        line.icon = "data/textures/icons/electric.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    -- size
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Size"%_t
    line.rtext = round(torpedo.size, 1)
    line.icon = "data/textures/icons/missile-pod.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- durability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Durability"%_t
    line.rtext = round(torpedo.durability)
    line.icon = "data/textures/icons/health-normal.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))
    tooltip:addLine(TooltipLine(15, 15))

    -- specialties
    local extraLines = 0

    if torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Dependent on Velocity"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldDeactivation then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Briefly Deactivates Shields"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.energyDrain then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Drains Target's Energy"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldPenetration then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Penetrates Shields"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldAndHullDamage then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damages Both Shield and Hull"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Requires Energy in Storage"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    for i = 1, 3 - extraLines do
        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end

	if replaceFactionNames~=nil then replaceFactionNames(tooltip) end
    return tooltip

end

function isCivilTurret( weapon )
    return  (weapon.stoneRawEfficiency > 0) or
            (weapon.stoneRefinedEfficiency > 0) or
            (weapon.metalRawEfficiency > 0) or
            (weapon.metalRefinedEfficiency > 0);
end

function getCivilTurretType( weapon )
    local t = {}

    if ((weapon.stoneRawEfficiency > 0) or (weapon.stoneRefinedEfficiency > 0)) then
        t.type = "Mining"
    elseif ((weapon.metalRawEfficiency > 0) or (weapon.metalRefinedEfficiency > 0)) then
        t.type = "Salvaging"
    else
        t.type = "Unknown"
    end

    t.mode = ((weapon.stoneRawEfficiency > 0) or (weapon.metalRawEfficiency > 0)) and "Raw" or "Refining"

    t.access =  (t.mode == "Raw" and t.type == "Mining") and "stoneRawEfficiency" or
                (t.mode == "Refining" and t.type == "Mining") and "stoneRefinedEfficiency" or
                (t.mode == "Raw" and t.type == "Salvaging") and "metalRawEfficiency" or
                (t.mode == "Refining" and t.type == "Salvaging") and "metalRefinedEfficiency";
    return t
end