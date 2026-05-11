--XENO ONLY--

local Config = {
    Effects = {
        Chorus = {
            Enabled = false,
            Depth = nil,
            Mix = nil,
            Rate = nil
        },
        Distortion = {
            Enabled = true,
            Level = nil
        },
        Equalizer = {
            Enabled = true,
            LowGain = 9.99996586559972,
            MidGain = 9.99996586559972,
            HighGain = 9.99996586559972,
            MidRange = {
                min = 19999.992490431938,
                max = 19999.992490431938
            }
        },
        Flanger = {
            Enabled = false,
            Depth = nil,
            Mix = nil,
            Rate = nil
        },
        Filter = {
            Enabled = false,
            FilterType = nil,
            Frequency = nil,
            Gain = nil,
            Q = nil
        },
        Pitch = {
            Enabled = false,
            Pitch = nil
        },
        Reverb = {
            Enabled = true,
            DecayRatio = nil,
            DecayTime = 0.1,
            Density = nil,
            Diffusion = nil,
            DryLevel = 19.999962072888565,
            EarlyDelayTime = nil,
            HighCutFrequency = nil,
            LateDelayTime = nil,
            LowShelfFrequency = nil,
            LowShelfGain = 11.99998179498651,
            ReferenceFrequency = nil,
            WetLevel = 5.707812820602612
        }
    },
    
    Presets = {
        Alien = false,
        Android = false,
        Chorus = false,
        Demon = false,
        Elf = false,
        Fun = false,
        Funk = false,
        Low = false,
        Radio = false,
        Regular = false,
        Reverb = false,
        Titan = false
    }
}

local Map = {
    Chorus = { gui = "chorus", remote = "chorus", props = { Depth = "depth", Mix = "mix", Rate = "rate" } },
    Distortion = { gui = "distortion", remote = "distortion", props = { Level = "level" } },
    Equalizer = { gui = "equalier", remote = "equalier", props = { LowGain = "low_gain", MidGain = "mid_gain", HighGain = "high_gain" } },
    Flanger = { gui = "flanger", remote = "flanger", props = { Depth = "depth", Mix = "mix", Rate = "rate" } },
    Filter = { gui = "flter", remote = "flter", props = { FilterType = "flter_typ", Frequency = "frequency", Gain = "gain", Q = "q" } },
    Pitch = { gui = "pitch", remote = "pitch", props = { Pitch = "pitch" } },
    Reverb = { gui = "reverb", remote = "reverb", props = { 
        DecayRatio = "decay_ratio", DecayTime = "decay_tim", Density = "density",
        Diffusion = "diffusion", DryLevel = "dry_level", EarlyDelayTime = "early_delay_tim",
        HighCutFrequency = "high_cut_frequency", LateDelayTime = "late_delay_tim",
        LowShelfFrequency = "low_shelf_frequency", LowShelfGain = "low_shelf_gain",
        ReferenceFrequency = "reference_frequency", WetLevel = "wet_level" 
    }}
}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local eventAdd = RS:FindFirstChild("event_effect_add")
local eventProp = RS:FindFirstChild("event_effect_property")

local function clickButton(btn)
    if not btn then return false end
    local ok1 = pcall(function()
        for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
            conn:Fire()
        end
    end)
    if ok1 then return true end
    local ok2 = pcall(function() firesignal(btn.MouseButton1Click) end)
    if ok2 then return true end
    local ok3 = pcall(function()
        for _, conn in ipairs(getconnections(btn.Activated)) do
            conn:Fire()
        end
    end)
    return ok3
end

local function touchSlider(sliderFrame)
    if not sliderFrame then return false end
    
    local restoreProps = {}
    
    for _, desc in ipairs(sliderFrame:GetDescendants()) do
        pcall(function()
            if desc:IsA("Frame") or desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
                local nameLow = desc.Name:lower()
                if nameLow:find("bar") or nameLow:find("fill") or nameLow:find("progress") then
                    table.insert(restoreProps, {desc = desc, prop = "Size", val = desc.Size})
                    desc.Size = UDim2.new(1, 0, desc.Size.Y.Scale, desc.Size.Y.Offset)
                end
                if nameLow:find("knob") or nameLow:find("handle") or nameLow:find("button") or nameLow:find("drag") then
                    table.insert(restoreProps, {desc = desc, prop = "Position", val = desc.Position})
                    desc.Position = UDim2.new(1, 0, desc.Position.Y.Scale, desc.Position.Y.Offset)
                end
            end
            if desc:IsA("NumberValue") or desc:IsA("IntValue") then
                desc.Value = 1
            end
        end)
    end
    
    pcall(function()
        if sliderFrame:IsA("TextButton") or sliderFrame:IsA("ImageButton") then
            clickButton(sliderFrame)
        end
    end)
    
    task.wait(0.05)
    
    for _, data in ipairs(restoreProps) do
        pcall(function()
            if data.prop == "Size" then
                data.desc.Size = data.val
            elseif data.prop == "Position" then
                data.desc.Position = data.val
            end
        end)
    end
    
    return true
