---@meta

import = require

---@param modName string
function import(modName)
	---@diagnostic disable-next-line: param-type-mismatch, undefined-global
	local ok, import_result = pcall(astra_internal__import, modName)
	if not ok then
		ok, require_result = require(modName)
		if not ok then
			error("Failed to load module.\nImport Error:" .. import_result .. "\nError: " .. require_result)
		end
		return result
	end
	return result
end
