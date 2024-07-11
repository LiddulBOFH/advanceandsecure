ENT.Type = "point"

-- Simple change for simple network load handling
-- Turning it to TRANSMIT_NEVER means the client will never know it exists, otherwise TRANSMIT_ALWAYS means all clients will know it exists, always
-- This gets forcefully triggered with EditMode is changed
function ENT:UpdateTransmitState()
    if GetGlobalBool("EditMode",false) == true then return TRANSMIT_ALWAYS else return TRANSMIT_NEVER end
end
