settings = {} --settings is a global to allow other lua files access
settings["TabName"] = GetSetting("TabName") 
settings["APIUrl"] = GetSetting("APIUrl") 
settings["Password"] = GetSetting("APIPassword") 
settings["Username"] = GetSetting("APIUsername") 
settings["RepoCode"] = GetSetting("RepoCode") 

-- Logging needs to precede all but settings to enable supporting libraries to log
InterfaceMngr = GetInterfaceManager() 
settings["AddonName"] = InterfaceMngr.Environment.Info.Name 
settings["AddonVersion"] = InterfaceMngr.Environment.Info.Version 
settings["LogLabel"] = settings.AddonName .. " v" .. settings.AddonVersion 

LogDebug("Launching ASpace Basic Plugin") 
LogDebug("Loading Assemblies") 
LogDebug("Loading System Data Assembly") 

luanet.load_assembly("System") 
luanet.load_assembly("System.Data") 
luanet.load_assembly("System.Net") 

LogDebug("Loading .NET Types") 
Types = {} 
Types["System.Data.DataTable"] = luanet.import_type("System.Data.DataTable") 
Types["System.Data.DataColumn"] = luanet.import_type("System.Data.DataColumn") 
Types["System.Net.WebClient"] = luanet.import_type("System.Net.WebClient") 
Types["System.Collections.Specialized.NameValueCollection"] = luanet.import_type("System.Collections.Specialized.NameValueCollection") 
Types["System.Text.Encoding"] = luanet.import_type("System.Text.Encoding")

Buttons = {} 
Ribbons = {} 

require("Helpers")
require("EventHandlers")
require("Grids")
require("API")
require "Atlas-Addons-Lua-ParseJson.JsonParser"

local form = nil 
interfaceMngr = nil 

function Init()

	interfaceMngr = GetInterfaceManager() 
	form = interfaceMngr:CreateForm(settings.TabName, settings.TabName) 
	settings['APIUrl'] = removeTrailingSlash(settings['APIUrl'])
	settings['sessionID'] = GetSessionId()
	if settings['sessionID'] == nil then
		interfaceMngr:ShowMessage('The session ID for interaction with the API could not be retrieved. Please check the username and password in the container lookup addon settings.', 'Network error')
		return
	end

	settings["repoTable"] = getListOfRepo()
	settings["numberOfRepos"] = tableLength(settings["repoTable"])
	if settings["numberOfRepos"] == 0 then
		interfaceMngr:ShowMessage('You do not currently have access to the ArchivesSpace API. Please check that the network you are on is allowed to access the ArchivesSpace API.', 'API access error')
		return
	end

	Ribbons["CN"] = form:CreateRibbonPage("Container Search") 

	if (AddonInfo.CurrentForm == "FormRequest") then
		Buttons["CNS-ICaC"] = Ribbons["CN"]:CreateButton("Import Container and Citation", GetClientImage("impt_32x32"), "importContainerAndCitation", "Container Search") 
		Buttons["CNS-IC"] = Ribbons["CN"]:CreateButton("Import Container", GetClientImage("impt_32x32"), "importContainer", "Container Search") 
		Buttons["CNS-PS"] = Ribbons["CN"]:CreateButton("Perform Search", GetClientImage("srch_32x32"), "containersSearch", "Container Search") 
		
		asItemsGrid = form:CreateGrid("MySqlGrid", "ArchivesSpace Results") 
		asItemsGrid.GridControl.MainView.OptionsView.ShowGroupPanel = false 

		numberSearchResult = form:CreateTextEdit("NumberSearchResult", "Number of item(s) found:") 
		numberSearchResult.ReadOnly = true 
		numberSearchResult.Value = 0

	end

	callNumber = GetFieldValue("Transaction", "CallNumber")
	if callNumber == '' or callNumber == nil then
		-- precedence of the call number for the search over the title
		title = GetFieldValue("Transaction", "ItemTitle")
	end

	--Build the "Request" TextEdit Box
	searchTerm = form:CreateTextEdit("Search", "Call Number") 
	searchTerm.Value = callNumber
	searchTerm.Editor.KeyDown:Add(CallNumberSubmitCheck) 


	--Add a spot for collection title
	collectionTitle = form:CreateTextEdit("CollectionTitle", "Collection Title") 
	if title ~= nil then
		collectionTitle.Value = title
	end
	collectionTitle.Editor.KeyDown:Add(TitleSubmitCheck) 

	eadidTerm = form:CreateTextEdit('eadid', "EADID") 
	eadidTerm.Editor.KeyDown:Add(EADIDSubmitCheck)

	barcodeTerm = form:CreateTextEdit("barcode", "Barcode")
	barcodeTerm.Editor.KeyDown:Add(BarcodeSubmitCheck)

	-- This specifies the layout of the different component of the addon (the grid, the ribbons etc..) the default placement being rather poor.
	form:LoadLayout("layout.xml") 

	form:Show() 
	local result = {} 
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

	local tab = convertResultsIntoDataTable(result)

	GetBoxes(tab, searchTypeStr)
