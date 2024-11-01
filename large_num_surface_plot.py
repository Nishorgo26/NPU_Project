import numpy as np
import matplotlib.pyplot as plt

F = np.loadtxt('large_num.csv', delimiter=',')

err = F[:, 2]

step_size = 1.5
range_values = np.arange(-255, 255 + step_size, step_size)

in_a, in_b = np.meshgrid(range_values, range_values)

err_mat = np.reshape(err, (len(range_values), len(range_values)))

fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
ax.plot_surface(in_a, in_b, err_mat, cmap='viridis')

ax.set_xlabel('Input A')
ax.set_ylabel('Input B')
ax.set_zlabel('Error(%)')

plt.show()

