-- Master IR v13.6 compact + talent recheck
if not ItemRack then return end
local D,P,M="Default","PvP","Mounted"
local MT="Default - Trinkets"
local P13,P14="",""
local INS="Insignia of the Horde"
local HM=.3

local function swap(slot,pref)
  if InCombatLockdown() then return end
  if pref~="" then EquipItemByName(pref,slot) return end
  for b=0,4 do
    for i=1,GetContainerNumSlots(b) do
      local l=GetContainerItemLink(b,i)
      if l then
        local n,_,_,_,_,_,_,_,loc=GetItemInfo(l)
        if loc=="INVTYPE_TRINKET" and n~=INS then EquipItemByName(n,slot) return end
      end
    end
  end
end

local function apply()
  local inInst,t=IsInInstance()
  local m=IsMounted()
  local now=GetTime()

  local spec=IR__spec or (GetActiveTalentGroup and GetActiveTalentGroup()) or 2
  IR__spec=spec

  IR__mountedPrev=(IR__mountedPrev==nil) and m or IR__mountedPrev
  IR__lastMountAt=IR__lastMountAt or 0
  if m and not IR__mountedPrev then IR__lastMountAt=now end
  IR__mountedPrev=m

  local desired
  if inInst and (t=="pvp" or t=="arena") then
    desired=P
  elseif inInst then
    desired=(spec==1) and P or D
  else
    desired=(m or (now-IR__lastMountAt)<=HM) and M or ((spec==1) and P or D)
  end

  local leaving=(IR_LAST_SET==P and desired==D)

  if InCombatLockdown() then
    IR__pending=desired
    if leaving then IR__kick=1 end
    return
  end

  if IR__pending then desired=IR__pending IR__pending=nil end

  if IR_LAST_SET~=desired then
    ItemRack.EquipSet(desired)
    IR_LAST_SET=desired
  end

  if leaving or IR__kick then
    IR__kick=nil
    if ItemRackUser and ItemRackUser.Sets and ItemRackUser.Sets[MT] then
      ItemRack.EquipSet(MT)
    else
      local l=GetInventoryItemLink("player",13)
      if l and GetItemInfo(l)==INS then swap(13,P13) end
      l=GetInventoryItemLink("player",14)
      if l and GetItemInfo(l)==INS then swap(14,P14) end
    end
  end
end

if event=="ACTIVE_TALENT_GROUP_CHANGED" and tonumber(arg1) then
  IR__spec=tonumber(arg1)
end

apply()

if event=="ACTIVE_TALENT_GROUP_CHANGED" or event=="PLAYER_TALENT_UPDATE" then
  if not IR__specTimer then IR__specTimer=CreateFrame("Frame") end
  local t=0
  IR__specTimer:SetScript("OnUpdate",function(self,el)
    t=t+el
    if t<0.4 then return end
    self:SetScript("OnUpdate",nil)
    IR__spec=(GetActiveTalentGroup and GetActiveTalentGroup()) or IR__spec or 2
    apply()
  end)
end
