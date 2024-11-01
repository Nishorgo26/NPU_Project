clear;

F = csvread('small_num_twd.csv');
in_a = (-1:0.0015:1);
err     = (F(:,3))';

plot(in_a, err);
