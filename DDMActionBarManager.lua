local addon = ...
local events = CreateFrame("Frame")
local book = C_SpellBook
local bank = Enum.SpellBookSpellBank.Player
local ignored, window, previous, queued
local learned, rows = {}, {}

local function ScanBook()
    local spells, highest = {}, {}
    for line = 1, book.GetNumSpellBookSkillLines() do
        local info = book.GetSpellBookSkillLineInfo(line)
        if info and not info.offSpecID then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local spell = book.GetSpellBookItemInfo(slot, bank)
                if spell and spell.spellID and not spell.isPassive and not spell.isOffSpec
                    and book.IsSpellKnown(spell.spellID, bank) then
                    local name, label = book.GetSpellBookItemName(slot, bank)
                    local prefix, digits, suffix = (label or ""):match("^(.-)(%d+)(%D*)$")
                    if name and digits then
                        local family = name .. "\031" .. prefix .. "\031" .. suffix
                        local rank = tonumber(digits)
                        local entry = { id = spell.spellID, slot = slot, family = family,
                            name = name, label = label, rank = rank }
                        spells[entry.id] = entry
                        if not highest[family] or rank > highest[family].rank then
                            highest[family] = entry
                        end
                    end
                end
            end
        end
    end
    return spells, highest
end

local function FindUpgrades(spells, highest)
    local results = {}
    for slot = 1, math.max(180, NUM_ACTIONBAR_SLOTS or 0) do
        local kind, id = GetActionInfo(slot)
        local equipped = kind == "spell" and spells[id]
        local best = equipped and highest[equipped.family]
        if best and best.rank > equipped.rank and ignored[slot] ~= id then
            results[#results + 1] = { slot = slot, equipped = equipped, best = best }
        end
    end
    return results
end

local function Replace(result)
    if InCombatLockdown() then
        return "Leave combat before replacing a spell."
    end
    if GetCursorInfo() then
        return "Empty your cursor before replacing a spell."
    end

    local kind, id = GetActionInfo(result.slot)
    local best = result.best
    local current = book.GetSpellBookItemInfo(best.slot, bank)
    if kind ~= "spell" or id ~= result.equipped.id or not current
        or best.id ~= current.spellID or not book.IsSpellKnown(best.id, bank) then
        return "The bar or spellbook changed. Review the refreshed list."
    end

    local pickedUp = pcall(book.PickupSpellBookItem, best.slot, bank)
    if not pickedUp or GetCursorInfo() ~= "spell" then
        ClearCursor()
        return "Could not pick up the replacement spell."
    end
    local placed = pcall(PlaceAction, result.slot)
    local newKind, newID = GetActionInfo(result.slot)
    ClearCursor()
    if not placed or newKind ~= "spell" or newID ~= best.id then
        return "Could not verify the replacement. Check the action slot."
    end
    return ("Updated slot %d to %s %s."):format(result.slot, best.name, best.label)
end

local function Button(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    return button
end

local Refresh
local function CreateWindow()
    local frame = CreateFrame("Frame", "DDMActionBarManagerWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(570, 340)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText("DDM Action Bar Manager")
    tinsert(UISpecialFrames, frame:GetName())

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.status:SetPoint("TOPLEFT", 14, -34)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -58)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
    frame.content = CreateFrame("Frame", nil, scroll)
    frame.content:SetSize(510, 1)
    scroll:SetScrollChild(frame.content)

    local reset = Button(frame, "Reset kept ranks", 130)
    reset:SetPoint("BOTTOMRIGHT", -14, 12)
    reset:SetScript("OnClick", function()
        wipe(ignored)
        Refresh()
    end)
    return frame
end

local function Render(results, message)
    if not window or not window:IsShown() then
        return
    end
    window.status:SetText(message or (#results == 0 and "No higher learned ranks found."
        or ("%d action slots have a higher learned rank."):format(#results)))
    for index, result in ipairs(results) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, window.content)
            row:SetSize(510, 28)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
            row.keep = Button(row, "Keep rank", 85)
            row.keep:SetPoint("RIGHT")
            row.replace = Button(row, "Replace", 80)
            row.replace:SetPoint("RIGHT", row.keep, "LEFT", -4, 0)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT")
            row.label:SetPoint("RIGHT", row.replace, "LEFT", -4, 0)
            row.label:SetJustifyH("LEFT")
            rows[index] = row
        end
        row.label:SetText(("Slot %d   %s (%s to %s)"):format(
            result.slot, result.equipped.name, result.equipped.label, result.best.label))
        row.replace:SetEnabled(not InCombatLockdown())
        row.replace:SetScript("OnClick", function()
            local message = Replace(result)
            print("DDM Action Bar Manager: " .. message)
            Refresh(message)
        end)
        row.keep:SetScript("OnClick", function()
            ignored[result.slot] = result.equipped.id
            Refresh()
        end)
        row:Show()
    end
    for index = #results + 1, #rows do
        rows[index]:Hide()
    end
    window.content:SetHeight(math.max(1, #results * 28))
end

Refresh = function(message)
    local spells, highest = ScanBook()
    local results = FindUpgrades(spells, highest)
    local alerts = {}
    for _, result in ipairs(results) do
        local best = result.best
        if learned[best.id] or (previous and not previous[best.id]) then
            local alert = alerts[best.id]
            if not alert then
                alert = { spell = best, slots = {} }
                alerts[best.id] = alert
            end
            alert.slots[#alert.slots + 1] = tostring(result.slot)
        end
    end
    for _, alert in pairs(alerts) do
        print(("%s %s learned. Older rank in slot(s) %s. Type /ddmabm to review."):format(
            alert.spell.name, alert.spell.label, table.concat(alert.slots, ", ")))
    end
    wipe(learned)
    previous = spells
    Render(results, message)
end

local function QueueRefresh()
    if queued then
        return
    end
    queued = true
    C_Timer.After(0.15, function()
        queued = false
        Refresh()
    end)
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, spellID)
    if event == "ADDON_LOADED" then
        if spellID ~= addon then
            return
        end
        self:UnregisterEvent(event)
        DDMActionBarManagerDB = DDMActionBarManagerDB or {}
        DDMActionBarManagerDB.ignored = DDMActionBarManagerDB.ignored or {}
        ignored = DDMActionBarManagerDB.ignored
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
        self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        SLASH_DDMACTIONBARMANAGER1 = "/ddmabm"
        SlashCmdList.DDMACTIONBARMANAGER = function()
            window = window or CreateWindow()
            window:Show()
            Refresh()
        end
        return
    end
    if event == "LEARNED_SPELL_IN_SKILL_LINE" and spellID then
        learned[spellID] = true
    end
    QueueRefresh()
end)
