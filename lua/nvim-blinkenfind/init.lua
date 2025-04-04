local M = {}
local api = vim.api

local config = {
    highlights = {
        "BlinkenFind1",
        "BlinkenFind2",
        "BlinkenFind3",
        "BlinkenFind4",
        "BlinkenFind5",
        "BlinkenFind6",
        "BlinkenFind7",
        "BlinkenFind8",
        "BlinkenFind9",
    },

    create_mappings = true,
    treesitter_repeat = true,
}


local namespace = api.nvim_create_namespace("nvim-blinkenlights")

local function highlight_motion(cmd, count)
    local goes_backward = cmd == "F" or cmd == "T"
    local cursor = api.nvim_win_get_cursor(0)
    local line = api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1]

    local index = 0
    local lastwasword = false
    local lastwascap = false

    local seen = {}
    --[[
    Highlight the following:
        - non alphanumeric characters
        - first capital character in a sequence
        - first character of word
        - only if it's not the first, which would be easily reachable by hl
    ]]
    local start = cursor[2] + (goes_backward and 0 or 2)
    for i = cursor[2] + (goes_backward and 0 or 2), (goes_backward and 1 or #line), (goes_backward and -1 or 1) do
        local char = line:sub(i, i)
        seen[char] = (seen[char] or 0) + 1
        local isalpha = char:lower() ~= char:upper()
        local iscap = isalpha and (char:upper() == char)

        if (i - start ~= 0)                                   -- is not directly adjacent
            and (not isalpha or (isalpha and not lastwasword) -- not a letter or first letter
                or (iscap and not lastwascap))                -- capital letter
            and seen[char] == count then
            api.nvim_buf_set_extmark(0, namespace, cursor[1] - 1, i - 1, {
                hl_group = config.highlights[(index % #config.highlights) + 1],
                end_col = i,
                end_line = cursor[1] - 1,
            })
            index = index + 1
        end

        lastwasword = isalpha
        lastwascap = iscap
    end
end

local highlighted_find = function(cmd)
    local count = vim.v.count1
    highlight_motion(cmd, count)

    -- we're in some "normal-ish" mode, no weird hacks
    if vim.api.nvim_get_mode().mode ~= "no" then
        api.nvim_feedkeys(count .. cmd, "n")
        -- as soon as the key is typed, we're done
        vim.on_key(function(key, typed)
            api.nvim_buf_clear_namespace(0, namespace, 0, -1)
            vim.on_key(nil, namespace)
        end, namespace)
    else
        -- WARN: here be dragons
        local op = vim.v.operator

        -- ensure normal mode
        api.nvim_feedkeys("\x1b", "n")

        -- avoid incorrect cursor position
        if op == "c" then
            api.nvim_feedkeys("l", "n")
        end

        -- give it time to highlight
        vim.defer_fn(function()
            -- TODO: do this properly
            api.nvim_create_autocmd("ModeChanged", {
                callback = function()
                    if vim.v.event.old_mode == "no" then
                        api.nvim_buf_clear_namespace(0, namespace, 0, -1)
                        return true
                    end
                end
            })

            -- make sure that custom operators work
            api.nvim_feedkeys(op, "")
            -- so feed the motion separately
            api.nvim_feedkeys(count .. cmd, "n")
        end, 10)
    end

    if config.treesitter_repeat then
        -- make ; and , work with this
        require("nvim-treesitter.textobjects.repeatable_move").last_move = {
            func = cmd,
            opts = { forward = cmd == "f" or cmd == "t" }
        }
    end
end

M.highlighted_find = highlighted_find

M.setup = function(opts)
    config = vim.tbl_extend("force", config, opts)
    if config.create_mappings then
        for _, cmd in ipairs { "f", "F", "t", "T" } do
            vim.keymap.set({ "x", "n", "o" }, cmd, function() return highlighted_find(cmd) end)
        end
    end
end

return M
