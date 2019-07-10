function OnError(e)
    LogDebug("[OnError]") 
    if e == nil then
        LogDebug("OnError supplied a nil error") 
        return 
    end

    if not e.GetType then
        -- Not a .NET type
        -- Attempt to log value
        pcall(function ()
            LogDebug(e) 
        end) 
        return 
    else
        if not e.Message then
            LogDebug(e:ToString()) 
            return 
        end
    end

    local message = TraverseError(e) 

    if message == nil then
        message = "Unspecified Error" 
    end
    ReportError(message) 
    return message
end


-- Recursively logs exception messages and returns the innermost message to caller
function TraverseError(e)
    if not e.GetType then
        -- Not a .NET type
        return nil 
    else
        if not e.Message then
            -- Not a .NET exception
            LogDebug(e:ToString()) 
            return nil 
        end
    end

    LogDebug(e.Message) 

    if e.InnerException then
        return TraverseError(e.InnerException) 
    else
        return e.Message 
    end
end

function ReportError(message)
    if (message == nil) then
        message = "Unspecific error" 
    end

    LogDebug("An error occurred: " .. message) 
    interfaceMngr:ShowMessage("An error occurred:\r\n" .. message, "ArchivesSpace Addon") 
end 

function GetSessionId()
    local authentication = GetAuthenticationToken()
    local sessionId = nil
    if authentication ~= JsonParser.NIL then
        sessionId = ExtractProperty(authentication, "session")
    end

    if (sessionId == nil or sessionId == '') then
        ReportError("Unable to get valid session ID token.")
        return nil 
    end

    return sessionId 
end

function GetAuthenticationToken()
	local authenticationToken = JsonParser:ParseJSON(SendApiRequest('users/' .. settings.Username .. '/login', 'POST', { ["password"] = settings.Password })) 

    if (authenticationToken == nil) then
        ReportError("Unable to get valid authentication token.")
        return 
    elseif (authenticationToken == JsonParser.NIL) then
        ReportError("The server took too much time to answer. Please check whether any firewall is blocking communication to archivesspace.")
        return
    end


    return authenticationToken
end


function SendApiRequest(apiPath, method, parameters, authToken)
    LogDebug('[SendApiRequest] ' .. method) 
    LogDebug('apiPath: ' .. apiPath) 

    local webClient = Types["System.Net.WebClient"]() 

    local postParameters = Types["System.Collections.Specialized.NameValueCollection"]() 
    if (parameters ~= nil) then
        for k, v in pairs(parameters) do
            postParameters:Add(k, v) 
        end
    end

    webClient.Headers:Clear() 
    if (authToken ~= nil and authToken ~= "") then
        webClient.Headers:Add("X-ArchivesSpace-Session", authToken) 
    end

    local success, result 

    if (method == 'POST') then
        success, result = pcall(WebClientPost, webClient, apiPath, postParameters) 
    else
        success, result = pcall(WebClientGet, webClient, apiPath) 
    end

    if (success) then
        LogDebug("API call successful") 

        local utf8Result = Types["System.Text.Encoding"].UTF8:GetString(result) 

        return utf8Result 
    else
        LogDebug("API call error") 
        HTTPErrorCode = ExtractHTTPErrorCode(result.innerException:ToString())
        if HTTPErrorCode == '403' or HTTPErrorCode == '404' or HTTPErrorCode == '412' then
            return '{"httpErrorCode":'..HTTPErrorCode..'}'
        else 
	       OnError(result) 
           return nil 
        end
    end
end

function ExtractHTTPErrorCode(innerException) 
    extractCodePattern = '%((%d+)%)' -- this will extract an integer contained between an open and closing parenthesis.
    --.NET will internalise the exception as 
    return string.match(innerException, extractCodePattern)
end

function WebClientPost(webClient, apiPath, postParameters)
    return webClient:UploadValues(PathCombine(settings.APIUrl, apiPath), method, postParameters) 
end

function WebClientGet(webClient, apiPath)
    return webClient:DownloadData(PathCombine(settings.APIUrl, apiPath)) 
end


-- source: https://github.com/gordonbrander/lettersmith/blob/master/lettersmith/path_utils.lua
function removeTrailingSlash(s)
  -- Remove trailing slash from string. Will not remove slash if it is the
  -- only character in the string.
  return s:gsub('(.)%/$', '%1')
end


-- Combines two parts of a path, ensuring they're separated by a / character
function PathCombine(path1, path2)
    local trailingSlashPattern = '/$' 
    local leadingSlashPattern = '^/' 

    if(path1 and path2) then
        local result = path1:gsub(trailingSlashPattern, '') .. '/' .. path2:gsub(leadingSlashPattern, '') 
        return result 
    else
        return "" 
    end
end

function ArchivesSpaceGetRequest(sessionId, uri)
    local response = nil 

    if sessionId and uri then
        response =  JsonParser:ParseJSON(SendApiRequest(uri, 'GET', nil, sessionId)) 
    else
        LogDebug("Session ID or URI was nil.")
    end

    if response == nil then
        LogDebug("Could not parse response") 
    end

    return response 
end