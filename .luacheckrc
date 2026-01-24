
self = false
unused = false
-- unused_args = false
global = false
allow_defined_top = true
max_line_length = false
codes = true

-- Ideally reenable these warnings later
redefined = false

ignore = {
    "011", -- TODO: invalid escape sequence
    "511", -- TODO: unreachable code
    "512", -- Loop can be executed at most once.

    "531", -- TODO: right side of assignment has more values than left side expects
    "541", -- TODO: empty do..end block
    "542", -- TODO: empty if branch
    "581", -- overly specific rule:  'not (x == y)' can be replaced by 'x ~= y'
    "582", -- TODO: Error prone negation: negation is executed before relational operator.
    "611", -- TODO: line contains only whitespace
    "612", -- TODO: line contains trailing whitespace
    "613", -- TODO: line contains trailing whitespace inside a string
    "614", -- TODO: trailing whitespace in a comment
    "621", -- TODO: inconsistent indentation
}
-- Something to think about in the future
-- max_cyclomatic_complexity = 10


-- Default is probably fine, but anyway
std=lua51
quiet = 1

globals = {
    -- std extensions
    "math.round", "math.bit_or", "math.diag", "math.cross_product", "math.triangulate",
    "table.ifind", "table.show", "table.save", "table.echo", "table.print",
    -- Spring
    "Spring", "VFS", "gl", "GL", "Game",
    "UnitDefs", "UnitDefNames", "FeatureDefs", "FeatureDefNames",
    "WeaponDefs", "WeaponDefNames", "LOG", "KEYSYMS", "CMD", "Script",
    "SendToUnsynced", "Platform", "Engine", "include", "COB",
    -- GL
    "GL_TEXTURE_2D", "GL_HINT_BIT",
    -- Gadgets
    "GG", "gadgetHandler", "gadget",
    -- Widgets
    "WG", "widgetHandler", "widget", "LUAUI_DIRNAME", "self",
    -- Chili
    "Chili", "Checkbox", "Control", "ComboBox", "Button", "Label",
    "Line", "EditBox", "Font", "Window", "ScrollPanel", "LayoutPanel",
    "Panel", "StackPanel", "Grid", "TextBox", "Image", "TreeView", "Trackbar",
    "DetachableTabPanel", "screen0", "Progressbar",
    -- Libs
    -- "LCS", "Path", "Table", "Log", "String", "Shaders", "Time", "Array", "StartScript",

    "CMDTYPE", "COBSCALE", "CallAsTeam", "SYNCED", "loadlib",
}

exclude_files = {
    ".git/**/*",
}