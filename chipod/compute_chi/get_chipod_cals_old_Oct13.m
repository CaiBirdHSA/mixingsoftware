function [cal,data,head]=get_chipod_cals(dpath,dpl,unit,ts,tf,depth,hpf_cutoff,use_n2,time_offset)
% [cal,data,head]=get_chipod_cals(dpath,unit,ts,tf)
% get clibrated chipod data and buoy current and from time ts to time tf
%
% dpath - data directory, i.e. '\\mserver\data\chipod\tao_sep05\'
% dpl - deployment name (string), i.e. 'or07b'
% unit - unit number, (integer) i.e. 305
% ts - start time, Matlab format
% tf - finish time, Matlab format
% depth - unit depth, it is necessarry for current data interpolation
% hpf_cutoff - hpf filter cutoff in Hz. - optional, but should be adjusted  
% for every cruise!!!  
%   $Revision: 1.18 $  $Date: 2012/12/28 21:15:52 $
clear vel disp
unitstr=num2str(unit);
if nargin<9
    time_offset=0;
end
if nargin<8
    use_n2=0;
end

[data,head]=get_chipod_raw(dpath,dpl,unit,ts,tf,time_offset);
if isempty(data)
    cal=[];
    return
end
[cal,head]=eval(['cali_chipod_' dpl '(data,head,unit)']);

[moor]=get_mooring(dpath,ts,tf,depth,dpl,unit);
if any(head.version==[16 32 48 64])
    cal.time_acc=interp1(1:length(cal.time),cal.time,[1:length(cal.AX)]/head.submax_oversample,'linear','extrap');
else
    cal.time_acc=cal.time(1:head.submax_oversample:end);
end
% interpolate water speed to Chipod time
fields=fieldnames(moor);fields=setdiff(fields,'curtime');
if use_n2==0
    fields=setdiff(fields,{'N2','dTdz'});
end
for ii=1:length(fields)
    cal.(char(fields(ii)))=interp1(moor.curtime,moor.(char(fields(ii))),cal.time_acc,'spline');
end
cal.cur_u=cal.u;cal.cur_v=cal.v;cal.curspd=cal.spd;
cal=rmfield(cal,{'u','v','spd'});
if size(cal.cur_u,1)~=size(cal.AX,1)
    for ii=1:length(fields)
        cal.(char(fields(ii)))=cal.(char(fields(ii)))';
    end
