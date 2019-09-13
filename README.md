# AeonASpaceContainersAddon
Aeon Addon which retrieve top containers from ArchivesSpace given a request 

## Search behavior discrepancies

Currently the search feature of the addon will behave differently according to which field the search is performed on. It stems from an unresolved issue on the way ASpace indexes its internal dynamic fields. Hopefully in the future this will be resolved and the addon will showcase the same fuzzy behavior for the three type of search however

### Call Number Search

The Call Number Search features a flexible search behavior: the system is oblivious about whitespaces and casing on the search token. This means that in order to retrieve top containers associated to a resource whose call number is "Arch GA 9.75", the following tokens will produce the same set of results: "ArchGA9.75", "arch ga 9.75", "archga9.75".

Another great consequence of the flexibility of the call number field search implies that users can perform substring search. Meaning that entering the token "Arch" will return all top containers whose resource have a call number containing the substring "Arch" .

Depending on the context such a fuzzy might not be wanted but in the context of this addon we value the amount of freedom and flexibility this system offers to the user.

### Collection Title Search

In total opposition to the call number search, searching on this field is extremely strict. Getting top containers by searching through this field requires an exact match between the search token and the resource's collection title. Meaning the casing needs to be respected, and user can not get results containing the search token as a substring.


#### How to solve it (eventually)

Fuzzy search on collection title cannot be enabled yet because the current instance of ArchivesSpace's server has no solr field generated which would allow for this search behavior. The way this addon works is by using the "search" endpoint from ASpace's API with using certain fields as parameters. For example, the field for the Call Number search is `collection_identifier_u_stext`. 'collection_identifier' is the internal ASpace's name for the Call Number, 'u_stext' is a dynamic field stating this field should be considered as a stored text and thus searches operated on it should have lemmatization and case insensitive behavior. The code generating this field can be found at line 555 on [this ruby file from ASpace's server source code](https://github.com/archivesspace/archivesspace/blob/ae5c60ca9376d9ee83ad0d561a5bcfbdd2467894/indexer/app/lib/indexer_common.rb). 

The code about the field for the collection's title can also be found on this file at 553, which generate the `collection_display_string_u_sstr`. 'collection_display_string' is the collection title internal name, while 'u_sstr' is a dynamic field stating this field should be considered as a stored string and not text. Thus search using this field are unfuzzy and need exact string matching. As can be seen there is nowhere on this file (or archivesspace source code in general) the generation of a `collection_display_string_u_stext`which would allow for fuzzy search. On my archivesspace's fork I wrote the code that would allow for the generation of such a field as can be seen on [this commit](https://github.com/cedricviaccoz/archivesspace/commit/e6619c5578ed91e58a3549573ec6577eef40c195). Once someone with contributing privilege to archivesspace's repository merges this commit to the codebase, then a simple change on this addon's code would enable fuzzy title collection search. In Main.lua, starting at line 197 this function 
```Lua
function getTopContainersByTitle(title)
	return getTopContainersBySearchQuery('q=collection_display_string_u_sstr:("'..title..'")')
end
```

should just be replaced by this one:
```Lua
function getTopContainersByTitle(title)
	return getTopContainersBySearchQuery('q=collection_display_string_u_stext:("'..title..'")')
end
```

I hope someday my commit will be merger to archivesspace and someone will be able to apply this change to my addon. To whom it may concern, thank you for taking care of that for me.

