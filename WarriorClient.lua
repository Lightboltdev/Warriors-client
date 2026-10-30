--[[
	WARRIOR CLIENT  |  Menu para o mapa "Dead Freds"
	Dev: Lightbolt_dev

	LocalScript único em StarterPlayer > StarterPlayerScripts.
	Não precisa de script no servidor: a música usa o remote que o Brookhaven já tem.

	Botão "–"  : esconde o menu na bolinha.
	Botão "×"  : pergunta e oculta TUDO (menu e bolinha). Para voltar: /menu no chat ou RightShift.
]]

-- SERVIÇOS
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local rng = Random.new()

-- Se o script for executado de novo, remove a cópia antiga
do
	local oldGui = PlayerGui:FindFirstChild("WarriorClient")
	if oldGui then oldGui:Destroy() end
	local oldBlur = Lighting:FindFirstChild("WarriorBlur")
	if oldBlur then oldBlur:Destroy() end
end

-- CONFIG
local Config = {
	Name = "Warrior Client",
	Developer = "Lightbolt_dev",
	Version = "1.7.0",
	UpdateDate = "30/10/2026",
	MenuBlur = true,

	Colors = {
		Bg = Color3.fromRGB(12, 12, 16),
		BgTint = Color3.fromRGB(26, 14, 44),
		Panel = Color3.fromRGB(22, 22, 28),
		Row = Color3.fromRGB(28, 28, 36),
		Purple = Color3.fromRGB(150, 70, 255),
		PurpleDark = Color3.fromRGB(88, 36, 160),
		Text = Color3.fromRGB(240, 238, 248),
		SubText = Color3.fromRGB(150, 148, 165),
		Ok = Color3.fromRGB(90, 210, 140),
		Error = Color3.fromRGB(240, 90, 110),
	},

	-- Imagens: envie no Creator Hub (Assets > Images) e cole "rbxassetid://ID"
	ButtonImage = "", -- bolinha flutuante
	BackgroundImage = "", -- fundo do menu
	LogoImage = "", -- logo da abertura

	-- Ícones Lucide (rbxassetid). Vazio = ícone simples de reserva
	Icons = { Status = "", Jogador = "", Visual = "", Executor = "", Teleport = "", Musica = "", Protecao = "", Config = "", Info = "" },
}
local C = Config.Colors
local DefaultTheme = { Purple = C.Purple, PurpleDark = C.PurpleDark, BgTint = C.BgTint }

-- LIMPEZA: tudo que o script conecta é desligado quando o script é encerrado
local Conns, Hooks = {}, {}
local function Track(conn) Conns[#Conns + 1] = conn; return conn end
local function OnClose(fn) Hooks[#Hooks + 1] = fn end

-- Travas (aba Config)
local Locks = { Menu = false, Ball = false }

-- Controles da janela (preenchidos no final do script): Hide, Show, Close
local Window = {}

-- UTILS
local function New(class, props, children)
	local obj = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else obj[k] = v end
	end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	obj.Parent = parent
	return obj
end
local function Corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function Stroke(color, thick, trans)
	return New("UIStroke", { Color = color, Thickness = thick or 1, Transparency = trans or 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function Tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function Label(parent, text, size, color, bold, align)
	return New("TextLabel", {
		Parent = parent, BackgroundTransparency = 1, Text = text, TextSize = size or 14,
		TextColor3 = color or C.Text, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	})
end
local function Round(n) return math.floor(n + 0.5) end

-- Arrastar. lockKey = "Menu" ou "Ball" (ver Locks). Devolve { Moved } para separar arrasto de clique
local function MakeDraggable(handle, target, lockKey)
	local state = { Moved = false }
	local dragging, startPos, origin

	local function clamp()
		local parent = target.Parent
		if not parent then return end
		local ps, sz, a, pos = parent.AbsoluteSize, target.AbsoluteSize, target.AnchorPoint, target.Position
		local x = ps.X * pos.X.Scale + pos.X.Offset - a.X * sz.X
		local y = ps.Y * pos.Y.Scale + pos.Y.Offset - a.Y * sz.Y
		local cx = math.clamp(x, 0, math.max(0, ps.X - sz.X))
		local cy = math.clamp(y, 0, math.max(0, ps.Y - sz.Y))
		target.Position = UDim2.new(pos.X.Scale, pos.X.Offset + (cx - x), pos.Y.Scale, pos.Y.Offset + (cy - y))
	end

	Track(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.Moved = false
			if lockKey and Locks[lockKey] then return end
			dragging, startPos, origin = true, input.Position, target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end))
	Track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startPos
			if d.Magnitude > 6 then state.Moved = true end
			target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
			clamp()
		end
	end))
	return state
end

-- Partículas que sobem. Usado no painel e na abertura
local function Flames(parent, n, big)
	for _ = 1, n do
		local size, x = rng:NextInteger(big and 6 or 5, big and 16 or 12), rng:NextNumber(0, 1)
		local p = New("Frame", {
			Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 1.03, 0),
			Size = UDim2.fromOffset(size, size), Rotation = rng:NextInteger(0, 90), BorderSizePixel = 0, ZIndex = big and 51 or 1,
			BackgroundColor3 = C.Purple:Lerp(Color3.fromRGB(230, 150, 255), rng:NextNumber(0, 0.7)),
			BackgroundTransparency = big and 0.2 or 0.35,
		}, { Corner(3) })
		local t = rng:NextNumber(1.4, 2.6)
		Tween(p, t, {
			Position = UDim2.new(x + rng:NextNumber(-0.06, 0.06), 0, big and rng:NextNumber(0.1, 0.6) or rng:NextNumber(0.5, 0.9), 0),
			BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2), Rotation = p.Rotation + rng:NextInteger(-120, 120),
		}, Enum.EasingStyle.Sine)
		task.delay(t, function() p:Destroy() end)
	end
end

-- GUI RAIZ E NOTIFICAÇÕES
local Gui = New("ScreenGui", {
	Name = "WarriorClient", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
	Parent = PlayerGui,
})
local Blur = New("BlurEffect", { Size = 0, Parent = Lighting, Name = "WarriorBlur" })
local function SetBlur(on) Tween(Blur, 0.4, { Size = (on and Config.MenuBlur) and 10 or 0 }) end

local ToastHolder = New("Frame", {
	Parent = Gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 200,
}, { New("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	New("UISizeConstraint", { MaxSize = Vector2.new(330, 9999) }) })

-- kind: "ok" | "err" | "info"
local function Notify(title, text, kind)
	local col = (kind == "err" and C.Error) or (kind == "ok" and C.Ok) or C.Purple
	local scale = New("UIScale", { Scale = 0.85 })
	local toast = New("CanvasGroup", {
		Parent = ToastHolder, Size = UDim2.new(1, 0, 0, 58), GroupTransparency = 1, BackgroundColor3 = C.Panel, ZIndex = 200,
	}, { Corner(12), Stroke(col, 1.5, 0.3), scale,
		New("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0 }) })
	local t = Label(toast, title, 14, C.Text, true); t.Position = UDim2.fromOffset(18, 10); t.Size = UDim2.new(1, -28, 0, 18)
	local d = Label(toast, text or "", 12, C.SubText); d.Position = UDim2.fromOffset(18, 30); d.Size = UDim2.new(1, -28, 0, 18)
	Tween(toast, 0.3, { GroupTransparency = 0 }); Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		Tween(toast, 0.35, { GroupTransparency = 1 }); Tween(scale, 0.35, { Scale = 0.9 })
		task.wait(0.4); toast:Destroy()
	end)
end

-- TEMA (cor) E FONTE
-- Trocar a cor: percorre a interface e troca as cores antigas pelas novas.
-- Objetos dentro de Theme.Skip (swatches, seletor) não são alterados.
local Theme = { Skip = {}, Queued = nil }

local function near(a, b)
	return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
end

local function DeriveTheme(accent)
	local h, s, v = accent:ToHSV()
	return {
		Purple = accent,
		PurpleDark = Color3.fromHSV(h, math.min(1, s * 1.05), v * 0.62),
		BgTint = Color3.fromHSV(h, 0.68, 0.17),
	}
end

local function SetTheme(new)
	local old = { Purple = C.Purple, PurpleDark = C.PurpleDark, BgTint = C.BgTint }
	C.Purple, C.PurpleDark, C.BgTint = new.Purple, new.PurpleDark, new.BgTint
	local function remap(col)
		for key, oc in pairs(old) do
			if near(col, oc) then return new[key] end
		end
	end
	for _, o in ipairs(Gui:GetDescendants()) do
		local skip = false
		for _, root in ipairs(Theme.Skip) do
			if o == root or o:IsDescendantOf(root) then skip = true break end
		end
		if not skip then
			if o:IsA("GuiObject") then
				local n = remap(o.BackgroundColor3); if n then o.BackgroundColor3 = n end
				if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
					n = remap(o.TextColor3); if n then o.TextColor3 = n end
				elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
					n = remap(o.ImageColor3); if n then o.ImageColor3 = n end
				elseif o:IsA("ScrollingFrame") then
					n = remap(o.ScrollBarImageColor3); if n then o.ScrollBarImageColor3 = n end
				end
			elseif o:IsA("UIStroke") then
				local n = remap(o.Color); if n then o.Color = n end
			elseif o:IsA("UIGradient") then
				local changed, keys = false, {}
				for i, k in ipairs(o.Color.Keypoints) do
					local n = remap(k.Value)
					if n then changed = true end
					keys[i] = ColorSequenceKeypoint.new(k.Time, n or k.Value)
				end
				if changed then o.Color = ColorSequence.new(keys) end
			end
		end
	end
end

function Theme.Apply(accent) SetTheme(DeriveTheme(accent)) end
function Theme.Reset() SetTheme(DefaultTheme) end
-- Agrupa várias mudanças seguidas (arrastar o seletor) em uma só por frame
function Theme.QueueApply(accent)
	local first = Theme.Queued == nil
	Theme.Queued = accent
	if first then
		task.defer(function()
			local c = Theme.Queued
			Theme.Queued = nil
			if c and Gui.Parent then Theme.Apply(c) end
		end)
	end
end

local FontState = { Reg = nil, Bold = nil }
local OrigFont = setmetatable({}, { __mode = "k" })
local BoldFonts = {
	[Enum.Font.GothamBold] = true, [Enum.Font.GothamBlack] = true, [Enum.Font.GothamSemibold] = true,
	[Enum.Font.SourceSansBold] = true, [Enum.Font.ArialBold] = true,
}
local function isText(o) return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") end
local function setFont(o)
	if o:GetAttribute("KeepFont") then return end
	local orig = OrigFont[o]
	if not orig then orig = o.Font; OrigFont[o] = orig end
	if orig == Enum.Font.Code then return end
	if FontState.Reg then
		o.Font = BoldFonts[orig] and FontState.Bold or FontState.Reg
	else
		o.Font = orig
	end
end
-- reg = nil volta para a fonte padrão
function Theme.ApplyFont(reg, bold)
	FontState.Reg, FontState.Bold = reg, bold or reg
	for _, o in ipairs(Gui:GetDescendants()) do
		if isText(o) then setFont(o) end
	end
end
Track(Gui.DescendantAdded:Connect(function(o)
	if FontState.Reg and isText(o) then
		task.defer(function() if o.Parent then setFont(o) end end)
	end
end))

-- COMPONENTES
local Components = {}

function Components.Row(parent, title, height)
	local row = New("Frame", {
		Parent = parent, Size = UDim2.new(1, 0, 0, height or 50),
		BackgroundColor3 = C.Row, BackgroundTransparency = 0.25,
	}, { Corner(10), Stroke(C.Purple, 1, 0.85) })
	if title then
		local t = Label(row, title, 14, C.Text, true)
		t.Position = UDim2.new(0, 14, 0, 0)
		t.Size = UDim2.new(0.6, 0, 0, height or 50)
	end
	return row
end

function Components.Toggle(parent, title, default, callback)
	local row = Components.Row(parent, title)
	local state = default or false
	local track = New("TextButton", {
		Parent = row, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(44, 22), BackgroundColor3 = C.Panel,
	}, { Corner(11) })
	local knob = New("Frame", {
		Parent = track, Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = C.SubText,
	}, { Corner(8) })
	local function render(animate)
		local t = animate and 0.2 or 0
		Tween(track, t, { BackgroundColor3 = state and C.Purple or C.Panel })
		Tween(knob, t, {
			Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or C.SubText,
		})
	end
	local function set(v, silent)
		state = v; render(true)
		if not silent and callback then task.spawn(callback, state) end
	end
	track.Activated:Connect(function() set(not state) end)
	render(false)
	if state and callback then task.spawn(callback, true) end
	return row, set
end

function Components.SmallButton(parent, text, w)
	local b = New("TextButton", {
		Parent = parent, Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false, Size = UDim2.fromOffset(w or 70, 28), BackgroundColor3 = C.Purple,
	}, { Corner(8) })
	b.MouseEnter:Connect(function() Tween(b, 0.15, { BackgroundColor3 = C.PurpleDark }) end)
	b.MouseLeave:Connect(function() Tween(b, 0.15, { BackgroundColor3 = C.Purple }) end)
	return b
end

function Components.Button(parent, title, btnText, callback)
	local row = Components.Row(parent, title)
	local btn = Components.SmallButton(row, btnText or "Usar", 78)
	btn.AnchorPoint = Vector2.new(1, 0.5); btn.Position = UDim2.new(1, -14, 0.5, 0)
	btn.Activated:Connect(function() if callback then callback() end end)
	return row, btn
end

function Components.Slider(parent, title, min, max, default, callback)
	local row = Components.Row(parent, title, 56)
	local value = Label(row, tostring(default), 13, C.Purple, true, Enum.TextXAlignment.Right)
	value.AnchorPoint = Vector2.new(1, 0); value.Position = UDim2.new(1, -14, 0, 8); value.Size = UDim2.fromOffset(60, 18)
	local bar = New("Frame", {
		Parent = row, Position = UDim2.new(0, 14, 1, -16), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.Panel,
	}, { Corner(3) })
	local fill = New("Frame", { Parent = bar, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Purple }, { Corner(3) })
	New("Frame", {
		Parent = fill, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1),
	}, { Corner(7) })
	local function set(v, silent)
		v = math.clamp(v, min, max)
		Tween(fill, 0.08, { Size = UDim2.fromScale((v - min) / (max - min), 1) })
		value.Text = tostring(Round(v))
		if not silent and callback then callback(v) end
	end
	local dragging = false
	local function fromInput(input)
		set(min + (max - min) * math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1))
	end
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; fromInput(i) end
	end)
	Track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
	end))
	Track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
	set(default, true)
	return row, set
