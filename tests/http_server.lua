local PORT = 3000
local DB_PATH = 'tests/posts_test.db'
local mock = require("tests.mock_server")

local server_task = spawn_task(function ()
    local server = mock.create({ port = PORT, db_path = DB_PATH })
    server:run()
end)

print('WAIT 3 SECONDS TO INITIATE THE SERVER')
spawn_timeout(function ()
    local lust = require 'tests.lust'
    local describe, it, expect = lust.describe, lust.it, lust.expect

    -- define the custom assertion - check str contain (not provided on lust)
    lust.paths.contain = {
        test = function(str, substr)
        local ok = type(str) == 'string' and type(substr) == 'string' and str:find(substr, 1, true) ~= nil
        return ok,
            "expected '" .. tostring(str) .. "' to contain '" .. tostring(substr) .. "'",
            "expected '" .. tostring(str) .. "' to not contain '" .. tostring(substr) .. "'"
        end
    }
    table.insert(lust.paths.to, 'contain')

    -- util
    local function get_one_valid_id()
        local response = Astra.http.request('http://localhost:' .. PORT .. '/posts'):execute()
        local latest_id = response:body():json()[1].id
        return latest_id
    end

    -- helper
    local function post_helper(payload)
        local response = Astra.http.request('http://localhost:' .. PORT .. '/posts')
            :set_method('POST')
            :set_json(payload)
            :execute()

        local status_code = response:status_code()
        local data = response:body():json()
        return status_code, data
    end
    local function get_helper(uri)
        local response = Astra.http.request(uri)
            :set_method('GET')
            :execute()

        local status_code = response:status_code()
        local data = response:body():json()
        return status_code, data
    end
    local function put_helper(id, payload)
        local response = Astra.http.request('http://localhost:' .. PORT .. '/posts/' .. tostring(id))
            :set_method('PUT')
            :set_json(payload)
            :execute()

        local status_code = response:status_code()
        local data = response:body():json()
        return status_code, data
    end
    local function del_helper(uri)
        local response = Astra.http.request(uri)
            :set_method('DELETE')
            :execute()

        local status_code = response:status_code()
        local data = response:body():json()
        return status_code, data
    end

    -- test
    describe('TestPostPostAPI', function()
        -- 200: valid
        it('testPostValidPost', function()
            local status_code, data = post_helper({
                author = 'tester',
                title = 'test_ttl',
                content = 'test_content'
            })
            expect(status_code).to.equal(200)
            expect(data.status).to.equal('created')
        end)

        -- 400: missing field
        it('testPostMissingFieldPost', function()
            local status_code, data = post_helper({
                author = 'tester',
                title = 'test_ttl',
            })
            expect(status_code).to.equal(400)
            expect(data.status).to_not.be.truthy()
            expect(data.error).to.contain('Invalid input')
        end)
    
        -- 400: invalid schema
        it('testPostInvalidTypePost', function()
            local status_code, data = post_helper({
                author = 123,
                content = 'test_content'
            })
            expect(status_code).to.equal(400)
            expect(data.status).to_not.be.truthy()
            expect(data.error).to.contain('Invalid input')
        end)
    end)

    describe('TestGetPostAPI', function()
        local uri = 'http://localhost:' .. PORT .. '/posts'
        -- 200: valid
        it('testGetAllPosts', function()
            local status_code, data = get_helper(uri)
            expect(status_code).to.equal(200)
            expect(data).to.be.a('table')
            if #data > 0 then
                expect(data[1].author).to.be.a('string')
                expect(data[1].content).to.be.a('string')
                expect(data[1].timestamp).to.be.a('number')
            end
        end)
        -- 200: valid id
        it('testGetValidId', function()
            local id = get_one_valid_id()
            local status_code, data = get_helper(uri .. '/' .. tostring(id))
            expect(status_code).to.equal(200)
            expect(data).to.be.a('table')
        end)
        -- 500: invalid id
        it('testGetInvalidId', function()
            local id = 0 -- never exist
            local status_code, data = get_helper(uri .. '/' .. tostring(id))
            expect(status_code).to.equal(500)
        end)
        -- 200: valid range
        it('testGetPostsInRange', function()
            local status_code, data = get_helper(uri .. '/range?from=2025-01-01&to=2026-01-01')
            expect(status_code).to.equal(200)
            expect(data).to.be.a('table')
            expect(#data).to_not.equal(0)
        end)
        -- 200: still valid but no matches
        it('testGetRangePostsNoMatches', function()
            local status_code, data = get_helper(uri .. '/range?from=2024-01-01&to=2025-01-01')
            expect(status_code).to.equal(200)
            expect(data).to.be.a('table')
            expect(#data).to.equal(0)
        end)
    end)

    describe('TestUpdatePostAPI', function()
        -- 200: valid id
        it('testValidUpdate', function()
            local id = get_one_valid_id()
            local status_code, data = put_helper(id, {
                author = 'Edited',
                content = 'Updated content'
            })
            expect(status_code).to.equal(200)
            expect(data.status).to.equal('Updated')
            expect(data.id).to.equal(id)
        end)
        -- 400: invalid id
        it('testInvalidId', function()
            local id = 'a'
            local status_code, data = put_helper(id, {
                author = 'Edited',
                content = 'Updated content'
            })
            expect(status_code).to.equal(400)
            expect(data.error).to.equal('Invalid post ID')
        end)
        -- 400: invalid schema
        it('testInvalidSchema', function()
            local id = get_one_valid_id()
            local status_code, data = put_helper(id, {
                author = 123,
                content = 'Updated content'
            })
            expect(status_code).to.equal(400)
            expect(data.error).to.contain('Invalid input')
        end)
        -- 404: nonexisting post
        it('testNonexistPost', function()
            local id = 0
            local status_code, data = put_helper(id, {
                author = 'Edited',
                content = 'Updated content'
            })
            expect(status_code).to.equal(404)
            expect(data.error).to.equal('Post not found')
        end)
    end)

    describe('TestDelPostAPI', function()
        local uri = 'http://localhost:' .. PORT .. '/posts'
        -- 404: nonexisting post
        it('testNonexistPost', function()
            local id = 0
            local status_code, data = del_helper(uri .. '/' .. tostring(id))
            expect(status_code).to.equal(404)
            expect(data.error).to.equal('Post not found')
        end)
        -- 400: invalid id
        it('testInvalidId', function()
            local id = 'a'
            local status_code, data = del_helper(uri .. '/' .. tostring(id))
            expect(status_code).to.equal(400)
            expect(data.error).to.equal('Invalid post ID')
        end)
        -- 200: valid
        it('testValidId', function()
            local id = get_one_valid_id()
            local status_code, data = del_helper(uri .. '/' .. tostring(id))
            expect(status_code).to.equal(200)
            expect(data.status).to.equal('Deleted')
            expect(data.id).to.equal(id)
        end)
    end)
    os.remove(DB_PATH)
    os.remove(DB_PATH .. '-shm')
    os.remove(DB_PATH .. '-wal')
    print('TERMINATING THE SERVER')
    -- stop the server instance
    os.exit(0) 
end, 3000)
