local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local media = LibStub("LibSharedMedia-3.0")
local mod = Skada:NewModule("ParticleDisplay")

-- Set module properties
mod.name = L["Particle Display"]
mod.description = L["Options for the particle display."]

-- Particle system variables
local MAX_PARTICLES_PER_PLAYER = 30
local MIN_PARTICLE_SIZE = 2
local MAX_PARTICLE_SIZE = 8
local PARTICLE_SPEED_FACTOR = 0.2
local FLOW_WIDTH = 200

-- Local functions
local CreateFrame = CreateFrame
local pairs, ipairs = pairs, ipairs
local math_random, math_floor = math.random, math.floor
local GetTime = GetTime or function() return 0 end

-- Custom wipe function
local function clearTable(t)
    if type(t) ~= "table" then return {} end
    for k in pairs(t) do t[k] = nil end
    return t
end

-- Texture path for particles
local DEFAULT_TEXTURE = "Round"
local function GetParticleTexture(win)
    if win and win.db and win.db.particletexture then
        return media:Fetch("statusbar", win.db.particletexture)
    else
        return media:Fetch("statusbar", DEFAULT_TEXTURE)
    end
end

-- Register with Skada
function mod:OnEnable()
    Skada:AddDisplaySystem("particle", mod)
end

function mod:OnDisable()
    -- Clean up any active animations
    for _, win in pairs(Skada:GetWindows()) do
        if win.display and win.display.animationFrame then
            win.display.animationFrame:SetScript("OnUpdate", nil)
        end
    end
end

-- Apply settings to the display
function mod:ApplySettings(win)
    local display = win.display
    if not display then return end
    
    -- Update display settings from window settings
    display.particleDensity = win.db.particle_density or 1
    display.particleSpeed = win.db.particle_speed or 1
    display.particleSize = win.db.particle_size or 1
    display.particleSpacing = win.db.particle_spacing or 1
    display.spellEffects = win.db.spell_effects
    display.criticalEffects = win.db.critical_effects
    display.fadeParticles = win.db.fade_particles ~= false
    display.useClassColors = win.db.use_class_colors ~= false
    display.customColor = win.db.custom_color or {r = 1, g = 1, b = 1, a = 1}
    
    -- Update the display
    if win.selectedmode then
        win:UpdateDisplay()
    end
end

-- Add display options
function mod:AddDisplayOptions(win, options)
    options.particle = {
        type = "group",
        name = L["Particle Display"],
        desc = L["Particle display settings."],
        order = 20,
        args = {
            particle_density = {
                type = "range",
                name = L["Particle Density"],
                desc = L["Adjusts the number of particles shown."],
                min = 0.1,
                max = 2,
                step = 0.1,
                order = 1,
                width = "double",
                set = function(_, val)
                    win.db.particle_density = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.particle_density or 1
                end
            },
            particle_speed = {
                type = "range",
                name = L["Particle Speed"],
                desc = L["Adjusts the speed of the particles."],
                min = 0.5,
                max = 2,
                step = 0.1,
                order = 2,
                width = "double",
                set = function(_, val)
                    win.db.particle_speed = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.particle_speed or 1
                end
            },
            particle_size = {
                type = "range",
                name = L["Particle Size"],
                desc = L["Adjusts the size of the particles."],
                min = 0.5,
                max = 2,
                step = 0.1,
                order = 3,
                width = "double",
                set = function(_, val)
                    win.db.particle_size = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.particle_size or 1
                end
            },
            particle_spacing = {
                type = "range",
                name = L["Particle Spacing"],
                desc = L["Adjusts the spacing between particles."],
                min = 0.5,
                max = 2,
                step = 0.1,
                order = 4,
                width = "double",
                set = function(_, val)
                    win.db.particle_spacing = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.particle_spacing or 1
                end
            },
            particletexture = {
                type = "select",
                name = L["Particle Texture"],
                desc = L["Select a texture for the particles."],
                order = 5,
                values = media:List("statusbar"),
                set = function(_, val)
                    win.db.particletexture = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.particletexture or DEFAULT_TEXTURE
                end
            },
            header1 = {
                type = "header",
                name = L["Visual Effects"],
                order = 10
            },
            spell_effects = {
                type = "toggle",
                name = L["Spell Effects"],
                desc = L["Show spell effects on particles."],
                order = 11,
                width = "double",
                set = function(_, val)
                    win.db.spell_effects = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.spell_effects
                end
            },
            critical_effects = {
                type = "toggle",
                name = L["Critical Effects"],
                desc = L["Show critical hit effects on particles."],
                order = 12,
                width = "double",
                set = function(_, val)
                    win.db.critical_effects = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.critical_effects
                end
            },
            fade_particles = {
                type = "toggle",
                name = L["Fade Particles"],
                desc = L["Fade particles as they reach the end of their path."],
                order = 13,
                width = "double",
                set = function(_, val)
                    win.db.fade_particles = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.fade_particles ~= false
                end
            },
            header2 = {
                type = "header",
                name = L["Color Options"],
                order = 20
            },
            use_class_colors = {
                type = "toggle",
                name = L["Use Class Colors"],
                desc = L["Color particles based on player class."],
                order = 21,
                width = "double",
                set = function(_, val)
                    win.db.use_class_colors = val
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    return win.db.use_class_colors ~= false
                end
            },
            custom_color = {
                type = "color",
                name = L["Custom Color"],
                desc = L["Set a custom color for particles when not using class colors."],
                order = 22,
                hasAlpha = true,
                disabled = function() return win.db.use_class_colors ~= false end,
                set = function(_, r, g, b, a)
                    win.db.custom_color = win.db.custom_color or {}
                    win.db.custom_color.r = r
                    win.db.custom_color.g = g
                    win.db.custom_color.b = b
                    win.db.custom_color.a = a
                    Skada:UpdateDisplay(true)
                end,
                get = function()
                    local c = win.db.custom_color or {r = 1, g = 1, b = 1, a = 1}
                    return c.r, c.g, c.b, c.a
                end
            }
        }
    }
