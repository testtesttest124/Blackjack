local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlackjackEvent = ReplicatedStorage:WaitForChild("BlackjackEvent")
local countdownDecision = ReplicatedStorage:WaitForChild("countdownDecision")
local ShowBlackjackGui = ReplicatedStorage:WaitForChild("ShowBlackjackGui")
local soundFolder = ReplicatedStorage:WaitForChild("Table1")

local seats = {
	workspace.Games.Blackjack.Tables.Table1:WaitForChild("Seat1"):FindFirstChild("Seat"),
	workspace.Games.Blackjack.Tables.Table1:WaitForChild("Seat2"):FindFirstChild("Seat"),
	workspace.Games.Blackjack.Tables.Table1:WaitForChild("Seat3"):FindFirstChild("Seat"),
	workspace.Games.Blackjack.Tables.Table1:WaitForChild("Seat4"):FindFirstChild("Seat")
}

local seatedPlayers = {}
local gameStarted = false
local currentPlayerIndex = 1
local isRoundInProgress = false

local startGame

local function drawCard(deck, hand)
	local card = table.remove(deck)
	table.insert(hand, card)
	print("[DEBUG] Drawn card:", card.Value, card.Suit)
end

local function createDeck()
	local deck = {}
	local suits = {"Hearts", "Diamonds", "Clubs", "Spades"}
	local values = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
	for _, suit in pairs(suits) do
		for _, value in pairs(values) do
			table.insert(deck, {Value = value, Suit = suit})
		end
	end
	return deck
end

local function shuffleDeck(deck)
	for i = #deck, 2, -1 do
		local j = math.random(i)
		deck[i], deck[j] = deck[j], deck[i]
	end
end

local function calculateHandValue(hand)
	if type(hand) ~= "table" then
		warn("Invalid hand provided to calculateHandValue. Expected table, got " .. type(hand))
		return 0
	end

	local value, aces = 0, 0
	for _, card in ipairs(hand) do
		print("[DEBUG] Calculating card value:", card.Value, card.Suit)
		if card.Value == "A" then
			aces = aces + 1
			value = value + 11
		elseif card.Value == "K" or card.Value == "Q" or card.Value == "J" then
			value = value + 10
		else
			value = value + tonumber(card.Value)
		end
	end
	while value > 21 and aces > 0 do
		value = value - 10
		aces = aces - 1
	end
	print("[DEBUG] Hand value calculated:", value)
	return value
end

local function updateDealerHandDisplay(dealerHand)
	local dealerHandValue = calculateHandValue(dealerHand)
	local dealerTextLabel = game.Workspace.Games.Blackjack.Hand.Dealer.BillboardGui.TextLabel
	dealerTextLabel.Text = dealerHandValue
end

local function playHandValueSound(player, value)
	BlackjackEvent:FireClient(player, "PlaySound", value)
end

local function updatePlayerHandDisplay(player, playerHand, seatNumber)
	local playerHandValue = calculateHandValue(playerHand)
	print("[DEBUG] Calculated Player Hand Value: " .. tostring(playerHandValue))

	local seatPath = "Seat" .. tostring(seatNumber)
	local seatHand = game.Workspace.Games.Blackjack.Hand:FindFirstChild(seatPath)

	if not seatHand then
		warn("[DEBUG] No Hand found for seat: " .. seatPath)
		return
	end

	local seatBillboardGui = seatHand:FindFirstChild("BillboardGui")
	if not seatBillboardGui then
		warn("[DEBUG] No BillboardGui found for seat: " .. seatPath)
		return
	end

	local playerTextLabel = seatBillboardGui:FindFirstChild("TextLabel")
	if not playerTextLabel then
		warn("[DEBUG] No TextLabel found inside BillboardGui for seat: " .. seatPath)
		return
	end

	playerTextLabel.Text = tostring(playerHandValue)
	playHandValueSound(player, playerHandValue) -- Play sound for player's hand value
end

local function promptPlayerAction(currentPlayer)
	local timeLeft = 10
	while timeLeft > 0 do
		countdownDecision:FireClient(currentPlayer, timeLeft)
		timeLeft = timeLeft - 1
		task.wait(1)
	end
end

local function resetGame()
	gameStarted = false
	local countdownLabel = workspace.Games.Blackjack.Tables.Table1:WaitForChild("Countdown")
		:FindFirstChild("BillboardGui")
		:FindFirstChild("TextLabel")

	if not countdownLabel then
		warn("[DEBUG] Countdown TextLabel not found")
		return
	end

	-- Ensure a new round does not start if a round is in progress
	if isRoundInProgress then
		countdownLabel.Text = "Round in progress"
		task.wait(1)
		countdownLabel.Text = "" 
		return
	end

	if #seatedPlayers >= 1 then
		local countdownTime = 5
		while countdownTime > 0 do
			countdownLabel.Text = "Game starting in " .. countdownTime
			countdownTime = countdownTime - 1
			task.wait(1)
		end
		countdownLabel.Text = "" 
		startGame()
	else
		countdownLabel.Text = "Waiting for players"
		print("No players seated. Waiting for players...")
		task.wait(1)
		countdownLabel.Text = "" 
	end
