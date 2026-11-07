-- ============================================================================
-- IMPORTANT NOTICE POPUP LUA (Made for @SohailPG1)
-- Safe to use alongside other mods. Shows in Training & Lobby (40-60s).
-- ============================================================================

local NoticePopupShown = false

local function ShowImportantNotice()
    if NoticePopupShown then return end
    
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        local Web = require("client.slua.logic.url.logic_webview_sdk")
        if not Msg or not Msg.Show then return end

        local Title = "IMPORTANT NOTICE"
        local Message = [[
WARNING: Don't use any file.
PUBG Mobile has created a new AI cheating detection.
Please wait for the next update (4.7).
I am fixing all anti-cheat detections.
Play your game easily. Love you all and thanks for your trust!]]

        Msg.Show(2, Title, Message, 
            function() 
                if Web and Web.OpenURL then Web:OpenURL("https://t.me/SohailPG1") end
            end, 
            function() end, 
            "JOIN TELEGRAM", 
            "CLOSE"
        )
        
        NoticePopupShown = true
        print("[NoticePopup] Popup Shown Successfully!")
    end)
end

local function CheckGameStateForNotice()
    pcall(function()
        if NoticePopupShown then return end
        
        -- Check for Training Ground
        local isTraining = false
        if CGameState and slua.isValid(CGameState) then
            if CGameState.bIsTrainingMode or CGameState.STDeadBoxClientShowFeature then
                isTraining = true
            end
        end
        
        if isTraining then
            ShowImportantNotice()
            return
        end
        
        -- Check for Lobby Countdown (40s to 60s)
        local ok, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if ok and GameplayData then
            local GS = GameplayData.GetGameState and GameplayData.GetGameState()
            if slua.isValid(GS) then
                local state = GS:GetGameModeState()
                if state == "ReadyState" or state == "StartState" then
                    local remainTime = 0
                    pcall(function()
                        if GS.GetRemainingStartTime then remainTime = GS:GetRemainingStartTime() end
                    end)
                    
                    if remainTime >= 40 and remainTime <= 60 then
                        ShowImportantNotice()
                    end
                end
            end
        end
    end)
end

-- Start the timer loop
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(2.0, function()
            CheckGameStateForNotice()
        end, -1, 1.0)
    end
end)

print("[NoticePopup] Script Loaded Successfully!")
