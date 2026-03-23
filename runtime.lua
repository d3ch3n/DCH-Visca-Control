--vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv UDP vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

if Properties["Connection"].Value == "UDP" then
  Connection = UdpSocket.New()
elseif Properties["Connection"].Value == "TCP" then
  Connection = TcpSocket.New()
  Connection.ReadTimeout = 0
  Connection.WriteTimeout = 0
  Connection.ReconnectTimeout = 5
elseif Properties["Connection"].Value == "RS232" then
  Connection = SerialPorts[1]
end

ConnectionOpen = false

IPAddressCtl = Controls["system_ip_address"]
IPPortCtl = Controls["system_ip_port"]

IPAddress = IPAddressCtl.String
Port = IPPortCtl.Value

LocalIPAddress = nil
LocalPort = nil
LocalNICName = nil

PollInteval = 10

function SelectNIC()
  if LocalNICName ~= nil then
    local nics = Network.Interfaces()
    for i,nic in ipairs(nics) do
      if nic.Interface == LocalNICName then
        LocalIPAddress = nic.Address
      end
    end
  end
end

function Connected()
  print("Socket Opened")
  ConnectionOpen = true
  CommsPoll()
end

function OpenPorts(ip, port)
  Connection:Open(ip, port)
end

function OpenSocket()
  if LocalIPAddress ~= nil then
    local portGood, err = pcall(OpenPorts, LocalIPAddress, LocalPort)
    if not portGood then
      print("Error opening UDP Socket: " .. err)
    else
      Connected()
    end
  else
    OpenPorts(nil,nil)
    Connected()
  end
end

function Send(command)
  if ConnectionOpen then

    if Properties["Connection"].Value == "UDP" then
      Connection:Send(IPAddress, Port, command)

    elseif Properties["Connection"].Value == "TCP" then
      Connection:Write(command)

    elseif Properties["Connection"].Value == "RS232" then
      Connection:Write(command)
    end

  else
    Initialize()
    Send(command)
  end
end

function Close()
  Connection:Close()
  ConnectionOpen=false
  Controls["system_online"].Boolean = false
  CommsPollTimer:Stop()
end

-- Data handlers

if Properties["Connection"].Value == "UDP" then

  Connection.Data = function(socket, packet)
    if string.sub(packet.Data, 1, 2) == "\x01\x11" then
      Controls["system_online"].Boolean = true
      CommsTimeoutTimer:Start(PollInteval * 2.5)
    end
  end

elseif Properties["Connection"].Value == "TCP" then

  Connection.Data = function(socket)
  end

  Connection.Connected = function()
    Controls["system_online"].Boolean = true
    ConnectionOpen = true
  end

  Connection.Closed = function()
    Controls["system_online"].Boolean = false
    ConnectionOpen = false
  end

elseif Properties["Connection"].Value == "RS232" then

  Connection.Data = function(port)
    port:ReadLine(SerialPorts.EOL.Any)
    Controls["system_online"].Boolean = true
  end

  Connection.Connected = function()
    ConnectionOpen = true
  end
end

function Initialize()

  Controls["system_online"].Boolean = false

  IPAddress = IPAddressCtl.String
  Port = IPPortCtl.Value

  if ConnectionOpen == true then
    Close()
  end

  if Properties["Connection"].Value == "UDP" then

    if IPAddress.String ~= "" then
      SelectNIC()
      OpenSocket()
    end

  elseif Properties["Connection"].Value == "TCP" then

    if IPAddress.String ~= "" then
      Connection:Connect(IPAddress, Port)
    end

  elseif Properties["Connection"].Value == "RS232" then
    Connection:Open(9600, 8, "N")
  end
end

IPAddressCtl.EventHandler = Initialize
IPPortCtl.EventHandler = Initialize

--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

local MsgSeqIndex = 0
local PresetHold = nil

local NumPresets = Properties["Num Presets"].Value
local PresetHoldTime = Properties["Preset Hold Time"].Value

local PanSpeed = Controls["setup_pan_speed"].Value
local TiltSpeed = Controls["setup_tilt_speed"].Value
local ZoomSpeed = Controls["setup_zoom_speed"].Value

function HexToString(num, len)

  local val = num
  local ret = ""

  for i = 1, len do
    ret = string.char(val & 0xff) .. ret
    val = math.floor(val / 0x100)
  end

  return ret
end

