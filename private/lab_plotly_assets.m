function [bundle, license] = lab_plotly_assets(bundle, license, caller)
%LAB_PLOTLY_ASSETS Check the optional local renderer and license pair.
    bundle = convertCharsToStrings(bundle);
    license = convertCharsToStrings(license);
    if ~isstring(bundle) || ~isscalar(bundle) || ismissing(bundle)
        error([caller ':InvalidOption'], 'PlotlyJS must be a text scalar.');
    end
    if ~isstring(license) || ~isscalar(license) || ismissing(license)
        error([caller ':InvalidOption'], 'PlotlyLicense must be a text scalar.');
    end
    if xor(bundle ~= "", license ~= "")
        error([caller ':BundlePair'], 'Provide both PlotlyJS and its matching PlotlyLicense.');
    end
    if bundle ~= "" && (~isfile(bundle) || ~endsWith(bundle, '.js', 'IgnoreCase', true) || ~isfile(license))
        error([caller ':BundleFile'], 'The local JavaScript bundle and license must both exist.');
    end
end