end

function mod:Create(win)
    -- Create main display frame
    local display = CreateFrame("Frame", win.db.name.."ParticleDisplay", win.frame)
    display:SetAllPoints(win.frame)
    
    -- Create title
    display.title = CreateFrame("Frame", nil, display)
    display.title:SetPoint("TOPLEFT", display, "TOPLEFT")
    display.title:SetPoint("TOPRIGHT", display, "TOPRIGHT")
    display.title:SetHeight(15)
    display.title.label = display.title:CreateFontString(nil, "OVERLAY")
    display.title.label:SetPoint("LEFT", display.title, "LEFT", 2, 0)
    display.title.label:SetJustifyH("LEFT")
    display.title.label:SetFont(media:Fetch("font", "Arial Narrow"), 10)
    display.title.label:SetTextColor(1, 1, 1, 1)
    
    -- Create particle container
    display.particleContainer = CreateFrame("Frame", nil, display)
    display.particleContainer:SetPoint("TOPLEFT", display, "TOPLEFT", 5, -20)
    display.particleContainer:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", -5, 5)
    
    -- Create particle pools and streams
    display.particlePools = {}
    display.streams = {}
    display.textures = {}
    
    -- Default settings
    display.particleDensity = win.db.particle_density or 1
    display.particleSpeed = win.db.particle_speed or 1
    display.particleSize = win.db.particle_size or 1
    display.particleSpacing = win.db.particle_spacing or 1
    display.spellEffects = win.db.spell_effects
    display.criticalEffects = win.db.critical_effects
    display.fadeParticles = win.db.fade_particles ~= false
    display.useClassColors = win.db.use_class_colors ~= false
    display.customColor = win.db.custom_color or {r = 1, g = 1, b = 1, a = 1}
    
    -- Store reference to window
    display.win = win
    
    -- Create animation frame
    display.animationFrame = CreateFrame("Frame", nil, display)
    display.animationFrame:SetScript("OnUpdate", function(self, elapsed)
        mod:UpdateParticles(display, elapsed)
    end)
    
    return display
end

-- Wipe method to clear the display when needed
function mod:Wipe(win)
    if not win or not win.display then return end
    
    local display = win.display
    
    -- Clear all streams
    if display.streams then
        clearTable(display.streams)
    end
    
    -- Hide all textures
    if display.textures then
        for _, texture in pairs(display.textures) do
            texture:Hide()
        end
    end
    
    -- Reset title
    if display.title and display.title.label then
        display.title.label:SetText("")
    end
    
    -- Hide particle container
    if display.particleContainer then
        display.particleContainer:Hide()
    end
    
    -- Hide animation frame
    if display.animationFrame then
        display.animationFrame:Hide()
    end
end

-- Destroy method to clean up the display when switching to another display type
function mod:Destroy(win)
    if not win or not win.display then return end
    
    local display = win.display
    
    -- Stop any animations
    if display.animationFrame then
        display.animationFrame:SetScript("OnUpdate", nil)
        display.animationFrame:Hide()
    end
    
    -- Clear all streams
    if display.streams then
        clearTable(display.streams)
    end
    
    -- Release all textures
    if display.textures then
        for _, texture in pairs(display.textures) do
            texture:Hide()
            texture:SetParent(nil)
        end
        clearTable(display.textures)
    end
    
    -- Clean up frames
    if display.particleContainer then
        display.particleContainer:Hide()
        display.particleContainer:SetParent(nil)
    end
    
    if display.title then
        display.title:Hide()
        display.title:SetParent(nil)
    end
    
    -- Remove frame
    display:Hide()
    display:SetParent(nil)
    
    -- Break circular references
    display.win = nil