function VISCA(typ, msg)

  if ConnectionOpen == true then

    CommsPollTimer:Start(PollInteval)

    local msgType = string.char(0x01,0x00)

    if string.sub(typ, 1, 3) == "Inq" then
      msgType = string.char(0x01,0x10)
    end

    local msgLen = HexToString(#msg, 2)

    if MsgSeqIndex < 0xFFFFFFFF then
      MsgSeqIndex = MsgSeqIndex + 1
    else
      MsgSeqIndex = 0
    end

    local msgSeq = HexToString(MsgSeqIndex, 4)

    local viscaMsg = ""

    if Properties["Command Set"].Value == "VISCA" then
      viscaMsg = msg

    elseif Properties["Command Set"].Value == "VISCA over IP" then
      viscaMsg = msgType .. msgLen .. msgSeq .. msg
    end

    Send(viscaMsg)
  end
end


function PTZ_Control(func)

  local PS = PanSpeed
  local TS = TiltSpeed
  local ID = Controls["setup_camera_id"].Value + 128

  if func == "preset_home_load" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x04,0xff))

  elseif func == "tilt_up" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x03,0x01,0xff))

  elseif func == "tilt_down" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x03,0x02,0xff))

  elseif func == "pan_left" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x01,0x03,0xff))

  elseif func == "pan_right" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x02,0x03,0xff))

  elseif func == "pan_right_tilt_up" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x02,0x01,0xff))

  elseif func == "pan_right_tilt_down" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x02,0x02,0xff))

  elseif func == "pan_left_tilt_down" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x01,0x02,0xff))

  elseif func == "pan_left_tilt_up" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,PS,TS,0x01,0x01,0xff))

  elseif func == "zoom_in" then
    VISCA("Cmd", string.char(ID,0x01,0x04,0x07,(0x20 + ZoomSpeed),0xff))

  elseif func == "zoom_out" then
    VISCA("Cmd", string.char(ID,0x01,0x04,0x07,(0x30 + ZoomSpeed),0xff))

  elseif func == "pan_tilt_stop" then
    VISCA("Cmd", string.char(ID,0x01,0x06,0x01,0x00,0x00,0x03,0x03,0xff))

  elseif func == "zoom_stop" then
    VISCA("Cmd", string.char(ID,0x01,0x04,0x07,0x00,0xff))

  -- Tracking

  elseif func == "tracking_on" then
    VISCA("Cmd", string.char(ID,0x0A,0x11,0x54,0x02,0xff))

  elseif func == "tracking_off" then
    VISCA("Cmd", string.char(ID,0x0A,0x11,0x54,0x03,0xff))

  -- Figure Size

  elseif func == "tracking_figure_full" then
    VISCA("Cmd", string.char(ID,0x0A,0x0F,0x01,0x00,0x00,0xff))

  elseif func == "tracking_figure_half_body" then
    VISCA("Cmd", string.char(ID,0x0A,0x0F,0x01,0x00,0x01,0xff))

  elseif func == "tracking_figure_close_up" then
    VISCA("Cmd", string.char(ID,0x0A,0x0F,0x01,0x00,0x02,0xff))

  -- Placement

  elseif func == "tracking_place_left" then
    VISCA("Cmd", string.char(ID,0x0A,0x0F,0x01,0x07,0x00,0xff))

  elseif func == "tracking_place_center" then
    VISCA("Cmd", string.char(ID,0x0A,0x0F,0x01,0x07,0x01,0xff))

  elseif func == "tracking_place_right" then
    VISCA("Cmd", string.char(ID,0x0A,0x0F,0x01,0x07,0x02,0xff))
  end
end


-- Event Handlers

for key, val in pairs(Controls) do
 
  if string.sub(key, -6, -1) == "_speed" then

    val.EventHandler = function()

      PanSpeed = Controls["setup_pan_speed"].Value
      TiltSpeed = Controls["setup_tilt_speed"].Value
      ZoomSpeed = Controls["setup_zoom_speed"].Value

    end

  elseif string.sub(key, 1, 4) == "pan_" or
         string.sub(key, 1, 5) == "tilt_" or
         string.sub(key, 1, 5) == "zoom_" or
         string.sub(key, 1, 16) == "tracking_figure_" or
         string.sub(key, 1, 15) == "tracking_place_" or
         string.sub(key, 1, 9) == "tracking_" or

         key == "preset_home_load" then

    val.EventHandler = function(ctl)

      if ctl.Boolean == true then
        PTZ_Control(key)

      elseif key == "zoom_in" or key == "zoom_out" then
        PTZ_Control("zoom_stop")

      elseif key ~= "preset_home_load" and string.sub(key,1,9) ~= "tracking_" then
        PTZ_Control("pan_tilt_stop")
      end
    end
  end
end

-- Polling

CommsPollTimer = Timer.New()

function CommsPoll()
  VISCA("Inq", string.char(Controls["setup_camera_id"].Value + 128,0x09,0x00,0x02,0xFF))
end

CommsPollTimer.EventHandler = CommsPoll


CommsTimeoutTimer = Timer.New()

function CommsTimeout()
  CommsTimeoutTimer:Stop()
  Controls["system_online"].Boolean = false
end

CommsTimeoutTimer.EventHandler = CommsTimeout

Initialize()