end

function convertResultsIntoDataTable(repoJsonTable)
	local resultDataTable = Types["System.Data.DataTable"]()
	for repoCode, jsonRes in pairs(repoJsonTable) do
		local currDataTable = jsonArrayToDataTable(jsonRes, repoCode)
		resultDataTable:Merge(currDataTable)
	end
	return resultDataTable
end

function containersSearch()

	function isFieldFilled(field) 
		return field.Value ~= '' and field.Value ~= nil 
	end

	titleIsFilled = isFieldFilled(collectionTitle)
	eadIsFilled = isFieldFilled(eadidTerm)
	callIsFilled = isFieldFilled(searchTerm)
	barcodeIsFilled = isFieldFilled(barcodeTerm)


	function countIfTrue(cond) 
		if cond then return 1 else return 0 end
	end

	local nField = countIfTrue(titleIsFilled) + countIfTrue(eadIsFilled) + countIfTrue(callIsFilled) + countIfTrue(barcodeIsFilled)
	if nField ~= 1 then
		interfaceMngr:ShowMessage('Only one search field should be filled for containers search', 'Cannot retrieve search results')
		return
	end

	local gridControl = asItemsGrid.GridControl
	-- this is a way to have some 'loading' info displayed to the user
	noSearchResult(gridControl, 'Fetching search results, please wait')

	if titleIsFilled then
		performSearch(collectionTitle, 'title')
	elseif eadIsFilled then
		performSearch(eadidTerm, 'ead_id')
	elseif callIsFilled then
		performSearch(searchTerm, 'call number')
	else
		performSearch(barcodeTerm, 'barcode')
	end
end

function getFullResourceById(repoID, resourceId)
	local searchResourceReq = 'repositories/' .. repoID .. '/resources/' .. resourceId
	return getElementBySearchQuery(searchResourceReq)
end

function getResourceByCallNumber(callNumb, repoId)
	local searchResourceReq = 'repositories/' .. repoId .. '/search?page=1&q=four_part_id:("' .. callNumb .. '")&type[]=resource'
	local res = getElementBySearchQuery(searchResourceReq)

	total_hits = ExtractProperty(res, "total_hits")
	if total_hits == 0 then
		interfaceMngr:ShowMessage('The resource corresponding to the call number "' .. callNumb .. '" could not be found on the database.','Error')
		return nil-- no point in trying to do anything else in such case
	elseif total_hits > 1 then
		LogDebug('Call number search returned ' .. total_hits .. ' results when only 1 should have been returned. The first result will be used')
	end 

	results = ExtractProperty(res, "results")
	return results[1]
end

function getTopContainersByCallNumber(callNumb)
	return getTopContainersBySearchQuery('q=collection_identifier_u_stext:("'..callNumb..'")')
end

function getTopContainersByTitle(title)
	return getTopContainersBySearchQuery('q=collection_display_string_u_sstr:("'..title..'")')
end

function getTopContainersByBarcode(barcode)
	return getTopContainersBySearchQuery('q=barcode_u_sstr:("'..barcode..'")')
end

function getTopContainersByEADID(eadid)
	for id in settings["repoTable"] do
		local resourceId = getResourceIdByEADID(eadid:lower(), id)
		if resourceId ~= nil then
			return getTopContainersByResourceId(resourceId, id)
		end
	end
	return {}
end

function getTopContainersByResourceId(resourceId, repoId)
	local resultTable = {}
	local searchTopContReq = 'repositories/' .. repoId .. '/top_containers/search?q=collection_uri_u_sstr:("'..resourceId..'")'
	local res = getElementBySearchQuery(searchTopContReq)
	getResultAndPopulateTableOfJson(searchTopContReq, resultTable, repoId)
	return resultTable
end


