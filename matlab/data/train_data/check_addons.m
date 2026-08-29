try
    a = matlab.addons.installedAddons;
    ids = string(a.Identifier);
    ok = any(ids == "XCEPTION") && any(ids == "INCEPTIONRESNETV2");
    disp(ok);
catch
    disp(false);
end
