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


### EADID Search

The current way to get top containers through their resource's EADID is to get the resource's call number corresponding the EADID search token, and then reduce it to a Call Number search to get all the top containers associated to this call number. However considering how substring search is possible with the Call Number search this implies some results will not correspond to the EADID entered as a search token. If the EADID entered was "bak00206" and it corresponds to the call number "Arch GA 8", it will also get top containers associated to the resource whose call number are "Arch GA 8X", with X being any number between 0 and 9. And those resource does not share the same EADID as "Arch GA 8". 

Some investigation might be needed to find a better way to do top container search using the EADID, but to the best of our knowledge, it is the best way to offer such a functionnality.