end

function mod:Update(win)
    local display = win.display
    if not display then return end
    
    -- Update title
    if display.title and display.title.label then
        display.title.label:SetText(win.metadata and win.metadata.title or win.db.name or "")
    end
    
    -- Clear existing streams
    if not display.streams then
        display.streams = {}
    else
        clearTable(display.streams)
    end
    
    -- Get dataset
    local dataset = win.dataset
    if not dataset or #dataset == 0 then return end
    
    -- Create streams for each player
    local maxValue = dataset[1] and dataset[1].value or 1
    for i, data in ipairs(dataset) do
        if i <= 10 and data.id and data.value and data.value > 0 then
            local stream = {
                id = data.id,
                name = data.label,
                value = data.value,
                class = data.class,
                color = data.color or {r = 1, g = 1, b = 1},
                lastParticleTime = 0,
                particles = {}
            }
            display.streams[data.id] = stream
        end
    end
    
    -- Show particle container
    if display.particleContainer then
        display.particleContainer:Show()
    end
    
    -- Show animation frame
    if display.animationFrame then
        display.animationFrame:Show()
    end
end

-- Update particle animations
function mod:UpdateParticles(display, elapsed)
    if not display or not display.streams then return end
    
    local currentTime = GetTime()
    local totalValue = 0
    
    -- Calculate total value for scaling
    for _, stream in pairs(display.streams) do
        totalValue = totalValue + stream.value
    end
    
    if totalValue == 0 then return end
    
    -- Update existing particles
    for _, stream in pairs(display.streams) do
        -- Remove old particles
        for i = #stream.particles, 1, -1 do
            local particle = stream.particles[i]
            if not particle.texture then
                table.remove(stream.particles, i)
            else
                -- Update particle position
                local speed = particle.speed * display.particleSpeed * elapsed
                particle.x = particle.x + speed
                
                -- Remove particles that have moved off the screen
                if particle.x > FLOW_WIDTH then
                    particle.texture:Hide()
                    table.remove(stream.particles, i)
                else
                    -- Update particle visual
                    particle.texture:SetPoint("CENTER", display.particleContainer, "LEFT", particle.x, particle.y)
                    
                    -- Optional: Add some vertical movement
                    particle.y = particle.y + math_random(-1, 1) * elapsed
                    
                    -- Optional: Fade out as they approach the end
                    if particle.x > FLOW_WIDTH * 0.8 then
                        local alpha = 1 - ((particle.x - FLOW_WIDTH * 0.8) / (FLOW_WIDTH * 0.2))
                        particle.texture:SetAlpha(alpha)
                    end
                end
            end
        end
        
        -- Add new particles based on value
        local particleRate = stream.value / totalValue * MAX_PARTICLES_PER_PLAYER * display.particleDensity
        local timeSinceLastParticle = currentTime - stream.lastParticleTime
        
        if timeSinceLastParticle > 1 / particleRate then
            -- Create a new particle
            local particle = {
                x = 0,
                y = math_random(-40, 40),
                size = math_random(MIN_PARTICLE_SIZE, MAX_PARTICLE_SIZE) * display.particleSize,
                speed = math_random(80, 120) / 100 * PARTICLE_SPEED_FACTOR,
                color = display.useClassColors and stream.color or display.customColor
            }
            
            -- Create or reuse a texture
            local texture = nil
            for _, tex in ipairs(display.textures) do
                if not tex:IsShown() then
                    texture = tex
                    break
                end
            end
            
            if not texture then
                texture = display.particleContainer:CreateTexture(nil, "OVERLAY")
                table.insert(display.textures, texture)
            end
            
            -- Set up the texture
            texture:SetTexture(GetParticleTexture(display.win))
            texture:SetSize(particle.size, particle.size)
            texture:SetPoint("CENTER", display.particleContainer, "LEFT", particle.x, particle.y)
            texture:SetVertexColor(particle.color.r or 1, particle.color.g or 1, particle.color.b or 1, particle.color.a or 1)
            texture:SetAlpha(1)
            texture:Show()
            
            particle.texture = texture
            table.insert(stream.particles, particle)
            
            stream.lastParticleTime = currentTime
        end
    end
end

-- Set the title of the window
function mod:SetTitle(win, title)
    if not win or not win.display then return end
    
    local display = win.display
    if display.title and display.title.label then
        display.title.label:SetText(title or "")
    end
end
