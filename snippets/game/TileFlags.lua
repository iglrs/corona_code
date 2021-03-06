--- This module deals with tile direction flags.
--
-- Terminology-wise, a "flag" in the following refers to an unsigned integer with a single
-- bit set, and a "union of flags" is the logical or of one or more distinct flags.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --

-- Modules --
local bitwise_ops = require("bitwise_ops")
local dispatch_list = require("game.DispatchList")
local index_ops = require("index_ops")
local iterators = require("iterators")
local numeric_ops = require("numeric_ops")
local table_ops = require("table_ops")
local utils = require("utils")

-- Imports --
local PowersOf2 = bitwise_ops.PowersOf2
local TestFlag = utils.TestFlag

-- Exports --
local M = {}

-- Flags for each cardinal direction --
local DirFlags = utils.MakeFlags{ "left", "right", "up", "down" }

-- Helper to build up tile flags as combination of cardinal directions
local function OrFlags (...)
	local flags = 0

	for _, name in iterators.Args(...) do
		flags = flags + DirFlags[name]
	end

	return flags
end

-- Flag unions describing which directions leave tiles --
local TileFlags = {
	FourWays = OrFlags("left", "right", "up", "down"),
	UpperLeft = OrFlags("right", "down"),
	UpperRight = OrFlags("left", "down"),
	LowerLeft = OrFlags("right", "up"),
	LowerRight = OrFlags("left", "up"),
	TopT = OrFlags("left", "right", "down"),
	LeftT = OrFlags("right", "up", "down"),
	RightT = OrFlags("left", "up", "down"),
	BottomT = OrFlags("left", "right", "up"),
	Horizontal = OrFlags("left", "right"),
	Vertical = OrFlags("up", "down")
}

-- Working set of per-tile flags --
local Flags

---@int index Tile index.
-- @treturn uint Working flags, as assigned by @{SetFlags}; 0 if no value has been assigned,
-- or _index_ is outside the level.
--
-- When the level starts, no flags are considered assigned.
function M.GetFlags (index)
	return Flags[index] or 0
end

---@string name One of **"left"**, **"right"**, **"up"**, **"down"**, **"FourWays"**,
-- **"UpperLeft"**, **"UpperRight"**, **"LowerLeft"**, **"LowerRight"**, **"TopT"**,
-- **"LeftT"**, **"RightT"**, **"BottomT"**, **"Horizontal"**, **"Vertical"**.
-- @treturn uint Union of flags corresponding to _name_, or 0 if no match is found.
function M.GetFlagsByName (name)
	return TileFlags[name] or DirFlags[name] or 0
end

--- Indicates what combination a group of named flags will yield.
-- @param ... Some combination of **"left"**, **"right"**, **"up"**", and **"down"**.
-- @treturn string One of the values of _name_ in @{GetFlagsByName}, or **nil** if no
-- match was found.
function M.GetNameByFlagNames (...)
	return M.GetNameByFlags(OrFlags(...)) -- TODO: COULD (easily) be called with duplicate names...
end

-- The names of each cardinal direction, indexed by its flag --
local NamesByValueDir = table_ops.Invert(DirFlags)

-- The names of each flag combination, indexed by its union of flags --
local NamesByValueTile = table_ops.Invert(TileFlags)

--- Variant of @{GetNameByFlagNames} using the flags themselves as input.
-- @uint flags Union of flags.
-- @treturn string As per @{GetNameByFlagNames}.
function M.GetNameByFlags (flags)
	return NamesByValueTile[flags] or NamesByValueDir[flags]
end

-- The "true" value of flags, as used outside the module --
local ResolvedFlags

---@int index Tile index.
-- @treturn uint Resolved flags, as of the last @{ResolveFlags} call; 0 if no resolution
-- has been performed or _index_ is invalid.
--
-- When the level begins, no flags are considered resumed.
function M.GetResolvedFlags (index)
	return ResolvedFlags[index] or 0
end

---@int index Tile index.
-- @string name One of **"left"**, **"right"**, **"up"**, or **"down"**.
-- @treturn boolean _index_ is valid and the resolved flag is set for the tile?
-- @see ResolveFlags
function M.IsFlagSet (index, name)
	return TestFlag(ResolvedFlags[index] or 0, DirFlags[name])
end

---@int index Tile index.
-- @treturn boolean Is _index_ valid, and did it resolve to neighboring more than two tiles?
-- @treturn uint Number of outbound directions, &isin; [0, 4].
-- @see ResolveFlags
function M.IsJunction (index)
	local n = 0

	for _ in bitwise_ops.PowersOf2(ResolvedFlags[index] or 0) do
		n = n + 1
	end

	return n > 2, n
end

---@int index Tile index.
-- @treturn boolean Is _index_ valid, and would its flags resolve to some combination?
-- @see GetFlagsByName, ResolveFlags
function M.IsOnPath (index)
	local flags = ResolvedFlags[index] or 0

	return flags > 0
