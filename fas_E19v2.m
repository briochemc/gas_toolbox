function [Ks, Kp, Kc, Fd, Fp, Fc, Deq] = fas_E19v2(gas, u10, SP, pt, C, pslp, rh)
% fas_E19: Function to calculate air-sea fluxes with Liang 2013
% parameterization
%
% USAGE:-------------------------------------------------------------------
% [Ks, Kp, Kc, Fd, Fp, Fc, Deq] = fas_E19v2(gas, u10, SP, pt, [C, pslp, rh])
%
% EXAMPLES:----------------------------------------------------------------
% [Ks, Kp, Kc, Fd, Fp, Fc, Deq] = fas_E19v2('Ar',5,35,10,0.01410,1)
% > Ks = 2.0377e-05
% > Kp = 1.3436e-06
% > Kc = 5.3942e-09
% > Fd = -5.6030e-09
% > Fp = -2.4485e-10
% > Fc = 5.0339e-11
% > Deq = 5.8254e-04
%
% [Ks, Kp, Kc] = fas_E19v2('Ar',5,35,10)
% > Ks = 2.0377e-05
% > Kp = 1.3436e-06
% > Kc = 5.3942e-09
%
% DESCRIPTION:-------------------------------------------------------------
%
% Calculate air-sea fluxes and steady-state supersat based on Emerson et
% al. (2019) modification to the Liang et al. 2013 parameterization which
% multiplies bubble fluxes by 0.37
%
%
% INPUTS:------------------------------------------------------------------
% C:    gas concentration (mol m-3)
% u10:  10 m wind speed (m/s)
% SP:   Sea surface salinity (PSS)
% pt:   Sea surface temperature (deg C)
% pslp: sea level pressure (atm)
% gas:  formula for gas (He, Ne, Ar, Kr, Xe, N2, or O2), formatted as a
%       string, e.g. 'He'
% rh:   relative humidity as a fraction of saturation (0.5 = 50% RH)
%       rh is an optional but recommended argument. If not provided, it
%       will be automatically set to 1 (100% RH).
%
%       Code    Gas name        Reference
%       ----   ----------       -----------
%       He      Helium          Weiss 1971
%       Ne      Neon            Hamme and Emerson 2004
%       Ar      Argon           Hamme and Emerson 2004
%       Kr      Krypton         Weiss and Keiser 1978
%       Xe      Xenon           Wood and Caputi 1966
%       N2      Nitrogen        Hamme and Emerson 2004
%       O2      Oxygen          Garcia and Gordon 1992
%
% OUTPUTS:-----------------------------------------------------------------
%
% Fd:   Surface gas flux                              (mol m-2 s-1)
% Fc:   Flux from fully collapsing small bubbles      (mol m-2 s-1)
% Fp:   Flux from partially collapsing large bubbles  (mol m-2 s-1)
% Deq:  Equilibrium supersaturation                   (unitless (%sat/100))
% k:    Diffusive gas transfer velocity               (m s-1)
%
% Note: Total air-sea flux is Ft = Fd + Fc + Fp
%
% REFERENCE:---------------------------------------------------------------
% Emerson, S., Yang, B., White, M., & Cronin, M. (2019). Air?sea gas
%   transfer: Determining bubble fluxes with in situ N2 observations.
%   Journal of Geophysical Research: Oceans, 124, 2716?2727.
%   https://doi.org/10.1029/2018JC014786
%
% Liang, J.-H., C. Deutsch, J. C. McWilliams, B. Baschek, P. P. Sullivan,
%   and D. Chiba (2013), Parameterizing bubble-mediated air-sea gas
%   exchange and its effect on ocean ventilation, Global Biogeochem. Cycles,
%   27, 894?905, doi:10.1002/gbc.20080.
%
% AUTHOR:---------------------------------------------------------------
% Written by David Nicholson dnicholson@whoi.edu
%
% Woods Hole Oceanographic Institution
% Version: 21 Feb 2020
%
% COPYRIGHT:---------------------------------------------------------------
%
% Copyright 2017 David Nicholson and Cara Manning
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License, which
% is available at http://www.apache.org/licenses/LICENSE-2.0
%
% MODIFICATIONS:---------------------------------------------------------------
%
% Modified by Benoit Pasquier b.pasquier@unsw.edu.au for use in PCO2 model