end

local function ApplyVoiceEffects()
    print("[Hyperion Volume Enhancer] Initializing Voice Setup...")
    
    local PG = LP:WaitForChild("PlayerGui", 10)
    if not PG then 
        warn("[Hyperion Volume Enhancer] PlayerGui not found.")
        return 
    end

    local hubBg = PG:FindFirstChild("hub") and PG.hub:FindFirstChild("bg")
    local hubToggle = PG:FindFirstChild("hub") and PG.hub:FindFirstChild("toggle") and PG.hub.toggle:FindFirstChild("bg")
    if hubBg and not hubBg.Visible and hubToggle then 
        clickButton(hubToggle) 
        task.wait(0.5)
    end

    local voiceBg = hubBg and hubBg:FindFirstChild("voice") and hubBg.voice:FindFirstChild("bg")
    local voiceToggle = hubBg and hubBg:FindFirstChild("voice") and hubBg.voice:FindFirstChild("toggle")
    if voiceBg and not voiceBg.Visible and voiceToggle then 
        clickButton(voiceToggle) 
        task.wait(0.5)
    end

    if not voiceBg then
        warn("[Hyperion Volume Enhancer] Failed to find voice GUI background.")
        return
    end

    local presetGui = voiceBg:FindFirstChild("preset")
    if presetGui then
        for presetName, enabled in pairs(Config.Presets) do
            if enabled then
                local presetBtn = presetGui:FindFirstChild(presetName:lower())
                if presetBtn and presetBtn:FindFirstChild("activate") then
                    clickButton(presetBtn.activate)
                    task.wait(1)
                end
            end
        end
    end

    for effectName, effectConfig in pairs(Config.Effects) do
        if effectConfig.Enabled then
            local mapInfo = Map[effectName]
            if mapInfo then
                if eventAdd then
                    pcall(function() eventAdd:FireServer(mapInfo.remote) end)
                end
                task.wait(0.3)
                
                local effectGui = voiceBg:FindFirstChild("effect")
                if effectGui then
                    local actGui = effectGui:FindFirstChild(mapInfo.gui)
                    if actGui and actGui:FindFirstChild("activate") then
                        clickButton(actGui.activate)
                        task.wait(0.5)
                    end
                end
                
                local dragGui = voiceBg:FindFirstChild("drag")
                if dragGui then
                    local effectDrag = dragGui:FindFirstChild(mapInfo.gui)
                    if effectDrag then
                        local innerDrag = effectDrag:FindFirstChild("drag") or effectDrag
                        for propName, propVal in pairs(effectConfig) do
                            if propName ~= "Enabled" and propName ~= "MidRange" and propVal ~= nil then
                                local guiPropName = mapInfo.props[propName]
                                if guiPropName then
                                    local sliderFrame = innerDrag:FindFirstChild(guiPropName)
                                    if sliderFrame then
                                        touchSlider(sliderFrame)
                                        task.wait(0.3)
                                    end
                                    
                                    if eventProp then
                                        pcall(function() eventProp:FireServer(mapInfo.remote, propName, propVal) end)
                                    end
                                    task.wait(0.2)
                                end
                            end
                        end
                        
                        if effectName == "Equalizer" and effectConfig.MidRange then
                            local minSlider = innerDrag:FindFirstChild("mid_range_min")
                            local maxSlider = innerDrag:FindFirstChild("mid_range_max")
                            
                            if minSlider then touchSlider(minSlider) task.wait(0.3) end
                            if maxSlider then touchSlider(maxSlider) task.wait(0.3) end
                            
                            if eventProp then
                                pcall(function() eventProp:FireServer("equalier", "MidRange", effectConfig.MidRange) end)
                            end
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
    print("[Hyperion Volume Enhancer] ═══ VOICE EFFECTS SETUP COMPLETE ═══")
end

if LP.Character then
    task.spawn(function()
        task.wait(1)
        ApplyVoiceEffects()
    end)
end

LP.CharacterAdded:Connect(function()
    task.wait(2)
    ApplyVoiceEffects()
end)
