------------------------------------------------------------------------

-- Meru 
-- Server/Client Test
-- merutochan@gmail.com

-- General purpose packet structure: ID TYPE DATA (all as ints)
-- Logout Packet: ID TYPE=2
-- Movement Packet: ID TYPE=3 X Y DX DY

------------------------------------------------------------------------

hostName = "localhost" 
--hostName = "54.38.182.111"
portNo = 42069
socket = require "socket"

LOGOUT_PACKET = 2
MOVEMENT_PACKET = 3
TIME_INTERVAL = 10 -- (ms)

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
			if(packet[1] == 3) then
				players[i].x = packet[2]
				players[i].y = packet[3]
				players[i].dx = packet[4]
				players[i].dy = packet[5]
				return
			-- LOGOUT PACKET
			-- Remove Player
			elseif(packet[1] == 2) then
				print("Remove player ", packet[0])
				table.remove(players, searchPlayerByID(packet[0]))
				return
			-- INVALID PACKET
			else
				return
			end
		end
	end
	-- MOVEMENT PACKET OF NEW CLIENT ADDS CLIENTS INFO
	if (packet[1] == 3) then 
		print("Adding player ", packet[0])
		p = loadPg(packet[2], packet[3], packet[0])
		table.insert(players, p)
		return
	end
end

-- Startup Routine
function love.load()
	-- Define global list of players (clients)
	players = {}
	-- Time
	t = socket.gettime()*1000
	
	-- Seed Random ID
	math.randomseed(os.time()) 
	-- Prepare socket
	udp = assert(socket.udp())
	udp:settimeout(0)
	assert(udp:setpeername(hostName, portNo))
	-- Load Player
	playerOne = loadPg(32, 32, math.random(65536))
	table.insert(players, playerOne)
end

-- Loop Routine
function love.update()

	local send
	-- Receive server message
	local data, msg
	data, msg = udp:receive()
	if data then
		processPacket(data)
	end
	
	-- Temporarily reset dx and dy
	players[1].dx = 0
	players[1].dy = 0
	
	-- Player Movement Command
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
	
	-- Send Movement Packet
	if ((socket.gettime()*1000 -t)>=TIME_INTERVAL) then
		send = string.format("%d %d %d %d %d %d;\n",
								players[1].id, MOVEMENT_PACKET, 
								players[1].x, players[1].y, 
								players[1].dx, players[1].dy)
		udp:send(send)
		t=socket.gettime()
	end
	
	-- Update other Players' movement through prevision
	for i=2,#players do
		players[i].x = players[i].x + players[i].dx
		players[i].y = players[i].y + players[i].dy
	end
	
	
end

-- Draw on screen Routine
function love.draw()
	for i=1,#players do
		love.graphics.rectangle("fill", players[i].x, players[i].y, 
								10, 10)
	end
end
