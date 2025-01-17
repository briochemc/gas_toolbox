% fas_L13: Function to calculate air-sea fluxes with Liang 2013
% parameterization
%
% USAGE:-------------------------------------------------------------------
%
% [Fd, Fc, Fp, Deq, k] = fsa_L13(C_w,C_a,u10,S,T,gas)
% T = 10; u10 = 12; S = 35;
% pAr = gasmolfract('Ar')*(1-vpress(35,10));
% [Fd, Fc, Fp, Deq, k] = fsa_L13(0.014,pAr,u10,S,T,'Ar')
%
% > Fd = 8.8028e-09
% > Fc = -4.4549e-09
% > Fp = -2.9367e-09
% > Deq = 0.0116
% > k = 5.0311e-05
%
% DESCRIPTION:-------------------------------------------------------------
%
% Calculate air-sea fluxes and steady-state supersat based on:
% Liang, J.-H., C. Deutsch, J. C. McWilliams, B. Baschek, P. P. Sullivan,
% and D. Chiba (2013), Parameterizing bubble-mediated air-sea gas exchange
% and its effect on ocean ventilation, Global Biogeochem. Cycles, 27,
% 894?905, doi:10.1002/gbc.20080.
%
% INPUTS:------------------------------------------------------------------
% Cw:   dissolved gas concentration (mol m-3)
% Ca:   Concentration in equilibrium with overlying atmosphere (mol m-3)
%        Ca = K0 * pG  or also Ca = K0 * xG * (slp - rh * vpress)
%       where pG is actual partial pressure (atm) and xG is dry mol/mol
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
%
% Liang, J.-H., C. Deutsch, J. C. McWilliams, B. Baschek, P. P. Sullivan,
%   and D. Chiba (2013), Parameterizing bubble-mediated air-sea gas
%   exchange and its effect on ocean ventilation, Global Biogeochem. Cycles,
%   27, 894?905, doi:10.1002/gbc.20080.
%
% AUTHOR:---------------------------------------------------------------
% Written by David Nicholson dnicholson@whoi.edu
% Modified by Cara Manning cmanning@whoi.edu
% Woods Hole Oceanographic Institution
% Version: 30 Nov 2017
%
% COPYRIGHT:---------------------------------------------------------------
%
% Copyright 2017 David Nicholson and Cara Manning
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License, which
% is available at http://www.apache.org/licenses/LICENSE-2.0
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Fd, Fc, Fp, Deq, Ks] = fsa_L13(Cw,Ca,u10,SP,pt,gas)
% -------------------------------------------------------------------------
% Conversion factors
% -------------------------------------------------------------------------
m2cm = 100; % cm in a meter
h2s = 3600; % sec in hour
atm2Pa = 1.01325e5; % Pascals per atm
Ca_mmolm3 = gasmolsol(SP,pt,Ca,gas);
% -------------------------------------------------------------------------
% Parameters for COARE 3.0 calculation
% -------------------------------------------------------------------------

% Calculate potential density at surface
SA = SP.*35.16504./35;
CT = gsw_CT_from_pt(SA,pt);
rhow = gsw_sigma0(SA,CT)+1000;
rhoa = 1.225;

lam = 13.3;
A = 1.3;
phi = 1;
tkt = 0.01;
hw=lam./A./phi;
ha=lam;

% air-side schmidt number
ScA = 0.9;

R = 8.314;  % units: m3 Pa K-1 mol-1

% -------------------------------------------------------------------------
% Calculate gas physical properties
% -------------------------------------------------------------------------
%xG = gasmolfract(gas);
% assume 1 atm pressure to get dry mix ratio - not exact!! (necessary to
% pass in slp and rh?)
xG = Ca ./ (1 - vpress(SP,pt));
alc = (Ca_mmolm3./atm2Pa).*R.*(pt+273.15);

%Gsat = Cw./Ca;
[~, ScW] = gasmoldiff(SP,pt,gas);

% -------------------------------------------------------------------------
% Calculate COARE 3.0 and gas transfer velocities
% -------------------------------------------------------------------------
% ustar
cd10 = cdlp81(u10);
ustar = u10.*sqrt(cd10);

% water-side ustar
ustarw = ustar./sqrt(rhow./rhoa);

% water-side resistance to transfer
rwt = sqrt(rhow./rhoa).*(hw.*sqrt(ScW)+(log(.5./tkt)/.4));

% air-side resistance to transfer
rat = ha.*sqrt(ScA)+1./sqrt(cd10)-5+.5*log(ScA)/.4;

% diffusive gas transfer coefficient (L13 eqn 9)
Ks = ustar./(rwt+rat.*alc);

% bubble transfer velocity (L13 eqn 14)
Kb = 1.98e6.*ustarw.^2.76.*(ScW./660).^(-2/3)./(m2cm.*h2s);

% overpressure dependence on windspeed (L13 eqn 16)
dP = 1.5244.*ustarw.^1.06;


% -------------------------------------------------------------------------
% Calculate air-sea fluxes
% -------------------------------------------------------------------------

Fd = Ks.*(Cw - Ca_mmolm3); % Fs in L13 eqn 3
Fp = Kb.*(Cw - Ca_mmolm3.*(1+dP)); % Fp in L13 eqn 3
Fc = -xG.*5.56.*ustarw.^3.86; % L13 eqn 15

% -------------------------------------------------------------------------
% Calculate steady-state supersaturation
% -------------------------------------------------------------------------
Deq = (Kb.*Ca_mmolm3.*dP-Fc)./((Kb+Ks).*Ca_mmolm3); % L13 eqn 5

end
