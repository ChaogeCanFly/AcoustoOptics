function [SQR] = createSMatrix(order, type)
%----------------------------------
% Quadratic Residue
%----------------------------------
m = 0:10000;
possibleOrders = 4*m+3;
possiblePrimeOrders = possibleOrders(isprime(possibleOrders));
% userOrder = 19 ; %19 - 4 cycles, 76 - 1 cycle
I = find(possiblePrimeOrders >= order);
n = possiblePrimeOrders(I(1));
d =  (1:((n-1)/2)).^2;
qr = mod(d,n);

SQR = zeros(1,n);
SQR(1) = 1;
SQR(qr+1) = 1;

for i = 1:n-1
    SQR = [SQR; circshift(SQR(end,:),-1)];
end

% SQR = flip(SQR,1);
end

