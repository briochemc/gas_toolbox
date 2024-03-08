function [cd] = cdlp81(u10)
    % Calculates drag coefficient from u10, wind speed at 10 m height
    cd = (4.9e-4 + 6.5e-5 * u10);
    cd(u10 <= 11) = 0.0012;
    cd(u10 >= 20) = 0.0018;
end