function [moor]=get_mooring(dpath,ts,tf,depth,dpl,varargin)
% function [moor]=get_mooring(dpath,ts,tf,depth,dpl,varargin)
% dpath - data directory, i.e. '\\mserver\data\chipod\tao_sep05\'
% ts - start time, Matlab format
% tf - finish time, Matlab format
% depth - unit depth, it is used to get current correcpoding ADCA depth bin
% dpl - deployment ID, e.g. 'tao_aug06'
% Optional arguments should appear in the following order:
% Chipod unit number (integer), i.e. 520
% current data should be either sufficiently filtered or averaged so that
% it does not include wind waves and swell
%   $Revision: 1.1 $  $Date: 2012/12/28 21:18:21 $

if ~isempty(varargin)
    unit=num2str(varargin{1});
end
if exist([dpath '\mooring_data\mooring_' dpl '.mat'])
    load([dpath '\mooring_data\mooring_' dpl '.mat']);
else
    load([dpath '\mooring_data\mooring_' dpl '_' unit]);
end
fields=fieldnames(moor);
moor1=moor;
clear moor;
if size(moor1.u,1)<size(moor1.u,2)
    for ii=1:length(fields)
        moor1.(char(fields(ii)))=moor1.(char(fields(ii)))';
    end
end    
idt=find(moor1.time>(ts-1/24) & moor1.time<(tf+1/24));
moor.curtime=moor1.time(idt);
if size(moor1.depth,2)>1
    [c,idz]=min(abs(nanmean(moor1.depth,1)-depth));
else
    idz=1;
end
fields1=setdiff(fields,{'depth','time','readme'});
for ii=1:length(fields1)
    moor.(char(fields1(ii)))=moor1.(char(fields1(ii)))(idt,idz);
end
% speed2=moor.u.^2+moor.v.^2+moor.w.^2;
speed2=moor.u.^2+moor.v.^2;
speed=sqrt(speed2);
moor.spd=speed;
theta=atan2(moor.u,moor.v).*180./pi;
idtheta=find(theta<0);
theta(idtheta)=theta(idtheta)+360;
moor.dir=theta;
