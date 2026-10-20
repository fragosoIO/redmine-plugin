--!nonstrict
-- Shared Redmine URL, API key, and issue-row shape.

local M = {}

local function fieldName(value)
  if type(value) == "table" and type(value.name) == "string" then
    return value.name
  end
  return ""
end

-- pathAndQuery starts with "/". Returns a request table, or nil and an error key.
function M.endpoint(pathAndQuery)
  local raw = noctalia.string.trim(noctalia.getConfig("url") or "")
  raw = raw:gsub("/+$", "")
  if raw == "" then
    return nil, "unconfigured"
  end
  if raw:match("^https?://") == nil then
    return nil, "bad_url"
  end
  local key = noctalia.string.trim(noctalia.getConfig("api_key") or "")
  if key:find("[\r\n]") ~= nil then
    return nil, "bad_key"
  end
  local headers = nil
  if key ~= "" then
    headers = { "X-Redmine-API-Key: " .. key }
  end
  return { url = raw .. pathAndQuery, headers = headers, base = raw }, nil
end

function M.issueRow(issue, base)
  if type(issue) ~= "table" or type(issue.id) ~= "number" then
    return nil
  end
  return {
    id = issue.id,
    subject = type(issue.subject) == "string" and issue.subject or "",
    project = fieldName(issue.project),
    status = fieldName(issue.status),
    href = `{base}/issues/{issue.id}`,
  }
end

return M
