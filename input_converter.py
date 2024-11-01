import struct
import numpy as np

# opening the file in read mode 
input_file = open("weights_op.txt", "r") 
inputs = input_file.read() 
input_list = inputs.split('\n')
input_file.close() 

# decimal_input=[]

decimal_input_file = open("decimal_weights_op.txt", "w") 
decimal_input_file.write('')
decimal_input_file.close()

decimal_input_file = open("decimal_weights_op.txt", "a") 

for input in input_list:
    y = struct.pack("H",int(input,2))
    float = np.frombuffer(y, dtype =np.float16)[0]
    decimal_input_file.write(str(float)+'\n')

decimal_input_file.close()