end
if any(head.version==[16 32 48 64]) && isfield(cal,'RX') && ~all(isnan(cal.CMP))
    % filter rate sensor data and get high-freq rotations
    cal=calc_filtered_rotations(cal,head);
    % calculate low-freq rotations from accelerometer data
    cal=calc_lp_rotations(cal,head);
    % Remove gravitational part from acceleration measurements
    cal.roll=cal.rlp+cal.alphaX;cal.roll=fillgap(cal.roll,1);
    cal.pitch=cal.plp+cal.alphaY;cal.pitch=fillgap(cal.pitch,1);
    cal.yaw=cal.ylp+cal.alphaZ;cal.yaw=fillgap(cal.yaw,1);
    cal=remove_gravitation(cal,head);
    % compute mean yaw and mean compass angles
    ttt=exp(sqrt(-1)*cal.yaw*pi/180);
    uyaw=real(ttt); vyaw=imag(ttt);
    meanyaw=atan2(nanmean(vyaw),nanmean(uyaw))*180/pi;
    meanyaw(meanyaw<0)=meanyaw(meanyaw<0)+360;
    ttt=exp(sqrt(-1)*cal.CMP*pi/180);
    ucmp=real(ttt); vcmp=imag(ttt);
    meancmp=atan2(nanmean(vcmp),nanmean(ucmp))*180/pi;
    meancmp(meancmp<0)=meancmp(meancmp<0)+360;
    % rotate yaw to correspond to compass
    % we subtract compass reading because compass is in left-hand coordinate
    % system (alphaZ is a mirrow image of compass)
    cal.yaw=cal.yaw-meanyaw-meancmp;
    % add 90 degrees because axis X (u component of velocity) points East (not North)
    cal.yaw=cal.yaw+90;
    cal.yaw(cal.yaw>180)=cal.yaw(cal.yaw>180)-360;
    cal.yaw(cal.yaw<=-180)=cal.yaw(cal.yaw<=-180)+360;
    % translate current components to BCS. We assume that we know pitch and
    % roll of Chipod relatively to LCS. Using these data we can translate
    % current vector to BCS at each time step.
    r=cal.roll;
    p=cal.pitch;
    y=cal.yaw;
    if size(r,2)>1; r=r';p=p';y=y'; end
    curu=cal.cur_u;
    curv=cal.cur_v;
    curw=0*curu;
    if size(curu,2)>1;curu=curu';curv=curv';curw=curw';end
    [cal.cur_x cal.cur_y cal.cur_z] = translatevectorrpy([-r -p -y],[curu curv curw],'degrees');
    if size(cal.cur_x,1)~=size(cal.AX,1)
        cal.cur_x=cal.cur_x';
        cal.cur_y=cal.cur_y';
        cal.cur_z=cal.cur_z';
    end
    r1tip=1.818*2.54/100;% distance from cable to shorter sensor tip
    ra=3.3*0.0254;% distance from accelerometer package to cable 
    dyawdt=gradient(cal.yaw*pi/180,1/head.samplerate(head.sensor_index.R1));dyawdt=deglitch(dyawdt,30,2);dyawdt=fillgap(dyawdt,1);
    cal.r1omega=(ra+r1tip)*dyawdt;
    % Calculate Chipod motion in BCS
    [disp,vel]=integrate_acc(cal,head,hpf_cutoff);
    cal.dispx=disp.x;
    cal.dispy=disp.y;
    cal.dispz=disp.z;
    cal.velx=vel.x;
    cal.vely=vel.y;
    cal.velz=vel.z;
    cal.fspd=sqrt((cal.velx-cal.cur_x).^2+(cal.vely-(cal.cur_y+cal.r1omega)).^2+...
        (cal.velz-cal.cur_z).^2);
    % Transform accelerations from BCS to ENU - A(e,n,u)=R(r,p,y)*A(x,y,z)
    AX=cal.AX;if size(AX,2)>1;AX=AX';end
    AY=cal.AY;if size(AY,2)>1;AY=AY';end
    AZ=cal.AZ;if size(AZ,2)>1;AZ=AZ';end
    [cal.AE cal.AN cal.AU] = translatevectorrpy([r p y],[AX AY AZ],'degrees');
    if size(cal.AE,1)~=size(cal.AX,1);cal.AE=cal.AE';cal.AN=cal.AN';cal.AU=cal.AU';end
    % Calculate Chipod motion in ENU
    temp.AX=cal.AE;
    temp.AY=cal.AN;
    temp.AZ=cal.AU;
    temp.AX=fillgap(cal.AX);
    temp.AY=fillgap(cal.AY);
    temp.AZ=fillgap(cal.AZ);
    [disp,vel]=integrate_acc(temp,head,hpf_cutoff);
    cal.dispe=disp.x;
    cal.dispn=disp.y;
    cal.dispu=disp.z;
    cal.vele=vel.x;
    cal.veln=vel.y;
    cal.velu=vel.z;
