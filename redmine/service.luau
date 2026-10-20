--!nonstrict
-- Polls open issues assigned to the API user and publishes them on
-- noctalia.state "issues" for the bar widget and the panel.

local client = require("./client.luau")

-- shortcut: first 20 open issues, every 60s; raise LIMIT or shorten the interval if that is too coarse.
local LIMIT = 20
local INTERVAL_MS = 60000

noctalia.setUpdateInterval(INTERVAL_MS)

local busy = false
local dirty = false

local function publish(snapshot)
  noctalia.state.set("issues", snapshot)
end

local function fail(key, args)
  publish({ total = 0, issues = {}, error = key, errorArgs = args })
end

local function parseIssues(decoded, base)
  local issues = {}
  if type(decoded.issues) == "table" then
    for _, issue in ipairs(decoded.issues) do
      local row = client.issueRow(issue, base)
      if row ~= nil then
        table.insert(issues, row)
      end
    end
  end
  local total = decoded.total_count
  if type(total) ~= "number" then
    total = #issues
  end
  return { total = total, issues = issues, error = nil }
end

local function fetch()
  local req, err = client.endpoint(
    `/issues.json?assigned_to_id=me&status_id=open&limit={LIMIT}&sort=updated_on:desc`
  )
  if req == nil then
    fail(err)
    return
  end
  if busy then
    dirty = true
    return
  end
  busy = true

  local started = noctalia.http(req, function(res)
    busy = false
    if not res.ok then
      fail("offline")
    elseif res.status ~= 200 then
      fail("http_error", { status = res.status })
    else
      local decoded, decodeErr = noctalia.json.decode(res.body)
      if type(decoded) ~= "table" then
        noctalia.log(decodeErr or "invalid json")
        fail("bad_json")
      else
        publish(parseIssues(decoded, req.base))
      end
    end
    if dirty then
      dirty = false
      fetch()
    end
  end)

  if not started then
    busy = false
    fail("offline")
    if dirty then
      dirty = false
      fetch()
    end
  end
end

function update()
  fetch()
end

function onConfigChanged()
  fetch()
end

fetch()
