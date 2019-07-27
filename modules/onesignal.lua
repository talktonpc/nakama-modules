--[[
  Copyright 2017 The Nakama Authors

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]--

local nk = require("nakama")

--[[
  A module which implements the OneSignal REST API for push messages.
]]--

local MODULE_VERSION = "0.1.0"
local SDK_VERSION = ("nakama-onesignal/%s"):format(MODULE_VERSION)
local BASE_URL = "https://onesignal.com/api/v1"
local BASE_HEADERS = {
  ["Accept"] = "application/json",
  ["Content-Type"] = "application/json"
}
local HTTP_REQUEST = nk.http_request

local onesignal = {}

local onesignal_mt = {
  __name = "onesignal_object",
  __index = onesignal
}

local function table_merge(first, second)
  for _, v in ipairs(second)
  do
    table.insert(first, v)
  end

  for k, v in pairs(second)
  do
    first[k] = v
  end

  return first
end

--[[
  Display OneSignal "object" in a readable way when printed.
]]--
function onesignal:__tostring()
  return ("onesignal{apikey=%q, appid=%q}"):format(self.apikey, self.appid)
end

--[[
  Register a new device with OneSignal.
]]--
function onesignal:add_device(device_type, identifier, language, tags, params)
  local url = ("%s/players"):format(BASE_URL)
  local method = "POST"
  local headers = table_merge({
    ["Authorization"] = self.auth_header_val
  }, BASE_HEADERS)
  local content = table_merge({
    app_id = self.appid,       -- required
    device_type = device_type, -- required
    identifier = identifier,
    language = language or "en",
    sdk = SDK_VERSION,
    tags = tags
  }, params or {})
  local json = nk.json_encode(content)
  local success, code, _, resp = pcall(HTTP_REQUEST, url, method, headers, json)
  if (not success) then
    nk.logger_error(("Failed %q"):format(code))
    error(code)
  elseif (code >= 400) then
    nk.logger_error(("Failed %q %q"):format(code, resp))
    error(resp)
  else
    nk.logger_info(("Success %q %q"):format(code, resp))
    -- resp -> {"success": true, "id": "ffffb794-ba37-11e3-8077-031d62f86ebf"}
    return nk.json_decode(resp)
  end
end

--[[
  Update an existing device within a OneSignal app.
]]--
function onesignal:edit_device(device_id, identifier, language, tags, params)
  local url = ("%s/players/%s"):format(BASE_URL, device_id)
  local method = "PUT"
  local headers = table_merge({
    ["Authorization"] = self.auth_header_val
  }, BASE_HEADERS)
  local content = table_merge({
    app_id = self.appid,       -- required
    identifier = identifier,
    language = language or "en",
    sdk = SDK_VERSION,
    tags = tags
  }, params or {})
  local json = nk.json_encode(content)
  local success, code, _, resp = pcall(HTTP_REQUEST, url, method, headers, json)
  if (not success) then
    nk.logger_error(("Failed %q"):format(code))
    error(code)
  elseif (code >= 400) then
    nk.logger_error(("Failed %q %q"):format(code, resp))
    error(resp)
  else
    nk.logger_info(("Success %q %q"):format(code, resp))
    -- resp -> {"success": true, "id": "ffffb794-ba37-11e3-8077-031d62f86ebf"}
    return nk.json_decode(resp)
  end
end

--[[
  Report a new session is active for the {@code player_id}.
]]--
function onesignal:new_session(player_id, identifier, language, tags, params)
  local url = ("%s/players/%s/on_session"):format(BASE_URL, player_id)
  local method = "POST"
  local headers = table_merge({
    ["Authorization"] = self.auth_header_val
  }, BASE_HEADERS)
  local content = table_merge({
    identifier = identifier,
    language = language or "en",
    sdk = SDK_VERSION,
    tags = tags
  }, params or {})
  local json = nk.json_encode(content)
  local success, code, _, resp = pcall(HTTP_REQUEST, url, method, headers, json)
  if (not success) then
    nk.logger_error(("Failed %q"):format(code))
    error(code)
  elseif (code >= 400) then
    nk.logger_error(("Failed %q %q"):format(code, resp))
    error(resp)
  else
    nk.logger_info(("Success %q %q"):format(code, resp))
    -- resp -> {"success": true}
    return nk.json_decode(resp)
  end
end

--[[
  Create a notification which can be sent to a segment or individual users.
]]--
function onesignal:create_notification(contents, headings, included_segments, filters, player_ids, params)
  if (not included_segments and not filters and not player_ids) then
    error("Must have at least one of 'included_segments', 'filters', or 'player_ids' parameters.")
  end
  if (included_segments and #included_segments < 1) then
    error("'included_segments' param must have at least one value.")
  end
  if (filters and #filters < 1) then
    error("'filters' param must have at least one value.")
  end
  if (player_ids and #player_ids < 1) then
    error("'player_ids' param must have at least one value.")
  end

  local url = ("%s/notifications"):format(BASE_URL)
  local method = "POST"
  local headers = table_merge({
    ["Authorization"] = self.auth_header_val
  }, BASE_HEADERS)
  local content = {
    app_id = self.appid,       -- required
    contents = contents or {},
    headings = headings or {}
  }
  if (included_segments) then
    content.included_segments = included_segments
  end
  if (filters) then
    content.filters = filters
  end
  if (player_ids) then
    content.included_player_ids = player_ids
  end
  content = table_merge(content, params or {})
  local json = nk.json_encode(content)
  local success, code, _, resp = pcall(HTTP_REQUEST, url, method, headers, json)
  if (not success) then
    nk.logger_error(("Failed %q"):format(code))
    error(code)
  elseif (code >= 400) then
    nk.logger_error(("Failed %q %q"):format(code, resp))
    error(resp)
  else
    nk.logger_info(("Success %q %q"):format(code, resp))
    -- resp -> {"id": "458dcec4-cf53-11e3-add2-000c2940e62c", "recipients": 3}
    return nk.json_decode(resp)
  end
end

--[[
  Stop a scheduled or currently outgoing notification.
]]--
function onesignal:cancel_notification(notification_id)
  local url = ("%s/notifications/%s?app_id=%s"):format(BASE_URL, notification_id, self.appid)
  local method = "DELETE"
  local headers = table_merge({
    ["Authorization"] = self.auth_header_val
  }, BASE_HEADERS)
  local success, code, _, resp = pcall(HTTP_REQUEST, url, method, headers, nil)
  if (not success) then
    nk.logger_error(("Failed %q"):format(code))
    error(code)
  elseif (code >= 400) then
    nk.logger_error(("Failed %q %q"):format(code, resp))
    error(resp)
  else
    nk.logger_info(("Success %q %q"):format(code, resp))
    -- resp -> {'success': "true"}
    return nk.json_decode(resp)
  end
end

--[[
  Build a new OneSignal "object".
]]--
local function new_onesignal(apikey, appid)
  apikey = apikey or "mustsetapikey"
  local self = setmetatable({
    apikey = apikey,
    appid = appid or "mustsetappid",
    auth_header_val = ("Basic %s"):format(apikey)
  }, onesignal_mt)
  return self
end

return {
  new = new_onesignal;
}
