import pandas as pd
import numpy as np
import matplotlib.pylab as plt

a = pd.read_csv('input_data.csv')

print(a.values)

fig, ax = plt.subplots(figsize=(10, 6))
ax.plot(a.values, linestyle='-', color='b', label='Data Points')
ax.set_title('Input Data Plot')

plt.show()
