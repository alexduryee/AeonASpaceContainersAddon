-- Utility Functions

function makeRibbonVisible(ribbon, visibilitySetting)
	--ribbon is of type AtlasSystems.Scripting.UI.ScriptRibbonPage
	--visibilitySetting is a boolean value
	--this should probably be switched to a "show only" that searches the parent
	--and deactivates all but the specified ribbon within a particular group
	ribbon.Page.Visible = visibilitySetting;
end

function findObjectTypeInCollection(obj, typestr)
	local ctrlCount = getLength(obj);
	local idx = 0;
	local target = nil;
	while idx < ctrlCount do
		target = obj:get_Item(idx);
		if string.startsWith(tostring(target), typestr) then
			return target;
		end
		idx = idx + 1;
	end
	if idx == ctrlCount then
		return nil;
	end
end

-- cannot use '#' if the table is not numerically indexed in sequence. 
function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


function getLength(obj)
	local idx = 0;
	while true do
		if pcall(function () local test = obj:get_Item(idx) end) then
			idx = idx + 1;
		else
			break;
		end
	end
	return idx;
end

function string.startsWith(original, test)
	return string.sub(original, 1, string.len(test))==test;
end

function incomingStringCleaner(text)
	text = string.gsub(text,"(Accession)","Accn");
	return text
end

function isnumeric(val)
	if (val == nil) then
		return false;
	end
	-- make sure the string val is all numeric
	return string.match(val, "^[0-9]+$") ~= nil;
end

function isOnlyWhitespace(str)
  if str ~= nil then
    return str:gsub("%s+", "") == ''
  end
  return true
end

-- source: https://stackoverflow.com/questions/1426954/split-string-in-lua
function split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end