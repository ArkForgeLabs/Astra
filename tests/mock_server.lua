-- mock server for HTTP server testing
local M = {}

function M.create(opts)
    local PORT    = assert(opts.port, "opts.port required")
    local DB_PATH = assert(opts.db_path, "opts.db_path required")

    local server = Astra.http.server:new()
    server.port = PORT

    local db = Astra.database_connect('sqlite', DB_PATH)
    db:execute([[
        CREATE TABLE IF NOT EXISTS posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author TEXT NOT NULL,
            title TEXT,
            content TEXT NOT NULL,
            timestamp INTEGER,
            datetime text
        );
    ]], {});

    server:get("/", function()
        return "hello from default Astra instance!"
    end)

    -- posts
    -- GET all posts
    server:get('/posts', function(_, res)
        local ok, result = pcall(function()
            return db:query_all('SELECT * FROM posts ORDER BY timestamp DESC', {})
        end)
        if not ok then
            res:set_status_code(500)
            return { error = 'Failed to fetch posts.' }
        end
        return result
    end)

    -- GET posts by id
    server:get('/posts/{id}', function(req, res)
        local uri = req:uri()
        local id = tonumber(string.match(uri, '^/posts/(%d+)$'))
        local ok, result = pcall(function()
            return db:query_one('SELECT * FROM posts WHERE id = $1', {id})
        end)
        if not ok then
            res:set_status_code(500)
            return { error = 'Failed to fetch posts.' }
        end
        return result
    end)

    -- GET posts by daterange
    server:get('/posts/range', function(req, res)
        local queries = req:queries()
        local from_str = queries.from
        local to_str = queries.to

        local function text2timestamp(dt_str, eod)
            local year, month, day = dt_str:match("(%d+)%-(%d+)%-(%d+)")
            year = tonumber(year)
            month = tonumber(month)
            day = tonumber(day)
            local dt
            if eod == true then 
                dt = Astra.datetime.new(year, month, day, 23, 59, 59.999)
            else
                dt = Astra.datetime.new(year, month, day, 0, 0, 0)
            end
            return dt:get_epoch_milliseconds()
        end

        local from_ts = text2timestamp(from_str)
        local to_ts = text2timestamp(to_str, true)

        local ok, result = pcall(function()
            return db:query_all([[
                SELECT * FROM posts
                WHERE timestamp BETWEEN $1 AND $2
                ORDER BY timestamp DESC
            ]], { from_ts, to_ts })
        end)
        if not ok then
            res:set_status_code(500)
            return { error = 'Failed to fetch posts.' }
        end
        return result
    end)

    -- POST post
    server:post('/posts', function(req, res)
        local data = req:body():json()
        -- schema validation
        local schema = {
            author = { type = 'string' },
            title = { type = 'string', required = false },
            content = { type = 'string' },
        }
        local is_valid, err = Astra.validate_table(data, schema)
        if not is_valid then
            res:set_status_code(400)
            return { error = 'Invalid input: ' .. tostring(err) }
        end
        -- post
        local dt_now = Astra.datetime.new()
        local timestamp = dt_now:get_epoch_milliseconds()
        local datetime = dt_now:to_locale_datetime_string()
        db:execute([[
            INSERT INTO posts (author, title, content, timestamp, datetime)
            VALUES ($1, $2, $3, $4, $5);
        ]], { data.author, data.title, data.content, timestamp, datetime });
        res:set_status_code(200)
        return { status = 'created' }

    end)

    -- PUT post (by id)
    server:put('/posts/{id}', function(req, res)
        local uri = req:uri()
        local id = tonumber(string.match(uri, '^/posts/(%d+)$'))
        if not id then
            res:set_status_code(400)
            return { error = 'Invalid post ID' }
        end
        local data = req:body():json()
        -- schema validation
        local schema = {
            author = { type = 'string' },
            content = { type = 'string' },
        }
        local is_valid, err = Astra.validate_table(data, schema)
        if not is_valid then
            res:set_status_code(400)
            return { error = 'Invalid input: ' .. tostring(err) }
        end
        -- existence check
        local ok, post = pcall(function()
            return db:query_one('SELECT 1 FROM posts WHERE id = $1', {id})
        end)
        if not ok or not post then
            res:set_status_code(404)
            return { error = 'Post not found' }
        end
        -- update, pad the authors
        local ok, _ = pcall(function()
            return db:execute([[
                UPDATE posts
                SET 
                    author = author || $1,
                    content = $2
                WHERE id = $3
            ]], {', ' .. data.author, data.content, id})
        end)
        if not ok then
            res:set_status_code(500)
            return { error = 'Failed to update post' }
        end
        res:set_status_code(200)
        return { status = 'Updated', id = id }
    end)

    -- DEL post
    server:delete('/posts/{id}', function(req, res)
        local uri = req:uri()
        local id = tonumber(string.match(uri, '^/posts/(%d+)$'))
        if not id then
            res:set_status_code(400)
            return { error = 'Invalid post ID' }
        end
        -- existence check
        local ok, post = pcall(function()
            return db:query_one('SELECT 1 FROM posts WHERE id = $1', {id})
        end)
        if not ok or not post then
            res:set_status_code(404)
            return { error = 'Post not found' }
        end
        -- deletion
        local ok, _ = pcall(function()
            return db:execute([[
                DELETE FROM posts
                WHERE id = $1
            ]], { id })
        end)
        if not ok then
            res:set_status_code(500)
            return { error = 'Failed to delete post' }
        end
        res:set_status_code(200)
        return { status = 'Deleted', id = id }
    end)

    return server
end

return M