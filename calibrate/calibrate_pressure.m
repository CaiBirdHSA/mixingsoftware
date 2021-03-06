function calibrate_pressure(fname)
% Function to calibrate Chipod or Chameleon pressure sensor
% loads 2 column ASCII file
% 1st column - Pressure [PSI]
% 2nd column - Counts or Volts
% uses fname to create .png images with callibration coefficients\
%   $Revision: 1.1.1.1 $  $Date: 2011/05/17 18:08:05 $
%
% sjw note (April 2014):
% I'm confused as to which is the right version of this code, this one or
% the one which I have renamed calibrate_pressure_old_July2013. This
% version has a rewer date stamp, but the change seems to be backwards. In
% the comments above it says PSI in the first column and volts or counts in
% the second. The code has explicitely been changed to be the opposite of
% that with psi in the second column and volts or counts in the second
% column. Whoever made this change left no comments to explain why they had
% changed the indexing. ugh.

a=load(fname);
psi=a(:,2);
if mean(a(:,1))>100
    counts=a(:,1);
    % convert counts to Volts
    volts=(counts/65536.0)*4.096;
else
    volts=a(:,1);
end
% least square fit
[p1,s1]=polyfit(volts,psi,1);
fits1=polyval(p1,volts);
% robust linear regression
[p2,s2]=robustfit(volts,psi);
p2=flipud(p2);
fits2=polyval(p2,volts);
% figure(1);
figure('units','normalized','outerposition',[0 0 1 1])
subplot(2,1,1)
plot(volts,psi,'r<',volts,fits1,'b-',volts,fits2,'k-')
xlabel('Volts')
ylabel('Pressure [PSI]')
legend('Data Points','Least Square Fit','Robust Fit','location','SE')
grid on
name=fname(1:end-4);
name(name=='_')='-';
[ttle,err]=sprintf('%s Pressure Cal. LSF: PSI =%.4f+%.4f*V  RF: PSI =%.4f+%.4f*V',name,p1(2),p1(1),p2(2),p2(1));

title(ttle);
subplot(2,1,2)
[ttle,err]=sprintf('Fit Minius Actual Values');
title(ttle);
plot(volts,fits1-psi,'b*',volts,fits2-psi,'k*');
xlabel('Volts')
ylabel('Diff Pressure (Fit-Data) [PSI]')
grid on
legend('Least Square Fit','Robust Fit','location','best')
multi_print(fname(1:end-4),'png','same','-r200')

