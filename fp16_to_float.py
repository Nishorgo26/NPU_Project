import struct
import numpy as np

# opening the file in read mode 
input_file = open("fifo_output.txt", "r") 
inputs = input_file.read() 
input_list = inputs.split('\n')
input_file.close() 

# decimal_input=[]

# output_file = open("fifo_output_float.txt", "w") 
# output_file.write('')
# output_file.close()
# output_file = open("fifo_output_float.txt", "a") 

for input in input_list:
    if input == 'xxxxxxxxxxxxxxxx':
        break
    y = struct.pack("H",int(input,2))
    float = np.frombuffer(y, dtype =np.float16)[0]
    print(str(input) + ' | ' + str(float))