settings = {} --settings is a global to allow other lua files access
settings["TabName"] = GetSetting("TabName");
settings["APIUrl"] = GetSetting("APIUrl");
settings["Password"] = GetSetting("APIPassword");
settings["Username"] = GetSetting("APIUsername");
settings["RepoCode"] = GetSetting("RepoCode");

-- Logging needs to precede all but settings to enable supporting libraries to log
globalInterfaceMngr = GetInterfaceManager();
settings["AddonName"] = globalInterfaceMngr.environment.Info.Name;
settings["AddonVersion"] = globalInterfaceMngr.environment.Info.Version;
settings["LogLabel"] = settings.AddonName .. " v" .. settings.AddonVersion;


LogDebug("Launching ASpace Basic Plugin");
LogDebug("Loading Assemblies");
LogDebug("Loading System Data Assembly");
luanet.load_assembly("System");
luanet.load_assembly("System.Data");
luanet.load_assembly("System.Net");
luanet.load_assembly("DevExpress.Data");
luanet.load_assembly("System.Windows.Forms");
luanet.load_assembly("System.Threading.Tasks");
luanet.load_assembly("AtlasSystems.Core");

LogDebug("Loading .NET Types");
Types = {};
Types["System.Data.DataTable"] = luanet.import_type("System.Data.DataTable");
Types["System.Data.DataColumn"] = luanet.import_type("System.Data.DataColumn");
Types["System.Data.DataSet"] = luanet.import_type("System.Data.DataSet");
Types["System.Net.WebClient"] = luanet.import_type("System.Net.WebClient");
Types["DevExpress.Data.ColumnSortOrder"] = luanet.import_type("DevExpress.Data.ColumnSortOrder");
Types["System.Windows.Forms.Control"] = luanet.import_type("System.Windows.Forms.Control");
Types["System.Threading.Tasks.Task"] = luanet.import_type("System.Threading.Tasks.Task");
Types["System.Action"] = luanet.import_type("System.Action");
Types["System.Console"] = luanet.import_type("System.Console");
Types["AtlasSystems.Configuration.Settings"] = luanet.import_type("AtlasSystems.Configuration.Settings");
Types["System.Collections.Specialized.NameValueCollection"] = luanet.import_type("System.Collections.Specialized.NameValueCollection");
Types["System.Text.Encoding"] = luanet.import_type("System.Text.Encoding")


-- LogDebug("Create empty table for buttons");
Buttons = {};

-- LogDebug("Create empty table for ribbons");
Ribbons = {};

--LogDebug("Load additional lua libraries");
require("Helpers");
require("EventHandlers");
require("Grids");
require "Atlas-Addons-Lua-ParseJson.JsonParser"

local form = nil;
local interfaceMngr = nil;

local mySqlGrid = nil;

