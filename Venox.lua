local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local BASE_URL     = "https://api-ahcm.onrender.com"
local VERIFY_URL   = BASE_URL .. "/api/verify-key"
local CREATE_URL   = BASE_URL .. "/api/create-key"
local REQUEST_LOOT = BASE_URL .. "/api/request-loot"
local CLAIM_URL    = BASE_URL .. "/api/claim-key"

local request   = http_request or request or (syn and syn.request) or (fluxus and fluxus.request)
local clipboard = setclipboard or toclipboard or (syn and syn.write_clipboard)
local openurl   = (syn and syn.open_url) or nil

-- Вспомогательная функция: парсит JSON и возвращает читаемую ошибку
local function parseError(responseBody)
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(responseBody or "")
	end)
	if ok and decoded then
		-- FastAPI возвращает ошибку в поле "detail"
		if decoded.detail then
			return tostring(decoded.detail)
		elseif decoded.message then
			return tostring(decoded.message)
		end
	end
	return responseBody or "Unknown error"
end

-- ─── Уничтожаем старый GUI ──────────────────────────────────────────────────
if game.CoreGui:FindFirstChild("KeySystemUI") then
	game.CoreGui.KeySystemUI:Destroy()
end

-- ─── GUI ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "KeySystemUI"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 440, 0, 430)
frame.Position = UDim2.new(0.5, -220, 0.5, -215)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "Key System Panel"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextSize = 24
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Таб-кнопки
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, -20, 0, 36)
tabs.Position = UDim2.new(0, 10, 0, 44)
tabs.BackgroundTransparency = 1
tabs.Parent = frame

local function makeTabBtn(text, xPos)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.33, -4, 1, 0)
	btn.Position = UDim2.new(xPos, 2, 0, 0)
	btn.Text = text
	btn.TextColor3 = Color3.new(1,1,1)
	btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = tabs
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
	return btn
end

local verifyTabBtn = makeTabBtn("Verify", 0)
local lootTabBtn   = makeTabBtn("Get Key", 0.333)
local createTabBtn = makeTabBtn("Create Key", 0.666)

-- Страницы
local function makePage()
	local p = Instance.new("Frame")
	p.Size = UDim2.new(1,-20, 1,-150)
	p.Position = UDim2.new(0,10, 0,92)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.Parent = frame
	return p
end

local verifyPage = makePage()
local lootPage   = makePage()
local createPage = makePage()

-- ─── Виджеты ────────────────────────────────────────────────────────────────
local function makeBox(parent, placeholder, y)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1,0,0,42)
	box.Position = UDim2.new(0,0,0,y)
	box.PlaceholderText = placeholder
	box.Text = ""
	box.TextColor3 = Color3.new(1,1,1)
	box.PlaceholderColor3 = Color3.fromRGB(170,170,170)
	box.BackgroundColor3 = Color3.fromRGB(35,35,35)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Gotham
	box.TextSize = 15
	box.ClearTextOnFocus = false
	box.Parent = parent
	Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)
	return box
end

local function makeButton(parent, text, y, color)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1,0,0,42)
	btn.Position = UDim2.new(0,0,0,y)
	btn.Text = text
	btn.TextColor3 = Color3.new(1,1,1)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
	return btn
end

local function makeLabel(parent, text, y, sizeY)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,0,sizeY or 22)
	lbl.Position = UDim2.new(0,0,0,y)
	lbl.BackgroundTransparency = 1
	lbl.Text = text or ""
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.Parent = parent
	return lbl
end

-- Verify page
local verifyKeyBox = makeBox(verifyPage, "Enter key...", 0)
local verifyBtn    = makeButton(verifyPage, "Verify Key", 54, Color3.fromRGB(60,100,190))
local verifyStatus = makeLabel(verifyPage, "", 108, 120)

-- LootLabs page
local lootInfo     = makeLabel(lootPage, "Press the button to get your key.", 0, 30)
local lootBtn      = makeButton(lootPage, "Get Key via Tasks", 34, Color3.fromRGB(70,150,90))
local lootLinkBtn  = makeButton(lootPage, "Open Tasks in Browser", 88, Color3.fromRGB(90,90,30))
local lootClaimBtn = makeButton(lootPage, "I completed tasks - give key", 142, Color3.fromRGB(100,60,180))
local lootResult   = makeLabel(lootPage, "", 196, 90)