elseif ~all(isnan(cal.CMP))
    % here we compute fall speed using compass as yaw and
    % low-passed pitch and roll (the closest to we can get without rate sensors):
    % (components of current in Chipod coordinate system)
    % calculate low-freq rotations from accelerometer data
    cal=calc_lp_rotations(cal,head);
    % Remove gravitational part from acceleration measurements
    cal.roll=cal.rlp;cal.roll=fillgap(cal.roll,1);
    cal.pitch=cal.plp;cal.pitch=fillgap(cal.pitch,1);
    cal=remove_gravitation(cal,head);
    [time itime]=unique(cal.time_acc(1:head.samplerate(head.sensor_index.AX)/head.slow_samp_rate:end)-1/86400);
    cmp=exp(sqrt(-1)*cal.CMP(itime)*pi/180);
    cmpu=real(cmp); cmpv=imag(cmp);
    cmpu=interp1(time,cmpu,cal.time_acc,'linear','extrap');
    cmpv=interp1(time,cmpv,cal.time_acc,'linear','extrap');
    CMP_fast=atan2(cmpv,cmpu)*180/pi;
    cal.cur_x=cal.cur_u.*sind(CMP_fast)+cal.cur_v.*cosd(CMP_fast);
    cal.cur_y=-cal.cur_u.*cosd(CMP_fast)+cal.cur_v.*sind(CMP_fast);
    r1tip=1.818*2.54/100;% distance from cable to shorter sensor tip
    ra=3.3*0.0254;% distance from accelerometer package to cable 
    dyawdt=gradient(-CMP_fast*pi/180,1/head.samplerate(head.sensor_index.AX));dyawdt=deglitch(dyawdt,30,2);dyawdt=fillgap(dyawdt,1);
    if isnan(dyawdt(1)); dyawdt(1)=dyawdt(2);end
    if isnan(dyawdt(end)); dyawdt(end)=dyawdt(end-1);end
    cal.r1omega=(ra+r1tip)*dyawdt;
    cal.AX=fillgap(cal.AX);
    cal.AY=fillgap(cal.AY);
    cal.AZ=fillgap(cal.AZ);
    [disp,vel]=integrate_acc(cal,head,hpf_cutoff);
    cal.velz=vel.z;
    cal.vely=vel.y;
    cal.velx=vel.x;
    cal.dispz=disp.z;
    cal.dispy=disp.y;
    cal.dispx=disp.x;
    % calculate fallspeed
    cal.fspd=sqrt((cal.velx-cal.cur_x).^2+(cal.vely-(cal.cur_y+cal.r1omega)).^2+cal.velz.^2);
    if isfield(data,'W1')
        r2tip=3.76*2.54/100;% distance from longer sensor tip (3 pitot unit)to cable
        cal.r1omega_3P=(ra+r2tip)*dyawdt;
        cal.fspd_3P=sqrt((cal.velx-cal.cur_x).^2+(cal.vely-(cal.cur_y+cal.r1omega_3P)).^2+cal.velz.^2);
    end
else
    cal.cur_x=NaN*cal.cur_u;
    cal.cur_y=NaN*cal.cur_u;
    % calculate low-passed pitch and roll from accelerometer data
    cal=calc_lp_rotations(cal,head);
    % Remove gravitational part from acceleration measurements
    cal.roll=cal.rlp;cal.roll=fillgap(cal.roll,1);
    cal.pitch=cal.plp;cal.pitch=fillgap(cal.pitch,1);
    cal=remove_gravitation(cal,head);
    cal.AX=fillgap(cal.AX);
    cal.AY=fillgap(cal.AY);
    cal.AZ=fillgap(cal.AZ);
    [disp,vel]=integrate_acc(cal,head,hpf_cutoff);
    cal.velz=vel.z;
    cal.vely=vel.y;
    cal.velx=vel.x;
    cal.dispz=disp.z;
    cal.dispy=disp.y;
    cal.dispx=disp.x;
    cal.fspd=sqrt((cal.curspd+cal.velx).^2+cal.vely.^2+cal.velz.^2);
end

data.T1P=data.T1P-nanmean(data.T1P);
data.T2P=data.T2P-nanmean(data.T2P);

cal.T1Px=calibrate_tp(data.T1P,head.coef.T1P,data.T1,head.coef.T1,100*cal.fspd');
cal.T2Px=calibrate_tp(data.T2P,head.coef.T2P,data.T2,head.coef.T2,100*cal.fspd');
cal.T1Pt=calibrate_tp(data.T1P,head.coef.T1P,data.T1,head.coef.T1,100*ones(size(cal.fspd')));
cal.T2Pt=calibrate_tp(data.T2P,head.coef.T2P,data.T2,head.coef.T2,100*ones(size(cal.fspd')));

