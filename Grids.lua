--
-- Methods related to filling grid controls
--

function clearTable(gridControl)
	if (gridControl.MainView ~= nil) then
		if (gridControl.PrimaryTable ~= nil) then
			gridControl.PrimaryTable:Clear();
		end
		if (gridControl.MainView.Columns ~= nil) then
			gridControl.MainView.Columns:Clear();
		end
	end
end

function noSearchResult(gridControl, msg)

	LogDebug("No search results found, displaying message on grid");
	-- Set the grid view options
	local gridView = gridControl.MainView;
	gridView.Columns:Clear();
	gridView.OptionsView.ShowIndicator = false;
	gridView.OptionsView.ShowGroupPanel = false;
	gridView.OptionsView.RowAutoHeight = true;
	gridView.OptionsView.ColumnAutoWidth = false;
	gridView.OptionsBehavior.AutoExpandAllGroups = true;
	gridView.OptionsBehavior.Editable = false;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = msg;
	gridColumn.FieldName = "noSearchResult";
	gridColumn.Name = "gcNoSearchResult";
	-- arbitrarily long tab length to be sure the user does not see its end
	gridColumn.Width = 5550;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 0;
	gridColumn.OptionsColumn.ReadOnly = true;
end

function fillItemTable(gridControl)

	LogDebug("Initializing item grid control");

	-- Set the grid view options
	local gridView = gridControl.MainView;
	gridView.Columns:Clear();
	gridView.OptionsView.ShowIndicator = false;
	gridView.OptionsView.ShowGroupPanel = false;
	gridView.OptionsView.RowAutoHeight = true;
	gridView.OptionsView.ColumnAutoWidth = false;
	gridView.OptionsBehavior.AutoExpandAllGroups = true;
	gridView.OptionsBehavior.Editable = false;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Collection Title";
	gridColumn.FieldName = "collectionTitle";
	gridColumn.Name = "gcCollectionTitle";
	gridColumn.Width = 150;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 0;
	gridColumn.OptionsColumn.ReadOnly = true;


	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Call Number";
	gridColumn.FieldName = "callNumber";
	gridColumn.Name = "gcCallNumber";
	gridColumn.Width = 120;
	gridColumn.Visible = true;
	-- puting a minus index makes the column invisible, but the row values can still be accessed for the item import
	gridColumn.VisibleIndex = 1;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Container";
	gridColumn.FieldName = "enumeration";
	gridColumn.Name = "gcEnumeration";
	gridColumn.Width = 100;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 2;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Barcode";
	gridColumn.FieldName = "item_barcode";
	gridColumn.Name = "gcItemBarcode";
	gridColumn.Width = 70;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 3;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Location";
	gridColumn.FieldName = "location";
	gridColumn.Name = "gcLocation";
	gridColumn.Width = 200;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 4;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Container Profile";
	gridColumn.FieldName = "profile";
	gridColumn.Name = "gcContainerProfile";
	gridColumn.Width = 200;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 5;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Series";
	gridColumn.FieldName = "series";
	gridColumn.Name = "gcSeries";
	gridColumn.Width = 80;
	gridColumn.Visible = true;
	-- IMPORTANT: if Type/subLocation are added back to the addon, this or sublocation's index needs to be changed
	gridColumn.VisibleIndex = 6;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Restricted";
	gridColumn.FieldName = "restrictions";
	gridColumn.Name = "gcRestrictions";
	gridColumn.Width = 60;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 7;
	gridColumn.OptionsColumn.ReadOnly = true;

	local gridColumn;
	gridColumn = gridView.Columns:Add();
	gridColumn.Caption = "Record ID";
	gridColumn.FieldName = "item_id";
	gridColumn.Name = "gcItem_Id";
	gridColumn.Width = 50;
	gridColumn.Visible = true;
	gridColumn.VisibleIndex = 8;
	gridColumn.OptionsColumn.ReadOnly = true;
	--gridColumn.SortOrder = Types["DevExpress.Data.ColumnSortOrder"].Ascending;
end