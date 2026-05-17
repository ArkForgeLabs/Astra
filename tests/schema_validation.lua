local v = require("validation").validation
local validate = v.validate
require("test")

---@param test Test
return function(test)
	local describe, it, expect = test.describe, test.it, test.expect

	test.paths.falsy = {
		test = function(value)
			local ok = (value == false)
			return ok, "expected " .. tostring(value) .. " to be falsy", "expected " .. tostring(value) .. " to not be falsy"
		end,
	}
	table.insert(test.paths.be, "falsy")

	local function expect_valid(validator, value)
		local ok, err = validate(validator, value)
		expect(ok).to.be.truthy()
		if not ok then
			print("  unexpected error: " .. tostring(err))
		end
	end

	local function expect_invalid(validator, value)
		local ok, _ = validator:validate(value)
		expect(ok).to.be.falsy()
	end

	describe("Primitives", function()
		it("string", function()
			expect_valid(v.string(), "hello")
			expect_invalid(v.string(), 42)
			expect_invalid(v.string(), true)
			expect_invalid(v.string(), nil)
		end)

		it("number", function()
			expect_valid(v.number(), 42)
			expect_valid(v.number(), 0)
			expect_valid(v.number(), -1.5)
			expect_invalid(v.number(), "42")
			expect_invalid(v.number(), nil)
		end)

		it("integer", function()
			expect_valid(v.integer(), 42)
			expect_valid(v.integer(), 0)
			expect_valid(v.integer(), -100)
			expect_invalid(v.integer(), 3.14)
			expect_invalid(v.integer(), "42")
		end)

		it("boolean", function()
			expect_valid(v.boolean(), true)
			expect_valid(v.boolean(), false)
			expect_invalid(v.boolean(), 1)
			expect_invalid(v.boolean(), nil)
		end)

		it("none", function()
			expect_valid(v.none(), nil)
			expect_invalid(v.none(), false)
			expect_invalid(v.none(), 0)
		end)
	end)

	describe("Range", function()
		it("inclusive", function()
			local r = v.range({ min = 0, max = 100 })
			expect_valid(r, 0)
			expect_valid(r, 50)
			expect_valid(r, 100)
			expect_invalid(r, -1)
			expect_invalid(r, 101)
		end)

		it("exclusive", function()
			local r = v.range({ min = 0, minExclusive = true, max = 10, maxExclusive = true })
			expect_invalid(r, 0)
			expect_valid(r, 1)
			expect_valid(r, 9)
			expect_invalid(r, 10)
		end)

		it("min-only", function()
			local r = v.range({ min = 5 })
			expect_valid(r, 5)
			expect_valid(r, 100)
			expect_invalid(r, 4)
		end)

		it("max-only", function()
			local r = v.range({ max = 10 })
			expect_valid(r, 10)
			expect_valid(r, -100)
			expect_invalid(r, 11)
		end)
	end)

	describe("Pattern", function()
		it("matches pattern", function()
			local p = v.pattern("^%a+$")
			expect_valid(p, "hello")
			expect_valid(p, "abc")
			expect_invalid(p, "hello123")
			expect_invalid(p, "123")
		end)

		it("rejects non-strings", function()
			expect_invalid(v.pattern("^%d+$"), 42)
		end)
	end)

	describe("Literal", function()
		it("exact match", function()
			local l = v.literal("hello")
			expect_valid(l, "hello")
			expect_invalid(l, "world")
			expect_invalid(l, nil)
		end)

		it("numeric literal", function()
			local l = v.literal(42)
			expect_valid(l, 42)
			expect_invalid(l, 43)
		end)
	end)

	describe("Struct", function()
		it("basic struct", function()
			local User = v.struct({
				id = v.number(),
				name = v.string(),
			})
			expect_valid(User, { id = 1, name = "Alice" })
			expect_invalid(User, { id = "1", name = "Alice" })
			expect_invalid(User, { id = 1, name = 42 })
		end)

		it("rejects missing required keys", function()
			local User = v.struct({
				id = v.number(),
				name = v.string(),
			})
			expect_invalid(User, { id = 1 })
			expect_invalid(User, { name = "Alice" })
		end)

		it("rejects unexpected keys", function()
			local User = v.struct({ id = v.number() })
			expect_valid(User, { id = 1 })
			expect_invalid(User, { id = 1, extra = "bad" })
		end)

		it("nested struct", function()
			local Profile = v.struct({
				user = v.struct({
					id = v.number(),
					name = v.string(),
				}),
			})
			expect_valid(Profile, { user = { id = 1, name = "Alice" } })
			expect_invalid(Profile, { user = { id = "1", name = "Alice" } })
			expect_invalid(Profile, { user = { id = 1 } })
		end)
	end)

	describe("Array", function()
		it("array of primitives", function()
			local Numbers = v.array(v.number())
			expect_valid(Numbers, { 1, 2, 3 })
			expect_valid(Numbers, {})
			expect_invalid(Numbers, { 1, "two", 3 })
			expect_invalid(Numbers, "not-an-array")
		end)

		it("array of structs", function()
			local Entries = v.array(v.struct({
				id = v.number(),
				text = v.string(),
			}))
			expect_valid(Entries, {
				{ id = 1, text = "hello" },
				{ id = 2, text = "world" },
			})
			expect_invalid(Entries, {
				{ id = 1, text = "ok" },
				{ id = "bad", text = "fail" },
			})
		end)
	end)

	describe("Optional", function()
		it("accepts nil or matching value", function()
			local Field = v.optional(v.string())
			expect_valid(Field, "hello")
			expect_valid(Field, nil)
			expect_invalid(Field, 42)
		end)

		it("works in structs", function()
			local User = v.struct({
				id = v.number(),
				email = v.optional(v.string()),
			})
			expect_valid(User, { id = 1, email = "a@b.com" })
			expect_valid(User, { id = 1 })
			expect_invalid(User, { id = 1, email = 42 })
		end)
	end)

	describe("Union", function()
		it("accepts either type", function()
			local StrOrNum = v.union(v.string(), v.number())
			expect_valid(StrOrNum, "hello")
			expect_valid(StrOrNum, 42)
			expect_invalid(StrOrNum, true)
			expect_invalid(StrOrNum, nil)
		end)
	end)

	describe("Composition", function()
		it("nested struct with array of structs and optional", function()
			local Company = v.struct({
				name = v.string(),
				employees = v.array(v.struct({
					id = v.integer(),
					name = v.string(),
					email = v.optional(v.string()),
					tags = v.array(v.string()),
				})),
				metadata = v.optional(v.struct({
					founded = v.number(),
					active = v.boolean(),
				})),
			})

			expect_valid(Company, {
				name = "Acme Corp",
				employees = {
					{ id = 1, name = "Alice", tags = { "admin" } },
					{ id = 2, name = "Bob", email = "bob@acme.com", tags = {} },
				},
			})

			expect_valid(Company, {
				name = "Startup",
				employees = {},
				metadata = { founded = 2024, active = true },
			})

			expect_invalid(Company, {
				name = 42,
				employees = {},
			})

			expect_invalid(Company, {
				name = "Bad",
				employees = { { id = 1.5, name = "bad", tags = {} } },
			})
		end)
	end)
end
