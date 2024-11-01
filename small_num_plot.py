import numpy as np
import matplotlib.pyplot as plt

filename = 'small_num_twd.csv'

try:
    F = np.loadtxt(filename, delimiter=',')
except OSError:
    raise FileNotFoundError(f"File '{filename}' does not exist.")
except ValueError:
    raise ValueError(f"Error reading file '{filename}'. Ensure it is a valid CSV.")

in_a = np.arange(-1, 1, 0.0015)

if F.shape[1] >= 3:
    err = F[:, 2]
else:
    raise ValueError("CSV file does not have at least 3 columns.")

if len(in_a) != len(err):
    raise ValueError("Dimensions of in_a and err do not match.")

plt.figure()
plt.plot(in_a, err)
plt.xlabel('Input A')
plt.ylabel('Error(%)')
plt.title('Plot of Error(%) vs. Input A with a Fixed Input B of 0.001')
plt.grid(True)
plt.show()

