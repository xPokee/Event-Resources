SS13 = require("SS13")
SS13.wait(1)

local user = SS13.get_runner_client()
local spawn_loc = user.mob.loc

local PATH_ITEM     = "/obj/item"
local PATH_STORAGE  = "/datum/component/storage"
local PATH_CRYSTAL  = "/obj/item/stack/ore/bluespace_crystal"

local SIG_EXAMINE     = "atom_examine"
local SIG_PRE_ATTACK  = "item_pre_attack"

-- Credit goes to Fikou on GitHub for the loadIcon function

iconsByHttp = iconsByHttp or {}
local loadIcon = function(http)
	if iconsByHttp[http] then
		return iconsByHttp[http]
	end
	local request = SS13.new("/datum/http_request")
	local file_name = "tmp/custom_map_icon.dmi"
	request:prepare("get", http, "", "", file_name)
	request:begin_async()
	while request:is_complete() == 0 do
		sleep()
	end
	iconsByHttp[http] = SS13.new("/icon", file_name)
	return iconsByHttp[http]
end

local kit_state = {}

local kit = SS13.new("/obj/item", spawn_loc)
kit.name = "bluespace compression kit"
kit.desc = "An illegally modified BSRPED, capable of reducing the size of most items."
kit.icon = loadIcon("https://github.com/xPokee/Event-Resources/raw/refs/heads/main/bs-compression-kit/compression_kit.dmi")
kit.icon_state = "compression_c"
kit.inhand_icon_state = "BS_RPED"
kit.lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
kit.righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
kit.w_class = 3
kit_state[kit] = {
    charges = 5
}

local function charges_of(kit)
    return kit_state[kit].charges
end

local function set_charges(kit, value)
    kit_state[kit].charges = value
end

local function sparks()
    local s = SS13.new("/datum/effect_system/spark_spread")
    s:set_up(5, 1, kit.loc)
    s:start()
end

SS13.register_signal(kit, SIG_EXAMINE, function(_, user, examine_list)
    local text =
        "<span class='notice'>It has " ..
        tostring(charges_of(kit)) ..
        " charges left. Recharge with bluespace crystals.</span>"

    if type(examine_list) == "userdata" then
        list.add(examine_list, text)
    else
        return tostring(examine_list) .. "<br>" .. text
    end
end)

SS13.register_signal(kit, SIG_PRE_ATTACK, function(_, target, attacker, proximity)
    if proximity == 0 or target == nil then return end

    if charges_of(kit) <= 0 then
        dm.global_procs.playsound(kit.loc, 'sound/machines/buzz-two.ogg', 50, 1)
        dm.global_procs.to_chat(attacker,
            "<span class='notice'>The bluespace compression kit is out of charges! Recharge it with bluespace crystals.</span>")
        return 1
    end

    if not SS13.istype(target, PATH_ITEM) then return end
    local O = target

    if O.w_class == 1 then
        dm.global_procs.playsound(kit.loc, 'sound/machines/buzz-two.ogg', 50, 1)
        dm.global_procs.to_chat(attacker,
            "<span class='notice'>" .. tostring(O) .. " cannot be compressed smaller!.</span>")
        return 1
    end

    if O:GetComponent(SS13.type(PATH_STORAGE)) then
        dm.global_procs.to_chat(attacker,
            "<span class='notice'>You feel like compressing an item that stores other items would be counterproductive.</span>")
        return 1
    end

    local delay = 40

    local ok = dm.global_procs.do_after(attacker, delay, O)
    if ok == 0 then
        return 1
    end

    local start = dm.world.time
    while dm.world.time < start + delay do
        sleep()
    end

    if not SS13.is_valid(attacker)
        or not SS13.is_valid(O)
        or not SS13.is_valid(kit) then
        return 1
    end

    if charges_of(kit) <= 0 or O.w_class <= 1 then
        return 1
    end

    dm.global_procs.playsound(kit.loc, 'sound/weapons/emitter2.ogg', 50, 1)

    local s = SS13.new("/datum/effect_system/spark_spread")
    s:set_up(5, 1, kit.loc)
    s:start()

    O.w_class = O.w_class - 1
    set_charges(kit, charges_of(kit) - 1)

    dm.global_procs.to_chat(attacker,
        "<span class='notice'>You successfully compress " .. tostring(O) ..
        "! The compressor now has " .. charges_of(kit) .. " charges.</span>"
    )

    return 1
end)

SS13.register_signal(kit, "atom_attackby",
    function(src, attacking_item, user, modifiers, attack_modifiers)

        if not SS13.istype(attacking_item, PATH_CRYSTAL) then
            return
        end

        set_charges(kit, charges_of(kit) + 2)

        dm.global_procs.to_chat(user,
            "<span class='notice'>You insert " .. tostring(attacking_item) ..
            " into " .. tostring(kit) ..
            ". It now has " .. charges_of(kit) .. " charges.</span>"
        )

        if attacking_item.amount and attacking_item.amount > 1 then
            attacking_item.amount = attacking_item.amount - 1
        else
            dm.global_procs.qdel(attacking_item)
        end

        return 1
    end
)