lootLinkBtn.Visible  = false
lootClaimBtn.Visible = false

-- Create page (admin)
local adminTokenBox = makeBox(createPage, "Admin Token", 0)
local labelBox      = makeBox(createPage, "Label (optional)", 54)
local expiresBox    = makeBox(createPage, "Expires At (optional, 2026-12-31T23:59:59Z)", 108)
local createBtn     = makeButton(createPage, "Create Key", 162, Color3.fromRGB(70,150,90))
local createStatus  = makeLabel(createPage, "", 214, 90)

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,28)
closeBtn.Position = UDim2.new(1,-36,0,10)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.BackgroundColor3 = Color3.fromRGB(130,45,45)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1,-20,0,18)
info.Position = UDim2.new(0,10,1,-24)
info.BackgroundTransparency = 1
info.Text = "Executor HTTP required"
info.TextColor3 = Color3.fromRGB(170,170,170)
info.TextXAlignment = Enum.TextXAlignment.Left
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.Parent = frame

-- ─── Drag ───────────────────────────────────────────────────────────────────
local dragging, dragStart, startPos = false, nil, nil
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true; dragStart = input.Position; startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
title.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- ─── Tabs ───────────────────────────────────────────────────────────────────
local ACTIVE   = Color3.fromRGB(50,90,170)
local INACTIVE = Color3.fromRGB(40,40,40)

local function switchTab(name)
	verifyPage.Visible = (name == "verify")
	lootPage.Visible   = (name == "loot")
	createPage.Visible = (name == "create")
	verifyTabBtn.BackgroundColor3 = name=="verify" and ACTIVE or INACTIVE
	lootTabBtn.BackgroundColor3   = name=="loot"   and ACTIVE or INACTIVE
	createTabBtn.BackgroundColor3 = name=="create" and ACTIVE or INACTIVE
end