function Init()

	interfaceMngr = GetInterfaceManager();
	form = interfaceMngr:CreateForm(settings.TabName, settings.TabName);

	settings['sessionID'] = GetSessionId()
	if settings['sessionID'] == nil then
		interfaceMngr:ShowMessage('The session ID for interaction with the API could not be retrieved', 'Network error')
		return
	end
	
	settings["RepoID"] = getRepoId(settings["RepoCode"])

	if settings["RepoID"] == nil or settings["RepoID"] == '' then
		interfaceMngr:ShowMessage('The repository ID could not be retrieved for the current repository code: '.. settings["RepoCode"], 'error')
		return
	end
	
	Ribbons["CN"] = form:CreateRibbonPage("Container Search");

	if (AddonInfo.CurrentForm == "FormRequest") then
		Buttons["CNS-ICaC"] = Ribbons["CN"]:CreateButton("Import Container and Citation", GetClientImage("impt_32x32"), "importContainerAndCitation", "Container Search");
		Buttons["CNS-IC"] = Ribbons["CN"]:CreateButton("Import Container", GetClientImage("impt_32x32"), "importContainer", "Container Search");
		Buttons["CNS-PS"] = Ribbons["CN"]:CreateButton("Perform Search", GetClientImage("srch_32x32"), "containersSearch", "Container Search");
		
		asItemsGrid = form:CreateGrid("MySqlGrid", "ArchivesSpace Results");
		asItemsGrid.GridControl.MainView.OptionsView.ShowGroupPanel = false;

		numberSearchResult = form:CreateTextEdit("NumberSearchResult", "Number of item(s) found:");
		numberSearchResult.ReadOnly = true;
		numberSearchResult.Value = 0

	end

	callNumber = GetFieldValue("Transaction", "CallNumber")
	if callNumber == '' or callNumber == nil then
		-- precedence of the call number for the search over the title
		title = GetFieldValue("Transaction", "ItemTitle")
	end

	--Build the "Request" TextEdit Box
	searchTerm = form:CreateTextEdit("Search", "Call Number");
	searchTerm.Value = callNumber
	searchTerm.Editor.KeyDown:Add(CallNumberSubmitCheck);


	--Add a spot for collection title
	collectionTitle = form:CreateTextEdit("CollectionTitle", "Collection Title");
	if title ~= nil then
		collectionTitle.Value = title
	end
	collectionTitle.Editor.KeyDown:Add(TitleSubmitCheck);

	eadidTerm = form:CreateTextEdit('eadid', "EADID");
	eadidTerm.Editor.KeyDown:Add(EADIDSubmitCheck)


	-- This specifies the layout of the different component of the addon (the grid, the ribbons etc..) the default placement being rather poor.
	form:LoadLayout("layout.xml");

	form:Show();
	local result = nil 
	local searchTypeStr = 'call number'

	if callNumber == nil or callNumber == ''  then
		if title ~= nil and title ~= '' then
			result = getTopContainersByTitle(title)
			searchTypeStr = 'title' 
		else
			searchTypeStr = 'resource'
		end
	else
		result = getTopContainersByCallNumber(callNumber)
	end
	
	local tab = jsonArrayToDataTable(result)

	GetBoxes(tab, searchTypeStr)
end

function containersSearch()

	function isFieldFilled(field) 
		return field.Value ~= '' and field.Value ~= nil 
	end

	titleIsFilled = isFieldFilled(collectionTitle)
	eadIsFilled = isFieldFilled(eadidTerm)
	callIsFilled = isFieldFilled(searchTerm)

	function countIfTrue(cond) 
		if cond then return 1 else return 0 end
	end

	local nField = countIfTrue(titleIsFilled) + countIfTrue(eadIsFilled) + countIfTrue(callIsFilled)
	if nField ~= 1 then
		interfaceMngr:ShowMessage('Only one search field should be filled for containers search', 'Cannot retrieve search results')
		return
	end

	if titleIsFilled then
		performSearch(collectionTitle, 'title')
	elseif eadIsFilled then
		performSearch(eadidTerm, 'ead_id')
	else
		performSearch(searchTerm, 'call number')
	end
end


function getFullResourceById(resourceId)
	local searchResourceReq = 'repositories/' .. settings['RepoID'] .. '/resources/' .. resourceId
	return getElementBySearchQuery(searchResourceReq)
end


