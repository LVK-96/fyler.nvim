local helper = require('tests.helper')
local n = helper.new_child_neovim()
local T = helper.new_set({ hooks = { pre_case = n.setup, post_once = n.stop } })
local eq = helper.expect.equality

-- On NFS uv.fs_readdir returns directory entries with
-- type = nil rather than 'directory'. This happens because libuv maps
-- UV_DIRENT_UNKNOWN to nil in Lua, not the string 'unknown'.
--
-- Strip the type from directory entries
-- returned by fs_scan_dir for the tests
local patch_nil_type_dirs = [[
  local scheme = require('fyler.schemes.file')
  local orig = scheme.fs_scan_dir
  scheme.fs_scan_dir = function(path, cb)
    orig(path, function(err, entries)
      if entries then
        for _, e in ipairs(entries) do
          if e.type == 'directory' then e.type = nil end
        end
      end
      cb(err, entries)
    end)
  end
]]

T['directory with nil readdir type is stored as directory in state'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.lua(patch_nil_type_dirs)
  n.fwd_lua('require("fyler").open')({ kind = 'replace', root_path = tmpdir })
  vim.uv.sleep(10)

  n.lua([[
    _G.dir_type = ""
    local state = require('fyler.state')
    for _, e in pairs(state.store) do
      if e.name == 'a-dir' then
        _G.dir_type = e.type
        break
      end
    end
  ]])
  eq(n.lua_get('_G.dir_type'), 'directory')
end

T['directory with nil readdir type is expandable with Enter'] = function()
  local tmpdir = helper.get_tmpdir('data', { 'a-dir/', 'a-dir/a-file' })
  n.fwd_lua('require("fyler").setup')({})
  n.lua(patch_nil_type_dirs)
  n.fwd_lua('require("fyler").open')({ kind = 'replace', root_path = tmpdir })
  vim.uv.sleep(10)
  n.type_keys('<CR>')
  vim.uv.sleep(10)

  local is_expanded = n.lua([[
    _G.is_expanded = false
    local state = require('fyler.state')
    local libpath = require('fyler.lib.path')
    local finder = require('fyler.finder')
    local inst = finder.instance_get_or_nil()
    if not inst then return false end
    for _, e in pairs(state.store) do
      if e.name == 'a-dir' then
        _G.is_expanded = inst.state.meta[libpath.to_key(e.path)]
        break
      end
    end
  ]])
  eq(n.lua_get('_G.is_expanded'), true)
end

return T
