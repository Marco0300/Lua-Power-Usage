local component = require("component")
local gpu = component.gpu
local probe = component.ElnProbe
local event = require("event")
local computer = require("computer") -- Include the computer library


-- Set up the screen resolution
gpu.setResolution(60, 15)


-- Function to convert voltage to power
local function voltageToPower(voltage)
    return voltage * 1000 / 5
end


-- Function to set the text color based on power level
local function setTextColor(power)
    if power < 200 then
        gpu.setForeground(0x00FF00) -- Green for low power
    elseif power < 500 then
        gpu.setForeground(0xFFFF00) -- Yellow for medium power
    else
        gpu.setForeground(0xFF0000) -- Red for high power
    end
end


-- Function to format power display
local function formatPower(power)
    if power >= 1000 then
        return string.format("%.2f", power / 1000) .. "MW"
    else
        return string.format("%.2f", power) .. "kW"
    end
end


-- Function to update and display the current power
local function updateCurrentPower(power)
    local formattedPower = formatPower(power)
    gpu.set(1, 1, "Current Power: ")
    setTextColor(power)
    gpu.set(15, 1, formattedPower)
    gpu.setForeground(0xFFFFFF) -- Reset to default color
end


-- Function to update and display the highest KW used
local function updateHighestPower(power, highestPower)
    if power > highestPower then
        highestPower = power
    end
    local formattedHighestPower = formatPower(highestPower)
    gpu.set(1, 2, "Highest Power: " .. formattedHighestPower)
    return highestPower
end


-- Function to update and display the KWh used
local function updateKWh(power, timeStep, totalKWh)
    local kWhIncrement = power * timeStep / 3600 -- Convert power to kWh for the time step
    totalKWh = totalKWh + kWhIncrement
    local formattedTotalKWh = string.format("%.2f", totalKWh)
    gpu.set(1, 3, "Total KWh: " .. formattedTotalKWh)
    return totalKWh
end


-- Function to calculate and display the cost of KWh used
local function updateCost(totalKWh)
    local costPerKWh = 2.62 -- Cost per KWh in dollars
    local totalCost = totalKWh * costPerKWh
    local formattedTotalCost = string.format("%.2f", totalCost)
    gpu.set(1, 5, "Total Cost: $" .. formattedTotalCost)
end


-- Function to update and display the power level indicator
local function updatePowerLevelIndicator(power)
    local maxPower = 1000 -- Define maximum power for full bar (1000kW)
    local barLength = 50 -- Define the length of the power bar
    local powerLevel = math.min(power / maxPower, 1) -- Ensure powerLevel is between 0 and 1
    local filledLength = math.floor(powerLevel * barLength)

    setTextColor(power)
    
    local fullBlock = "█"
    local partialBlock = {"▏", "▎", "▍", "▌", "▋", "▊", "▉"}

    local bar = string.rep(fullBlock, filledLength)
    
    if filledLength < barLength then
        local fraction = (powerLevel * barLength) % 1
        local partialIndex = math.ceil(fraction * #partialBlock)
        if partialIndex > 0 then
            bar = bar .. partialBlock[partialIndex]
        end
        bar = bar .. string.rep(" ", barLength - filledLength - 1)
    end

    gpu.set(1, 4, "[" .. bar .. "]")
    gpu.setForeground(0xFFFFFF) -- Reset to default color
end


-- Function to handle button press events
local function buttonHandler(_, address, button, state)
    if state == 1 then -- Button pressed
        probe.signalSetOut("XP", 5) -- Set output signal to 5V
    else -- Button released
        probe.signalSetOut("XP", 0) -- Reset output signal to 0V
    end
end


-- Function to handle touch events for the on/off button
local function touchHandler(_, _, x, y)
    if y == 6 and x >= 1 and x <= 20 then
        local currentState = probe.signalGetOut("ZP")
        if currentState > 0 then
            probe.signalSetOut("ZP", 0) -- Turn off
            gpu.set(1, 6, "[ Macerator Bank 1 ON  ]")
        else
            probe.signalSetOut("ZP", 5) -- Turn on
            gpu.set(1, 6, "[ Macerator Bank 1 OFF ]")
        end
    end
end


-- Initialize variables for highest power and total KWh
local highestPower = 0
local totalKWh = 0
local timeStep = 0.1 -- Time step between measurements in seconds


-- Register the button press event handler
event.listen("button_press", buttonHandler)
event.listen("touch", touchHandler)


-- Initialize the on/off button
gpu.set(1, 6, "[ Macerator Bank 1 ON  ]")

-- Function to handle touch events for the reboot button
local function touchHandler(_, _, x, y)
    -- Check if the reboot button was touched
    if y == 14 and x >= 1 and x <= 15 then -- Adjust the coordinates as needed
        -- Display a confirmation message
        gpu.setForeground(0xFF0000) -- Red color for warning
        gpu.set(1, 15, "Rebooting...")
        gpu.setForeground(0xFFFFFF) -- Reset to default color
        
        -- Wait for a short period to give the user time to see the message
        os.sleep(1)
        
        -- Reboot the computer
        computer.shutdown(true)
    end
end

-- Register the touch event handler
event.listen("touch", touchHandler)


-- Main loop to display power in real-time
while true do
    -- Read the incoming signal (raw voltage)
    local rawVoltage = probe.signalGetIn("YP")
    
    -- Scale the raw voltage to the 0 to 5V range
    local voltage = rawVoltage * 5
    
    -- Convert voltage to power
    local power = voltageToPower(voltage)
    
    -- Update and display the current power
    updateCurrentPower(power)
    
    -- Update and display the highest power used
    highestPower = updateHighestPower(power, highestPower)
    
    -- Update and display the total KWh used
    totalKWh = updateKWh(power, timeStep, totalKWh)
    
    -- Update and display the cost of KWh used
    updateCost(totalKWh)
    
    -- Update and display the power level indicator
    updatePowerLevelIndicator(power)
    
    -- Check for overload condition
    if power > 850 then
        -- Display overload warning
        gpu.setForeground(0xFF0000) -- Red color for warning
        gpu.set(1, 7, "OVERLOAD WARNING: Power usage above 850 kW!")
        gpu.setForeground(0xFFFFFF) -- Reset to default color
    else
        -- Clear any previous overload warning
        gpu.set(1, 7, "")
    end
    
    -- Short delay before updating again
    os.sleep(timeStep)
end
