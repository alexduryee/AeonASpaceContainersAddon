--- Event handlers related to archivespace search, event registration usually in main.lua

function CallNumberSubmitCheck(sender, args)
	if tostring(args.KeyCode) == "Return: 13" then
		performSearch(searchTerm, 'call number')
	end
end

function TitleSubmitCheck(sender, args)
	if tostring(args.KeyCode) == "Return: 13" then
		performSearch(collectionTitle, 'title')
	end
end

function EADIDSubmitCheck(sender, args)
	if tostring(args.KeyCode) == "Return: 13" then
		performSearch(eadidTerm, 'ead_id')
	end
end

function BarcodeSubmitCheck(sender, args)
	if tostring(args.KeyCode) == "Return: 13" then
		performSearch(barcodeTerm, 'barcode')
	end
end



function performSearch(field, fieldName)
	if field.Value == nil or field.Value == '' then
		LogDebug('Containers '.. fieldName ..' search run but no search term provided')
	else
		local res = nil
		if field == eadidTerm then
			collectionTitle.Value = ''
			searchTerm.Value = ''
			barcodeTerm.Value = ''
			res = getTopContainersByEADID(field.Value)
		elseif field == collectionTitle then
			eadidTerm.Value = ''
			searchTerm.Value = ''
			barcodeTerm.Value = ''
			res = getTopContainersByTitle(field.Value)
		elseif field == searchTerm then
			collectionTitle.Value = ''
			eadidTerm.Value = ''
			barcodeTerm.Value = ''
			res = getTopContainersByCallNumber(field.Value)
		elseif field == barcodeTerm then
			collectionTitle.Value = ''
			searchTerm.Value = ''
			eadidTerm.Value = ''
			res = getTopContainersByBarcode(field.Value)
		end

		GetBoxes(convertResultsIntoDataTable(res), fieldName)
	end
end