end

startGame = function()
	print("Attempting to start game...")
	if not gameStarted and #seatedPlayers >= 1 then
		gameStarted = true
		isRoundInProgress = true
		print("Game started with players:", #seatedPlayers)

		local deck = createDeck()
		shuffleDeck(deck)
		local dealerHand = {table.remove(deck)}
		updateDealerHandDisplay(dealerHand)

		local playerHands = {}
		local playerSeats = {}
		local turnIndex = 1
		local currentConnection
		local finishedPlayers = 0

		for seatIndex, seat in ipairs(seats) do
			local occupant = seat.Occupant
			local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
			if player then
				local hand = {table.remove(deck), table.remove(deck)}
				playerHands[player] = hand
				playerSeats[player] = seatIndex
				updatePlayerHandDisplay(player, hand, seatIndex)
				print(player.Name .. " is sitting on Seat" .. seatIndex)
			end
		end

		local function dealerTurn()
			while calculateHandValue(dealerHand) < 17 do
				drawCard(deck, dealerHand)
				updateDealerHandDisplay(dealerHand)
				task.wait(1)
			end
			print("Dealer's hand value: " .. calculateHandValue(dealerHand))

			-- Hide GUI for all players
			for _, player in ipairs(seatedPlayers) do
				ShowBlackjackGui:FireClient(player, false)
			end

			task.wait(2) -- Wait for a short period after the dealer has finished
			isRoundInProgress = false
			resetGame()
		end

		local function allPlayersTurn()
			local currentConnection = nil
			local finishedPlayers = 0

			if currentConnection then
				currentConnection:Disconnect()
			end

			if #seatedPlayers == 0 then
				resetGame()
				return
			end

			finishedPlayers = 0 -- Reset finished players count

			-- Show GUI for all players
			for _, player in ipairs(seatedPlayers) do
				ShowBlackjackGui:FireClient(player, true)
			end

			local function onServerEvent(firingPlayer, action)
				local playerHand = playerHands[firingPlayer]
				local playerHandValue = calculateHandValue(playerHand)

				print("[DEBUG] Player's initial hand value: " .. playerHandValue)
				print("[DEBUG] Player's hand before action:", playerHand)

				if action == "Hit" then
					drawCard(deck, playerHand)
					playerHandValue = calculateHandValue(playerHand)
					updatePlayerHandDisplay(firingPlayer, playerHand, playerSeats[firingPlayer])

					print("[DEBUG] Player's new hand value after Hit: " .. playerHandValue)
					print("[DEBUG] Player's hand after action:", playerHand)

					if playerHandValue > 21 then
						print(firingPlayer.Name .. " busts! Dealer wins!")
						ShowBlackjackGui:FireClient(firingPlayer, false)
						finishedPlayers = finishedPlayers + 1
						if finishedPlayers >= #seatedPlayers then
							dealerTurn()
						end
					end

				elseif action == "Stand" then
					print(firingPlayer.Name .. " stands.")
					ShowBlackjackGui:FireClient(firingPlayer, false)
					finishedPlayers = finishedPlayers + 1
					if finishedPlayers >= #seatedPlayers then
						dealerTurn()
					end
				end
			end

			currentConnection = BlackjackEvent.OnServerEvent:Connect(onServerEvent)
			task.spawn(function()
				local timeLeft = 10
				while timeLeft > 0 do
					task.wait(1)
					timeLeft -= 1
					for _, player in ipairs(seatedPlayers) do
						countdownDecision:FireClient(player, timeLeft)
					end
				end

				if finishedPlayers < #seatedPlayers then
					print("Time's up! Automatically standing remaining players.")
					for _, player in ipairs(seatedPlayers) do
						local playerHand = playerHands[player]
						local playerHandValue = calculateHandValue(playerHand)

						if playerHandValue <= 21 then
							finishedPlayers = finishedPlayers + 1
						end
						ShowBlackjackGui:FireClient(player, false)
					end
					dealerTurn()
				end
			end)
		end
		allPlayersTurn()
	end
end

for i, seat in ipairs(seats) do
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if occupant then
			local player = Players:GetPlayerFromCharacter(occupant.Parent)
			if player then
				print(player.Name .. " is sitting on Seat" .. i)

				if not table.find(seatedPlayers, player) then
					table.insert(seatedPlayers, player)
					if not gameStarted then
						startGame()
					end
				end
			end
		else
			for j = #seatedPlayers, 1, -1 do
				local seatedPlayer = seatedPlayers[j]
				if not seatedPlayer.Character or not seatedPlayer.Character:FindFirstChildWhichIsA("Humanoid") or seatedPlayer.Character.Humanoid.SeatPart ~= seat then
					print(seatedPlayer.Name .. " left Seat" .. i)
					table.remove(seatedPlayers, j)
				end
			end
		end
	end)
end
