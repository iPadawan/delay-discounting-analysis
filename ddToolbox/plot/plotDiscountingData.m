
function plotDiscountingData(data)
hold on
opts.maxlogB	= max( abs(data.B) );
opts.maxD		= max( data.DB );

% find unique experimental designs
D=[abs(data.A), abs(data.B), data.DA, data.DB];
[C, ia, ic] = unique(D,'rows');
%loop over unique designs (ic)
for n=1:max(ic)
	% binary set of which trials this design was used on
	myset=ic==n;
	% Size = number of times this design has been run
	F(n) = sum(myset);
	% Colour = proportion of times that participant chose immediate
	% for that design
	COL(n) = sum(data.R(myset)==0) ./ F(n);
	
	%x(n) = abs(p.Results.data.B( ia(n) )); % �B
	x(n) = data.DB( ia(n) ); % delay to get �B
	y(n) = abs(data.A( ia(n) )) ./ abs(data.B( ia(n) ));
end

% plot
for i=1:max(ic)
	h = plot(x(i), y(i),'o');
	h.Color='k';
	h.MarkerFaceColor=[1 1 1] .* (1-COL(i));
	h.MarkerSize = F(i)+4;
	hold on
end

xlabel('delay, $D^B$', 'interpreter','Latex')
%ylabel('$|A|/|B|$', 'interpreter','Latex')

xlim([0 opts.maxD*1.1])
%ylim([0 1])
box off
end
