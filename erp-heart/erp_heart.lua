SS13 = require("SS13")
SS13.wait(1)

local user = SS13.get_runner_client()

local mob_list = dm.global_vars.GLOB.mob_list

local len = #mob_list

for i = 1, len do
    local mob = mob_list[i]
    if mob and mob.client then
        mob:receive_heart(user, 24 * 36000, true)
    end
end
