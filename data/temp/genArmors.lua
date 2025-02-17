#! /usr/bin/lua

require( "common" )

Items  = data( "items" )
Skills = data( "skills" )

local Dir = "armor"

local Names, NamesCount = loadNames( Dir .. "/names.txt" )

local Types =
{
	"head",
	"body",
	"arms",
	"waist",
	"legs",
}

local Bases =
{
	head = { name = { hgg = "Helmets" }, short = "hlm" },
	body = { name = { hgg = "Plates" }, short = "plt" },
	arms = { name = { hgg = "Gloves" }, short = "arm" },
	waist = { name = { hgg = "Tassets" }, short = "wst" },
	legs = { name = { hgg = "Greaves" }, short = "leg" },
}

local MaxSlots = 3

local Actions =
{
	init = function( line, piece )
		if line:find( "/" ) then
			local maleName, femaleName = line:match( "^([%a ]*) / ([%a ]*)$" )

			-- supports blanks for snake armor
			-- although lua doesn't do lazy evaluation so every
			-- assert using piece.name.hgg after this will fail
			-- so i've not set any pieces up for this

			if maleName == "" then
				maleName = nil
			else
				assert( Names[ maleName ], "bad name: " .. maleName )

				Names[ maleName ] = nil
			end

			if femaleName == "" then
				femaleName = nil
			else
				assert( femaleName == "" or Names[ femaleName ], "bad name: " .. femaleName )

				Names[ femaleName ] = nil
			end

			piece.name = { hgg = maleName, hgg_fem = femaleName }
		else
			assert( Names[ line ]
				or line == "Ranger Belt" or line == "Scout Belt" or line == "Jolly Roger Skirt",
				"bad name: " .. line )

			Names[ line ] = nil

			piece.name = { hgg = line }
		end

		return "defense"
	end,

	defense = function( line, piece )
		local success, _, defense = line:find( "(%d+)" )

		assert( defense, "bad defense in " .. piece.name.hgg .. ": " .. line )

		piece.defense = tonumber( defense )

		return "elemdef"
	end,

	elemdef = function( line, piece )
		local success, _, fire, water, thunder, ice, dragon = line:find( "(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+)" )

		assert( success, "bad elemdef in " .. piece.name.hgg .. ": " .. line )

		piece.fireRes    = tonumber( fire )
		piece.waterRes   = tonumber( water )
		piece.thunderRes = tonumber( thunder )
		piece.iceRes     = tonumber( ice )
		piece.dragonRes  = tonumber( dragon )

		return "bladegun"
	end,

	bladegun = function( line, piece )
		piece.blade  = ( line:find( "B" ) ) ~= nil
		piece.gunner = ( line:find( "G" ) ) ~= nil

		return "rarity"
	end,

	rarity = function( line, piece )
		local success, _, rarity = line:find( "R(%d+)" )

		assert( success, "bad rarity in " .. piece.name.hgg .. ": " .. line )

		piece.rarity = tonumber( rarity )

		return "slots"
	end,

	slots = function( line, piece )
		local success = line:find( "O*%-*" )

		assert( success, "bad slots in " .. piece.name.hgg .. ": " .. line )

		local slots = 0

		for i = 1, MaxSlots do
			if line:sub( i, i ) == "O" then
				slots = slots + 1
			else
				break
			end
		end

		piece.slots = slots

		return "create"
	end,

	create = function( line, piece )
		if line:sub( -1 ) == "z" then
			piece.price = tonumber( line:sub( 1, -2 ) )

			return "skills"
		end

		local id, count = parseItem( line )

		assert( id, "bad material in " .. piece.name.hgg .. ": " .. line )

		if not piece.create then
			piece.create = { }
		end

		table.insert( piece.create, { id = id, count = count } )

		return "create"
	end,

	skills = function( line, piece )
		local id, points = parseSkill( line )

		if not id then
			piece.description = line

			return "scraps"
		end

		if not piece.skills then
			piece.skills = { }
		end

		table.insert( piece.skills, { id = id, points = points } )

		return "skills"
	end,

	scraps = function( line, piece )
		local id, count = parseItem( line )

		assert( id, "bad scrap in " .. piece.name.hgg .. ": " .. line )

		if not piece.scraps then
			piece.scraps = { }
		end

		table.insert( piece.scraps, { id = id, count = count } )

		return "scraps"
	end,
}

function doLine( line, piece, state )
	if not Actions[ state ] then
		print( state )
	end

	return Actions[ state ]( line, piece )
end

local Armor = { }
local ArmorCount = 0

for _, short in pairs( Types ) do
	io.input( Dir .. "/" .. short .. ".txt" )

	local class = Bases[ short ]
	class.pieces = { }

	local state = "init"
	local piece = { }

	local lastDepth = { }

	for line in io.lines() do
		if line == "" then
			table.insert( class.pieces, piece )

			ArmorCount = ArmorCount + 1

			state = "init"
			piece = { }
		else
			state = doLine( line, piece, state )
		end
	end

	table.insert( class.pieces, piece )

	ArmorCount = ArmorCount + 1

	table.insert( Armor, class )
end

local encoded = json.encode( Armor )

io.output( "../armors.json" )
io.write( encoded )

io.output( "../js/armors.js" )
io.write( "var Armors=" .. encoded )

print( ( "genArmors: ok, %.1f%% complete! (%d/%d)" ):format(
	100 * ( ArmorCount / NamesCount ),
	ArmorCount,
	NamesCount
) )
