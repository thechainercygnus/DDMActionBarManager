local addon = ...
local events = CreateFrame("Frame")
local book = C_SpellBook
local bank = Enum.SpellBookSpellBank.Player
local ignored, settings, window, minimapButton, previous, queued
local learned, rows, failedAutoReplacements = {}, {}, {}

local function PrintMessage(message)
    print("|cffc9a8ff[DDM Action Bar Manager]|r " .. message)
end


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

-- Action page assignments from Forever's Edit Mode action bars.
local barNames = {
    [1] = "Main Bar",
    [2] = "Main Bar Page 2",
    [3] = "Action Bar 4",
    [4] = "Action Bar 5",
    [5] = "Action Bar 3",
    [6] = "Action Bar 2",
    [13] = "Action Bar 6",
    [14] = "Action Bar 7",
    [15] = "Action Bar 8",
}

local function DescribeSlot(slot)
    local page = math.floor((slot - 1) / 12) + 1
    local button = (slot - 1) % 12 + 1
    local bar = barNames[page] or ("Action Page %d"):format(page)
    return ("%s, Button %d (slot %d)"):format(bar, button, slot)
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
    return ("Updated %s to %s %s."):format(DescribeSlot(result.slot), best.name, best.label), true
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
    local rowHeight = 38
    for index, result in ipairs(results) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, window.content)
            row:SetSize(510, rowHeight)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
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
        row.label:SetText(("%s\n%s (%s to %s)"):format(
            DescribeSlot(result.slot), result.equipped.name, result.equipped.label, result.best.label))
        row.replace:SetEnabled(not InCombatLockdown())
        row.replace:SetScript("OnClick", function()
            local message = Replace(result)
            PrintMessage(message)
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
    window.content:SetHeight(math.max(1, #results * rowHeight))
end

local function AutoReplace(results)
    if not settings.autoReplace or InCombatLockdown() or GetCursorInfo() then
        return false
    end

    local changed = false
    for _, result in ipairs(results) do
        local key = ("%d:%d:%d"):format(result.slot, result.equipped.id, result.best.id)
        if not failedAutoReplacements[key] then
            local message, replaced = Replace(result)
            if replaced then
                changed = true
                PrintMessage(message)
            else
                -- Pickup and placement can fire events even if a replacement fails.
                failedAutoReplacements[key] = true
                PrintMessage(("Auto-replace failed on %s. %s Use /ddmabm to review."):format(
                    DescribeSlot(result.slot), message))
            end
        end
    end
    return changed
end

Refresh = function(message)
    local spells, highest = ScanBook()
    local results = FindUpgrades(spells, highest)
    if AutoReplace(results) then
        results = FindUpgrades(spells, highest)
    end
    local alerts = {}
    for _, result in ipairs(results) do
        local best = result.best
        if settings.chatAlerts and (learned[best.id] or (previous and not previous[best.id])) then
            local alert = alerts[best.id]
            if not alert then
                alert = { spell = best, slots = {} }
                alerts[best.id] = alert
            end
            alert.slots[#alert.slots + 1] = DescribeSlot(result.slot)
        end
    end
    for _, alert in pairs(alerts) do
        PrintMessage(("%s %s learned. Older rank on %s. Type /ddmabm to review."):format(
            alert.spell.name, alert.spell.label, table.concat(alert.slots, "; ")))
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

local function OpenRankList()
    window = window or CreateWindow()
    window:Show()
    Refresh()
end

local function AddSettings(menu)
    menu:CreateCheckbox("Auto-replace lower ranks", function()
        return settings.autoReplace == true
    end, function()
        settings.autoReplace = not settings.autoReplace
        wipe(failedAutoReplacements)
        if settings.autoReplace then
            PrintMessage("Auto-replace is on for existing and newly detected lower ranks.")
            QueueRefresh()
        end
    end)
    menu:CreateCheckbox("Show minimap button", function()
        return settings.showMinimap
    end, function()
        settings.showMinimap = not settings.showMinimap
        minimapButton:SetShown(settings.showMinimap)
    end)
    menu:CreateCheckbox("Announce newly learned ranks in chat", function()
        return settings.chatAlerts
    end, function()
        settings.chatAlerts = not settings.chatAlerts
    end)
end

local function PositionMinimapButton(button)
    local borderOffset = 5
    local angle = settings.minimapAngle or math.pi / 4
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        x * (Minimap:GetWidth() / 2 + borderOffset), y * (Minimap:GetHeight() / 2 + borderOffset))
end

local function MoveMinimapButton(button)
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then
        return
    end
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local x = cursorX / scale - centerX
    local y = cursorY / scale - centerY
    if x ~= 0 or y ~= 0 then
        settings.minimapAngle = math.atan2(y / Minimap:GetHeight(), x / Minimap:GetWidth())
        PositionMinimapButton(button)
    end
end

local function StopMinimapDrag(button)
    button:SetScript("OnUpdate", nil)
end


local function CreateMinimapButton()
    local button = CreateFrame("Button", "DDMActionBarManagerMinimapButton", Minimap)
    button:SetSize(30, 30)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 50)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", MoveMinimapButton)
    end)
    button:SetScript("OnDragStop", StopMinimapDrag)
    button:SetScript("OnHide", StopMinimapDrag)
    PositionMinimapButton(button)
    Minimap:HookScript("OnSizeChanged", function()
        PositionMinimapButton(button)
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("DDM Action Bar Manager")
        GameTooltip:AddLine("Left-click to review spell ranks", 1, 1, 1)
        GameTooltip:AddLine("Right-click for settings", 1, 1, 1)
        GameTooltip:AddLine("Drag to move", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        GameTooltip:Hide()
        if mouseButton == "RightButton" then
            MenuUtil.CreateContextMenu(self, function(_, menu)
                menu:CreateTitle("DDM Action Bar Manager")
                AddSettings(menu:CreateButton("Settings", function() end))
            end)
        else
            OpenRankList()
        end
    end)
    button:SetShown(settings.showMinimap)
    return button
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
        self:RegisterEvent("CURSOR_CHANGED")
        SLASH_DDMACTIONBARMANAGER1 = "/ddmabm"
        local db = DDMActionBarManagerDB
        db.settings = db.settings or {}
        settings = db.settings
        if settings.showMinimap == nil then
            settings.showMinimap = true
        end
        if settings.chatAlerts == nil then
            settings.chatAlerts = true
        end
        SlashCmdList.DDMACTIONBARMANAGER = function(command)
            if command:match("^%s*settings%s*$") then
                if minimapButton then
                    MenuUtil.CreateContextMenu(UIParent, function(_, menu)
                        menu:CreateTitle("DDM Action Bar Manager Settings")
                        AddSettings(menu)
                    end)
                end
            else
                OpenRankList()
            end
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        minimapButton = CreateMinimapButton()
        if not settings.autoReplace and not settings.autoReplaceNoticeShown then
            PrintMessage("Auto-replace is off by default. Enable it with /ddmabm settings.")
            settings.autoReplaceNoticeShown = true
        end
    end
    if event == "LEARNED_SPELL_IN_SKILL_LINE" and spellID then
        learned[spellID] = true
    end
    if event ~= "CURSOR_CHANGED" or settings.autoReplace then
        QueueRefresh()
    end
end)