% Added some default values for C and pslp in case only k's output is required
arguments
    gas                  % string for gas (He, Ne, Ar, Kr, Xe, N2, or O2)
    u10                  % 10 m wind speed (m/s)
    SP                   % Sea surface salinity (PSS)
    pt                   % Sea surface temperature (deg C)
    C = gasmolfract(gas) % gas concentration (mol m-3)
    pslp = 1             % sea level pressure (atm)
    rh = ones(size(C))   % relative humidity as a fraction of saturation
end

% Bubble scaling factor from Emerson et al. 2019
bfact = 0.37;

% -------------------------------------------------------------------------
% Conversion factors
% -------------------------------------------------------------------------
m2cm = 100; % cm in a meter
h2s = 3600; % sec in hour
atm2Pa = 1.01325e5; % Pascals per atm

% -------------------------------------------------------------------------
% Parameters for COARE 3.0 calculation
% -------------------------------------------------------------------------

% Calculate potential density at surface
SA = SP .* 35.16504 ./ 35;
CT = gsw_CT_from_pt(SA, pt);
rhow = gsw_sigma0(SA, CT)+1000;
rhoa = 1.225;

lam = 13.3;
A = 1.3;
phi = 1;
tkt = 0.01;
hw = lam ./ A ./ phi;
ha = lam;

% air-side schmidt number
ScA = 0.9;

R = 8.314;  % units: m3 Pa K-1 mol-1

% -------------------------------------------------------------------------
% Calculate gas physical properties
% -------------------------------------------------------------------------
Geq = gasmoleq(SP, pt, gas);
alc = (Geq / atm2Pa) .* R .* (pt+273.15);

[~, ScW] = gasmoldiff(SP, pt, gas);

% -------------------------------------------------------------------------
% Calculate COARE 3.0 and gas transfer velocities
% -------------------------------------------------------------------------
% ustar
cd10 = cdlp81(u10);
ustar = u10 .* sqrt(cd10);

% water-side ustar
ustarw = ustar ./ sqrt(rhow ./ rhoa);

% water-side resistance to transfer
rwt = sqrt(rhow ./ rhoa) .* (hw .* sqrt(ScW) + (log(0.5 ./ tkt) / 0.4));

% air-side resistance to transfer
rat = ha .* sqrt(ScA) + 1 ./ sqrt(cd10) - 5 + 0.5 * log(ScA) / 0.4;

% diffusive gas transfer coefficient (L13 eqn 9)
Ks = ustar ./ (rwt + rat .* alc);

% bubble transfer velocity (L13 eqn 14)
Kp = bfact .* 1.98e6 .* ustarw.^2.76 .* (ScW ./ 660).^(-2/3) ./ (m2cm .* h2s);

% overpressure dependence on windspeed (L13 eqn 16)
dP = 1.5244 .* ustarw.^1.06;

% bubble transfer velocity (dervied from L13 eqn 15)
Kc = bfact .* 5.56 .* ustarw.^3.86;

if nargout <= 3, return, end

% -------------------------------------------------------------------------
% Calculate air-sea fluxes
% -------------------------------------------------------------------------
% Calculate water vapor pressure and adjust sea level pressure
ph2oveq = vpress(SP, pt);
ph2ov = rh .* ph2oveq;
% slpc = (observed dry air pressure)/(reference dry air pressure)
% see Description section in header of fas_N11.m
pslpc = (pslp - ph2ov) ./ (1 - ph2oveq);

Gsat = C ./ Geq;
xG = gasmolfract(gas);

Fd = Ks .* Geq .* (pslpc - Gsat); % Fd in L13 eqn 3
Fp = Kp .* Geq .* ((1 + dP) .* pslpc - Gsat); % Fp in L13 eqn 3
Fc = Kc .* xG; % L13 eqn 15

if nargout <= 6, return, end

% -------------------------------------------------------------------------
% Calculate steady-state supersaturation
% -------------------------------------------------------------------------
Deq = (Kp .* Geq .* dP .* pslpc + Fc) ./ ((Kp + Ks) .* Geq .* pslpc); % L13 eqn 5