function getTopContainersBySearchQuery(searchQuery)
	local resultTable = {}
	for index, id in pairs(settings['repoTable']) do
		resultTable[id] = nil
		local searchResourceReq = 'repositories/' .. id .. '/top_containers/search?' .. searchQuery
		getResultAndPopulateTableOfJson(searchResourceReq, resultTable, id)
	end
 	return resultTable
end

function getResultAndPopulateTableOfJson(searchResourceQuery, jsonTable, repoId)
	local res = getElementBySearchQuery(searchResourceQuery)
	local response = ExtractProperty(res, "response")
	if response ~= '' then
		local numFound = ExtractProperty(response, "numFound")
		if numFound ~= '' and numFound > 0 then
			local docs = ExtractProperty(response, "docs")
			jsonTable[repoId] = docs
		end
	end
end

function getResourceIdByEADID(eadid, repoId)
	local searchResourceReq = 'repositories/' .. repoId .. '/search?page=1&q=ead_id:("' .. eadid .. '")&type[]=resource'
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
	
	return ExtractProperty(results[1], "id")
end

function getElementBySearchQuery(searchQuery)
	local res = ArchivesSpaceGetRequest(settings['sessionID'], searchQuery)
	--LogDebug(res)
	local errorCode = res['httpErrorCode']
	if errorCode == 412 then
		-- the http error code of 412 means the session id has expired
		settings['sessionID'] = GetSessionId()
		return getElementBySearchQuery(searchQuery)
	end

	if res == nil then
		interfaceMngr:ShowMessage('could not retrieve search query result', 'error')
		return nil -- no point in trying to do anything else in such case
	end
	return res
end

-- returns the identifiers of repos the current user can access
function getListOfRepo()
	local resTable = {}
	local searchResourceReq = 'users/current-user'
	local res = getElementBySearchQuery(searchResourceReq)
	for k, v in pairs(res['permissions']) do
		if k ~= '_archivesspace' then
			table.insert(resTable, split(k, '/')[2])
		end
	end
	return resTable
end

function setItemNode(itemRow, aeonField, data)
    local success, err = pcall(function()
        itemRow:set_Item(aeonField, data) 
    end) 

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
        LogDebug("Error: ".. err.code) 
    end

    return itemRow 
end

