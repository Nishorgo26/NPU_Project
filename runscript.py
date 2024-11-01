import subprocess
import os
import tkinter as tk
from tkinter import filedialog

root = tk.Tk()
root.withdraw()

file_path = filedialog.askopenfilename()

if file_path == "":
    print("No input file selected. Program exiting...\n")
    quit()
    
file_path = file_path.split('/samples/')[1]
print(file_path)

if os.path.isfile("fifo_output_float.txt"):
    os.remove("fifo_output_float.txt")
if os.path.isfile("fifo_output.txt"):
    os.remove("fifo_output.txt")

os.chdir('project')

with open('dofile.do', 'r') as file:
    # read a list of lines into data
    data = file.readlines()
file.close()
    
data[2] = "vsim -quiet work.testbench +INPUTFILE=" + file_path + '\n'

with open('dofile.do', 'w') as file:
    file.writelines( data )
file.close()

os.system('cmd /c "vsim -c -do dofile.do"')
os.chdir('../')
subprocess.run(["python", "fifo_bin_2_float.py"])

with open('fifo_output_float.txt', 'r') as file:
    # read a list of lines into data
    output_data = file.readlines()
file.close()

i = 0

print("\n\n+--------------------------------------------------------+")
print("|                      Final Report                      |")
print("+--------------------------------------------------------+\n")
print("\n\tInput file : " + file_path)
print("\n\tExpected number: " + file_path[-5])
print("\n\tOutput results: ")

for line in output_data:
    print('\t\t[' + str(i) + '] : ' + line, end="")
    i=i+1