end

-- ABERTURA
local function PlayIntro()
	local overlay = New("Frame", {
		Parent = Gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 50,
	})
	Tween(overlay, 0.6, { BackgroundTransparency = 0.35 })
	Tween(Blur, 0.6, { Size = 14 })

	local logo = New("Frame", {
		Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(0, 0), BackgroundColor3 = C.Panel, ZIndex = 52,
	}, { Corner(22), Stroke(C.Purple, 2, 0.1), New("UIGradient", { Color = ColorSequence.new(C.PurpleDark, C.Bg), Rotation = 45 }) })
	if Config.LogoImage ~= "" then
		New("ImageLabel", { Parent = logo, Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), BackgroundTransparency = 1, Image = Config.LogoImage, ZIndex = 53 })
	else
		local w = Label(logo, "W", 56, C.Purple, true, Enum.TextXAlignment.Center)
		w.Size = UDim2.fromScale(1, 1); w.ZIndex = 53; w.Font = Enum.Font.GothamBlack
	end
	Tween(logo, 0.7, { Size = UDim2.fromOffset(96, 96) }, Enum.EasingStyle.Back)

	local welcome = Label(overlay, "Bem-vindo ao Warrior Client", 22, C.Text, true, Enum.TextXAlignment.Center)
	welcome.AnchorPoint = Vector2.new(0.5, 0)
	welcome.Position = UDim2.fromScale(0.5, 0.45) + UDim2.fromOffset(0, 70)
	welcome.Size = UDim2.new(1, 0, 0, 30); welcome.ZIndex = 52; welcome.TextTransparency = 1
	Tween(welcome, 0.8, { TextTransparency = 0 })

	local running = true
	task.spawn(function()
		while running and Gui.Parent do
			Flames(overlay, 3, true)
			task.wait(0.06)
		end
	end)

	task.wait(3)
	running = false
	if not overlay.Parent then return end
	for _, d in ipairs(overlay:GetDescendants()) do
		if d:IsA("TextLabel") then Tween(d, 0.6, { TextTransparency = 1 }) end
		if d:IsA("Frame") then Tween(d, 0.6, { BackgroundTransparency = 1 }) end
	end
	Tween(overlay, 0.6, { BackgroundTransparency = 1 })
	Tween(logo, 0.6, { Size = UDim2.fromOffset(0, 0) })
	task.wait(0.65)
	overlay:Destroy()
end

-- JANELA PRINCIPAL
local Main = New("Frame", {
	Parent = Gui, Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.8), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.12,
	ClipsDescendants = true, Visible = false,
}, {
	Corner(16), Stroke(C.Purple, 1.5, 0.4),
	New("UISizeConstraint", { MaxSize = Vector2.new(640, 390), MinSize = Vector2.new(300, 240) }),
	New("UIGradient", { Color = ColorSequence.new(C.BgTint, C.Bg), Rotation = 90 }),
})
local FullSize = Main.Size

if Config.BackgroundImage ~= "" then
	New("ImageLabel", {
		Parent = Main, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Config.BackgroundImage,
		ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.5,
	}, { Corner(16) })
end
-- Brilho no fundo e linha luminosa no topo
New("Frame", { Parent = Main, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 90),
	BackgroundColor3 = C.Purple, BorderSizePixel = 0 },
	{ New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.72) }) }) })
New("Frame", { Parent = Main, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Purple, BorderSizePixel = 0 },
	{ New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }) })
local FxLayer = New("Frame", { Parent = Main, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true })
task.spawn(function()
	while Gui.Parent do
		if Main.Visible then Flames(FxLayer, 2) end
		task.wait(0.15)
	end
end)