function jsonArrayToDataTable(json_arr, repoId)

	local asItemTable = Types["System.Data.DataTable"]()
	local repoCodes = repositoryList();

	if json_arr == nil then
		return asItemTable
	end

	local allRecords = {}
	for i = 1, #json_arr do
		local obj = json_arr[i]
		local callNumbers = ExtractProperty(obj, 'collection_identifier_stored_u_sstr')
		local titles = ExtractProperty(obj, 'collection_display_string_u_sstr')
		local docIds = ExtractProperty(obj, 'collection_uri_u_sstr')
		for i=1,#callNumbers do
			local currCN = callNumbers[i]
			local currTitle = titles[i]
			local currDocIds = docIds[i]
			-- in the barcode case, one search result will be linked to one or more resources.
			allRecords[#allRecords + 1] = extractTopContainersInformation(obj, currCN, currTitle, currDocIds, repoId)
			-- a[#a+1] is an efficient way to append an element at the end of an array-like
		end
	end


	-- "This order function receives two arguments and must return true if the first argument should come first in the sorted array."
	function sortingByCallNumberContainerIndicator(tab1, tab2)
		-- this assumes that the title of the json object is in the following format: "<callNumber>, <ContainterType> <ContainerNumber> [...]"

		local cn1, cont1, indic1 = tab1['callNumber'], tab1['hidden_container'], tab1['hidden_indicator']
		local cn2, cont2, indic2 = tab2['callNumber'], tab2['hidden_container'], tab2['hidden_indicator']
		if cn1 ~= cn2 then
			return cn1 < cn2
		elseif cont1 ~= cont2 then
			return cont1 < cont2
		else
			-- some indicators might still be string
			if type(indic1) == type(indic2) then
				return indic1 < indic2
			else
				return false
			end
		end
	end

	table.sort(allRecords, sortingByCallNumberContainerIndicator)

	asItemTable.Columns:Add("collectionTitle")
	asItemTable.Columns:Add("callNumber")
	asItemTable.Columns:Add("enumeration")
	asItemTable.Columns:Add("item_barcode")
	asItemTable.Columns:Add("location")
	asItemTable.Columns:Add("restrictions")
	asItemTable.Columns:Add("item_id")
	asItemTable.Columns:Add("series")
	asItemTable.Columns:Add("profile")
	asItemTable.Columns:Add("repo_code")
	asItemTable.Columns:Add("doc_path")

	for _, value in ipairs(allRecords) do
		local row = asItemTable:NewRow()
		setItemNode(row,'collectionTitle', value['collectionTitle'])
		setItemNode(row,'callNumber', value['callNumber'])
		setItemNode(row,'enumeration', value['enumeration'])
		setItemNode(row,'item_barcode', value['item_barcode'])
		setItemNode(row,'location', value['location'])
		setItemNode(row,'restrictions', value['restrictions'])
		setItemNode(row,'item_id', value['item_id'])
		setItemNode(row,'series', value['series'])
		setItemNode(row,'profile', value['profile'])
		setItemNode(row,'repo_code', repoCodes[value['repoId']])
		setItemNode(row,'doc_path', value['docPath']) -- hidden value
		asItemTable.Rows:Add(row)
	end

	return asItemTable
end

function extractTopContainersInformation(obj, callNumber, title, docId, repoId)
	local row = {}
	row['callNumber'] = truncateIfNotNil(callNumber)

	row['collectionTitle'] = truncateIfNotNil(title)

	local jsonString = JsonParser:ParseJSON(ExtractProperty(obj, 'json'))

	local indicator = ExtractProperty(jsonString, 'indicator')
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
			indicator = tonumber(indicator)
		else
			indicator = 0
		end
	else
		if not container then
			-- failsafe so the sorting works later.
			container = ''
		end
		typeEnum = container
		-- sort nil is not stored inside the hidden indicator column
		indicator = 0
	end

	row['hidden_indicator'] = truncateIfNotNil(indicator)
	row['hidden_container'] = truncateIfNotNil(container)
	row['enumeration'] = truncateIfNotNil(typeEnum)
	row['item_barcode'] = ExtractProperty(obj, 'barcode_u_sstr')[1]

	-- apparently some locations can be empty!
	row['location'] = truncateIfNotNil(ExtractProperty(obj, 'location_display_string_u_sstr')[1])

	-- fetching this information from the 'restricted' field of the json embedded data 
	local restricted = 'N'
	if ExtractProperty(jsonString, 'restricted') then
		restricted = 'Y'
	end
	row['restrictions'] = restricted

	-- all the ids are prepended with the database path.
	-- format of a top container path: /repositories/[repoID]/top_containers/[TopContainerID]
	local tcId = split(ExtractProperty(obj, 'id'), '/')
	row['item_id'] = tcId[#tcId]

	--useful to make a callback when making the import later (hidden value on the grid)
	row['docPath'] = docId

	local seriesStr = ''
	local seriesArray = ExtractProperty(jsonString, 'series')
	if #seriesArray > 0 then
		seriesStr = ExtractProperty(seriesArray[1], 'display_string')

		for i = 2,#seriesArray do
			local displayString = ExtractProperty(seriesArray[i], 'display_string')
			if displayString ~= '' and displayString ~= nil then
				seriesStr = seriesStr .. '  ' .. displayString
			end
		end 
	end
	row['series'] = truncateIfNotNil(seriesStr)

	local profile = ExtractProperty(obj, 'container_profile_display_string_u_sstr')[1]
	row['profile'] = truncateIfNotNil(profile)
	row['repoId'] = repoId
	return row
end

function truncateIfNotNil(value)
	-- If string are longer than 255 char, Aeon will not import them in the grid.  
	if type(value) == 'string' then
		if value ~= nil and value ~= '' then
			return value:sub(0,255)
		else
			return ''
		end
	else
		return value
	end
end

function GetBoxes(tab, itemQuery)
		-- itemQuery specify which term was used for the search (call number or title), usefule for outputting the was "not found" message. 
		LogDebug("Retrieving boxes.") 
		clearTable(asItemsGrid)  --Clear item grid to avoid mixed series/items
		numberSearchResult.Value = tab.Rows.Count -- for the user to see the number of search results
		local itemGridControl = asItemsGrid.GridControl 
		if (tab.Rows.Count ~= 0) then
			itemGridControl:BeginUpdate()
			--asItemsGrid.PrimaryTable = tab 
			itemGridControl.DataSource=tab
			itemGridControl:EndUpdate()

			fillItemTable(itemGridControl) 
			asItemsGrid.GridControl:Focus() 
		else
			noSearchResult(itemGridControl, 'No top containers were found for the current '..itemQuery)
			LogDebug("No results returned from webservice on box search") 
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
	local repoCode = itemRow:get_Item("repo_code")
	local recordId = itemRow:get_Item("item_id")

	-- Update the item object with the new values.
	function setFieldValueIfNotNil(formName, fieldName, value)
		if value ~= '' and value ~= nil then
			-- this way the empty field won't be highlighted in the import
			SetFieldValue(formName, fieldName, value)
		end 
	end

	LogDebug("Updating the item object.") 
	setFieldValueIfNotNil("Transaction", "ItemVolume", itemVolume) 
	setFieldValueIfNotNil("Transaction", "ItemNumber", barcode) 
	setFieldValueIfNotNil("Transaction", "ItemInfo5", location) 
	

	if withCitation then
		setFieldValueIfNotNil("Transaction", "CallNumber", callNumber)
		setFieldValueIfNotNil("Transaction", "ItemTitle", collectionTitle)
		setFieldValueIfNotNil("Transaction", "Location", repoCode)

		local documentPath = itemRow:get_Item("doc_path")
		-- format of a document path: /repositories/[repoID]/[resources|accessions]/[documentID]
		
		local documentType = split(documentPath, '/')
		if documentType[3] == 'resources' then

			setFieldValueIfNotNil("Transaction", "ItemCitation", series)
			
			local res = getResourceByCallNumber(callNumber, documentType[2])
			local creators = ExtractProperty(res, 'creators') 
			local creator = nil
			if creators ~= nil then
				creator = creators[1]
			end
			setFieldValueIfNotNil("Transaction", "ItemAuthor", creator)
			
			local resourceURL = ExtractProperty(res, 'id')
			local resourceElems = split(resourceURL, '/')
			local resourceId = resourceElems[#resourceElems]
--			local repoId = settings["repoTable"][0]
			local resourceObj = getFullResourceById(documentType[2], resourceId)
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


			local accessRestrictNotes = extractNoteContent(notes, 'type', 'accessrestrict', 'subnotes')
			if accessRestrictNotes and #accessRestrictNotes > 0 then
				local subnoteContent = ExtractProperty(accessRestrictNotes[1], 'content')
				if subnoteContent then
					-- Aeon Transaction fields 
					local truncated = subnoteContent:sub(0, 255)
					setFieldValueIfNotNil('Transaction', 'ItemInfo2', truncated)
				end				
			end
		elseif documentType[3] == 'accessions' then

			-- there is only two types of document: resources and accessions
			-- if the else part is reached, that means the current document is an accession.
			local creatorApiPath = getAccessionCreatorAgentById(documentType[#documentType], settings["repoTable"][0])
			if creatorApiPath ~= nil and creatorApiPath ~= '' then
				local agentJson = getElementBySearchQuery(creatorApiPath)
				if agentJson ~= nil and agentJson ~= '' then
					local creatorNames = ExtractProperty(agentJson, 'names')
					if creatorNames ~= nil and creatorNames ~= '' and #creatorNames > 0 then
						setFieldValueIfNotNil("Transaction", "ItemAuthor", ExtractProperty(creatorNames[1], 'sort_name'))
					end
				end
			end

		end
	end

	LogDebug("Switching to the detail tab.")
	ExecuteCommand("SwitchTab", {"Detail"})
end

function getAccessionCreatorAgentById(accessId, repoId)
	local searchQuery = '/repositories/'..repoId..'/accessions/'..accessId
	local accessJson = getElementBySearchQuery(searchQuery)
	if accessJson ~= nil then
		local linked_agents = ExtractProperty(accessJson, 'linked_agents')
		if linked_agents ~= nil then
			for _, v in pairs(linked_agents) do
				if ExtractProperty(v, 'role') == 'creator' then
					return ExtractProperty(v, 'ref')
				end
			end
		end
	end
	return nil
end

function extractNoteContent(notesArray, jsonField, fieldValue, toExtract)
	for i = 1, #notesArray do
		local currNote = notesArray[i]
		if currNote[jsonField] == fieldValue then
			return currNote[toExtract]
		end
	end
	return nil
end

function ExtractProperty(object, property)
    if object then
        return EmptyStringIfNil(object[property]) 
    end
end

function EmptyStringIfNil(value)
    if (value == nil or value == JsonParser.NIL) then
        return "" 
    else
        return value 
    end
end