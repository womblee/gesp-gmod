--[[
    gESP, by nloginov and Fy-e

	'gesp_enabled' 0|1 -- disable/enable gESP
	'gesp_compact' 0|1 -- compact view
	'gesp_pixvis' 0|1 -- visibility check
	'gesp_ents' 0|1 -- show entities with configured profiles
	'gesp_players' 0|1 -- show players
	'gesp_limit' int -- how many entities to show
	'gesp_spectators' 0|1 -- show spectators
	'gesp_halo_enable' 0|1 -- halo effect
	'gesp_halo_team' 0|1 -- halo based on team (0 for health, 1 for team color)
	'gesp_radius' int -- radius (30470400 for best coverage)
	''
]]

local next = next
local math = math
local draw = draw
local surface = surface
local string = string
local table = table
local player = player
local Vector = Vector
local LocalPlayer = LocalPlayer
local Color = Color
local PLAYER = FindMetaTable("Player")

gESP = gESP or {}
local gESP = gESP
gESP.IntEnabled = gESP.IntEnabled or false

gESP.Drawables = {}

gESP.Enabled = CreateClientConVar("gesp_enabled", "0", true, false)
gESP.Compact = CreateClientConVar("gesp_compact", "0", true, false)
gESP.PixVis = CreateClientConVar("gesp_pixvis", "1", true, false)
gESP.Spec = CreateClientConVar("gesp_spectators", "0", true, false)
gESP.Ents = CreateClientConVar("gesp_ents", "0", true, false)
gESP.Players = CreateClientConVar("gesp_players", "1", true, false)
gESP.Limit = CreateClientConVar("gesp_limit", "0", true, false)
gESP.Halo = CreateClientConVar("gesp_halo_enable", "0", true, false)
gESP.HaloTeam = CreateClientConVar("gesp_halo_team", "0", true, false)
gESP.Radius = CreateClientConVar("gesp_radius", "30470400", true, false)

local empty = {}

local color_traitor = Color(255, 0, 0)
local color_detective = Color(0, 0, 255)

gESP.Profiles = {
	player = function(e)
		if gESP.Spec:GetBool() == false and e:Team() == TEAM_SPECTATOR then return end

		if not e.gESP_PixVis then
			e.gESP_PixVis = util.GetPixelVisibleHandle()
		end

		return {
			ent = e,
			--name = e._Name and (e:_Name() ~= e:Name() and Format("%s (%s)", e:_Name(), e:Name()) or e:_Name()) or e:Name(),
			name = e:Name(),
			color = KARMA and (e:IsTraitor() and color_traitor or e:IsDetective() and color_detective) or team.GetColor(e:Team()),
			lbl = team.GetName(e:Team()),
			info = not gESP.Compact:GetBool() and {
				"Health: " .. e:Health(),
				(e:Armor() > 0 and "Armor: " .. e:Armor()) or nil,
				"Distance: " .. math.floor(e:GetPos():Distance(LocalPlayer():GetPos())),
				(
					rp and "Money: " .. rp.FormatMoney(e:GetMoney()) or -- Superior Servers (OBSOLETE, data is not given out to randoms)
                                        DarkRP and "Money: " .. DarkRP.formatMoney(e:getDarkRPVar("money")) or -- DarkRP (WORKS)
                                        nil
                                ),
				--[[
				(e.DarkRPVars and
					(
						(e.DarkRPVars.money and e.DarkRPVars.salary and e.DarkRPVars.salary > 0
							and Format("Money: %s (+%d)",string.Comma(e.DarkRPVars.money),e.DarkRPVars.salary)
						)
							or
						(e.DarkRPVars.money and "Money: " .. string.Comma(e.DarkRPVars.money))
					)
				) or nil,
				]]
				(e:GetActiveWeapon():IsValid() and "Weapon: " .. e:GetActiveWeapon():GetClass()) or nil,
				--(e:IsSuperAdmin() and "Super Admin") or (e:IsAdmin() and "Admin") or nil
			} or empty,
			friend = e:GetFriendStatus() == "friend",
		}
	end,

	["money_printer*"] = function(e)
		if not e.gESP_PixVis then
			e.gESP_PixVis = util.GetPixelVisibleHandle()
		end

		return {
			ent = e,
			color = color_traitor,
			info = empty
		}
	end,

	["spawned_*"] = "money_printer*",

	["gmod_wire_user"] = "money_printer*",
	["gmod_wire_soundemitter"] = "money_printer*",

	ttt_c4 = KARMA and function(e)
		local t = math.max(0, e:GetExplodeTime() - CurTime())
		--gESP.DrawInfo(e,{},"Bomb",Color(255,0,0),t)
		return {
			ent = e,
			name = "Bomb",
			info = empty,
			color = color_traitor,
			lbl = t,
		}
	end or nil,

	prop_ragdoll = KARMA and function(e)
		if CORPSE then
			if not e.gESP_PixVis then
				e.gESP_PixVis = util.GetPixelVisibleHandle()
			end

			if e.NoTarget then
				return
			end

			local pl = CORPSE.GetPlayerNick(e,false)
			local found = CORPSE.GetFound(e, false)

			return {
				ent = e,
				name = found and pl or "Unknown body",
				color = found and Color(128, 0, 0) or Color(255,128,0),
				info = empty,
			}
		end
	end or nil,
}

for c, f in pairs(gESP.Profiles) do
	if isstring(f) then
		gESP.Profiles[c] = gESP.Profiles[f]
	end
end