-- Barra superior
local TopBar = New("Frame", { Parent = Main, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
local Title = Label(TopBar, "WARRIOR CLIENT", 15, C.Text, true)
Title.Position = UDim2.new(0, 16, 0, 0); Title.Size = UDim2.new(0, 140, 1, 0); Title.Font = Enum.Font.GothamBlack
local Ver = Label(TopBar, "v" .. Config.Version, 12, C.Purple, true)
Ver.Position = UDim2.new(0, 158, 0, 0); Ver.Size = UDim2.new(0, 60, 1, 0)
MakeDraggable(TopBar, Main, "Menu")

local function WindowButton(text, xOffset, color)
	local b = New("TextButton", {
		Parent = TopBar, Text = text, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.Text,
		AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),
		Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.Row,
	}, { Corner(8) })
	b.MouseEnter:Connect(function() Tween(b, 0.15, { BackgroundColor3 = color }) end)
	b.MouseLeave:Connect(function() Tween(b, 0.15, { BackgroundColor3 = C.Row }) end)
	return b
end
local CloseBtn = WindowButton("×", -12, Color3.fromRGB(200, 50, 70))
local MinBtn = WindowButton("–", -46, C.PurpleDark)

-- Sidebar
local Sidebar = New("ScrollingFrame", {
	Parent = Main, Position = UDim2.new(0, 10, 0, 50), Size = UDim2.new(0, 150, 1, -60),
	BackgroundColor3 = C.Panel, BackgroundTransparency = 0.3, BorderSizePixel = 0,
	ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, { Corner(12) })
New("UIListLayout", { Parent = Sidebar, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
New("UIPadding", { Parent = Sidebar, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
local Indicator = New("Frame", {
	Parent = Main, Size = UDim2.fromOffset(3, 24), BackgroundColor3 = C.Purple, ZIndex = 5, Position = UDim2.fromOffset(12, 62),
}, { Corner(2) })

local Content = New("Frame", { Parent = Main, Position = UDim2.new(0, 170, 0, 50), Size = UDim2.new(1, -180, 1, -60), BackgroundTransparency = 1 })

-- Ícone vetorial (Lucide via asset ID) ou desenho simples de reserva
local function MakeIcon(parent, assetId, key)
	local holder = New("Frame", { Parent = parent, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
	if assetId ~= "" then
		local img = New("ImageLabel", { Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = assetId, ImageColor3 = C.SubText })
		return holder, function(col) Tween(img, 0.2, { ImageColor3 = col }) end
	end
	local parts = {}
	local function box(x, y, w, h, filled, round)
		local f = New("Frame", {
			Parent = holder, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = C.SubText, BackgroundTransparency = filled and 0 or 1, BorderSizePixel = 0,
		})
		if round then New("UICorner", { Parent = f, CornerRadius = UDim.new(round, 0) }) end
		if filled then
			parts[#parts + 1] = f
		else
			local st = Stroke(C.SubText, 2, 0); st.Parent = f
			parts[#parts + 1] = st
		end
		return f
	end
	local function traco(cx, cy, w, h, rot)
		New("Frame", {
			Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(w, h), Rotation = rot, BackgroundColor3 = C.Bg, BorderSizePixel = 0,
		})
	end
	local function text(t, size)
		parts[#parts + 1] = New("TextLabel", {
			Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = t, TextSize = size,
			TextColor3 = C.SubText, Font = Enum.Font.GothamBold,
		})
	end
	if key == "Status" then
		box(3, 10, 4, 8, true, 0.2); box(8, 5, 4, 13, true, 0.2); box(13, 2, 4, 16, true, 0.2)
	elseif key == "Jogador" then
		box(6, 2, 8, 8, true, 1); box(3, 12, 14, 7, true, 0.5)
	elseif key == "Visual" then
		box(1, 5, 18, 10, false, 0.5); box(8, 8, 4, 4, true, 1)
	elseif key == "Executor" then
		text(">_", 14)
	elseif key == "Teleport" then
		box(3, 3, 14, 14, false, 1); box(8, 8, 4, 4, true, 1)
	elseif key == "Música" then
		box(11, 2, 2, 12, true); box(11, 2, 6, 3, true); box(5, 12, 7, 6, true, 1)
	elseif key == "Proteção" then
		box(3, 2, 14, 10, true, 0.15)
		local ponta = box(0, 0, 9, 9, true)
		ponta.AnchorPoint = Vector2.new(0.5, 0.5); ponta.Position = UDim2.fromOffset(10, 10); ponta.Rotation = 45
		traco(8.2, 9.2, 2, 4, -45); traco(11.2, 8, 2, 7, 45)
	elseif key == "Config" then
		box(2, 3, 16, 2, true); box(2, 9, 16, 2, true); box(2, 15, 16, 2, true)
		box(12, 1, 4, 6, true, 0.3); box(5, 7, 4, 6, true, 0.3); box(10, 13, 4, 6, true, 0.3)
	else
		box(2, 2, 16, 16, false, 1); text("i", 12)
	end
	return holder, function(col)
		for _, o in ipairs(parts) do
			if o:IsA("UIStroke") then o.Color = col
			elseif o:IsA("TextLabel") then o.TextColor3 = col
			else o.BackgroundColor3 = col end
		end
	end
end

local ActiveTab = nil
local function PlaceIndicator(instant)
	if not ActiveTab then return end
	local btn = ActiveTab.Button
	local y = btn.AbsolutePosition.Y - Main.AbsolutePosition.Y + (btn.AbsoluteSize.Y - 24) / 2
	Indicator.Visible = y >= 48 and y <= Sidebar.AbsoluteSize.Y + 30
	Tween(Indicator, instant and 0 or 0.3, { Position = UDim2.fromOffset(12, y) })
end
Track(Sidebar:GetPropertyChangedSignal("CanvasPosition"):Connect(function() PlaceIndicator(true) end))

local function CreateTab(name, iconId, order)
	local btn = New("TextButton", {
		Parent = Sidebar, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = C.Purple, BackgroundTransparency = 1, LayoutOrder = order,
	}, { Corner(8) })
	local icon, setIconColor = MakeIcon(btn, iconId, name)
	icon.AnchorPoint = Vector2.new(0, 0.5); icon.Position = UDim2.new(0, 12, 0.5, 0)
	local txt = Label(btn, name, 14, C.SubText, true)
	txt.Position = UDim2.new(0, 42, 0, 0); txt.Size = UDim2.new(1, -46, 1, 0)

	local page = New("CanvasGroup", {
		Parent = Content, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		GroupTransparency = 1, Visible = false, Position = UDim2.fromOffset(20, 0),
	})
	local scroll = New("ScrollingFrame", {
		Parent = page, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.Purple, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { New("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }),
		New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local tab = { Button = btn, Text = txt, Page = page, Scroll = scroll, SetIcon = setIconColor }
	btn.MouseEnter:Connect(function() if ActiveTab ~= tab then Tween(btn, 0.15, { BackgroundTransparency = 0.9 }) end end)
	btn.MouseLeave:Connect(function() if ActiveTab ~= tab then Tween(btn, 0.15, { BackgroundTransparency = 1 }) end end)
	btn.Activated:Connect(function() tab.Select() end)

	function tab.Select(instant)
		if ActiveTab == tab then return end
		local old = ActiveTab
		ActiveTab = tab
		if old then
			Tween(old.Text, 0.2, { TextColor3 = C.SubText }); old.SetIcon(C.SubText)
			Tween(old.Button, 0.2, { BackgroundTransparency = 1 })
			Tween(old.Page, 0.2, { GroupTransparency = 1, Position = UDim2.fromOffset(-20, 0) })
			task.delay(0.2, function() if ActiveTab ~= old then old.Page.Visible = false end end)
		end
		Tween(txt, 0.2, { TextColor3 = C.Purple }); setIconColor(C.Purple)
		Tween(btn, 0.2, { BackgroundTransparency = 0.88 })
		page.Position = UDim2.fromOffset(20, 0); page.Visible = true
		Tween(page, 0.3, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
		PlaceIndicator(instant)
	end
	return tab
end

local function SectionTitle(tab, text)
	local l = Label(tab.Scroll, text:upper(), 12, C.Purple, true)
	l.Size = UDim2.new(1, 0, 0, 20)
	return l
end

local TabStatus = CreateTab("Status", Config.Icons.Status, 1)
local TabPlayer = CreateTab("Jogador", Config.Icons.Jogador, 2)
local TabVisual = CreateTab("Visual", Config.Icons.Visual, 3)
local TabExecutor = CreateTab("Executor", Config.Icons.Executor, 4)
local TabTeleport = CreateTab("Teleport", Config.Icons.Teleport, 5)
local TabMusic = CreateTab("Música", Config.Icons.Musica, 6)
local TabProt = CreateTab("Proteção", Config.Icons.Protecao, 7)
local TabConfig = CreateTab("Config", Config.Icons.Config, 8)
local TabInfo = CreateTab("Info", Config.Icons.Info, 9)
local StartTab = TabStatus

-- RECURSOS (versão completa)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")
local AssetService = game:GetService("AssetService")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

-- Música pelo Brookhaven
-- MusicRemote: nome do RemoteEvent que a Boombox usa. Vazio = procura sozinho.
-- Se não achar, o menu escreve no Output (F9) a lista de remotes; copie o certo pra cá.
Config.MusicRemote = ""
Config.MusicPlay = "PlaySong" -- 1º argumento enviado ao remote ao tocar (junto com o ID)
Config.MusicStop = "StopSong" -- 1º argumento enviado ao remote ao parar
-- Músicas fixas opcionais: { Name = "Música", Artist = "Artista", Id = 123456789 }
Config.Catalog = {}

Config.Changelog = {
	"Botão × agora pergunta e oculta tudo (menu e bolinha). Volte com /menu ou RightShift.",
	"Botão – esconde o menu na bolinha.",
	"Música redesenhada: só Pesquisar e ID, com Play, Cancelar e Favorita.",
	"Config: cor do menu, fonte, travar menu e bolinha, encerrar script.",
	"NoClip, Voar, ESP, Fullbright e Anti Fling reforçado.",
	"Correção: o emote não continua mais ao pular.",
}

local function GetHum() local c = Player.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function GetRoot() local c = Player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function FormatTime(s) s = math.max(0, math.floor(s)); return string.format("%d:%02d", s // 60, s % 60) end
local function Trim(s) return s:match("^%s*(.-)%s*$") end

-- Conexões dos recursos (religadas ao ligar/desligar). Tudo é desligado no "×"
local Held = {}
local function Hold(name, conn)
	if Held[name] then Held[name]:Disconnect() end
	Held[name] = conn
	return conn
end
local function Release(name)
	if Held[name] then Held[name]:Disconnect(); Held[name] = nil end
end
OnClose(function()
	for name in pairs(Held) do Release(name) end
end)

-- Funções que outras abas (comandos do Executor) usam
local Features = {}

-- ABA STATUS
do
	local s = TabStatus.Scroll
	local head = New("Frame", { Parent = s, Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, LayoutOrder = 1 })
	local avatar = New("ImageLabel", {
		Parent = head, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(84, 84), BackgroundColor3 = C.Panel,
	}, { Corner(42), Stroke(C.Purple, 2, 0.2) })
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok then avatar.Image = img end
	end)
	local dn = Label(head, Player.DisplayName, 18, C.Text, true, Enum.TextXAlignment.Center)
	dn.Position = UDim2.new(0, 0, 0, 94); dn.Size = UDim2.new(1, 0, 0, 24)
	local un = Label(head, "@" .. Player.Name, 13, C.SubText, false, Enum.TextXAlignment.Center)
	un.Position = UDim2.new(0, 0, 0, 119); un.Size = UDim2.new(1, 0, 0, 20)

	local function InfoRow(title, order)
		local row = Components.Row(s, title, 44); row.LayoutOrder = order
		local v = Label(row, "", 13, C.Purple, true, Enum.TextXAlignment.Right)
		v.AnchorPoint = Vector2.new(1, 0); v.Position = UDim2.new(1, -14, 0, 0); v.Size = UDim2.new(0.55, 0, 1, 0)
		return v
	end
	local jobV, playersV, timeV = InfoRow("ID do servidor", 2), InfoRow("Jogadores", 3), InfoRow("Horário atual", 4)
	jobV.Text = (game.JobId ~= "" and game.JobId:sub(1, 13) .. "…") or "Studio"
	task.spawn(function()
		while Gui.Parent do
			if ActiveTab == TabStatus then
				playersV.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
				timeV.Text = os.date("%H:%M:%S")
			end
			task.wait(1)
		end
	end)
end

-- ABA JOGADOR
local PlayerState = { WalkSpeed = 16, JumpPower = 50, InfJump = false }
do
	local s = TabPlayer.Scroll
	local gravPadrao = math.floor(workspace.Gravity)

	SectionTitle(TabPlayer, "Movimento")
	local _, setSpeed = Components.Slider(s, "Velocidade", 16, 120, 16, function(v)
		PlayerState.WalkSpeed = v
		local h = GetHum(); if h then h.WalkSpeed = v end
	end)
	local _, setJump = Components.Slider(s, "Força do pulo", 50, 200, 50, function(v)
		PlayerState.JumpPower = v
		local h = GetHum(); if h then h.UseJumpPower = true; h.JumpPower = v end
	end)
	local _, setInf = Components.Toggle(s, "Pulo infinito", false, function(on) PlayerState.InfJump = on end)

	-- NoClip: atravessa paredes e objetos
	local noclipParts = {}
	local function applyNoClip(on)
		if on then
			Hold("noclip", RunService.Stepped:Connect(function()
				local char = Player.Character
				if not char then return end
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") and p.CanCollide then noclipParts[p] = true; p.CanCollide = false end
				end
			end))
		else
			Release("noclip")
			for p in pairs(noclipParts) do if p.Parent then p.CanCollide = true end end
			table.clear(noclipParts)
		end
	end
	local _, setNoClip = Components.Toggle(s, "NoClip (atravessar tudo)", false, applyNoClip)
	Features.NoClip = setNoClip

	-- Voar: botão de pulo / Espaço sobe, Shift desce. Olhando para cima/baixo enquanto anda também sobe/desce
	local fly = { On = false, Speed = 60, UpUntil = 0 }
	local function stopFly()
		Release("fly"); Release("flyjump")
		if fly.BV then fly.BV:Destroy(); fly.BV = nil end
		if fly.BG then fly.BG:Destroy(); fly.BG = nil end
		local h = GetHum()
		if h then h.PlatformStand = false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end
	local function startFly()
		local root, hum = GetRoot(), GetHum()
		if not (root and hum) then return end
		stopFly()
		fly.BV = New("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero, Parent = root })
		fly.BG = New("BodyGyro", { MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 1e4, CFrame = root.CFrame, Parent = root })
		hum.PlatformStand = true
		Hold("flyjump", UserInputService.JumpRequest:Connect(function() fly.UpUntil = os.clock() + 0.2 end))
		Hold("fly", RunService.RenderStepped:Connect(function()
			local h, r = GetHum(), GetRoot()
			if not (h and r and fly.BV and fly.BV.Parent) then return end
			local cf = Camera.CFrame
			local md = h.MoveDirection
			local vel = Vector3.zero
			if md.Magnitude > 0 then
				local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
				flat = flat.Magnitude > 0 and flat.Unit or Vector3.zero
				vel = md * fly.Speed + Vector3.new(0, cf.LookVector.Y * md:Dot(flat) * fly.Speed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or os.clock() < fly.UpUntil then vel += Vector3.new(0, fly.Speed, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, fly.Speed, 0) end
			fly.BV.Velocity = vel
			local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
			if look.Magnitude > 0 then fly.BG.CFrame = CFrame.lookAt(r.Position, r.Position + look) end
		end))
	end
	local function applyFly(on)
		fly.On = on
		if on then startFly() else stopFly() end
	end
	local _, setFly = Components.Toggle(s, "Voar", false, applyFly)
	Features.Fly = setFly
	Features.IsFlying = function() return fly.On end
	local _, setFlySpeed = Components.Slider(s, "Velocidade do voo", 10, 150, 60, function(v) fly.Speed = v end)

	-- Emote: para quando pular (e, se quiser, ao andar). Corrige o emote que ficava rodando
	local emote = { Jump = true, Walk = false }
	local function stopEmotes()
		local char, hum = Player.Character, GetHum()
		if not (char and hum) then return end
		if char:FindFirstChildOfClass("Tool") then return end -- segurando item: não mexe nas animações do item
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then return end
		local defaults = {}
		local animate = char:FindFirstChild("Animate")
		if animate then
			for _, d in ipairs(animate:GetDescendants()) do
				if d:IsA("Animation") then defaults[d.AnimationId] = true end
			end
		end
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local id = track.Animation and track.Animation.AnimationId
			if not (id and defaults[id]) and track.Priority ~= Enum.AnimationPriority.Movement then
				track:Stop(0.1)
			end
		end
	end
	local emoteClock = 0
	Hold("emote", RunService.Heartbeat:Connect(function(dt)
		emoteClock += dt
		if emoteClock < 0.1 then return end
		emoteClock = 0
		local h = GetHum()
		if not h then return end
		local st = h:GetState()
		if emote.Jump and (st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall) then stopEmotes() end
		if emote.Walk and h.MoveDirection.Magnitude > 0 then stopEmotes() end
	end))
	Hold("emotejump", UserInputService.JumpRequest:Connect(function()
		if emote.Jump then stopEmotes() end
	end))
	local _, setEmoteJump = Components.Toggle(s, "Parar emote ao pular", true, function(on) emote.Jump = on end)
	local _, setEmoteWalk = Components.Toggle(s, "Parar emote ao andar", false, function(on) emote.Walk = on end)

	-- Teleporte por clique (PC: Ctrl + clique | celular: toque no mundo)
	local function rayHit(ray)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Player.Character }
		return workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	end
	local function tpTo(res)
		local r = GetRoot()
		if r and res then r.CFrame = CFrame.new(res.Position + Vector3.new(0, 3.5, 0)) end
	end
	local function applyClickTp(on)
		if on then
			Hold("ctp1", UserInputService.InputBegan:Connect(function(i, processed)
				if processed then return end
				if i.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
					local m = UserInputService:GetMouseLocation()
					tpTo(rayHit(Camera:ViewportPointToRay(m.X, m.Y)))
				end
			end))
			Hold("ctp2", UserInputService.TouchTapInWorld:Connect(function(pos, processed)
				if processed then return end
				tpTo(rayHit(Camera:ScreenPointToRay(pos.X, pos.Y)))
			end))
		else
			Release("ctp1"); Release("ctp2")
		end
	end
	local _, setClickTp = Components.Toggle(s, "Teleporte por clique", false, applyClickTp)
	local hint = Label(s, "PC: Ctrl + clique  •  Celular: toque no chão", 11, C.SubText)
	hint.Size = UDim2.new(1, 0, 0, 14)

	SectionTitle(TabPlayer, "Câmera e mundo")
	local _, setFov = Components.Slider(s, "Campo de visão (FOV)", 50, 120, 70, function(v) Camera.FieldOfView = v end)
	local _, setGrav = Components.Slider(s, "Gravidade", 40, 196, gravPadrao, function(v) workspace.Gravity = v end)
	local zoomMax, zoomMin = Player.CameraMaxZoomDistance, Player.CameraMinZoomDistance
	local _, setZoom = Components.Toggle(s, "Zoom da câmera livre", false, function(on)
		Player.CameraMaxZoomDistance = on and 100000 or zoomMax
		Player.CameraMinZoomDistance = on and 0 or zoomMin
	end)

	SectionTitle(TabPlayer, "Configurações")
	Components.Button(s, "Resetar configurações", "Resetar", function()
		setSpeed(16); setJump(50); setFov(70); setGrav(gravPadrao); setInf(false)
		setNoClip(false); setFly(false); setFlySpeed(60); setClickTp(false); setZoom(false)
		setEmoteJump(true); setEmoteWalk(false)
		Notify("Jogador", "Configurações voltaram ao normal.", "ok")
	end)

	Track(UserInputService.JumpRequest:Connect(function()
		if PlayerState.InfJump and not fly.On then local h = GetHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
	end))
	Track(Player.CharacterAdded:Connect(function(char)
		local h = char:WaitForChild("Humanoid")
		h.WalkSpeed = PlayerState.WalkSpeed; h.UseJumpPower = true; h.JumpPower = PlayerState.JumpPower
		if fly.On then task.wait(0.6); startFly() end
	end))

	-- Ao fechar o menu, devolve tudo ao normal
	OnClose(function()
		applyNoClip(false); stopFly(); applyClickTp(false)
		local h = GetHum()
		if h then h.WalkSpeed = 16; h.UseJumpPower = true; h.JumpPower = 50 end
		Camera.FieldOfView = 70
		workspace.Gravity = gravPadrao
		Player.CameraMaxZoomDistance = zoomMax; Player.CameraMinZoomDistance = zoomMin
	end)
end

-- ABA VISUAL
do
	local s = TabVisual.Scroll
	local folder = New("Folder", { Name = "ESP", Parent = Gui })
	local esp = { Fill = false, Names = false, Items = {} }

	SectionTitle(TabVisual, "ESP")
	local function clear(p)
		local it = esp.Items[p]
		if it then
			if it.hl then it.hl:Destroy() end
			if it.tag then it.tag:Destroy() end
			esp.Items[p] = nil
		end
	end
	local function build(p)
		if p == Player then return end
		local char = p.Character
		local head = char and char:FindFirstChild("Head")
		if not (char and head) then clear(p); return end
		local it = esp.Items[p] or {}
		esp.Items[p] = it
		if esp.Fill then
			if not (it.hl and it.hl.Parent) then
				it.hl = New("Highlight", {
					Parent = folder, Adornee = char, FillColor = C.Purple, FillTransparency = 0.6,
					OutlineColor = Color3.new(1, 1, 1), OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				})
			end
			it.hl.Adornee = char
		elseif it.hl then
			it.hl:Destroy(); it.hl = nil
		end
		if esp.Names then
			if not (it.tag and it.tag.Parent) then
				it.tag = New("BillboardGui", {
					Parent = folder, Size = UDim2.fromOffset(160, 36), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true,
				})
				it.label = New("TextLabel", {
					Parent = it.tag, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextSize = 13, Font = Enum.Font.GothamBold,
					TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4,
				})
			end
			it.tag.Adornee = head
		elseif it.tag then
			it.tag:Destroy(); it.tag = nil
		end
	end
	local function rebuildAll()
		for _, p in ipairs(Players:GetPlayers()) do build(p) end
	end
	local function watch(p)
		if p == Player then return end
		Track(p.CharacterAdded:Connect(function() task.wait(0.3); build(p) end))
	end
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	Track(Players.PlayerAdded:Connect(watch))
	Track(Players.PlayerRemoving:Connect(clear))
	task.spawn(function()
		while Gui.Parent do
			if esp.Names then
				for p, it in pairs(esp.Items) do
					local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if it.label and r then
						it.label.Text = ("%s\n%d studs"):format(p.DisplayName, (Camera.CFrame.Position - r.Position).Magnitude)
					end
				end
			end
			task.wait(0.25)
		end
	end)

	local _, setEspFill = Components.Toggle(s, "ESP destaque (contorno)", false, function(on) esp.Fill = on; rebuildAll() end)
	local _, setEspNames = Components.Toggle(s, "ESP nome e distância", false, function(on) esp.Names = on; rebuildAll() end)
	Features.ESP = function(on) setEspFill(on); setEspNames(on) end

	-- Iluminação
	SectionTitle(TabVisual, "Iluminação")
	local orig = {
		Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
	}
	local atmos = {}
	local function fullbright(on)
		if on then
			Hold("fullbright", RunService.RenderStepped:Connect(function()
				Lighting.Brightness = 2; Lighting.GlobalShadows = false
				Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
			end))
		else
			Release("fullbright")
			Lighting.Brightness = orig.Brightness; Lighting.GlobalShadows = orig.GlobalShadows
			Lighting.Ambient = orig.Ambient; Lighting.OutdoorAmbient = orig.OutdoorAmbient
		end
	end
	local function nofog(on)
		if on then
			Hold("nofog", RunService.RenderStepped:Connect(function()
				Lighting.FogEnd = 1e6
				for _, a in ipairs(Lighting:GetChildren()) do
					if a:IsA("Atmosphere") then
						if atmos[a] == nil then atmos[a] = a.Density end
						a.Density = 0
					end
				end
			end))
		else
			Release("nofog")
			Lighting.FogEnd = orig.FogEnd; Lighting.FogStart = orig.FogStart
			for a, d in pairs(atmos) do if a.Parent then a.Density = d end end
			table.clear(atmos)
		end
	end
	local _, setFull = Components.Toggle(s, "Fullbright (tudo iluminado)", false, fullbright)
	local _, setFog = Components.Toggle(s, "Sem neblina", false, nofog)
	local clock0 = Lighting.ClockTime
	local _, setClock = Components.Slider(s, "Hora do dia", 0, 24, math.floor(clock0), function(v) Lighting.ClockTime = v end)

	Components.Button(s, "Resetar visual", "Resetar", function()
		setEspFill(false); setEspNames(false); setFull(false); setFog(false)
		Lighting.ClockTime = clock0; setClock(clock0)
		Notify("Visual", "Visual voltou ao normal.", "ok")
	end)

	OnClose(function()
		esp.Fill, esp.Names = false, false
		for p in pairs(esp.Items) do clear(p) end
		fullbright(false); nofog(false)
		Lighting.ClockTime = clock0
	end)
end

-- ABA EXECUTOR
-- Console de comandos. Os mesmos comandos funcionam no chat; os logs aparecem aqui.
local Executor = {}
do
	local page = TabExecutor.Page
	TabExecutor.Scroll.Visible = false
	local KIND = { info = C.Text, ok = C.Ok, err = C.Error, chat = C.Purple }

	local logs = New("ScrollingFrame", {
		Parent = page, Size = UDim2.new(1, 0, 1, -118), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.Purple, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { Corner(10), Stroke(C.Purple, 1, 0.8), New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }) })
	local lines, order = {}, 0
	function Executor.Log(text, kind)
		order += 1
		local l = New("TextLabel", {
			Parent = logs, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true, Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = KIND[kind or "info"] or C.Text, Text = ("[%s] %s"):format(os.date("%H:%M:%S"), text),
		})
		table.insert(lines, l)
		if #lines > 100 then table.remove(lines, 1):Destroy() end
		task.defer(function() logs.CanvasPosition = Vector2.new(0, 1e6) end)
	end
	function Executor.Clear() for _, l in ipairs(lines) do l:Destroy() end; table.clear(lines) end

	local inputRow = New("Frame", {
		Parent = page, Position = UDim2.new(0, 0, 1, -110), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.Row, BackgroundTransparency = 0.25,
	}, { Corner(10), Stroke(C.Purple, 1, 0.6) })
	local box = New("TextBox", {
		Parent = inputRow, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0), Text = "",
		PlaceholderText = "/comando", PlaceholderColor3 = C.SubText, TextColor3 = C.Text, Font = Enum.Font.Code, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
	})
	local send = Components.SmallButton(inputRow, "Enviar", 64)
	send.AnchorPoint = Vector2.new(1, 0.5); send.Position = UDim2.new(1, -8, 0.5, 0)

	local function findPlayer(q)
		q = (q or ""):lower()
		if q == "" then return end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q then return p end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then return p end
		end
	end
	local function number(a, min, max)
		local n = tonumber(a)
		if n and n >= min and n <= max then return n end
	end

	-- Para criar um comando novo, adicione uma linha aqui. run(args) retorna: sucesso, mensagem
	local Commands = {
		{ name = "view", usage = "/view nick", run = function(a)
			local t = findPlayer(a[1]); if not t then return false, "Jogador não encontrado." end
			local h = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
			if not h then return false, "Personagem indisponível." end
			Camera.CameraSubject = h; return true, "Vendo " .. t.Name
		end },
		{ name = "unview", usage = "/unview", run = function()
			local h = GetHum(); if not h then return false, "Sem personagem." end
			Camera.CameraSubject = h; return true, "Câmera restaurada."
		end },
		{ name = "goto", usage = "/goto nick", run = function(a)
			local t = findPlayer(a[1]); if not t then return false, "Jogador não encontrado." end
			local tr, r = t.Character and t.Character:FindFirstChild("HumanoidRootPart"), GetRoot()
			if not (tr and r) then return false, "Personagem indisponível." end
			r.CFrame = tr.CFrame + Vector3.new(0, 3, 0); return true, "Teleportado até " .. t.Name
		end },
		{ name = "speed", usage = "/speed valor", run = function(a)
			local n = number(a[1], 0, 500); if not n then return false, "Valor inválido (0 a 500)." end
			PlayerState.WalkSpeed = n; local h = GetHum(); if h then h.WalkSpeed = n end
			return true, "Velocidade: " .. n
		end },
		{ name = "jump", usage = "/jump valor", run = function(a)
			local n = number(a[1], 0, 500); if not n then return false, "Valor inválido (0 a 500)." end
			PlayerState.JumpPower = n; local h = GetHum(); if h then h.UseJumpPower = true; h.JumpPower = n end
			return true, "Pulo: " .. n
		end },
		{ name = "fov", usage = "/fov valor", run = function(a)
			local n = number(a[1], 1, 120); if not n then return false, "Valor inválido (1 a 120)." end
			Camera.FieldOfView = n; return true, "FOV: " .. n
		end },
		{ name = "noclip", usage = "/noclip", run = function() Features.NoClip(true); return true, "NoClip ligado." end },
		{ name = "clip", usage = "/clip", run = function() Features.NoClip(false); return true, "NoClip desligado." end },
		{ name = "fly", usage = "/fly", run = function() Features.Fly(true); return true, "Voo ligado." end },
		{ name = "unfly", usage = "/unfly", run = function() Features.Fly(false); return true, "Voo desligado." end },
		{ name = "esp", usage = "/esp", run = function() Features.ESP(true); return true, "ESP ligado." end },
		{ name = "unesp", usage = "/unesp", run = function() Features.ESP(false); return true, "ESP desligado." end },
		{ name = "rejoin", usage = "/rejoin", run = function()
			if game.JobId == "" then return false, "Não funciona no Studio." end
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
			return true, "Reentrando no servidor..."
		end },
		{ name = "reset", usage = "/reset", run = function()
			local h = GetHum(); if not h then return false, "Sem personagem." end
			h.Health = 0; return true, "Personagem resetado."
		end },
		{ name = "ocultar", usage = "/ocultar", run = function() task.defer(Window.Hide); return true end },
		{ name = "fechar", usage = "/fechar", run = function() task.spawn(Window.Close); return true end },
		{ name = "clear", usage = "/clear", run = function() Executor.Clear(); return true end },
	}
	local byName = {}
	for _, c in ipairs(Commands) do byName[c.name] = c end

	function Executor.Run(text, source)
		local t = Trim(text)
		if t == "" then return end
		if t:sub(1, 1) ~= "/" then t = "/" .. t end
		local args = t:sub(2):split(" ")
		local cmd = table.remove(args, 1):lower()
		local def = byName[cmd]
		if cmd ~= "clear" then Executor.Log((source == "chat" and "chat > " or "> ") .. t, source == "chat" and "chat" or "info") end
		if not def then
			Executor.Log("Comando desconhecido: " .. cmd, "err"); Notify("Erro", "Comando desconhecido: " .. cmd, "err"); return
		end
		local ok, success, msg = pcall(def.run, args)
		if not ok then success, msg = false, "Erro interno ao executar." end
		if msg then Executor.Log(msg, success and "ok" or "err") end
		if not success then Notify("Erro", msg or "Falha ao executar.", "err") end
	end

	-- Sugestões: filtram enquanto digita, toque para preencher
	local sug = New("ScrollingFrame", {
		Parent = page, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = C.Purple, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { New("UIListLayout", { Padding = UDim.new(0, 2) }) })
	local function refreshSuggestions()
		for _, c in ipairs(sug:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local first = box.Text:match("^/?(%S*)"):lower()
		for _, c in ipairs(Commands) do
			if first == "" or c.name:sub(1, #first) == first then
				local b = New("TextButton", {
					Parent = sug, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = c.usage, Font = Enum.Font.Code, TextSize = 13,
					TextColor3 = C.Purple, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false,
				}, { New("UIPadding", { PaddingLeft = UDim.new(0, 6) }) })
				b.Activated:Connect(function() box.Text = "/" .. c.name .. " "; box:CaptureFocus() end)
			end
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(refreshSuggestions)
	refreshSuggestions()

	local function submit() Executor.Run(box.Text, "exec"); box.Text = "" end
	box.FocusLost:Connect(function(enter) if enter then submit() end end)
	send.Activated:Connect(submit)

	-- Os mesmos comandos digitados no chat
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local made = {}
		for _, c in ipairs(Commands) do
			local cmd = Instance.new("TextChatCommand")
			cmd.Name = "Warrior_" .. c.name; cmd.PrimaryAlias = "/" .. c.name
			cmd.Triggered:Connect(function(_, text) Executor.Run(text, "chat") end)
			cmd.Parent = TextChatService
			made[#made + 1] = cmd
		end
		OnClose(function() for _, cmd in ipairs(made) do cmd:Destroy() end end)
	else
		Track(Player.Chatted:Connect(function(msg)
			if msg:sub(1, 1) == "/" and byName[msg:sub(2):split(" ")[1]:lower()] then Executor.Run(msg, "chat") end
		end))
	end
	Executor.Log("Warrior Client pronto.", "ok")
end

-- ABA TELEPORT
do
	local s = TabTeleport.Scroll
	local ROW_H, VISIBLE_ROWS = 36, 5
	local selected

	SectionTitle(TabTeleport, "Jogadores")
	local list = New("ScrollingFrame", {
		Parent = s, Size = UDim2.new(1, 0, 0, VISIBLE_ROWS * (ROW_H + 4) + 8), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.4,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Purple, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { Corner(10), Stroke(C.Purple, 1, 0.8), New("UIListLayout", { Padding = UDim.new(0, 4) }),
		New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })

	local function refresh()
		for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
		local count = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player then
				count += 1
				local b = New("TextButton", {
					Parent = list, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, ROW_H),
					BackgroundColor3 = (selected == p) and C.PurpleDark or C.Row, BackgroundTransparency = 0.2,
				}, { Corner(8) })
				local n = Label(b, p.DisplayName .. "  @" .. p.Name, 13, C.Text, true)
				n.Position = UDim2.fromOffset(12, 0); n.Size = UDim2.new(1, -24, 1, 0)
				b.Activated:Connect(function()
					selected = p
					for _, o in ipairs(list:GetChildren()) do if o:IsA("TextButton") then Tween(o, 0.15, { BackgroundColor3 = C.Row }) end end
					Tween(b, 0.15, { BackgroundColor3 = C.PurpleDark })
				end)
			end
		end
		if count == 0 then
			local l = Label(list, "Nenhum outro jogador", 12, C.SubText, false, Enum.TextXAlignment.Center); l.Size = UDim2.new(1, 0, 0, 30)
		end
	end
	refresh()
	Track(Players.PlayerAdded:Connect(refresh))
	Track(Players.PlayerRemoving:Connect(function(p)
		if selected == p then selected = nil end
		task.defer(refresh)
	end))

	Components.Button(s, "Teleportar até o jogador", "Ir", function()
		if not selected then Notify("Erro", "Selecione um jogador.", "err") return end
		local tr = selected.Character and selected.Character:FindFirstChild("HumanoidRootPart")
		local r = GetRoot()
		if not tr or not r then Notify("Erro", "Personagem indisponível.", "err") return end
		r.CFrame = tr.CFrame + Vector3.new(0, 3, 0)
	end)

	SectionTitle(TabTeleport, "Posição")
	local saved
	Components.Button(s, "Salvar posição atual", "Salvar", function()
		local r = GetRoot(); if not r then Notify("Erro", "Sem personagem.", "err") return end
		saved = r.CFrame; Notify("Teleport", "Posição salva.", "ok")
	end)
	Components.Button(s, "Voltar à posição salva", "Voltar", function()
		local r = GetRoot()
		if not saved then Notify("Erro", "Nenhuma posição salva.", "err") return end
		if r then r.CFrame = saved end
	end)
	Components.Button(s, "Ir para o spawn", "Ir", function()
		local r = GetRoot()
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if not (r and spawn) then Notify("Erro", "Spawn não encontrado.", "err") return end
		r.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
	end)

	SectionTitle(TabTeleport, "Servidor")
	local row = Components.Row(s, nil, 48)
	local box = New("TextBox", {
		Parent = row, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -112, 1, -16), BackgroundColor3 = C.Panel,
		Text = "", PlaceholderText = "ID do servidor", PlaceholderColor3 = C.SubText, TextColor3 = C.Text,
		Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd,
	}, { Corner(8), New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	local bJoin = Components.SmallButton(row, "Entrar", 78)
	bJoin.AnchorPoint = Vector2.new(1, 0.5); bJoin.Position = UDim2.new(1, -10, 0.5, 0)

	Track(TeleportService.TeleportInitFailed:Connect(function(plr)
		if plr == Player then Notify("Erro", "Servidor indisponível, cheio ou ID errado.", "err") end
	end))
	bJoin.Activated:Connect(function()
		local id = box.Text:gsub("%s", "")
		if id == "" then Notify("Erro", "Digite o ID do servidor.", "err") return end
		if id == game.JobId then Notify("Erro", "Você já está nesse servidor.", "err") return end
		Notify("Teleport", "Entrando no servidor...", "ok")
		local ok = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, id, Player)
		if not ok then Notify("Erro", "Não foi possível entrar nesse servidor.", "err") end
	end)

	local meu = Components.Row(s, nil, 48)
	New("TextBox", {
		Parent = meu, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 1, -16), BackgroundColor3 = C.Panel,
		Text = game.JobId ~= "" and game.JobId or "Studio", TextEditable = false, ClearTextOnFocus = false, TextColor3 = C.SubText,
		Font = Enum.Font.Gotham, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
	}, { Corner(8), New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })

	Components.Button(s, "Reentrar neste servidor", "Reentrar", function()
		if game.JobId == "" then Notify("Erro", "Não funciona no Studio.", "err") return end
		Notify("Teleport", "Reentrando...", "ok")
		pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, Player)
	end)
end

-- ABA MÚSICA
-- Duas abas: Pesquisar e ID. Três botões: Play, Cancelar e Favorita.
-- Manda o ID para o remote de música do Brookhaven. O próprio Brookhaven toca o som
-- e faz quem está perto ouvir (inclusive a checagem da gamepass), então não há servidor aqui.
-- "Só eu" toca um som local que só você ouve (nesse modo dá para avançar a música na barra).
-- Pause e Volume mexem no som do seu lado; Cancelar também manda parar no Brookhaven.
do
	local s = TabMusic.Scroll
	local M = {
		Volume = 5, OnlyMe = false, Mode = 1,
		Selected = nil, Current = nil, Active = nil, Busy = false, Gen = 0,
		Favorites = {}, Results = {}, Pages = nil, SearchV = 0,
	}
	local localSound = New("Sound", { Name = "WarriorLocal", Parent = SoundService, Volume = 0.5 })
	OnClose(function() localSound:Stop(); localSound:Destroy() end)

	-- Remote do Brookhaven
	local KEYWORDS = { "mus", "song", "boom", "radio", "audio", "sound" }
	local remoteCache

	local function isRemote(r) return r:IsA("RemoteEvent") or r:IsA("RemoteFunction") end
	local function findRemote()
		if remoteCache and remoteCache.Parent then return remoteCache end
		if Config.MusicRemote ~= "" then
			local re = ReplicatedStorage:FindFirstChild("RE")
			local r = ReplicatedStorage:FindFirstChild(Config.MusicRemote) or (re and re:FindFirstChild(Config.MusicRemote))
			remoteCache = r and isRemote(r) and r or nil
			return remoteCache
		end
		for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
			if isRemote(r) then
				local n = r.Name:lower()
				for _, k in ipairs(KEYWORDS) do
					if n:find(k, 1, true) then remoteCache = r; return r end
				end
			end
		end
	end
	local function printRemotes()
		warn("[Warrior] Remote de música não encontrado. Remotes em ReplicatedStorage:")
		for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
			if isRemote(r) then warn("  " .. r:GetFullName()) end
		end
		warn("[Warrior] Copie o nome do remote da Boombox para Config.MusicRemote.")
	end
	local function fire(...)
		local r = findRemote()
		if not r then return false end
		local args = table.pack(...)
		return pcall(function()
			if r:IsA("RemoteEvent") then r:FireServer(table.unpack(args, 1, args.n)) else r:InvokeServer(table.unpack(args, 1, args.n)) end
		end)
	end

	-- Objeto que toca a música: Boombox na mão ou veículo em que você está
	local function soundOf(root)
		return root and (root:FindFirstChild("PlayersChoice", true) or root:FindFirstChildWhichIsA("Sound", true))
	end
	local function findObject()
		local char = Player.Character
		local tool = char and char:FindFirstChild("Boombox")
		if tool and tool:IsA("Tool") and tool:FindFirstChild("Handle") then
			return { Name = tool.Name, Kind = "Boombox", Root = tool }
		end
		local h = GetHum()
		local seat = h and h.SeatPart
		if seat then
			local model = seat:FindFirstAncestorOfClass("Model")
			return { Name = model and model.Name or seat.Name, Kind = "Veículo", Root = model or seat }
		end
	end
	local function parseId(text)
		local n = (text or ""):match("%d%d%d+")
		return n and tonumber(n)
	end

	-- CARD DO PLAYER
	local card = New("Frame", { Parent = s, Size = UDim2.new(1, 0, 0, 190), BackgroundColor3 = C.Row, BackgroundTransparency = 0.15, LayoutOrder = 1 },
		{ Corner(16), Stroke(C.Purple, 1.5, 0.35) })
	local art = New("Frame", { Parent = card, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = C.PurpleDark, ClipsDescendants = true },
		{ Corner(14), New("UIGradient", { Color = ColorSequence.new(C.Purple, C.Bg), Rotation = 45 }) })
	local bars = {}
	for i = 1, 4 do
		bars[i] = New("Frame", {
			Parent = art, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12 + (i - 1) * 17, 1, -12), Size = UDim2.fromOffset(10, 6),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1, BorderSizePixel = 0,
		}, { Corner(4) })
	end
	local npTitle = Label(card, "Nada tocando", 16, C.Text, true); npTitle.Position = UDim2.fromOffset(112, 20); npTitle.Size = UDim2.new(1, -126, 0, 22)
	local npArtist = Label(card, "Escolha uma música", 12, C.SubText); npArtist.Position = UDim2.fromOffset(112, 44); npArtist.Size = UDim2.new(1, -126, 0, 16)
	local npStatus = Label(card, "PARADO", 11, C.Purple, true); npStatus.Position = UDim2.fromOffset(112, 70); npStatus.Size = UDim2.new(1, -126, 0, 16)

	local barBg = New("TextButton", {
		Parent = card, Text = "", AutoButtonColor = false, Position = UDim2.new(0, 14, 0, 110), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = C.Panel,
	}, { Corner(4) })
	local barFill = New("Frame", { Parent = barBg, Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Purple, BorderSizePixel = 0 }, { Corner(4) })
	local tCur = Label(card, "0:00", 11, C.SubText); tCur.Position = UDim2.fromOffset(14, 122); tCur.Size = UDim2.fromOffset(60, 16)
	local tEnd = Label(card, "0:00", 11, C.SubText, false, Enum.TextXAlignment.Right)
	tEnd.AnchorPoint = Vector2.new(1, 0); tEnd.Position = UDim2.new(1, -14, 0, 122); tEnd.Size = UDim2.fromOffset(60, 16)

	local ctrl = New("Frame", { Parent = card, Position = UDim2.new(0, 14, 1, -14), AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -28, 0, 36), BackgroundTransparency = 1 },
		{ New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function ctrlBtn(text, w, order, fill)
		return New("TextButton", {
			Parent = ctrl, Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false,
			Size = UDim2.new(w, -4, 1, 0), BackgroundColor3 = fill, LayoutOrder = order,
		}, { Corner(10) })
	end
	local bPlay = ctrlBtn("Play", 0.4, 1, C.Purple)
	local bStop = ctrlBtn("Cancelar", 0.3, 2, C.Panel)
	bStop.TextColor3 = C.Text; Stroke(C.Purple, 1, 0.6).Parent = bStop
	local bFav = ctrlBtn("☆ Favorita", 0.3, 3, C.Panel)
	bFav.TextColor3 = C.Text; Stroke(C.Purple, 1, 0.6).Parent = bFav

	local playItem, buildList, showList, refreshFav

	-- Reprodução
	local endedConn
	local function detach()
		if endedConn then endedConn:Disconnect(); endedConn = nil end
		M.Gen += 1
	end
	local function resetNowPlaying()
		detach()
		M.Active, M.Current = nil, nil
		npTitle.Text = "Nada tocando"; npArtist.Text = "Escolha uma música"
	end
	local function stopActive()
		local snd = M.Active
		detach()
		if snd and snd ~= localSound then fire(Config.MusicStop) end
		if snd then snd:Stop() end
		M.Active = nil
	end
	-- Quando a música acaba, limpa o player
	local function attach(snd)
		if endedConn then endedConn:Disconnect() end
		local gen = M.Gen
		endedConn = snd.Ended:Connect(function()
			if gen == M.Gen and M.Active == snd then resetNowPlaying() end
		end)
	end

	-- Toca o som local e espera carregar (confirma se o áudio funciona)
	local function playLocal(id)
		localSound.Volume, localSound.Looped = M.Volume / 10, false
		localSound.SoundId = "rbxassetid://" .. id
		localSound:Play()
		local w = 0
		while not localSound.IsLoaded and w < 6 do w += task.wait(0.1) end
		if not localSound.IsLoaded then localSound:Stop(); return false, "Áudio não carregou (ID/permissão)." end
		M.Active = localSound
		return true, "Tocando só para você."
	end

	-- Envia o ID ao Brookhaven e confirma olhando se o som do objeto trocou para esse ID
	local function playBrookhaven(id)
		local obj = findObject()
		if not obj then return false, "Equipe a Boombox ou sente no veículo." end
		if not findRemote() then printRemotes(); return false, "Remote não encontrado. Veja o Output (F9)." end
		local ok = fire(Config.MusicPlay, id)
		if not ok then return false, "Erro ao enviar para o Brookhaven." end
		local key = tostring(id)
		local w = 0
		while w < 4 do
			local snd = soundOf(obj.Root)
			if snd and snd.SoundId:find(key, 1, true) then
				M.Active = snd
				snd.Looped = false
				return true, "Tocando para quem está perto."
			end
			w += task.wait(0.2)
		end
		return false, "O Brookhaven não tocou. Falta a gamepass de música ou o remote está diferente."
	end

	-- it = { Id, Name, Artist }
	function playItem(it)
		if M.Busy then return end
		local id = it and it.Id
		if not id or id <= 0 then Notify("Erro", "Escolha uma música ou digite um ID.", "err") return end
		M.Busy = true
		npStatus.Text = "CARREGANDO..."
		local ok, success, msg = pcall(function()
			local okInfo, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Asset)
			if okInfo and info then
				if info.AssetTypeId ~= 3 then return false, "Esse ID não é um áudio." end
				it.Name = it.Name or info.Name
				it.Artist = it.Artist or (info.Creator and info.Creator.Name)
			end
			stopActive()
			if M.OnlyMe then return playLocal(id) end
			return playBrookhaven(id)
		end)
		M.Busy = false
		if not ok then success, msg = false, "Erro ao tocar a música." end
		Notify(success and "Música" or "Erro", msg, success and "ok" or "err")
		if success then
			M.Current, M.Selected = it, it
			npTitle.Text = it.Name or ("Áudio " .. id); npArtist.Text = it.Artist or "—"
			attach(M.Active)
			refreshFav()
		end
	end

	-- Favoritas
	local function favIndex(id)
		for i, f in ipairs(M.Favorites) do if f.Id == id then return i end end
	end
	local idBox -- caixa da aba ID (definida abaixo)
	local function favTarget()
		if M.Mode == 2 and idBox then
			local id = parseId(idBox.Text)
			if id then return (M.Current and M.Current.Id == id) and M.Current or { Id = id, Name = "Áudio " .. id } end
		end
		return M.Selected
	end
	function refreshFav()
		local t = favTarget()
		local on = t and favIndex(t.Id)
		bFav.Text = on and "★ Favorita" or "☆ Favorita"
		Tween(bFav, 0.2, { BackgroundColor3 = on and C.PurpleDark or C.Panel })
	end

	-- Botões do card
	local function wanted()
		if M.Mode == 2 then
			local id = parseId(idBox.Text)
			return id and { Id = id }
		end
		return M.Selected
	end
	bPlay.Activated:Connect(function()
		local snd, want = M.Active, wanted()
		if want and (not M.Current or want.Id ~= M.Current.Id) then playItem(want) return end
		if snd and snd.IsPlaying then snd:Pause() return end
		if snd and snd.IsPaused then snd:Resume() return end
		if want then playItem(want) else Notify("Erro", "Escolha uma música ou digite um ID.", "err") end
	end)
	bStop.Activated:Connect(function() stopActive(); resetNowPlaying() end)
	bFav.Activated:Connect(function()
		local t = favTarget()
		if not t then Notify("Erro", "Escolha uma música primeiro.", "err") return end
		local i = favIndex(t.Id)
		if i then
			table.remove(M.Favorites, i)
			Notify("Favoritas", "Removida das favoritas.", "info")
		else
			table.insert(M.Favorites, { Id = t.Id, Name = t.Name, Artist = t.Artist })
			Notify("Favoritas", "Adicionada às favoritas.", "ok")
		end
		refreshFav(); showList()
	end)

	-- Clicar na barra avança a música (só no modo "Só eu")
	barBg.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
		if M.Active == localSound and localSound.TimeLength > 0 then
			local f = math.clamp((i.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
			localSound.TimePosition = f * localSound.TimeLength
		elseif M.Active then
			Notify("Música", "Avançar só funciona no modo \"Só eu\".", "info")
		end
	end)

	local volRow = Components.Slider(s, "Volume", 0, 10, 5, function(v)
		M.Volume = v
		localSound.Volume = v / 10
		if M.Active then M.Active.Volume = v / 10 end
	end)
	volRow.LayoutOrder = 2

	local onlyMe = Components.Toggle(s, "Só eu (ouvir só pra mim)", false, function(on)
		M.OnlyMe = on
		stopActive(); resetNowPlaying()
	end)
	onlyMe.LayoutOrder = 3
	local objLbl = Label(s, "", 12, C.SubText); objLbl.Size = UDim2.new(1, 0, 0, 16); objLbl.LayoutOrder = 4

	-- ABAS: Pesquisar e ID
	local panels = {}
	local seg = New("Frame", { Parent = s, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.3, LayoutOrder = 5 }, { Corner(12) })
	local pill = New("Frame", { Parent = seg, Size = UDim2.new(0.5, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4), BackgroundColor3 = C.Purple }, { Corner(9) })
	local function panel()
		local p = New("Frame", { Parent = s, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 6 },
			{ New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		panels[#panels + 1] = p
		return p
	end
	local searchPanel, idPanel = panel(), panel()
	idPanel.Visible = false
	for i, text in ipairs({ "Pesquisar", "ID" }) do
		local b = New("TextButton", {
			Parent = seg, Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.Text, BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale((i - 1) * 0.5, 0), ZIndex = 2,
		})
		b.Activated:Connect(function()
			M.Mode = i
			Tween(pill, 0.25, { Position = UDim2.new((i - 1) * 0.5, 4, 0, 4) })
			for j, p in ipairs(panels) do p.Visible = j == i end
			refreshFav()
		end)
	end

	-- Lista de músicas (toque para escolher; depois Play)
	function buildList(container, items, empty, more)
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
		end
		if #items == 0 then
			local l = Label(container, empty, 12, C.SubText, false, Enum.TextXAlignment.Center)
			l.Size = UDim2.new(1, 0, 0, 40); l.TextWrapped = true; l.TextTruncate = Enum.TextTruncate.None
			return
		end
		for idx, it in ipairs(items) do
			local row = New("Frame", {
				Parent = container, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 0.2, LayoutOrder = idx,
				BackgroundColor3 = (M.Selected and M.Selected.Id == it.Id) and C.PurpleDark or C.Row,
			}, { Corner(10) })
			local pick = New("TextButton", { Parent = row, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
			local n = Label(row, it.Name or "Sem título", 13, C.Text, true)
			n.Position = UDim2.fromOffset(12, 5); n.Size = UDim2.new(1, -52, 0, 18)
			local a = Label(row, it.Artist or "Artista desconhecido", 11, C.SubText)
			a.Position = UDim2.fromOffset(12, 24); a.Size = UDim2.new(1, -52, 0, 14)
			if favIndex(it.Id) then
				local st = Label(row, "★", 16, C.Purple, true, Enum.TextXAlignment.Center)
				st.AnchorPoint = Vector2.new(1, 0.5); st.Position = UDim2.new(1, -8, 0.5, 0); st.Size = UDim2.fromOffset(28, 28)
			end
			pick.Activated:Connect(function()
				M.Selected = it
				for _, r in ipairs(container:GetChildren()) do if r:IsA("Frame") then Tween(r, 0.15, { BackgroundColor3 = C.Row }) end end
				Tween(row, 0.15, { BackgroundColor3 = C.PurpleDark })
				refreshFav()
			end)
		end
		if more then
			local b = New("TextButton", {
				Parent = container, Text = "Carregar mais", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
				AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.Purple, LayoutOrder = #items + 1,
			}, { Corner(10) })
			b.Activated:Connect(function() b.Text = "Carregando…"; more() end)
		end
	end

	-- Pesquisa online (AssetService:SearchAudioAsync); se falhar usa o Config.Catalog
	local function toItems(page)
		local out = {}
		for _, a in ipairs(page) do out[#out + 1] = { Id = a.Id, Name = a.Title, Artist = a.Artist } end
		return out
	end
	local function searchOnline(q)
		local ok, pages = pcall(function()
			local params = Instance.new("AudioSearchParams")
			params.SearchKeyword = q
			return AssetService:SearchAudioAsync(params)
		end)
		if not ok or not pages then return nil end
		local ok2, page = pcall(pages.GetCurrentPage, pages)
		if not ok2 then return nil end
		return toItems(page), pages
	end

	local searchRow = Components.Row(searchPanel, nil, 50)
	searchRow.LayoutOrder = 1
	local search = New("TextBox", {
		Parent = searchRow, Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -20, 0, 34),
		BackgroundColor3 = C.Panel, TextColor3 = C.Text, PlaceholderText = "Pesquisar música ou artista", PlaceholderColor3 = C.SubText, Text = "",
		Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, { Corner(10), Stroke(C.Purple, 1, 0.7), New("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
	local listTitle = Label(searchPanel, "SUAS FAVORITAS", 11, C.Purple, true)
	listTitle.Size = UDim2.new(1, 0, 0, 16); listTitle.LayoutOrder = 2
	local results = New("ScrollingFrame", {
		Parent = searchPanel, Size = UDim2.new(1, 0, 0, 5 * 48 + 12), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.4, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.Purple, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 3,
	}, { Corner(12), New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

	-- Pesquisa vazia: mostra as favoritas (ou o catálogo). Com texto: mostra os resultados
	function showList()
		local q = Trim(search.Text)
		if q == "" then
			if #M.Favorites > 0 then
				listTitle.Text = "SUAS FAVORITAS"
				buildList(results, M.Favorites, "")
			elseif #Config.Catalog > 0 then
				listTitle.Text = "SUGESTÕES"
				buildList(results, Config.Catalog, "")
			else
				listTitle.Text = "SUAS FAVORITAS"
				buildList(results, {}, "Pesquise uma música acima.\nAs que você favoritar aparecem aqui.")
			end
			return
		end
		listTitle.Text = "RESULTADOS"
		local more
		if M.Pages and not M.Pages.IsFinished then
			local v, pages = M.SearchV, M.Pages
			more = function()
				local ok = pcall(pages.AdvanceToNextPageAsync, pages)
				if v ~= M.SearchV then return end
				local ok2, page = false, nil
				if ok then ok2, page = pcall(pages.GetCurrentPage, pages) end
				if ok2 then
					for _, it in ipairs(toItems(page)) do table.insert(M.Results, it) end
				else
					Notify("Erro", "Não foi possível carregar mais.", "err")
					M.Pages = nil
				end
				showList()
			end
		end
		buildList(results, M.Results, "Nenhum resultado", more)
	end
	showList()

	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = Trim(search.Text)
		M.SearchV += 1
		local v = M.SearchV
		if q == "" then
			M.Results, M.Pages = {}, nil
			showList()
			return
		end
		task.delay(0.5, function()
			if v ~= M.SearchV then return end
			listTitle.Text = "RESULTADOS"
			buildList(results, {}, "Pesquisando…")
			local items, pages = searchOnline(q)
			if v ~= M.SearchV then return end
			if not items then
				items = {}
				for _, song in ipairs(Config.Catalog) do
					if ((song.Name or "") .. " " .. (song.Artist or "")):lower():find(q:lower(), 1, true) then table.insert(items, song) end
				end
				Notify("Erro", "Pesquisa online indisponível.", "err")
			end
			M.Results, M.Pages = items, pages
			showList()
		end)
	end)

	-- Aba ID (aceita link ou "rbxassetid://") e mostra o nome do áudio
	local idRow = Components.Row(idPanel, nil, 50)
	idRow.LayoutOrder = 1
	idBox = New("TextBox", {
		Parent = idRow, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0, 34),
		BackgroundColor3 = C.Panel, TextColor3 = C.Text, PlaceholderText = "Cole o ID ou o link do áudio", PlaceholderColor3 = C.SubText,
		Text = "", Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, { Corner(10), Stroke(C.Purple, 1, 0.7), New("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
	local idInfo = Label(idPanel, "Digite um ID e aperte Play.", 12, C.SubText)
	idInfo.Size = UDim2.new(1, 0, 0, 18); idInfo.LayoutOrder = 2
	local idV = 0
	idBox:GetPropertyChangedSignal("Text"):Connect(function()
		idV += 1
		local v = idV
		refreshFav()
		local id = parseId(idBox.Text)
		if not id then idInfo.Text = "Digite um ID e aperte Play."; idInfo.TextColor3 = C.SubText; return end
		task.delay(0.6, function()
			if v ~= idV then return end
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Asset)
			if v ~= idV then return end
			if ok and info and info.AssetTypeId == 3 then
				idInfo.Text = "Áudio: " .. info.Name; idInfo.TextColor3 = C.Ok
			else
				idInfo.Text = "ID inválido ou não é um áudio."; idInfo.TextColor3 = C.Error
			end
		end)
	end)

	-- Progresso, equalizador e objeto detectado (só roda com a aba visível)
	local acc, acc2 = 0, 0
	Track(RunService.Heartbeat:Connect(function(dt)
		acc += dt; acc2 += dt
		if acc < 0.05 then return end
		acc = 0
		if ActiveTab ~= TabMusic or not Main.Visible then return end
		local snd = M.Active
		local playing = snd and snd.IsPlaying
		if snd and snd.TimeLength > 0 then
			barFill.Size = UDim2.fromScale(math.clamp(snd.TimePosition / snd.TimeLength, 0, 1), 1)
			tCur.Text, tEnd.Text = FormatTime(snd.TimePosition), FormatTime(snd.TimeLength)
		else
			barFill.Size = UDim2.fromScale(0, 1); tCur.Text, tEnd.Text = "0:00", "0:00"
		end
		bPlay.Text = playing and "Pausar" or "Play"
		if not M.Busy then
			npStatus.Text = playing and (M.OnlyMe and "TOCANDO • SÓ VOCÊ" or "TOCANDO • BROOKHAVEN") or (snd and "PAUSADO" or "PARADO")
		end
		for i, b in ipairs(bars) do
			b.Size = UDim2.fromOffset(10, playing and (8 + (math.sin(os.clock() * 6 + i * 1.7) * 0.5 + 0.5) * 50) or 6)
		end
		if acc2 > 1 then
			acc2 = 0
			if M.OnlyMe then objLbl.Text = "Modo: só você ouve"
			else
				local o = findObject()
				objLbl.Text = o and ("Brookhaven: " .. o.Kind .. " " .. o.Name) or "Equipe a Boombox ou sente no veículo"
			end
		end
	end))

	-- Se tirar a Boombox ou sair do veículo, limpa o player
	task.spawn(function()
		while Gui.Parent do
			task.wait(0.5)
			if M.Active and M.Active ~= localSound and not findObject() then resetNowPlaying() end
		end
	end)
end

-- ABA PROTEÇÃO
do
	local s = TabProt.Scroll
	local lastSafe

	Track(RunService.Heartbeat:Connect(function()
		local h, r = GetHum(), GetRoot()
		if h and r and h.FloorMaterial ~= Enum.Material.Air then lastSafe = r.CFrame end
	end))

	Components.Toggle(s, "Anti AFK", false, function(on)
		Release("afk")
		if on then Hold("afk", Player.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)) end
	end)

	-- ANTI FLING
	-- Faz tudo que não é seu e não está preso ao mapa (jogadores, veículos, itens de mão, bolas jogadas...)
	-- deixar de colidir com você. Quem te acertar atravessa, então não consegue te empurrar nem te arremessar.
	-- Não mexe: partes ancoradas (mapa), o veículo em que você está sentado e o que está debaixo dos seus pés.
	local AF = {
		On = false, Vehicle = nil, Standing = nil,
		Parts = setmetatable({}, { __mode = "k" }), -- peças que estamos ignorando
		Orig = setmetatable({}, { __mode = "k" }), -- peças que eram sólidas antes
	}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function ownerOf(part)
		local m = part:FindFirstAncestorOfClass("Model")
		while m do
			local pl = Players:GetPlayerFromCharacter(m)
			if pl then return pl end
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
		end
	end
	local function consider(inst)
		if inst:IsA("BasePart") and not inst.Anchored then AF.Parts[inst] = true end
	end
	local function restore(part)
		if AF.Orig[part] then part.CanCollide = true; AF.Orig[part] = nil end
	end
	local function scan()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not AF.On then return end
			consider(d)
			n += 1
			if n % 500 == 0 then task.wait() end
		end
	end
	local function applyAntiFling(on)
		AF.On = on
		Release("afstep"); Release("afadd")
		if on then
			task.spawn(function()
				scan()
				while AF.On and Gui.Parent do task.wait(3); scan() end
			end)
			Hold("afadd", workspace.DescendantAdded:Connect(consider))
			Hold("afstep", RunService.Stepped:Connect(function()
				local char, hum, root = Player.Character, GetHum(), GetRoot()
				-- veículo em que estou e peça sob meus pés
				AF.Vehicle, AF.Standing = nil, nil
				if hum and hum.SeatPart then AF.Vehicle = hum.SeatPart:FindFirstAncestorOfClass("Model") or hum.SeatPart end
				if root and char then
					rayParams.FilterDescendantsInstances = { char }
					local res = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), rayParams)
					if res and not res.Instance.Anchored and not ownerOf(res.Instance) then AF.Standing = res.Instance end
				end
				local veh, stand = AF.Vehicle, AF.Standing
				local standRoot = stand and stand.AssemblyRootPart
				for part in pairs(AF.Parts) do
					if not part.Parent or part.Anchored or (char and part:IsDescendantOf(char)) then
						AF.Parts[part] = nil
						restore(part)
					elseif (veh and part:IsDescendantOf(veh)) or (standRoot and part.AssemblyRootPart == standRoot) then
						restore(part)
					elseif part.CanCollide then
						AF.Orig[part] = true
						part.CanCollide = false
					end
				end
				-- Segurança extra: se mesmo assim algo te lançar, zera a velocidade
				if root and hum and not hum.SeatPart and not Features.IsFlying() then
					local v = root.AssemblyLinearVelocity
					local limit = math.max(150, PlayerState.WalkSpeed * 2)
					if Vector3.new(v.X, 0, v.Z).Magnitude > limit or v.Y > limit then
						root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
					end
					if root.AssemblyAngularVelocity.Magnitude > 40 then root.AssemblyAngularVelocity = Vector3.zero end
				end
			end))
		else
			for part in pairs(AF.Orig) do if part.Parent then part.CanCollide = true end end
			table.clear(AF.Orig); table.clear(AF.Parts)
		end
	end
	Components.Toggle(s, "Anti Fling (atravessa veículos e itens)", false, applyAntiFling)

	-- ANTI SIT e ANTI QUEDA (ragdoll): reaplicados a cada respawn
	local guard = { Sit = false, Ragdoll = false }
	local function applyStates()
		local h = GetHum()
		if not h then return end
		h:SetStateEnabled(Enum.HumanoidStateType.Seated, not guard.Sit)
		h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not guard.Ragdoll)
		h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not guard.Ragdoll)
	end
	Components.Toggle(s, "Anti Sit", false, function(on)
		guard.Sit = on; applyStates(); Release("sit")
		if on then
			Hold("sit", RunService.Heartbeat:Connect(function()
				local hum = GetHum(); if hum and hum.Sit then hum.Sit = false end
			end))
		end
	end)
	Components.Toggle(s, "Anti Queda (ragdoll)", false, function(on)
		guard.Ragdoll = on; applyStates(); Release("ragdoll")
		if on then
			Hold("ragdoll", RunService.Heartbeat:Connect(function()
				local hum = GetHum()
				if hum and hum.PlatformStand and not Features.IsFlying() then hum.PlatformStand = false end
			end))
		end
	end)
	Track(Player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		applyStates()
	end))

	Components.Toggle(s, "Anti Void", false, function(on)
		Release("void")
		if on then
			Hold("void", RunService.Heartbeat:Connect(function()
				local r = GetRoot()
				if r and r.Position.Y < workspace.FallenPartsDestroyHeight + 60 and lastSafe then
					r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = lastSafe + Vector3.new(0, 3, 0)
				end
			end))
		end
	end)

	OnClose(function()
		applyAntiFling(false)
		guard.Sit, guard.Ragdoll = false, false
		applyStates()
	end)
end

-- ABA INFO
do
	local s = TabInfo.Scroll
	local card = New("Frame", { Parent = s, Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = C.Row, BackgroundTransparency = 0.25, LayoutOrder = 1 },
		{ Corner(12), Stroke(C.Purple, 1, 0.8) })
	local av = New("ImageLabel", { Parent = card, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = C.Panel },
		{ Corner(34), Stroke(C.Purple, 2, 0.2) })
	task.spawn(function()
		local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, Config.Developer)
		if ok then
			local ok2, img = pcall(Players.GetUserThumbnailAsync, Players, id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if ok2 then av.Image = img end
		end
	end)
	local n = Label(card, Config.Name, 17, C.Text, true); n.Position = UDim2.fromOffset(96, 14); n.Size = UDim2.new(1, -110, 0, 22)
	local d = Label(card, "Desenvolvedor: " .. Config.Developer, 13, C.Purple, true); d.Position = UDim2.fromOffset(96, 38); d.Size = UDim2.new(1, -110, 0, 18)
	local v = Label(card, "Versão " .. Config.Version .. "  •  Atualizado em " .. Config.UpdateDate, 12, C.SubText)
	v.Position = UDim2.fromOffset(96, 58); v.Size = UDim2.new(1, -110, 0, 18)

	SectionTitle(TabInfo, "Atualização")
	local list = New("Frame", { Parent = s, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Row, BackgroundTransparency = 0.25 },
		{ Corner(12), Stroke(C.Purple, 1, 0.8), New("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10) }),
			New("UIListLayout", { Padding = UDim.new(0, 6) }) })
	for _, line in ipairs(Config.Changelog) do
		local l = Label(list, "•  " .. line, 13, C.Text)
		l.Size = UDim2.new(1, 0, 0, 0); l.AutomaticSize = Enum.AutomaticSize.Y; l.TextWrapped = true
		l.TextTruncate = Enum.TextTruncate.None
	end
end

-- ABA CONFIG
-- Cor do menu (cores prontas + seletor), fonte, travas do menu/bolinha e aparência.
do
	local s = TabConfig.Scroll
	local DEFAULT_ACCENT = DefaultTheme.Purple

	-- COR
	SectionTitle(TabConfig, "Cor do menu")

	local presets = {
		{ "Roxo", Color3.fromRGB(150, 70, 255) }, { "Azul", Color3.fromRGB(60, 130, 255) },
		{ "Ciano", Color3.fromRGB(0, 200, 230) }, { "Verde", Color3.fromRGB(60, 210, 120) },
		{ "Amarelo", Color3.fromRGB(250, 200, 50) }, { "Laranja", Color3.fromRGB(255, 140, 40) },
		{ "Vermelho", Color3.fromRGB(240, 70, 90) }, { "Rosa", Color3.fromRGB(255, 90, 190) },
	}
	local presetRow = Components.Row(s, nil, 50)
	local holder = New("Frame", {
		Parent = presetRow, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1,
	}, { New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	table.insert(Theme.Skip, holder)

	local pickRow = Components.Row(s, nil, 192)
	local pick = New("Frame", { Parent = pickRow, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	table.insert(Theme.Skip, pick)

	-- Quadro de saturação/brilho
	local hh, ss, vv = C.Purple:ToHSV()
	local sv = New("Frame", {
		Parent = pick, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 104),
		BackgroundColor3 = Color3.fromHSV(hh, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
	}, { Corner(8) })
	New("Frame", {
		Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, { New("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	New("Frame", {
		Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
	}, { New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local svDot = New("Frame", {
		Parent = sv, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, ZIndex = 3,
	}, { Corner(7), Stroke(Color3.new(1, 1, 1), 2, 0) })

	-- Barra de matiz
	local hueBar = New("Frame", {
		Parent = pick, Position = UDim2.fromOffset(12, 126), Size = UDim2.new(1, -24, 0, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, { Corner(8), New("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
	}) }) })
	local hueDot = New("Frame", {
		Parent = hueBar, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 22), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3,
	}, { Corner(3), Stroke(Color3.new(0, 0, 0), 1, 0.4) })

	-- Prévia e código hex
	local preview = New("Frame", {
		Parent = pick, Position = UDim2.fromOffset(12, 154), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.Purple,
	}, { Corner(8), Stroke(Color3.new(1, 1, 1), 1, 0.6) })
	local hex = New("TextBox", {
		Parent = pick, Position = UDim2.fromOffset(48, 154), Size = UDim2.new(1, -60, 0, 28), BackgroundColor3 = C.Panel,
		Text = "", PlaceholderText = "#RRGGBB", PlaceholderColor3 = C.SubText, TextColor3 = C.Text,
		Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false,
	}, { Corner(8), New("UIPadding", { PaddingLeft = UDim.new(0, 10) }) })
	hex.TextXAlignment = Enum.TextXAlignment.Left

	local function currentColor() return Color3.fromHSV(hh, ss, math.max(vv, 0.3)) end
	local function refresh(apply)
		sv.BackgroundColor3 = Color3.fromHSV(hh, 1, 1)
		svDot.Position = UDim2.fromScale(ss, 1 - vv)
		hueDot.Position = UDim2.fromScale(hh, 0.5)
		local col = currentColor()
		preview.BackgroundColor3 = col
		hex.Text = "#" .. col:ToHex():upper()
		if apply then Theme.QueueApply(col) end
	end
	refresh(false)

	local function dragArea(area, onMove)
		local active = false
		area.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				active = true; s.ScrollingEnabled = false; onMove(i.Position)
			end
		end)
		Track(UserInputService.InputChanged:Connect(function(i)
			if active and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then onMove(i.Position) end
		end))
		Track(UserInputService.InputEnded:Connect(function(i)
			if active and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
				active = false; s.ScrollingEnabled = true
			end
		end))
	end
	dragArea(sv, function(p)
		ss = math.clamp((p.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		vv = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		refresh(true)
	end)
	dragArea(hueBar, function(p)
		hh = math.clamp((p.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
		refresh(true)
	end)

	hex.FocusLost:Connect(function()
		local txt = hex.Text:gsub("[^%x]", "")
		if #txt == 6 then
			local ok, col = pcall(Color3.fromHex, txt)
			if ok then hh, ss, vv = col:ToHSV(); refresh(true); return end
		end
		Notify("Erro", "Use um código como #9646FF.", "err")
		refresh(false)
	end)

	for i, p in ipairs(presets) do
		local sw = New("TextButton", {
			Parent = holder, Text = "", AutoButtonColor = false, LayoutOrder = i,
			Size = UDim2.new(1 / #presets, -6, 0, 30), BackgroundColor3 = p[2],
		}, { Corner(8), Stroke(Color3.new(1, 1, 1), 1, 0.75) })
		sw.Activated:Connect(function()
			hh, ss, vv = p[2]:ToHSV()
			refresh(true)
		end)
	end

	-- FONTE
	SectionTitle(TabConfig, "Fonte")
	local FONT_LIST = {
		{ "Padrão (Gotham)" },
		{ "Source Sans", "SourceSans", "SourceSansBold" }, { "Arial", "Arial", "ArialBold" },
		{ "Ubuntu", "Ubuntu" }, { "Nunito", "Nunito" }, { "Roboto", "Roboto" }, { "Oswald", "Oswald" },
		{ "Titillium Web", "TitilliumWeb" }, { "Jura", "Jura" }, { "Michroma", "Michroma" }, { "Fredoka", "FredokaOne" },
		{ "Kalam", "Kalam" }, { "Patrick Hand", "PatrickHand" }, { "Merriweather", "Merriweather" },
		{ "Josefin Sans", "JosefinSans" }, { "Arcade", "Arcade" }, { "Sci-Fi", "SciFi" }, { "Fantasy", "Fantasy" },
		{ "Bangers", "Bangers" }, { "Creepster", "Creepster" }, { "Luckiest Guy", "LuckiestGuy" }, { "Roboto Mono", "RobotoMono" },
	}
	local fontFrame = New("ScrollingFrame", {
		Parent = s, Size = UDim2.new(1, 0, 0, 5 * 36 + 8), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.4,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.Purple, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { Corner(10), Stroke(C.Purple, 1, 0.8), New("UIListLayout", { Padding = UDim.new(0, 4) }),
		New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })

	local fontButtons, fontIndex = {}, 1
	local function markFont(i)
		fontIndex = i
		for j, b in ipairs(fontButtons) do
			Tween(b, 0.15, { BackgroundColor3 = j == i and C.PurpleDark or C.Row })
		end
	end
	for i, f in ipairs(FONT_LIST) do
		local okReg, reg = true, nil
		local bold
		if f[2] then
			okReg, reg = pcall(function() return Enum.Font[f[2]] end)
			if f[3] then
				local okB, b = pcall(function() return Enum.Font[f[3]] end)
				bold = okB and b or reg
			end
		end
		if okReg and (reg or i == 1) then
			local b = New("TextButton", {
				Parent = fontFrame, Text = f[1], TextSize = 14, Font = reg or Enum.Font.GothamBold, TextColor3 = C.Text,
				AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.Row, BackgroundTransparency = 0.2,
				LayoutOrder = i, TextXAlignment = Enum.TextXAlignment.Left,
			}, { Corner(8), New("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
			b:SetAttribute("KeepFont", true)
			fontButtons[#fontButtons + 1] = b
			local index = #fontButtons
			local entry = { reg = reg, bold = bold }
			b.Activated:Connect(function()
				Theme.ApplyFont(entry.reg, entry.bold)
				markFont(index)
			end)
			if i == 1 then b.BackgroundColor3 = C.PurpleDark end
		end
	end

	-- TRAVAS
	SectionTitle(TabConfig, "Travas")
	local _, setLockMenu = Components.Toggle(s, "Travar menu (não mover)", false, function(on)
		Locks.Menu = on
		Notify("Config", on and "Menu travado." or "Menu liberado.", "ok")
	end)
	local _, setLockBall = Components.Toggle(s, "Travar bolinha (não mover)", false, function(on)
		Locks.Ball = on
		Notify("Config", on and "Bolinha travada." or "Bolinha liberada.", "ok")
	end)

	-- APARÊNCIA
	SectionTitle(TabConfig, "Aparência")
	local _, setBlur = Components.Toggle(s, "Desfoque do fundo", Config.MenuBlur, function(on)
		Config.MenuBlur = on
		if Main.Visible then SetBlur(true) end
	end)
	local _, setTrans = Components.Slider(s, "Transparência do menu", 0, 60, 12, function(v)
		Main.BackgroundTransparency = v / 100
	end)

	Components.Button(s, "Restaurar padrão", "Restaurar", function()
		Theme.Reset()
		hh, ss, vv = DEFAULT_ACCENT:ToHSV()
		refresh(false)
		Theme.ApplyFont(nil)
		markFont(1)
		setLockMenu(false); setLockBall(false); setBlur(true); setTrans(12)
		Notify("Config", "Tudo voltou ao padrão.", "ok")
	end)

	-- ENCERRAR: desliga tudo e remove a interface de vez (o × só oculta)
	SectionTitle(TabConfig, "Script")
	Components.Button(s, "Encerrar o script de vez", "Encerrar", function() Window.Close() end)
end

-- CONTROLES DA JANELA
local Reopen = New("TextButton", {
	Parent = Gui, Text = Config.ButtonImage == "" and "W" or "", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C.Purple,
	AutoButtonColor = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(0, 0),
	BackgroundColor3 = C.Bg, Visible = false, ClipsDescendants = true,
}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }), Stroke(C.Purple, 2, 0.2) })
if Config.ButtonImage ~= "" then
	New("ImageLabel", { Parent = Reopen, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Config.ButtonImage, ScaleType = Enum.ScaleType.Crop })
end
local BallDrag = MakeDraggable(Reopen, Reopen, "Ball")

local busy, closing, hidden = false, false, false

local function OpenWindow()
	if busy or closing or Main.Visible then return end
	busy = true
	Reopen.Visible = false
	Reopen.Size = UDim2.fromOffset(0, 0)
	Main.Visible = true
	Main.Size = UDim2.fromScale(0.8, 0.7)
	Tween(Main, 0.4, { Size = FullSize }, Enum.EasingStyle.Back)
	SetBlur(true)
	task.delay(0.4, function() busy = false end)
end

-- "–": esconde só o menu, deixando a bolinha
local function Minimize()
	if busy or closing or not Main.Visible then return end
	busy = true
	SetBlur(false)
	Tween(Main, 0.3, { Size = UDim2.fromScale(0.7, 0.6) })
	task.wait(0.3)
	Main.Visible = false
	Reopen.Visible = true
	Tween(Reopen, 0.3, { Size = UDim2.fromOffset(50, 50) }, Enum.EasingStyle.Back)
	busy = false
end

-- OCULTAR TUDO: menu e bolinha somem, mas o que está ligado continua funcionando.
-- Para voltar: /menu no chat ou RightShift.
local function Notice(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Warrior Client", Text = text, Duration = 6 })
	end)
end
function Window.Hide()
	if closing or hidden then return end
	hidden = true
	SetBlur(false)
	Gui.Enabled = false
	Notice("Interface oculta. Digite /menu no chat ou aperte RightShift para voltar.")
end
function Window.Show()
	if closing or not hidden then return end
	hidden = false
	Gui.Enabled = true
	if Main.Visible then SetBlur(true) end
end

-- ENCERRAR: desliga tudo, desconecta tudo e remove a interface
function Window.Close()
	if closing then return end
	closing = true
	Gui.Enabled = true
	SetBlur(false)
	Reopen.Visible = false
	if Main.Visible then Tween(Main, 0.25, { Size = UDim2.fromScale(0.6, 0.5) }) end
	task.wait(0.3)
	for i = #Hooks, 1, -1 do pcall(Hooks[i]) end
	for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
	Gui:Destroy()
	Blur:Destroy()
end

-- Janela de confirmação do "×": Ocultar ou Cancelar
local Confirm = New("Frame", {
	Parent = Gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	Visible = false, Active = true, ZIndex = 150,
})
local confirmScale = New("UIScale", { Scale = 0.85 })
local confirmBox = New("Frame", {
	Parent = Confirm, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(310, 188),
	BackgroundColor3 = C.Panel,
}, { Corner(16), Stroke(C.Purple, 1.5, 0.25), confirmScale })
local cTitle = Label(confirmBox, "Ocultar a interface?", 17, C.Text, true, Enum.TextXAlignment.Center)
cTitle.Position = UDim2.fromOffset(0, 16); cTitle.Size = UDim2.new(1, 0, 0, 24)
local cText = Label(confirmBox, "O menu e a bolinha vão sumir, mas tudo que está ligado continua funcionando.\nPara voltar: digite /menu no chat ou aperte RightShift.", 12, C.SubText, false, Enum.TextXAlignment.Center)
cText.Position = UDim2.fromOffset(16, 46); cText.Size = UDim2.new(1, -32, 0, 62)
cText.TextWrapped = true; cText.TextTruncate = Enum.TextTruncate.None; cText.TextYAlignment = Enum.TextYAlignment.Top

local function ConfirmButton(text, xScale, color)
	local b = New("TextButton", {
		Parent = confirmBox, Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(xScale, xScale == 0 and 16 or 6, 1, -16),
		Size = UDim2.new(0.5, -22, 0, 38), BackgroundColor3 = color,
	}, { Corner(10) })
	return b
end
local bHide = ConfirmButton("Ocultar", 0, C.Purple)
local bCancel = ConfirmButton("Cancelar", 0.5, C.Row)
bCancel.TextColor3 = C.Text
Stroke(C.Purple, 1, 0.6).Parent = bCancel

local function ShowConfirm(on)
	if on then
		Confirm.Visible = true
		Tween(Confirm, 0.2, { BackgroundTransparency = 0.45 })
		confirmScale.Scale = 0.85
		Tween(confirmScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		Tween(Confirm, 0.15, { BackgroundTransparency = 1 })
		Tween(confirmScale, 0.15, { Scale = 0.9 })
		task.delay(0.16, function() Confirm.Visible = false end)
	end
end
bHide.Activated:Connect(function()
	ShowConfirm(false)
	task.delay(0.2, Window.Hide)
end)
bCancel.Activated:Connect(function() ShowConfirm(false) end)

MinBtn.Activated:Connect(Minimize)
CloseBtn.Activated:Connect(function()
	if closing or hidden or Confirm.Visible then return end
	ShowConfirm(true)
end)
Reopen.Activated:Connect(function()
	if BallDrag.Moved then return end
	OpenWindow()
end)

-- Voltar: RightShift (PC) ou /menu no chat (PC e celular)
Track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.RightShift then return end
	if hidden then Window.Show() else Window.Hide() end
end))
do
	local TextChatService = game:GetService("TextChatService")
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "Warrior_menu"; cmd.PrimaryAlias = "/menu"
		cmd.Triggered:Connect(function() Window.Show() end)
		cmd.Parent = TextChatService
		OnClose(function() cmd:Destroy() end)
	else
		Track(Player.Chatted:Connect(function(msg)
			if msg:lower():match("^/menu%s*$") then Window.Show() end
		end))
	end
end

-- INÍCIO
task.spawn(function()
	PlayIntro()
	if not Gui.Parent then return end
	OpenWindow()
	StartTab.Select(true)
	Notify("Warrior Client", "Carregado com sucesso", "ok")
end)
