clear;
F = csvread('large_num.csv');
in_a    = -255:1.5:255;
in_b    = -255:1.5:255;
err     = (F(:,3))';
err_mat = reshape(err, 341, 341);

mesh(in_a, in_b, err_mat);
