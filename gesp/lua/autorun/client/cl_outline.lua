outline = {}

local outlined = {}
local clear = true

-- interface

function outline.Add(ent, col)
	col = col or color_white
	outlined[ent] = {r = col.r/255, g = col.g/255, b = col.b/255, a = col.a/255}
	clear = false
end

local s = 1 -- outline size
function outline.SetSize(size)
	s = size
end

local rt_outline = GetRenderTargetEx("__rt_outline",ScrW(),ScrH(), RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_NONE , 0, CREATERENDERTARGETFLAGS_UNFILTERABLE_OK, IMAGE_FORMAT_RGB888)
local mat_outline = CreateMaterial("models/fullbrightoutline","UnlitGeneric",{
	["$color"]=Vector(1,1,1)
})
local mat_rtoutline = CreateMaterial("rtoutline","UnlitGeneric",{
	["$basetexture"]="__rt_outline",
	["$additive"]=1,
	["$translucent"]=1
})


hook.Add("HUDPaint","playeroutlines",function()
	hook.Run("PreDrawOutlines")

	if clear then return end

	local w, h = ScrW(), ScrH()

	render.SuppressEngineLighting(true)

	local oldrt = render.GetRenderTarget()
	render.SetRenderTarget(rt_outline) -- render fill
	render.Clear(0,0,0,0,false)
	cam.Start3D(EyePos(),EyeAngles())
		cam.IgnoreZ(true)
		render.MaterialOverride(mat_outline)
		render.OverrideDepthEnable(true, true)
		for e, v in next, outlined do
			if e:IsValid() then
				render.SetColorModulation(v.r, v.g, v.b)
				render.SetBlend(v.a)
				if e.RenderOverride then
					e:RenderOverride()
				elseif e.Draw then
					e:Draw()
				elseif e.DrawModel then
					e:DrawModel()
				end
				if e:IsPlayer() and IsValid(e:GetActiveWeapon()) then
					e:GetActiveWeapon():DrawModel()
				end
			end
		end
		render.SetColorModulation(1,1,1)
		render.OverrideDepthEnable(false,false)
		render.MaterialOverride()
	cam.End3D()
	render.SetRenderTarget(oldrt) -- done rending fill

	cam.Start3D(EyePos(),EyeAngles()) -- rendering stencil to hide real fill
		render.SetStencilEnable(true)
		render.ClearStencil()
		render.SetStencilFailOperation(STENCILOPERATION_KEEP)
		render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
		render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
		render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
		render.SetStencilWriteMask(1)
		render.SetStencilReferenceValue(1)

		render.SetBlend(0)
		render.MaterialOverride(mat_outline)
		for e in next, outlined do
			if e:IsValid() then
				if e.RenderOverride then
					e:RenderOverride()
				elseif e.Draw then
					e:Draw()
				elseif e.DrawModel then
					e:DrawModel()
				end
				if e:IsPlayer() and e:GetActiveWeapon():IsValid() then
					e:GetActiveWeapon():DrawModel()
				end
			end
		end
	cam.End3D() -- done rendering stencil
	-- now rendering fill masked by stencil
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0)
	render.SetStencilReferenceValue(0)
	render.SetStencilTestMask(255)
	render.SetStencilFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilPassOperation(STENCILOPERATION_KEEP)
	render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)

	render.SetMaterial(mat_rtoutline)
	render.SetBlend(1)
	render.DrawQuad(Vector(-s,0,0),Vector(w-s,0,0),Vector(w-s,h,0),Vector(-s,h,0))
	render.DrawQuad(Vector(s,0,0),Vector(w+s,0,0),Vector(w+s,h,0),Vector(s,h,0))
	render.DrawQuad(Vector(0,-s,0),Vector(w,-s,0),Vector(w,h-s,0),Vector(0,h-s,0))
	render.DrawQuad(Vector(0,s,0),Vector(w,s,0),Vector(w,h+s,0),Vector(0,h+s,0))
	render.SetStencilEnable(false)
	render.MaterialOverride()

	render.SuppressEngineLighting(false)

	clear = true
	table.Empty(outlined)
end)