end

---@int index Tile index.
-- @treturn boolean Is _index_ valid, and did it resolve to either the **"Horizontal"** or
-- the **"Vertical"** combination?
-- @see GetFlagsByName, ResolveFlags
function M.IsStraight (index)
	local flags = ResolvedFlags[index]

	return flags == TileFlags.Horizontal or flags == TileFlags.Vertical
end

-- Flags for the reverse of each cardinal direction --
local Reverse = { left = "right", right = "left", up = "down", down = "up" }

for k, v in pairs(Reverse) do
	Reverse[k] = DirFlags[v]
end

-- Tile index deltas in each direction --
local Deltas = { left = -1, right = 1 }

-- How many columns wide is each row and how many rows tall is each column? --
local NCols, NRows

-- Number of cells in level --
local Area

--- Resolves the current working flags, as set by @{SetFlags}, into the current active
-- flag set. The working flags will remain intact.
--
-- The operation begins with the working set of flags, and looks for these cases:
--
-- *  One-way, e.g. a right-flagged tile whose right neighbor is not left-flagged.
-- *  Orphaned border, e.g. a down-flagged tile on the lowest row.
--
-- The final result, after culling the troublesome flags, is the resolved flag set.
-- @bool update If true, the **"flags_updated"** event list is dispatched after resolution.
-- @see game.DispatchList.CallList
function M.ResolveFlags (update)
	local col = 0

	for i = 1, Area do
		local flags, ignore = Flags[i]

		col = index_ops.RotateIndex(col, NCols)

		if col == 1 then
			ignore = "left"
		elseif col == NCols then
			ignore = "right"
		end

		for _, power in PowersOf2(flags or 0) do
			local what = NamesByValueDir[power]
			local all = what ~= ignore and Flags[i + Deltas[what]]

			if not (all and TestFlag(all, Reverse[what])) then
				flags = flags - power
			end
		end

		ResolvedFlags[i] = flags
	end

	if update then
		dispatch_list.CallList("flags_updated")
	end
end

-- Clockwise flag rotations --
local RotateCW = { left = "up", right = "down", down = "left", up = "right" }

-- Counter-clockwise flag rotations --
local RotateCCW = table_ops.Invert(RotateCW)

--- Reports the state of a set of flags, after a rotation of some multiple of 90 degrees.
-- @uint flags Union of flags to rotate.
-- @string how If this is **"ccw"** or **"180"**, the flags are rotated through -90 or 180
-- degrees, respectively. Otherwise, the rotation is by 90 degrees.
-- @treturn uint Union of rotated flags.
function M.Rotate (flags, how)
	local rotate = how == "ccw" and RotateCCW or RotateCW
	local rflags = 0

	for _, power in PowersOf2(flags) do
		local new = rotate[NamesByValueDir[power]]

		new = how == "180" and rotate[new] or new
		rflags = rflags + DirFlags[new]
	end

	return rflags
end


--- Sets a tile's working flags.
--
-- @{ResolveFlags} can later be called to establish inter-tile connections.
-- @int index Tile index; if outside the level, this is a no-op.
-- @int flags Union of flags to assign.
-- @treturn uint Previous value of tile's working flags; 0 if no value has been assigned, or
-- _index_ is outside the level.
-- @see GetFlags
function M.SetFlags (index, flags)
	local old

	if index >= 1 and index <= Area then
		old, Flags[index] = Flags[index], flags
	end

	return old or 0
end

--- Clears all tile flags, in both the working and resolved sets, in a given region.
--
-- Neighboring tiles' flags remain unaffected. Flag resolution is not performed.
-- @int col1 Column of one corner...
-- @int row1 ...row of one corner...
-- @int col2 ...column of another corner... (Columns will be sorted, and clamped.)
-- @int row2 ...and row of another corner. (Rows too.)
function M.WipeFlags (col1, row1, col2, row2)
	col1, col2 = numeric_ops.MinMax_Range(col1, col2, NCols)
	row1, row2 = numeric_ops.MinMax_Range(row1, row2, NRows)

	local index = index_ops.CellToIndex(col1, row1, NCols)

	for _ = row1, row2 do
		for i = 0, col2 - col1 do
			ResolvedFlags[index + i], Flags[index + i] = nil
		end

		index = index + NCols
	end
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Enter Level --
	enter_level = function(level)
		Deltas.up = -level.ncols
		Deltas.down = level.ncols

		Flags = {}
		ResolvedFlags = {}
		NCols = level.ncols
		NRows = level.nrows
		Area = NCols * NRows
	end,

	-- Leave Level --
	leave_level = function()
		Flags, ResolvedFlags = nil
	end,

	-- Reset Level --
	reset_level = function()
		M.ResolveFlags()
	end,

	-- Tiles Changed --
	tiles_changed = function()
		M.ResolveFlags(true)
	end
}

-- Export the module.
return M