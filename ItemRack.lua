-- Master IR v13.4 — PvP-spec aware + talent-event cached + arena support, without stomping Mounted trinkets
if not ItemRack then return end

-- === Set names ===
local SET_DEFAULT, SET_PVP, SET_MOUNTED = "Default","PvP","Mounted"

-- (Optional) tiny 2-slot set with your baseline trinkets; if you make it, we’ll use it.
local MICRO_TRINKETS = "Default - Trinkets"  -- leave as-is or create this set (Trinket1/2 only)

-- If you want specific trinkets on PvP -> Default, put their exact names here (else leave "")
local PREFERRED_13, PREFERRED_14 = "", ""    -- e.g. "Royal Seal of Eldre'Thalas", "Darkmoon Card: Heroism"

local INSIGNIA = "Insignia of the Horde"

-- Smooth mount/dismount aura spam outdoors
local HOLD_MOUNT    = 0.30   -- pin Mounted right after mount
local HOLD_DISMOUNT = 0.90   -- stick to Default briefly after dismount

-- State
local inInst, instType = IsInInstance()
local mounted = IsMounted()
local now = GetTime()

-- PvP state: spec 1 = PvP, spec 2 = PvE
-- Cache the new spec immediately when the talent-group-changed event fires,
-- so we don't have to wait for some later event to see the new spec.
if event == "ACTIVE_TALENT_GROUP_CHANGED" then
  local newSpec = tonumber(arg1)
  if newSpec then
    IR__activeSpec = newSpec
  end
end

local activeSpec = IR__activeSpec
if not activeSpec and GetActiveTalentGroup then
  activeSpec = GetActiveTalentGroup()
  IR__activeSpec = activeSpec
end
if not activeSpec then
  activeSpec = 2
  IR__activeSpec = activeSpec
end

local inPvPSpec = (activeSpec == 1)
local inStructuredPVP = inInst and (instType == "pvp" or instType == "arena")

-- Track mount transitions
IR__mountedPrev    = (IR__mountedPrev == nil) and mounted or IR__mountedPrev
IR__lastMountAt    = IR__lastMountAt    or 0
IR__lastDismountAt = IR__lastDismountAt or 0

if mounted and not IR__mountedPrev then
  IR__lastMountAt = now
elseif not mounted and IR__mountedPrev then
  IR__lastDismountAt = now
end
IR__mountedPrev = mounted

-- Windows (outdoors only)
local inMountWindow    = (not inInst) and (now - IR__lastMountAt)    <= HOLD_MOUNT
local inDismountWindow = (not inInst) and (now - IR__lastDismountAt) <= HOLD_DISMOUNT

-- Decide desired set
local desired
if inStructuredPVP then
  -- BGs + arenas always use PvP
  desired = SET_PVP
elseif inInst then
  -- Other instances: use PvP if in PvP spec, else Default
  desired = inPvPSpec and SET_PVP or SET_DEFAULT
else
  -- Outdoors
  if mounted or inMountWindow then
    desired = SET_MOUNTED
  elseif inPvPSpec then
    desired = SET_PVP
  elseif inDismountWindow then
    desired = SET_DEFAULT
  else
    desired = SET_DEFAULT
  end
end

-- Helper: equip a specific trinket into a slot (if named), else any non-Insignia trinket from bags
local function equipPreferredOrAny(slot, preferred)
  if InCombatLockdown() then return false end
  if preferred and preferred ~= "" then
    EquipItemByName(preferred, slot)
    return true
  end
  for bag=0,4 do
    local slots = GetContainerNumSlots(bag)
    for i=1,slots do
      local link = GetContainerItemLink(bag,i)
      if link then
        local name, _, _, _, _, _, _, _, loc = GetItemInfo(link)
        if loc == "INVTYPE_TRINKET" and name ~= INSIGNIA then
          EquipItemByName(name, slot)
          return true
        end
      end
    end
  end
  return false
end

-- ONLY snap Insignia off when leaving PvP for Default
local leavingPVPToDefault = (IR_LAST_SET == SET_PVP and desired == SET_DEFAULT)

-- Defer while in combat
if InCombatLockdown() then
  IR__pending = desired
  if leavingPVPToDefault then IR__kickInsigniaAfterCombat = true end
  return
end

if IR__pending then
  desired = IR__pending
  IR__pending = nil
end

-- Equip only on change
if IR_LAST_SET ~= desired then
  ItemRack.EquipSet(desired)
  IR_LAST_SET = desired

  -- Special case: PvP -> Default only
  if leavingPVPToDefault or IR__kickInsigniaAfterCombat then
    IR__kickInsigniaAfterCombat = nil

    if ItemRackUser and ItemRackUser.Sets and ItemRackUser.Sets[MICRO_TRINKETS] then
      ItemRack.EquipSet(MICRO_TRINKETS)
    else
      local id13 = GetInventoryItemID("player", 13)
      local name13 = id13 and GetItemInfo(id13)
      local id14 = GetInventoryItemID("player", 14)
      local name14 = id14 and GetItemInfo(id14)

      if name13 == INSIGNIA then equipPreferredOrAny(13, PREFERRED_13) end
      if name14 == INSIGNIA then equipPreferredOrAny(14, PREFERRED_14) end
    end
  end
end
