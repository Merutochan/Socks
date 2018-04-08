------------------------------------------------------------------------

-- Meru 
-- Server/Client Test
-- merutochan@gmail.com

-- General purpose packet structure: ID TYPE DATA (all as ints)
-- Logout Packet: ID TYPE=2
-- Movement Packet: ID TYPE=3 X Y DX DY
-- Chat Packet: ID TYPE=4 MSG

------------------------------------------------------------------------

hostName = "localhost" 
portNo = 42069
socket = require "socket"

LOGOUT_PACKET = 2
MOVEMENT_PACKET = 3
CHAT_PACKET = 4

TIME_INTERVAL = 10 -- (ms)
CHAT_OPEN_TIME = 3 -- (s)
CHAT_LOG = 8

------------------------------------------------------------------------

-- Load Player
function loadPg(x,y,id)
	local pg = {}
	-- Prepare unique id
	pg.x = x
	pg.y = y
	pg.id = id
	pg.vx = 2
	pg.vy = 2
	pg.dx = 0
	pg.dy = 0
	return pg
end

-- Search Player in array Players by ID
function searchPlayerByID(id)
	local i
	for i=1,#players do
		if (players[i].id==id) then
			return i
		end
	end
	return -1
end

-- Open (Process) a Packet
function processPacket(data)
	local packet={}
	local packet2={}
	local i = 0
	local p
	
	-- Extract values from packet
	for word in string.gmatch(data, "%-?%d+") do
		packet[i] = tonumber(word)
		i=i+1
	end
	
	for i=1,#players do
		if(packet[0] == players[i].id) then
			-- MOVEMENT PACKET
			-- Update actual position and differential of Player
			if(packet[1] == MOVEMENT_PACKET) then
				players[i].x = packet[2]
				players[i].y = packet[3]
				players[i].dx = packet[4]
				players[i].dy = packet[5]
				return
			end
			-- LOGOUT PACKET
			-- Remove Player
			if(packet[1] == LOGOUT_PACKET) then
				print("Remove player ", packet[0])
				table.remove(players, searchPlayerByID(packet[0]))
				return
			end
			-- CHAT PACKET
			-- Append Message to Chatlog
			if(packet[1] == CHAT_PACKET) then
				-- Remove id from data
				data = string.gsub(data, "%d+", "")
				-- Remove CHAT_PACKET from data
				data = string.gsub(data, "%d+", "")
				-- Remove the HASH
				data = string.gsub(data, "%d+", "")
				-- Add chat element m to chatlog
				data = string.sub(data, 2, -1)
				local m = {}
				m.id = packet[0]
				m.msg = data
				table.insert(chatLog, m)
				-- Reset chat timeout
				chatTimeout = socket.gettime()
			end
		end
	end
	
	-- MOVEMENT PACKET OF NEW CLIENT ADDS CLIENTS INFO
	if (packet[1] == MOVEMENT_PACKET) then 
		print("Adding player ", packet[0])
		p = loadPg(packet[2], packet[3], packet[0])
		table.insert(players, p)
	end

end

-- Text Input
function love.textinput(t)
    if (chatOpen) then
		-- If char belongs to ascii set
		if(string.byte(t)<128) then
			chatInput = chatInput .. t
		-- An awful exception for accents (sorry non-italians lol)
		elseif(t=='à') then
			chatInput = chatInput .. "a'"
		elseif(t=='è') then
			chatInput = chatInput .. "e'"
		elseif(t=='ì') then
			chatInput = chatInput .. "i'"
		elseif(t=='ò') then
			chatInput = chatInput .. "o'"
		elseif(t=='ù') then
			chatInput = chatInput .. "u'"
		end
	end
end

-- Receive packet from server
function receiveFromServer()
	local send
	-- Receive server message
	local data, msg
	data, msg = udp:receive()
	if data then
		processPacket(data)
	end
end

-- Chat control
function chatControl()

	if (not love.keyboard.isDown("backspace")) then
		delPressed = false
	end
	if (love.keyboard.isDown('t') and not chatOpen) then
		chatOpen = true
	end
	if (chatOpen and love.keyboard.isDown("backspace") 
		and not delPressed) then
		chatInput = string.sub(chatInput, 1, -2)
		delPressed = true
	end
	if (chatOpen and love.keyboard.isDown("return")) then
		-- Cut string to 64 characters
		if (string.len(chatInput)>64) then
			chatInput = string.sub(chatInput, 1, 64)
		end
		-- Check if string without whitespaces is still longer than 1
		-- (avoid spam)
		local strip = string.gsub(chatInput, "%s*", "")
		if(string.len(strip)>0) then
			sendChatData()
		end
		chatOpen = false
		chatInput = ""
	end
	if (chatOpen and love.keyboard.isDown("escape")) then
		chatOpen = false
		chatInput = ""
	end