local pos_shift = Vector(0, 0, 5)
local col_gray = Color(128, 128, 128)
local col_f = Color(255, 255, 0)
function gESP.DrawInfo(entry)
	local e, info, name, col, lbl = entry.ent, entry.info, entry.name, entry.color or col_gray, entry.lbl

	local wpos
	local eyes = e:LookupAttachment("eyes")
	if eyes ~= 0 then
		wpos = e:GetAttachment(eyes).Pos
		wpos:Add(pos_shift)
	else
		wpos = e:GetPos()
	end

	local pos = wpos:ToScreen()
	if not pos.visible then return end
	pos.x = math.floor(pos.x)
	pos.y = math.floor(pos.y)

	if gESP.PixVis:GetBool() and e.gESP_PixVis then
		local visibility = util.PixelVisible(wpos, 4, e.gESP_PixVis)
		surface.SetAlphaMultiplier(math.max(0.2, visibility))
	end

	surface.SetFont("DermaDefault")
	local w, h = surface.GetTextSize(name)
	local infoheight = #info * h

	if entry.friend then
		draw.SimpleText("[F]", "DermaDefault", pos.x - h, pos.y - infoheight - h - 1, col_f, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	draw.RoundedBox(4, pos.x, pos.y - infoheight - h - 1, w + 7, h + 1, col)
	draw.SimpleText(name, "DermaDefault", pos.x + 5, pos.y - infoheight - h, color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(name, "DermaDefault", pos.x + 4, pos.y - infoheight - h - 1, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if lbl then
		lbl = "— " .. lbl
		draw.SimpleText(lbl, "DermaDefault", pos.x + 10 + w, pos.y - infoheight - h, color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(lbl, "DermaDefault", pos.x + 9 + w, pos.y - infoheight - h - 1, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local i = 0
	for _, v in pairs(info) do
		i = i + 1 -- `info` may contain nils
		local ew, eh = surface.GetTextSize(v)
		surface.SetDrawColor(0, 0, 0, 128)
		surface.DrawRect(pos.x, pos.y - infoheight + (i - 1) * (h + 1), ew, eh + 1)
		draw.SimpleText(v, "DermaDefault", pos.x, pos.y + 1 - infoheight + (i-1) * (h + 1), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	surface.SetAlphaMultiplier(1)
end

-- Arghh tabl function :d
function table.iEmpty(tab)
    for k, v in ipairs(tab) do
        tab[k] = nil
    end
end

hook.Add("Tick", "gESP", function()
	if gESP.IntEnabled and gESP.Enabled:GetBool() then
		i_empty(gESP.Drawables)

		local me = LocalPlayer()
		if not me:IsValid() then return end

		local pos = me:GetPos()
		local radius = gESP.Radius and gESP.Radius:GetFloat()
		radius = radius < 0 and 0 or radius

		if gESP.Players:GetBool() then
			for k, e in ipairs(player.GetAll()) do
				if e ~= me and pos:DistToSqr(e:GetPos()) < radius then
					local ret = gESP.Profiles.player(e)
					if ret then
						table.insert(gESP.Drawables, ret)
					end
				end
			end
		end

		if gESP.Ents:GetBool() then
			for c, f in pairs(gESP.Profiles) do
				if c == "player" then continue end

				for k, v in ipairs(ents.FindByClass(c)) do
					local ret = f(v)
					if ret then
						if not ret.name then
							ret.name = v:GetClass()
						end
						table.insert(gESP.Drawables, ret)
					end
				end
			end
		end

		table.sort(gESP.Drawables, function(a, b) return a.ent:GetPos():DistToSqr(pos) > b.ent:GetPos():DistToSqr(pos) end)
	end
end)

hook.Add("HUDPaint", "gESP", function()
	if gESP.IntEnabled and gESP.Enabled:GetBool() then
		local z = gESP.Limit:GetInt()
		if z > 0 then
			local m = #gESP.Drawables
			for k, v in ipairs(gESP.Drawables) do
				if (m - k) >= z then continue end

				if v.ent:IsValid() then
					gESP.DrawInfo(v)
				end
			end
		else
			for k, v in ipairs(gESP.Drawables) do
				if v.ent:IsValid() then
					gESP.DrawInfo(v)
				end
			end
		end
	end
end)

local function CalculateHealthColor(health)
    health = math.max(0, math.min(100, health))

    return Color(math.floor(255 * (1 - health / 100)), math.floor(255 * (health / 100)), 0)
end

hook.Add("PreDrawOutlines", "gESP", function()
	if gESP.Halo and gESP.Halo:GetBool() then
		local lp = LocalPlayer()
		local pos = lp:GetPos()
		for k, v in ipairs(gESP.Drawables) do
			local ply = v.ent
			if ply and ply:IsValid() and ply:GetClass() == "player" and ply:Alive() then
				local b1, b2 = ply:GetRenderBounds()
				local poss = {
					b1,
					b2,
					Vector(b2[1], b1[2], b1[3]),
					Vector(b1[1], b2[2], b1[3]),
					Vector(b1[1], b1[2], b2[3]),
					Vector(b2[1], b2[2], b1[3]),
					Vector(b1[1], b2[2], b2[3]),
					Vector(b2[1], b1[2], b2[3]),
				}

				for _, pos in next, poss do
					local toscr = ply:LocalToWorld(pos):ToScreen()
					if toscr.visible and toscr.x > 0 and toscr.y > 0 and toscr.x < ScrW() and toscr.y < ScrH() then
						outline.Add(ply, gESP.HaloTeam and gESP.HaloTeam:GetBool() and team.GetColor(ply:Team()) or CalculateHealthColor(ply:Health()))
						break
					end
				end
			end
		end
	end
end)

hook.Add("KeyPress", "gESP", function() -- AAAAAAAA LAAAAG CRAAAASH, ah nope
	gESP.IntEnabled = true
	hook.Remove("KeyPress", "gESP_ShowItUp")
end)
