local test = require("test")
local validation = require("validation")
local describe, it, expect = test.describe, test.it, test.expect

-- Add lust method: to.be.falsy()
test.paths.falsy = {
    test = function(value)
        local ok = (value == false)
        return ok,
            'expected ' .. tostring(value) .. ' to be falsy',
            'expected ' .. tostring(value) .. ' to not be falsy'
    end
}
table.insert(test.paths.be, 'falsy')

-- helper functions
local function expect_valid(example, schema)
    local ok, err = validation.validate_table(example, schema)
    expect(ok).to.be.truthy()
end

local function expect_invalid(example, schema)
    local ok, _ = validation.validate_table(example, schema)
    expect(ok).to.be.falsy()
end

-- test cases
describe('BasicSchema', function()
    local schema = {
        id   = { type = 'number' },
        name = { type = 'string', required = false }
    }

    it('valid-type', function()
        expect_valid({ id = 123, name = 'Ada' }, schema)
        expect_invalid({ id = '123', name = 'Ada' }, schema)
        expect_invalid({ id = 1, name = 456 }, schema)
    end)

    it('invalid-type', function()
        expect_valid({ id = 123, name = 'Ada' }, schema)
        expect_invalid({ id = '123', name = 'Ada' }, schema)
        expect_invalid({ id = 1, name = 456 }, schema)
    end)

    it('optional-field-absence', function()
        expect_valid({ id = 123 }, schema)
    end)
end)

describe('NestedSchema', function()
    local schema = {
        user = {
            type = 'table',
            schema = {
                profile = {
                    type = 'table',
                    schema = {
                        id         = { type = 'number' },
                        name       = { type = 'string' },
                        is_student = { type = 'boolean', required = false }
                    }
                }
            }
        }
    }

    it('valid-nested-type', function()
        expect_valid({ user = { profile = { id = 7, name = 'Grace', is_student = true } } }, schema)
    end)

    it('invalid-nested-type', function()
        expect_invalid({ user = { profile = { id = '7', name = 'Grace', is_student = true } } }, schema) -- wrong type
    end)

    it('missing-required-field', function()
        expect_invalid({ user = { profile = { name = 'Grace', is_student = true } } }, schema)
    end)

    it('optional-field-absence', function()
        expect_valid({ user = { profile = { id = 7, name = 'Grace' } } }, schema)
    end)
end)

describe('Arrays', function()
    local schema = {
        numbers = { type = 'array', array_item_type = 'number' },
        strings = { type = 'array', array_item_type = 'string' },
        entries = {
            type = 'array',
            schema = {
                id   = { type = 'number' },
                text = { type = 'string' }
            }
        }
    }

    it('valid-array', function()
        local ex = {
            numbers = { 1, 2, 3 },
            strings = { 'a', 'b' },
            entries = { { id = 1, text = 'hey' }, { id = 2, text = 'hello' } }
        }
        expect_valid(ex, schema)
    end)

    it('invalid-arrays', function()
        expect_invalid({ numbers = { 1, 'x' }, strings = {}, entries = {} }, schema)                    -- array level
        expect_invalid({ numbers = {}, strings = {}, entries = { { id = 'x', text = 'ok' } } }, schema) -- table-in-array level
    end)
end)