end

-- Player Movement
function playerMovementControl()
	-- Temporarily reset dx and dy
	players[1].dx = 0
	players[1].dy = 0
	if (not chatOpen) then	
		if love.keyboard.isDown('w') then
			players[1].y = players[1].y - players[1].vy
			players[1].dy = -(players[1].vy)
		elseif love.keyboard.isDown('s') then
			players[1].y = players[1].y + players[1].vy
			players[1].dy = players[1].vy
		elseif love.keyboard.isDown('a') then
			players[1].x = players[1].x - players[1].vx
			players[1].dx = -(players[1].vx)
		elseif love.keyboard.isDown('d') then
			players[1].x = players[1].x + players[1].vx
			players[1].dx = players[1].vx
		end
	end
	-- Update other Players' movement through prevision
	for i=2,#players do
		players[i].x = players[i].x + players[i].dx
		players[i].y = players[i].y + players[i].dy
	end
end

-- Send Movement Packet
function sendMovementData()
	if ((socket.gettime()*1000 - t)>=TIME_INTERVAL) then
		send = string.format("%d %d %d %d %d %d\n",
								players[1].id, MOVEMENT_PACKET, 
								players[1].x, players[1].y, 
								players[1].dx, players[1].dy)
		udp:send(send)
		t=socket.gettime()
	end
end

-- Dumb Hash function
function hashMSG()
	local hash = 0
	for i=1,#chatInput do
		hash = hash + string.byte(string.sub(chatInput,i,i));
	end
	return hash
end

-- Send Chat Data
function sendChatData()
	local send = string.format("%d %d %d %s",
							players[1].id, CHAT_PACKET, 
							hashMSG(chatInput), chatInput)
	udp:send(send)
	t=socket.gettime()
end

-- Startup Routine
function love.load()
	-- Define global list of players (clients)
	players = {}
	-- Time
	t = socket.gettime()*1000
	
	-- Chat Input Text
	chatInput = ""
	chatTimeout = 0
	chatLog = {}
	
	-- Seed Random ID
	math.randomseed(os.time()) 
	-- Prepare socket
	udp = assert(socket.udp())
	udp:settimeout(0)
	assert(udp:setpeername(hostName, portNo))
	-- Load Player
	playerOne = loadPg(32, 32, math.random(65536))
	table.insert(players, playerOne)
	
	-- Set boolean
	chatOpen = false
	delPressed = false
	
end

-- Loop Routine
function love.update()
	-- Receive Updates From Server
	receiveFromServer()
	-- Chat Control
	chatControl()
	-- Player Movement Control
	playerMovementControl()
	-- Send Movement Packet To Server
	sendMovementData()

end

-- Draw on screen Routine
function love.draw()
	love.graphics.setColor(255,255,255,255)
	for i=1,#players do
		love.graphics.printf(players[i].id, players[i].x-5, 
							players[i].y-16, 40)
		love.graphics.rectangle("fill", players[i].x, players[i].y, 
								10, 10)
	end
	
	-- Chat input window
	if (chatOpen) then
		love.graphics.setColor(255,255,255,60)
		love.graphics.rectangle("fill", 0, love.graphics.getHeight()-14,
								800, 14)
		love.graphics.setColor(255,255,255,255)
		love.graphics.printf("Chat:",0, love.graphics.getHeight()-14,40)
	    love.graphics.printf(chatInput,40, love.graphics.getHeight()-14,
							 love.graphics.getWidth())
	end
	
	if (socket.gettime() - chatTimeout<CHAT_OPEN_TIME or chatOpen) then
		-- Chat window
		love.graphics.setColor(255,255,255,60)
		love.graphics.rectangle("fill", 0, love.graphics.getHeight()-
						14*(CHAT_LOG+2),love.graphics.getWidth(),
						14*(CHAT_LOG+1))
		love.graphics.setColor(255,255,255,255)
		
		-- Chat msgs
		for i=#chatLog-CHAT_LOG,#chatLog do
			local d = #chatLog - i + CHAT_LOG
			if (chatLog[i]) then
				love.graphics.printf(chatLog[i].id, 0, 
									love.graphics.getHeight() - d*14 +
									14*(CHAT_LOG-2), 40)
				love.graphics.printf(chatLog[i].msg, 40, 
						love.graphics.getHeight()-d*14+14*(CHAT_LOG-2),
						love.graphics.getWidth())
			end
		end
	end
end
