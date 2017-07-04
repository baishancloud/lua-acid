local _M = { _VERSION = '1.0' }

local ngx = ngx

local function ph(val)
    if val == nil then
        return '-'
    elseif type(val) == 'number' then
        if val % 1 == 0 then
            return tostring(val)
        else
            return string.format('%.3f', val)
        end
    else
        return tostring(val)
    end
end


local function addfield(tbl, str, fld, sep)
    if fld ~= nil then
        table.insert(tbl, str)
        table.insert(tbl, ph(fld))
        if sep then
            table.insert(tbl, sep)
        end
    end
end


function _M.new_entry(service_key, opt)

    opt = opt or {}

    local now = ngx.now()
    local begin_process = ngx.req.start_time()

    local e = {

        service_key = service_key,
        added = false,

        begin_process = begin_process,

        start_in_req = now - begin_process,

        -- start time of conn, send or recv
        start = now,

        -- to other service
        upstream = {
            time = {
                -- conn = nil,
                -- send = nil,
                -- sendbody = nil,
                -- recv = nil,
                -- recvbody = nil,
            },
            byte = {
                -- send = nil,
                -- sendbody = nil,
                -- recv = nil,
                -- recvbody = nil,
            },
        },

        -- to client.
        -- presents if this log is for a piping rpc.
        -- for downstream, time.conn is meaningless, and it should always be
        -- nil.
        downstream = {
            time = {
                -- conn = nil,
                -- send = nil,
                -- sendbody = nil,
                -- recv = nil,
                -- recvbody = nil,
            },
            byte = {
                -- send = nil,
                -- sendbody = nil,
                -- recv = nil,
                -- recvbody = nil,
            },
        },
    }

    e.scheme = opt.scheme
    e.ip = opt.ip
    e.port = opt.port
    e.uri = opt.uri
    e.status = opt.status
    e.err = opt.err
    e.range = opt.range

    e.upstream = opt.upstream or e.upstream
    e.downstream = opt.downstream or e.downstream

    return e
end


function _M.reset_start(entry)
    if entry == nil then
        return
    end
    entry.start = ngx.now()
end

function _M.set_time(entry, updown, field)

    if entry == nil then
        return
    end

    local now = ngx.now()
    entry[updown].time[field] = now - entry.start

    entry.start = now
end

function _M.set_time_val(entry, updown, field, val)

    if entry == nil then
        return
    end

    entry[updown].time[field] = val
end


function _M.incr_stat(entry, updown, field, size)
    _M.incr_time(entry, updown, field)
    _M.incr_byte(entry, updown, field, size)
end


function _M.incr_time(entry, updown, field)

    if entry == nil then
        return
    end

    local now = ngx.now()
    local prev = entry[updown].time[field] or 0
    entry[updown].time[field] = prev + now - entry.start

    entry.start = now
end


function _M.incr_byte(entry, updown, field, size)

    if entry == nil then
        return
    end

    if size == 0 then
        return
    end

    local prev = entry[updown].byte[field] or 0
    entry[updown].byte[field] = prev + size
end


function _M.set_err(entry, err)
    if entry == nil then
        return
    end

    if err == nil then
        entry.err = nil
        return
    end

    _M.end_entry(entry, {err = err})
end


function _M.set_status(entry, status)
    if entry == nil then
        return
    end
    entry.status = status
end


function _M.end_entry(e, opt)
    if e == nil then
        return
    end

    opt = opt or {}
    e.err = opt.err
    e.status = opt.status

    _M.add_log(e)
end


function _M.add_log(entry)

    if entry == nil then
        return
    end

    if entry.added then
        return
    end

    local logs = ngx.ctx.rpc_logs
    if logs == nil then
        ngx.ctx.rpc_logs = {}
        logs = ngx.ctx.rpc_logs
    end

    table.insert(logs, entry)
    entry.added = true
end


function _M.get_logs()
    return ngx.ctx.rpc_logs or {}
end


function _M.log_str(logs)

    logs = logs or ngx.ctx.rpc_logs or {}

    local s = {}
    for _, e in ipairs(logs) do
        table.insert( s, _M.entry_str(e))
    end

    return table.concat( s, ' ' )
end


function _M.entry_str(e)
    local rng = e.range

    local s = { ph(e.service_key), }
    addfield(s, ',status:', e.status)
    addfield(s, ',err:', e.err)
    addfield(s, ',url:', '')
    addfield(s, '', e.scheme, '://')
    addfield(s, '', e.ip)
    addfield(s, ':', e.port)
    addfield(s, '', e.uri)

    if rng ~= nil then
        table.insert(s, ',range:[' .. ph(rng.from) .. ',' .. ph(rng.to) .. ')')
    end

    addfield(s, ',sent:', e.sent)

    addfield(s, ',start_in_req:', e.start_in_req)

    local up = e.upstream
    if up then

        addfield(s, ',upstream:{', '')
        local st

        st = up.time
        if st then
            addfield(s, 'time:{', '')
            addfield(s, 'conn:', st.conn, ',')
            addfield(s, 'send:', st.send, ',')
            addfield(s, 'sendbody:', st.sendbody, ',')
            addfield(s, 'recv:', st.recv, ',')
            addfield(s, 'recvbody:', st.recvbody)
            addfield(s, '},', '')
        end

        st = up.byte
        if st then
            addfield(s, 'byte:{', '')
            addfield(s, 'send:', st.send, ',')
            addfield(s, 'sendbody:', st.sendbody, ',')
            addfield(s, 'recv:', st.recv, ',')
            addfield(s, 'recvbody:', st.recvbody)
            addfield(s, '},', '')
        end

        addfield(s, '}', '')

    end

    local down = e.downstream
    if down then

        addfield(s, ',downstream:{', '')
        local st

        st = down.time
        if st then
            addfield(s, 'time:{', '')
            addfield(s, 'conn:', st.conn, ',')
            addfield(s, 'send:', st.send, ',')
            addfield(s, 'sendbody:', st.sendbody, ',')
            addfield(s, 'recv:', st.recv, ',')
            addfield(s, 'recvbody:', st.recvbody)
            addfield(s, '},', '')
        end

        st = down.byte
        if st then
            addfield(s, 'byte:{', '')
            addfield(s, 'send:', st.send, ',')
            addfield(s, 'sendbody:', st.sendbody, ',')
            addfield(s, 'recv:', st.recv, ',')
            addfield(s, 'recvbody:', st.recvbody)
            addfield(s, '},', '')
        end

        addfield(s, '}', '')

    end
    return table.concat(s)
end
return _M
