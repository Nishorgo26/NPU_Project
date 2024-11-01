clear;

F = csvread('large_num_twd.csv');
in_a = (-255:1.5:255);
err     = (F(:,3))';

plot(in_a, err);
