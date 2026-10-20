--!nonstrict
-- Lists assigned issues, and searches Redmine by title or ticket number.

local client = require("./client.luau")

local mode = "assigned"
local searchResult = nil
local generation = 0
local render

local function openIssue(href)
  noctalia.runAsync({ "xdg-open", href }, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError(noctalia.tr("title"), noctalia.tr("open_failed"))
    end
  end)
end

local function issueButton(issue)
  local href = issue.href
  local meta = issue.project
  if issue.status ~= "" then
    meta = meta == "" and issue.status or `{meta} · {issue.status}`
  end
  local props = {
    text = `#{issue.id} {issue.subject}`,
    variant = "ghost",
    contentAlign = "start",
    onClick = function()
      openIssue(href)
    end,
  }
  if meta ~= "" then
    props.tooltip = meta
  end
  return ui.button(props)
end

local function subjectFromTitle(title)
  return title:match("^Issue #%d+ %b():%s*(.+)$")
    or title:match("^Issue #%d+:%s*(.+)$")
    or title
end

local function statusFromTitle(title)
  local paren = title:match("^Issue #%d+ (%b())")
  if paren == nil then
    return ""
  end
  return paren:sub(2, -2)
end

local function rowsFromSearch(decoded, base)
  local rows = {}
  if type(decoded.results) ~= "table" then
    return rows
  end
  for _, result in ipairs(decoded.results) do
    if type(result) == "table" and type(result.id) == "number" and type(result.type) == "string" and result.type:find("^issue") == 1 then
      local title = type(result.title) == "string" and result.title or ""
      local href = type(result.url) == "string" and result.url or `{base}/issues/{result.id}`
      table.insert(rows, {
        id = result.id,
        subject = subjectFromTitle(title),
        project = "",
        status = statusFromTitle(title),
        href = href,
      })
    end
  end
  return rows
end

local function httpJson(path, gen, cb)
  local req, errKey = client.endpoint(path)
  if req == nil then
    cb(errKey, nil, 0, nil, nil)
    return
  end
  local started = noctalia.http({ url = req.url, headers = req.headers }, function(res)
    if gen ~= generation then
      return
    end
    if not res.ok then
      cb("offline", nil, 0, nil, req.base)
    elseif res.status ~= 200 then
      cb(nil, nil, res.status, nil, req.base)
    else
      local decoded, decodeErr = noctalia.json.decode(res.body)
      if type(decoded) ~= "table" then
        noctalia.log(decodeErr or "invalid json")
        cb("bad_json", nil, res.status, nil, req.base)
      else
        cb(nil, nil, res.status, decoded, req.base)
      end
    end
  end)
  if not started then
    cb("offline", nil, 0, nil, req.base)
  end
end

local function runSearch(raw)
  local query = noctalia.string.trim(raw)
  generation += 1
  local gen = generation
  if query == "" then
    mode = "assigned"
    searchResult = nil
    render()
    return
  end

  mode = "search"
  searchResult = { loading = true, query = query }
  render()

  local ticketId = query:match("^#(%d+)$") or query:match("^(%d+)$")
  local left = 0
  local exact = nil
  local found = {}
  local errorKey = nil
  local errorArgs = nil

  local function finish()
    if gen ~= generation then
      return
    end
    left -= 1
    if left > 0 then
      return
    end
    local issues = {}
    if exact ~= nil then
      table.insert(issues, exact)
    end
    for _, row in ipairs(found) do
      if exact == nil or row.id ~= exact.id then
        table.insert(issues, row)
      end
    end
    if #issues == 0 and errorKey ~= nil then
      searchResult = { error = errorKey, errorArgs = errorArgs, query = query }
    else
      searchResult = { issues = issues, query = query }
    end
    render()
  end

  local function noteError(key, args)
    if errorKey == nil then
      errorKey = key
      errorArgs = args
    end
  end

  local function track(path, handler)
    left += 1
    httpJson(path, gen, function(key, args, status, decoded, base)
      if gen ~= generation then
        return
      end
      handler(key, args, status, decoded, base)
      finish()
    end)
  end

  if ticketId ~= nil then
    track(`/issues/{ticketId}.json`, function(key, args, status, decoded, base)
      if key ~= nil then
        noteError(key, args)
      elseif status == 200 and type(decoded) == "table" then
        exact = client.issueRow(decoded.issue, base)
      elseif status ~= 404 then
        noteError("http_error", { status = status })
      end
    end)
  end

  -- shortcut: first 20 title matches, no paging; raise the limit if a longer list is needed.
  local q = noctalia.string.urlEncode(query)
  track(
    `/search.json?q={q}&issues=1&titles_only=1&scope=all&limit=20`,
    function(key, args, status, decoded, base)
      if key ~= nil then
        noteError(key, args)
      elseif status ~= 200 then
        noteError("http_error", { status = status })
      else
        found = rowsFromSearch(decoded, base)
      end
    end
  )
end

function render()
  local snap = noctalia.state.get("issues")
  local header = {
    ui.label({
      text = noctalia.tr("title"),
      fontSize = 16,
      fontWeight = "bold",
      color = "on_surface",
      flexGrow = 1,
    }),
  }
  if noctalia.getSetting("shell.show_close_buttons") ~= false then
    table.insert(header, ui.button({
      glyph = "close",
      variant = "ghost",
      onClick = function()
        panel.close()
      end,
    }))
  end

  local body = {}
  if mode == "search" then
    if searchResult == nil or searchResult.loading then
      table.insert(body, ui.label({ text = noctalia.tr("searching"), color = "on_surface_variant" }))
    elseif searchResult.error ~= nil then
      table.insert(body, ui.label({
        text = noctalia.tr(searchResult.error, searchResult.errorArgs),
        color = "on_surface",
      }))
    elseif searchResult.issues == nil or #searchResult.issues == 0 then
      table.insert(body, ui.label({ text = noctalia.tr("no_matches"), color = "on_surface_variant" }))
    else
      for _, issue in ipairs(searchResult.issues) do
        table.insert(body, issueButton(issue))
      end
    end
  elseif snap == nil then
    table.insert(body, ui.label({ text = noctalia.tr("loading"), color = "on_surface_variant" }))
  elseif snap.error ~= nil then
    table.insert(body, ui.label({ text = noctalia.tr(snap.error, snap.errorArgs), color = "on_surface" }))
    if snap.error == "unconfigured" or snap.error == "bad_url" or snap.error == "bad_key" then
      table.insert(body, ui.button({
        text = noctalia.tr("open_settings"),
        onClick = function()
          noctalia.openSettings()
        end,
      }))
    end
  elseif #snap.issues == 0 then
    table.insert(body, ui.label({ text = noctalia.tr("empty"), color = "on_surface_variant" }))
  else
    if snap.total > #snap.issues then
      table.insert(body, ui.label({
        text = noctalia.tr("showing", { shown = #snap.issues, total = snap.total }),
        color = "on_surface_variant",
      }))
    end
    for _, issue in ipairs(snap.issues) do
      table.insert(body, issueButton(issue))
    end
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, header),
    ui.input({
      key = "search",
      placeholder = noctalia.tr("search_placeholder"),
      onChange = function(value)
        if noctalia.string.trim(value) == "" and mode == "search" then
          generation += 1
          mode = "assigned"
          searchResult = nil
          render()
        end
      end,
      onSubmit = function(value)
        runSearch(value)
      end,
    }),
    ui.scroll({ flexGrow = 1, gap = 8 }, body),
  }))
end

noctalia.state.watch("issues", function()
  render()
end)

function onOpen()
  render()
end
