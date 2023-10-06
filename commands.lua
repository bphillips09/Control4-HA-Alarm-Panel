local ARM_HOME = 1
local ARM_AWAY = 2
local ARM_NIGHT = 4
local TRIGGER = 8
local ARM_CUSTOM_BYPASS = 16
local ARM_VACATION = 32

-- Create a table to map enum values to their names
local enum_to_name = {
    [ARM_HOME] = "ARM_HOME",
    [ARM_AWAY] = "ARM_AWAY",
    [ARM_NIGHT] = "ARM_NIGHT",
    [TRIGGER] = "TRIGGER",
    [ARM_CUSTOM_BYPASS] = "ARM_CUSTOM_BYPASS",
    [ARM_VACATION] = "ARM_VACATION"
}

SUPPORTED_FEATURES = {}
CodeRequired = false

function DRV.OnDriverLateInit(init)
    C4:SendToProxy(5002, "PARTITION_ENABLED", { ENABLED = "true" }, "NOTIFY")
    C4:SendToProxy(5002, "PARTITION_STATE_INIT", { STATE = "DISARMED_NOT_READY", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
    C4:SendToProxy(5001, "PANEL_INITIALIZED", {}, "NOTIFY")
end

function RFP.PARTITION_ARM(idBinding, strCommand, tParams)
    local bypass = tParams.Bypass
    local armType = tParams.ArmType
    local userCode = tParams.UserCode

    local serviceArmType = "alarm_arm_home"

    if armType == "Home" then
        serviceArmType = "alarm_arm_home"
    elseif armType == "Away" then
        serviceArmType = "alarm_arm_away"
    elseif armType == "Night" then
        serviceArmType = "alarm_arm_night"
    elseif armType == "Vacation" then
        serviceArmType = "alarm_arm_vacation"
    elseif armType == "Custom Bypass" then
        serviceArmType = "alarm_arm_custom_bypass"
    end

    AlarmServiceCall(serviceArmType, { code = tostring(userCode) })
end

function RFP.PARTITION_DISARM(idBinding, strCommand, tParams)
    local userCode = tParams.UserCode

    AlarmServiceCall("alarm_disarm", { code = tostring(userCode) })
end

function RFP.KEY_PRESS(idBinding, strCommand, tParams)
    local key = tParams.KeyName
end

function RFP.EXECUTE_EMERGENCY(idBinding, strCommand, tParams)
    local emergency = tParams.EmergencyType
end

function AlarmServiceCall(service, data)
    local alarmServiceCall = {
        domain = "alarm_control_panel",
        service = service,

        service_data = data,

        target = {
            entity_id = EntityID
        }
    }

    local tParams = {
        JSON = JSON:encode(alarmServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        print("NO DATA")
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if state ~= nil then
        if state == "disarmed" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT", { STATE = "DISARMED_READY", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "arming" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT", { STATE = "EXIT_DELAY", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "armed_home" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT",
                { STATE = "ARMED", TYPE = "Home", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "armed_away" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT",
                { STATE = "ARMED", TYPE = "Away", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "armed_night" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT",
                { STATE = "ARMED", TYPE = "Night", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "armed_vacation" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT",
                { STATE = "ARMED", TYPE = "Vacation", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "armed_custom_bypass" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT",
                { STATE = "ARMED", TYPE = "Custom Bypass", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        elseif state == "triggered" then
            C4:SendToProxy(5002, "PARTITION_STATE_INIT",
                { STATE = "ALARM", TYPE = "Burglary", CODE_REQUIRED_TO_CLEAR = false }, "NOTIFY")
        end
    end

    if attributes == nil then
        return
    end

    local selectedAttribute = attributes["code_arm_required"]
    if selectedAttribute ~= nil then
        if selectedAttribute == true or selectedAttribute == "true" then
            CodeRequired = true
        end

        C4:SendToProxy(5002, "CODE_REQUIRED", { CODE_REQUIRED_TO_ARM = CodeRequired }, "NOTIFY")
    end
end