function getResourceIdByCallNumber(callNumb)
	results = getResourceByCallNumber(callNumb)
	resource_id = ExtractProperty(results, 'id')
	pathSplit = split(resource_id, '/')
	actual_id = pathSplit[#pathSplit]
	return actual_id

end


function getResourceByCallNumber(callNumb)
	local searchResourceReq = 'repositories/' .. settings['RepoID'] .. '/search?page=1&q=four_part_id:("' .. callNumb .. '")&type[]=resource'
	local res = getElementBySearchQuery(searchResourceReq)

	total_hits = ExtractProperty(res, "total_hits")
	if total_hits == 0 then
		interfaceMngr:ShowMessage('The resource corresponding to the call number"' .. callNumb .. '" could not be found on the database.','Error')
		return nil-- no point in trying to do anything else in such case
	elseif total_hits > 1 then
		LogDebug('Call number search returned ' .. total_hits .. ' results when only 1 should have been returned. The first result will be used')
	end 

	results = ExtractProperty(res, "results")
	return results[1]

end

function getTopContainersByCallNumber(callNumb)
	return getTopContainersBySearchQuery('q=collection:identifier:("'..callNumb..'")')
end


function getTopContainersByTitle(title)
	return getTopContainersBySearchQuery('q=collection:display_string:("'..title..'")')
end

function getTopContainersByEADID(eadid)
	local callNumber = getResourceCallNumberByEADID(eadid)
	return getTopContainersByCallNumber(callNumber)
end

function getTopContainersBySearchQuery(searchQuery)
	local searchResourceReq = 'repositories/' .. settings['RepoID'] .. '/top_containers/search?' .. searchQuery
	local res = getElementBySearchQuery(searchResourceReq)

	-- to reformat
	local response = ExtractProperty(res, "response")
	if response == '' then
		return nil
	end

	local numFound = ExtractProperty(response, "numFound")
	if numFound == '' or numFound < 1 then
		--interfaceMngr:ShowMessage('No top containers were found for this Call Number', 'error')
		return nil
	end
	local docs = ExtractProperty(response, "docs")
	
	return docs
end

function getResourceCallNumberByEADID(eadid)
	local searchResourceReq = 'repositories/' .. settings['RepoID'] .. '/search?page=1&q=eadid:("' .. eadid .. '")&type[]=resource'
	local res = getElementBySearchQuery(searchResourceReq)

	-- to reformat
	local results = ExtractProperty(res, "results")
	if results == '' then
		return nil
	end

	local numFound = ExtractProperty(res, "total_hits")
	if numFound == '' or numFound < 1 then
		return nil
	end
	
	return ExtractProperty(results[1], "identifier")
end

function getElementBySearchQuery(searchQuery)
	local res = ArchivesSpaceGetRequest(settings['sessionID'], searchQuery)
	--LogDebug(res)
	if res == nil then
		interfaceMngr:ShowMessage('could not retrieve search query result', 'error')
		return nil -- no point in trying to do anything else in such case
	elseif res == '412' then
		-- if res was the 412 string, this means the session id expired. A new one will be fetched.
		settings['sessionID'] = GetSessionId()
		return getElementBySearchQuery(searchQuery)
	end
	return res
end

function checkRepoCode()
	repoCode = GetFieldValue("Transaction", "Location");
	if repoCode == nil or repoCode == '' then
		return -- in a hypothetical request with no repo code. 
	end
	if repoCode ~= settings['RepoCode'] then
		interfaceMngr:ShowMessage('You are not authorized to make top containers search on this repository', 'Warning')
		return;
	end
end

function getRepoCode(repoID)
	local searchResourceReq = 'repositories/' .. repoID
	local res = getElementBySearchQuery(searchResourceReq)

	-- to reformat
	return ExtractProperty(res, "repo_code")
end


function getRepoId(repoCode)
	local searchResourceReq = 'repositories'
	local res = getElementBySearchQuery(searchResourceReq)
	for i=1, #res do
		local currRepo = res[i]
		if ExtractProperty(currRepo, 'repo_code') == repoCode then
			local repoUri = split(ExtractProperty(currRepo, 'uri'), '/')
			return repoUri[#repoUri] 
		end
	end
	return nil
end

function setItemNode(itemRow, aeonField, data)
    local success, err = pcall(function()
        itemRow:set_Item(aeonField, data);
    end);

    if success then
    	if data ~= nil then
        	LogDebug('Setting '..aeonField..' to '..data)
        else
        	LogDebug('Setting '..aeonField..' to a nil value')
        end
    else
    	if data ~= nil then
        	LogDebug('Error setting '..aeonField..' to '..data)
        else
        	LogDebug('Error setting '..aeonField)
        end
        LogDebug("Error: ".. err.code);
    end

    return itemRow;
end

function jsonArrayToDataTable(json_arr)
	local asItemTable = Types["System.Data.DataTable"]()

	if json_arr == nil then
		return asItemTable
	end

	asItemTable.Columns:Add("collectionTitle")
	asItemTable.Columns:Add("callNumber")
	asItemTable.Columns:Add("enumeration")
	asItemTable.Columns:Add("item_barcode")
	asItemTable.Columns:Add("location")
	asItemTable.Columns:Add("restrictions")
	asItemTable.Columns:Add("item_id")
	asItemTable.Columns:Add("series")
	asItemTable.Columns:Add("profile")

	-- hidden columns used for the ordering.
	asItemTable.Columns:Add("hidden_container")
	asItemTable.Columns:Add("hidden_indicator")
	

	for i = 1, #json_arr do
		local obj = json_arr[i]
		local row = asItemTable:NewRow()
		
		-- I have been checking all the Call number in ASPace, none of them had a comma.
		setItemNode(row, 'callNumber', split(ExtractProperty(obj, 'title'), ',')[1])

		setItemNode(row, 'collectionTitle', ExtractProperty(obj, 'collection_display_string_u_sstr')[1])


		local jsonString = JsonParser:ParseJSON(ExtractProperty(obj, 'json'))
		
		local indicator = ExtractProperty(jsonString, 'indicator')
		-- old way of extracting the indicator, before I parsed the json string inside the json search result. Left there for historical purpose (and so I can reuse it at another moment if needed)
		--string.match(jsonString, 'indicator\":\"([0-9]+)')
		local containers =  ExtractProperty(obj, 'type_enum_s')
		local container = nil
		if containers ~= nil then
			container = containers[1]
		end

		local typeEnum = nil
		if indicator ~= nil and container ~= nil then
			-- concatenating the indicator with the container type.
			typeEnum = container .. ' ' .. indicator
			if isnumeric(indicator) then
				LogDebug('current indicator'.. indicator)
				-- converting the indicator to a number for ordering purpose.
				indicator = tonumber(indicator)
			end
		else
			typeEnum = container
			-- sor nil is not stored inside the hidden indicator column
			indicator = 0
		end

		setItemNode(row, 'hidden_indicator', indicator)
		setItemNode(row, 'hidden_container', container)
		setItemNode(row, 'enumeration', typeEnum)
		setItemNode(row, 'item_barcode', ExtractProperty(obj, 'barcode_u_sstr')[1])

		-- apparently some locations can be empty!
		setItemNode(row, 'location', ExtractProperty(obj, 'location_display_string_u_sstr')[1])

		-- fetching this information from the 'restricted' field of the json embedded data 
		local restricted = 'N'
		if ExtractProperty(jsonString, 'restricted') then
			restricted = 'Y'
		end
		setItemNode(row, 'restrictions', restricted)
		
		-- all the ids are 
		tcId = split(ExtractProperty(obj, 'id'), '/')
		setItemNode(row, 'item_id', tcId[#tcId])
		asItemTable.Rows:Add(row)

		local seriesArray = ExtractProperty(obj, 'series')
		local seriesStr = ''
		if #seriesArray > 0 then
			for i = 1,#seriesArray do
				seriesStr = seriesStr .. seriesArray[i]
			end 
		end
		setItemNode(row, 'series', seriesStr)

		local profile = ExtractProperty(obj, 'container_profile_display_string_u_sstr')[1]
		setItemNode(row, 'profile', profile)
	end
	return asItemTable
end


function GetBoxes(tab, itemQuery)
		-- itemQuery specify which term was used for the search (call number or title), usefule for outputting the was "not found" message. 
		LogDebug("Retrieving boxes.");
		clearTable(asItemsGrid); --Clear item grid to avoid mixed series/items
		
		numberSearchResult.Value = tab.Rows.Count -- for the user to see the number of search results
		local itemGridControl = asItemsGrid.GridControl;
		if (tab.Rows.Count ~= 0) then
			itemGridControl:BeginUpdate()
			--asItemsGrid.PrimaryTable = tab;
			itemGridControl.DataSource=tab
			itemGridControl:EndUpdate()

			fillItemTable(itemGridControl);
			asItemsGrid.GridControl:Focus();
		else
			noSearchResult(itemGridControl, 'No top containers were found for the current '..itemQuery)
			LogDebug("No results returned from webservice on box search");
		end
end


function importContainer() DoItemImport(false) end

function importContainerAndCitation() DoItemImport(true) end

function DoItemImport(withCitation) --note no ID since even for the event handler the selected row is the one which has been double clicked
	LogDebug("Performing Import")

	LogDebug("Retrieving import row.")
	local itemRow = asItemsGrid.GridControl.MainView:GetFocusedRow()

	if ((itemRow == nil)) then
		LogDebug("No rows selected - aborting")
		return
	end

	local collectionTitle = itemRow:get_Item("collectionTitle")
	local callNumber = itemRow:get_Item("callNumber")
	local itemVolume = itemRow:get_Item("enumeration")
	local barcode = itemRow:get_Item("item_barcode")
	local location = itemRow:get_Item("location")
	local itemInfo1 = itemRow:get_Item("restrictions")
	local series = itemRow:get_Item("series")

	-- Update the item object with the new values.
	function setFieldValueIfNotNil(formName, fieldName, value)
		if value ~= '' and value ~= nil then
			-- this way the empty field won't be highlighted in the import
			SetFieldValue(formName, fieldName, value)
		end 
	end

	LogDebug("Updating the item object.");
	setFieldValueIfNotNil("Transaction", "ItemVolume", itemVolume);
	setFieldValueIfNotNil("Transaction", "ItemNumber", barcode);
	setFieldValueIfNotNil("Transaction", "ItemInfo5", location);
	

	if withCitation then
		setFieldValueIfNotNil("Transaction", "CallNumber", callNumber);
		setFieldValueIfNotNil("Transaction", "ItemCitation", series)
		setFieldValueIfNotNil("Transaction", "ItemTitle", collectionTitle)

		local res = getResourceByCallNumber(callNumber)
		-- a use case for res to be nil: if the resource is actually an accession.
		if res ~= nil then
			local creators = ExtractProperty(res, 'creators') 
			local creator = nil
			if creators ~= nil then
				creator = creators[1]
			end
			setFieldValueIfNotNil("Transaction", "ItemAuthor", creator)
			
			local resourceURL = ExtractProperty(res, 'id')
			local resourceElems = split(resourceURL, '/')
			local repoCode = getRepoCode(resourceElems[2])
			local resourceId = resourceElems[#resourceElems]
			setFieldValueIfNotNil("Transaction", "Location", repoCode)

			local resourceObj = getFullResourceById(resourceId)
			local notes = ExtractProperty(resourceObj, 'notes')
			
			local a_id = extractNoteContent(notes, 'label', 'Alma ID', 'subnotes')
			if a_id == nil then
				a_id = extractNoteContent(notes, 'label', 'Aleph ID', 'subnotes')
			end
			if a_id ~= nil then
				a_id = ExtractProperty(a_id[1], 'content')
			end
			setFieldValueIfNotNil('Transaction', 'ReferenceNumber', a_id)
			
			-- the content of a physical location is an array.
			local physicLocation = extractNoteContent(notes, 'type', 'physloc', 'content')
			if physicLocation ~= nil then
				physicLocation = physicLocation[1]
			end
			setFieldValueIfNotNil('Transaction', 'SubLocation', physicLocation)
		end
	end

	LogDebug("Switching to the detail tab.")
	ExecuteCommand("SwitchTab", {"Detail"})
end

-- Andrew F. Brimmers papers

function extractNoteContent(notesArray, jsonField, fieldValue, toExtract)
	for i = 1, #notesArray do
		local currNote = notesArray[i]
		if currNote[jsonField] == fieldValue then
			return currNote[toExtract]
		end
	end
	return nil
end

-- BELOW ARE ATLAS ASPACE/AEON FUNCTIONS/METHODS
function OnError(e)
    LogDebug("[OnError]");
    if e == nil then
        LogDebug("OnError supplied a nil error");
        return;
    end

    if not e.GetType then
        -- Not a .NET type
        -- Attempt to log value
        pcall(function ()
            LogDebug(e);
        end);
        return;
    else
        if not e.Message then
            LogDebug(e:ToString());
            return;
        end
    end

    local message = TraverseError(e);

    if message == nil then
        message = "Unspecified Error";
    end

    ReportError(message);
    return message
end


-- Recursively logs exception messages and returns the innermost message to caller
function TraverseError(e)
    if not e.GetType then
        -- Not a .NET type
        return nil;
    else
        if not e.Message then
            -- Not a .NET exception
            LogDebug(e:ToString());
            return nil;
        end
    end

    LogDebug(e.Message);

    if e.InnerException then
        return TraverseError(e.InnerException);
    else
        return e.Message;
    end
end

function ReportError(message)
    if (message == nil) then
        message = "Unspecific error";
    end

    LogDebug("An error occurred: " .. message);
    interfaceMngr:ShowMessage("An error occurred:\r\n" .. message, "ArchivesSpace Addon");
end;

function GetSessionId()
    local authentication = GetAuthenticationToken()
    local sessionId = ExtractProperty(authentication, "session")

    if (sessionId == nil or sessionId == JsonParser.NIL or sessionId == '') then
        ReportError("Unable to get valid session ID token.")
        return nil;
    end

    return sessionId;
end

function GetAuthenticationToken()
	local authenticationToken = JsonParser:ParseJSON(SendApiRequest('users/' .. settings.Username .. '/login', 'POST', { ["password"] = settings.Password }));

    if (authenticationToken == nil or authenticationToken == JsonParser.NIL) then
        ReportError("Unable to get valid authentication token.")
        return;
    end

    return authenticationToken
end


function SendApiRequest(apiPath, method, parameters, authToken)
    LogDebug('[SendApiRequest] ' .. method);
    LogDebug('apiPath: ' .. apiPath);

    local webClient = Types["System.Net.WebClient"]();

    local postParameters = Types["System.Collections.Specialized.NameValueCollection"]();
    if (parameters ~= nil) then
        for k, v in pairs(parameters) do
            postParameters:Add(k, v);
        end
    end

    webClient.Headers:Clear();
    if (authToken ~= nil and authToken ~= "") then
        webClient.Headers:Add("X-ArchivesSpace-Session", authToken);
    end

    local success, result;

    if (method == 'POST') then
        success, result = pcall(WebClientPost, webClient, apiPath, postParameters);
    else
        success, result = pcall(WebClientGet, webClient, apiPath);
    end

    if (success) then
        LogDebug("API call successful");

        local utf8Result = Types["System.Text.Encoding"].UTF8:GetString(result);

        LogDebug("Response: " .. utf8Result);
        return utf8Result;
    else
        LogDebug("API call error");
        s = OnError(result);
        -- a message '(412) Precondition Failed' is crafted from OnError if the Session Id was wrong
        -- not the best way to handle this error, but with my knowledge of the Aeon addon API and Lua, it was the most easy solution.
        if string.match(s, '(412)') then
        	return '412'
        end
        return '';
    end
end

function WebClientPost(webClient, apiPath, postParameters)
    return webClient:UploadValues(PathCombine(settings.APIUrl, apiPath), method, postParameters);
end

function WebClientGet(webClient, apiPath)
    return webClient:DownloadData(PathCombine(settings.APIUrl, apiPath));
end


-- Combines two parts of a path, ensuring they're separated by a / character
function PathCombine(path1, path2)
    local trailingSlashPattern = '/$';
    local leadingSlashPattern = '^/';

    if(path1 and path2) then
        local result = path1:gsub(trailingSlashPattern, '') .. '/' .. path2:gsub(leadingSlashPattern, '');
        return result;
    else
        return "";
    end
end

function ArchivesSpaceGetRequest(sessionId, uri)
    local response = nil;

    if sessionId and uri then
        response =  JsonParser:ParseJSON(SendApiRequest(uri, 'GET', nil, sessionId));
    else
        LogDebug("Session ID or URI was nil.")
    end

    if response == nil then
        LogDebug("Could not parse response");
    end

    return response;
end


function ExtractProperty(object, property)
    if object then
        return EmptyStringIfNil(object[property]);
    end
end

function EmptyStringIfNil(value)
    if (value == nil or value == JsonParser.NIL) then
        return "";
    else
        return value;
    end
end