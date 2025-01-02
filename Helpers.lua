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


-- hardcoding this because it's _really slow_ to pull this from aspace 
-- every time we want to make a request
function repositoryList()
	local repo = {}
	repo['4'] = 'HUA';
	repo['5'] = 'LAW';
	repo['6'] = 'PEA';
	repo['7'] = 'DES';
	repo['8'] = 'SCH';
	repo['9'] = 'ART';
	repo['10'] = 'BER';
	repo['11'] = 'BAK';
	repo['12'] = 'DIV';
	repo['13'] = 'AJP';
	repo['14'] = 'MED';
	repo['15'] = 'ARN';
	repo['16'] = 'DDO';
	repo['17'] = 'ECB';
	repo['18'] = 'ENV';
	repo['19'] = 'FAL';
	repo['20'] = 'FAR';
	repo['21'] = 'FUN';
	repo['22'] = 'GRA';
	repo['23'] = 'HFA';
	repo['24'] = 'HOU';
	repo['25'] = 'HYL';
	repo['26'] = 'MCZ';
	repo['27'] = 'MUS';
	repo['28'] = 'ORC';
	repo['29'] = 'TOZ';
	repo['30'] = 'URI';
	repo['31'] = 'WID';
	repo['32'] = 'WOL'; -- will be HPS later on
	repo['33'] = 'HSI';
	repo['34'] = 'ORA';
	repo['35'] = 'VIT';
	repo['36'] = 'GUT';
	repo['37'] = 'OPH';
	return repo;
end