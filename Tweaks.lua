InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
if not InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory = function(frame, addOn, position)
        frame.OnCommit = frame.okay;
        frame.OnDefault = frame.default;
        frame.OnRefresh = frame.refresh;

        if frame.parent then
            local category = Settings.GetCategory(frame.parent);
            local subcategory, layout = Settings.RegisterCanvasLayoutSubcategory(category, frame, frame.name, frame.name);
            subcategory.ID = frame.name;

            return subcategory, category;
        else
            local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name);
            category.ID = frame.name;
            Settings.RegisterAddOnCategory(category);
            return category;
        end
    end
end