verifyTabBtn.MouseButton1Click:Connect(function() switchTab("verify") end)
lootTabBtn.MouseButton1Click:Connect(function()   switchTab("loot")   end)
createTabBtn.MouseButton1Click:Connect(function() switchTab("create") end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
switchTab("verify")

-- ─── Verify ─────────────────────────────────────────────────────────────────
verifyBtn.MouseButton1Click:Connect(function()
	verifyStatus.Text = "Checking..."
	if not request then verifyStatus.Text = "Executor HTTP not available"; return end

	local ok, response = pcall(function()
		return request({
			Url = VERIFY_URL, Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({
				key            = verifyKeyBox.Text,
				roblox_user_id = player.UserId,
				username       = player.Name,
				place_id       = game.PlaceId,
				job_id         = game.JobId,
			})
		})
	end)

	if not ok then verifyStatus.Text = "Request error: "..tostring(response); return end

	local decoded
	pcall(function() decoded = HttpService:JSONDecode(response.Body or "") end)

	if decoded and decoded.success then
		verifyStatus.Text = "✅ "..tostring(decoded.message or "Access granted")
	else
		verifyStatus.Text = "❌ "..parseError(response.Body)
	end
end)

-- ─── LootLabs flow ──────────────────────────────────────────────────────────
local _sessionToken = nil
local _lootUrl      = nil

lootBtn.MouseButton1Click:Connect(function()
	lootResult.Text      = "Requesting link..."
	lootLinkBtn.Visible  = false
	lootClaimBtn.Visible = false
	_sessionToken = nil
	_lootUrl      = nil

	if not request then lootResult.Text = "Executor HTTP not available"; return end

	local ok, response = pcall(function()
		return request({
			Url = REQUEST_LOOT, Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({
				roblox_user_id = player.UserId,
				username       = player.Name,
			})
		})
	end)

	if not ok then
		lootResult.Text = "❌ Request error: "..tostring(response)
		return
	end

	-- Показываем полный ответ сервера для отладки если ошибка
	local decoded
	local parseOk = pcall(function()
		decoded = HttpService:JSONDecode(response.Body or "")
	end)

	if not parseOk or not decoded then
		lootResult.Text = "❌ Parse error. Server said:\n"..(response.Body or "empty")
		return
	end

	if not decoded.success then
		-- Показываем полную деталь ошибки — detail из FastAPI
		lootResult.Text = "❌ "..parseError(response.Body)
		return
	end

	_sessionToken = decoded.session_token
	_lootUrl      = decoded.loot_url

	lootResult.Text      = "✅ Link ready!\nOpen tasks, complete them, then press claim."
	lootLinkBtn.Visible  = true
	lootClaimBtn.Visible = true
end)

lootLinkBtn.MouseButton1Click:Connect(function()
	if not _lootUrl then lootResult.Text = "Request a link first"; return end

	local opened = false
	if openurl then
		pcall(function() openurl(_lootUrl); opened = true end)
	end

	if opened then
		lootResult.Text = "✅ Browser opened!\nComplete tasks then press claim."
	elseif clipboard then
		pcall(function() clipboard(_lootUrl) end)
		lootResult.Text = "📋 Link copied!\nPaste in browser, complete tasks, then press claim.\n".._lootUrl
	else
		lootResult.Text = "Open manually:\n".._lootUrl
	end
end)

lootClaimBtn.MouseButton1Click:Connect(function()
	if not _sessionToken then
		lootResult.Text = "No active session. Press 'Get Key via Tasks' first."
		return
	end

	lootResult.Text = "Checking tasks..."

	local ok, response = pcall(function()
		return request({
			Url = CLAIM_URL, Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({
				session_token  = _sessionToken,
				roblox_user_id = player.UserId,
				username       = player.Name,
				place_id       = game.PlaceId,
				job_id         = game.JobId,
			})
		})
	end)

	if not ok then
		lootResult.Text = "❌ Request error: "..tostring(response)
		return
	end

	local decoded
	pcall(function() decoded = HttpService:JSONDecode(response.Body or "") end)

	if not decoded then
		lootResult.Text = "❌ Parse error:\n"..(response.Body or "empty")
		return
	end

	if decoded.success and decoded.key then
		local key = decoded.key
		if clipboard then
			pcall(function() clipboard(key) end)
			lootResult.Text = "🎉 Key copied!\n"..key
		else
			lootResult.Text = "🎉 Your key:\n"..key
		end
		_sessionToken    = nil
		_lootUrl         = nil
		lootLinkBtn.Visible  = false
		lootClaimBtn.Visible = false
	elseif decoded.pending then
		lootResult.Text = "⏳ Tasks not completed yet.\nFinish all tasks and try again."
	else
		lootResult.Text = "❌ "..parseError(response.Body)
	end
end)

-- ─── Create key (admin) ──────────────────────────────────────────────────────
createBtn.MouseButton1Click:Connect(function()
	createStatus.Text = "Creating..."
	if not request then createStatus.Text = "Executor HTTP not available"; return end

	local adminToken = adminTokenBox.Text:match("^%s*(.-)%s*$")
	if adminToken == "" then createStatus.Text = "Admin token required"; return end

	local ok, response = pcall(function()
		return request({
			Url = CREATE_URL, Method = "POST",
			Headers = {["Content-Type"] = "application/json", ["X-Admin-Token"] = adminToken},
			Body = HttpService:JSONEncode({
				label      = labelBox.Text ~= "" and labelBox.Text or nil,
				expires_at = expiresBox.Text ~= "" and expiresBox.Text or nil,
			})
		})
	end)

	if not ok then createStatus.Text = "❌ Request error: "..tostring(response); return end

	local decoded
	pcall(function() decoded = HttpService:JSONDecode(response.Body or "") end)

	if decoded and decoded.success and decoded.key then
		if clipboard then
			pcall(function() clipboard(decoded.key) end)
			createStatus.Text = "✅ Key created and copied:\n"..decoded.key
		else
			createStatus.Text = "✅ Key created:\n"..decoded.key
		end
	else
		createStatus.Text = "❌ "..parseError(response.Body)
	end
end)
